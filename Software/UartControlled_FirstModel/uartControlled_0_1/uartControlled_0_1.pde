/*
Initial program to control the LipLabz balm machine.

Date: May 16th 2011
By: Pascal Ethier

Copyright 2011 Lip Labz

6 input flavours
6 Multiplexed 2 ports output to Uart to control 6 Motor Drivers.
One start button
One Stop/Reset button

*/

// **** Pin definitions ****
//Motor select Multiplexing
#define PIN_MUX_A 2
#define PIN_MUX_B 3
#define PIN_MUX_C 4

//Flavour select lights
#define PIN_LIGHT_1 8
#define PIN_LIGHT_2 9
#define PIN_LIGHT_3 10
#define PIN_LIGHT_4 11
#define PIN_LIGHT_5 12
#define PIN_LIGHT_6 13

//Flavour select pins, use analog inputs
#define PIN_INPUT_FLAV_1 0
#define PIN_INPUT_FLAV_2 1
#define PIN_INPUT_FLAV_3 2
#define PIN_INPUT_FLAV_4 3
#define PIN_INPUT_FLAV_5 4
#define PIN_INPUT_FLAV_6 5

#define PIN_INPUT_START 7
#define PIN_INPUT_STOP 6

// **** Stepper control commands ****
#define CMD_OFF "F"
#define CMD_ON "O"
#define CMD_RUN "G"
#define CMD_BRAKE "B"
#define CMD_CW ">"
#define CMD_CCW "<"
#define CMD_ENCODER "E"
#define CMD_RESET "R"
#define CMD_TRACK "T"
#define CMD_SPEED "S"
#define CMD_MODE "M"
#define MODE_FULL 1
#define MODE_HALF 2

#define DIR_UP CMD_CW
#define DIR_DOWN CMD_CCW

// **** CONSTANTS ****
#define ANALOG_THRESHOLD 900
#define NUMBER_OF_FLAVOURS 6
#define MAX_STEPS_FILL_TUBE 2600
#define MOTOR_RUN_MODE 1
#define UART_DELAY 100
#define MOTOR_TIMEOUT 1
#define MOTOR_SPEED 200
#define MOTOR_SELECT_STEPS 10
#define MOTOR_PREP_STEPS 200

boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
int HowManyFlavoursSelected = 0;


void setup() {
  delay(2000);
  //Init serial
  Serial.begin(9600); 
  
  //Set input/output modes
  pinMode(PIN_MUX_A, OUTPUT);
  pinMode(PIN_MUX_B, OUTPUT);
  pinMode(PIN_MUX_C, OUTPUT);
  
  pinMode(PIN_INPUT_FLAV_1, INPUT);
  pinMode(PIN_INPUT_FLAV_2, INPUT);
  pinMode(PIN_INPUT_FLAV_3, INPUT);
  pinMode(PIN_INPUT_FLAV_4, INPUT);
  pinMode(PIN_INPUT_FLAV_5, INPUT);
  pinMode(PIN_INPUT_FLAV_6, INPUT);
  
  pinMode(PIN_INPUT_START, INPUT);
  pinMode(PIN_INPUT_STOP, INPUT);
  
  InitializeSequence();
}

void loop() {
  
  WaitForUserInputs();
  
  Pour();
  
  CleanUp();
  
}

void InitializeSequence()
{
  ResetAllFlavours();
  delay(1000);
  SelfTest_Motors();
}

void SelfTest_Motors()
{
  //Select each motor and pulse them down, then pulse them up
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    SelectMotor(i);
    RunMotor(MOTOR_SELECT_STEPS,DIR_DOWN);
    RunMotor(MOTOR_SELECT_STEPS,DIR_UP);
  }
}

void ResetAllFlavours()
{
  //Set the selected flavour array to all False
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    SelectedFlavours[i] = false;
  }
  HowManyFlavoursSelected = 0;
}

void DumpSelectedFlavour()
{
  Serial.println();
  Serial.println("Selected Flavours:");
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(SelectedFlavours[i])
      Serial.println("Flavour " + String(i) + " selected");
  }    
}

void WaitForUserInputs()
{
    unsigned long count = 0;
  
waitForFlavourOnly:
  //First, wait for at least one flavour to be selected
  while(HowManyFlavoursSelected < 1)
  {
    ReadInFlavourButtons(); 
     count++;  
    if(count % 1000 == 0)
      DumpSelectedFlavour();
    
  }
  
waitForGo:
  //Now wait for either an extra flavour to be selected/deselected
  //But also check the "GO" button or reset
  while(digitalRead(PIN_INPUT_START) != HIGH)
  {
    ReadInFlavourButtons();
    if(digitalRead(PIN_INPUT_STOP) == HIGH || HowManyFlavoursSelected == 0)
    {
      ResetAllFlavours();
      goto waitForFlavourOnly;
    }
    count++;
    if(count % 1000 == 0)
      DumpSelectedFlavour();

  }
  
  PrepSelectedMotors();
  Pour();
  ResetSelectedMotors();
  
}

void PrepSelectedMotors()
{
  //initialize each selected motor and
  //move 20 steps
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(SelectedFlavours[i])
    {
      SelectMotor(i);
      RunMotor(MOTOR_PREP_STEPS, DIR_DOWN);
    }
  }
}

void ResetSelectedMotors()
{
  //initialize each selected motor and
  //move 20 steps
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(SelectedFlavours[i])
    {
      SelectMotor(i);
      RunMotor(MOTOR_PREP_STEPS, DIR_UP);
    }
  }
}


// Proceed with the pouring sequence until end reached or
// user interrupted
void Pour()
{
  //Calculate number of steps per flavour based on number of flavours selected.
  int totalStepsPerFlavour = MAX_STEPS_FILL_TUBE / HowManyFlavoursSelected;
  int stepsPerformed = 0;
  
  while(digitalRead(PIN_INPUT_STOP) == LOW && stepsPerformed < MAX_STEPS_FILL_TUBE)
  {
    for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
    {
      if(digitalRead(PIN_INPUT_STOP) == HIGH)
        break;
      if(SelectedFlavours[i])
      {
        SelectMotor(i);
        RunMotor(MOTOR_PREP_STEPS, DIR_UP);
      }
    }
    stepsPerformed += totalStepsPerFlavour;
  }
  
  
}

void RunMotor(unsigned long howManySteps, char* dir)
{
  //set direction
  Serial.print(dir);
  delay(UART_DELAY);
  Serial.print(CMD_RESET);
  delay(UART_DELAY);
//  Serial.print(CMD_SPEED);
//  Serial.print(MOTOR_SPEED);
//    delay(UART_DELAY);
//  Serial.print(CMD_MODE);
//  Serial.print(MOTOR_RUN_MODE);
//    delay(UART_DELAY);  
  Serial.print(CMD_ON);
  delay(UART_DELAY);
  Serial.print(CMD_RUN);
  unsigned long startTime = millis();
  unsigned long timeNow = millis();
  unsigned int encoderValue = 0;
  
  
  //*** Use Tracker method ***
  encoderValue = howManySteps;
  Serial.print(CMD_TRACK);
  delay(UART_DELAY);  
  Serial.print(highByte(encoderValue));
  delay(UART_DELAY);  
  Serial.print(lowByte(encoderValue));
  delay(MOTOR_TIMEOUT * howManySteps);
  //delay(UART_DELAY);  
  //Serial.print(CMD_RUN);
  //*****************************
  
//  //*** Use Encoder method ***
//  while((timeNow - startTime < MOTOR_TIMEOUT) && encoderValue < howManySteps)
//  {
//    Serial.flush();
//    Serial.print(CMD_ENCODER);
//    delay(UART_DELAY);
//    encoderValue = B00000000;
//    encoderValue = encoderValue << 8;
//    encoderValue &= B00000000;
//    unsigned int highBits = Serial.read();
//    delay(UART_DELAY);
//    highBits = highBits << 8;
//    highBits &= 65280;
//    byte lowBits = Serial.read();
//    lowBits &= 255;
//    encoderValue = highBits ^ lowBits;
//    //Debug
//    Serial.println();
//    Serial.println("time: " + String(timeNow) + ", start: " + String(startTime));
//    Serial.println("highBits: " + String(highBits,BIN) + ",lowBits: " + String(lowBits,BIN));
//    Serial.println("encoder: " + String(encoderValue,BIN));
//    
//    delay(200);    
//    timeNow = millis();
//  }
  
  Serial.print(CMD_BRAKE);
  delay(UART_DELAY);
  Serial.print(CMD_OFF);
  //***********************************
  
}

//Perform cleanup steps at the end of a pouring sequence
void CleanUp()
{
  
}

void ReadInFlavourButtons()
{
  HowManyFlavoursSelected = 0;
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    //XOR operator "^" will set a selected flavour to false if it was selected and the button is pressed again
    //It will set it to true if the flavour was not previously selected
    if(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
    {
      SelectedFlavours[i] = SelectedFlavours[i] ^ IsAnalogInputThresholdMet(FlavourSelectInputs[i]);
      if(SelectedFlavours[i])
      {      
        //Pulse that motor
        SelectMotor(i);
        RunMotor(MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(200);
        RunMotor(MOTOR_SELECT_STEPS,DIR_UP);
      } else
      {
        //Pulse that motor
        SelectMotor(i);
        RunMotor(MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(1000);
        RunMotor(MOTOR_SELECT_STEPS,DIR_UP);        
      }
      //Wait until button is released
      while(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
      {
        
      }
    }
    HowManyFlavoursSelected++;
  }
   
}



//Returns true if the value measured at a specified input is above the 
//predetermined Threshold.
boolean IsAnalogInputThresholdMet(int analogPin)
{
  return analogRead(analogPin) > ANALOG_THRESHOLD;  
}

void SelectMotor(int motorNumber)
{
  //Select  the appropriate MUX channel
  switch(motorNumber) {
    case 1:
      digitalWrite(PIN_MUX_A,LOW);
      digitalWrite(PIN_MUX_B,LOW);
      digitalWrite(PIN_MUX_C,LOW);
      break;
      
    case 2:
      digitalWrite(PIN_MUX_A,HIGH);
      digitalWrite(PIN_MUX_B,LOW);
      digitalWrite(PIN_MUX_C,LOW);
      break;
    
    case 3:
      digitalWrite(PIN_MUX_A,LOW);
      digitalWrite(PIN_MUX_B,HIGH);
      digitalWrite(PIN_MUX_C,LOW);
      break;
      
    case 4:
      digitalWrite(PIN_MUX_A,HIGH);
      digitalWrite(PIN_MUX_B,HIGH);
      digitalWrite(PIN_MUX_C,LOW);
      break;
      
    case 5:
      digitalWrite(PIN_MUX_A,LOW);
      digitalWrite(PIN_MUX_B,LOW);
      digitalWrite(PIN_MUX_C,HIGH);
      break;
     
    case 6:
      digitalWrite(PIN_MUX_A,HIGH);
      digitalWrite(PIN_MUX_B,LOW);
      digitalWrite(PIN_MUX_C,HIGH);
      break;      
  }
  
}
