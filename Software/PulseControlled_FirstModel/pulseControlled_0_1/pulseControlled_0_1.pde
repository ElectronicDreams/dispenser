/*
Initial program to control the LipLabz balm machine.

Date: June 9th 2011
By: Pascal Ethier

Copyright 2011 Lip Labz

6 input flavours
6 Multiplexed 2 ports output to pulse to control N Motor Drivers.
One start button
One Stop/Reset button

*/

//// **** Pin definitions ****

#define PIN_MOTOR_SH 12
#define PIN_MOTOR_ST 13

//Motor Driver Pins
#define PIN_MOTOR_EN 11
#define PIN_MOTOR_DIR 8
#define PIN_MOTOR_PULSE 9


////Flavour select lights
//#define PIN_LIGHT_1 8
//#define PIN_LIGHT_2 9
//#define PIN_LIGHT_3 10
//#define PIN_LIGHT_4 11
//#define PIN_LIGHT_5 12
//#define PIN_LIGHT_6 13

//Flavour select pins, use analog inputs
#define PIN_INPUT_FLAV_1 0
#define PIN_INPUT_FLAV_2 1
#define PIN_INPUT_FLAV_3 2
#define PIN_INPUT_FLAV_4 3
#define PIN_INPUT_FLAV_5 4
#define PIN_INPUT_FLAV_6 5

#define PIN_INPUT_START 6
#define PIN_INPUT_STOP 5

#define DIR_UP HIGH
#define DIR_DOWN LOW

// **** CONSTANTS ****
#define ANALOG_THRESHOLD 900
#define NUMBER_OF_FLAVOURS 6
#define MAX_STEPS_FILL_TUBE 22000 //16 seconds for a full tube

#define MOTOR_SELECT_STEPS 200
#define MOTOR_PREP_STEPS 500
#define MOTOR_RUN_STEPS_PER_CYCLE 200

boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
int HowManyFlavoursSelected = 0;


void setup() {
  Serial.begin(9600);
  
  //Set input/output modes
  pinMode(PIN_MOTOR_ST, OUTPUT);
  pinMode(PIN_MOTOR_SH, OUTPUT);
  
  pinMode(PIN_MOTOR_EN, OUTPUT);
  pinMode(PIN_MOTOR_DIR, OUTPUT);
  pinMode(PIN_MOTOR_PULSE, OUTPUT);
  
  
  pinMode(PIN_INPUT_FLAV_1, INPUT);
  pinMode(PIN_INPUT_FLAV_2, INPUT);
  pinMode(PIN_INPUT_FLAV_3, INPUT);
  pinMode(PIN_INPUT_FLAV_4, INPUT);
  pinMode(PIN_INPUT_FLAV_5, INPUT);
  pinMode(PIN_INPUT_FLAV_6, INPUT);
  
  pinMode(PIN_INPUT_START, INPUT);
  pinMode(PIN_INPUT_STOP, INPUT);

  //Set speed
  //setPwmFrequency(9,4);
  
  //Disable all motors
   StopAllMotors();
  
    delay(2000);
  
  //Permanently output a PWM output to the MOTOR_PIN_PULSE
  analogWrite(PIN_MOTOR_PULSE, 175);
  
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
  SelfTest_Motors();
}

void SelfTest_Motors()
{
  //Select each motor and pulse them down, then pulse them up
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    RunMotor(i + 1,MOTOR_SELECT_STEPS,DIR_DOWN);
    RunMotor(i + 1,MOTOR_SELECT_STEPS,DIR_UP);
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
  Serial.print("Number of flavours selected: ");
  Serial.println(HowManyFlavoursSelected); 
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
    {
      count = 0;
      Serial.println("WAITING FOR FLAVOUR");      
      DumpSelectedFlavour();
    }
    
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
    {
      count = 0;
      Serial.println("WAITING FOR START");      
      DumpSelectedFlavour();
    }

  }
  
}

void PrepSelectedMotors()
{
  //initialize each selected motor and
  //move 20 steps
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(SelectedFlavours[i])
    {
      RunMotor(i + 1,MOTOR_PREP_STEPS, DIR_DOWN);
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
      RunMotor(i + 1,MOTOR_PREP_STEPS, DIR_UP);
    }
  }
}


// Proceed with the pouring sequence until end reached or
// user interrupted
void Pour()
{
    
  PrepSelectedMotors();
  
  //Calculate number of steps per flavour based on number of flavours selected.
  //int totalStepsPerFlavour = MAX_STEPS_FILL_TUBE / HowManyFlavoursSelected;
  
  int stepsPerformed = 0;
  boolean stopRequested = false;
  
  while(digitalRead(PIN_INPUT_STOP) == LOW && stepsPerformed < MAX_STEPS_FILL_TUBE)
  {
    for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
    {
      if(digitalRead(PIN_INPUT_STOP) == HIGH)
        goto stop_Pouring;
      if(SelectedFlavours[i])
      {
        RunMotor(i+1,MOTOR_RUN_STEPS_PER_CYCLE, DIR_DOWN);
        stepsPerformed += MOTOR_RUN_STEPS_PER_CYCLE;
      }
      if(digitalRead(PIN_INPUT_STOP) == HIGH)
        goto stop_Pouring;
        
    }

  }

stop_Pouring:  
  StopAllMotors();
  
  ResetSelectedMotors(); 
}

void RunMotor(int motorNumber, unsigned long runDuration, int dir)
{
  //set direction
  digitalWrite(PIN_MOTOR_DIR,dir);

  unsigned long startTime = millis();
  unsigned long timeNow = millis();
  unsigned int stepCount = 0;

    Serial.println("");
    
    Serial.print("Running Motor ");
    Serial.println(motorNumber);
    Serial.print("Direction: ");
    Serial.println(dir);
    Serial.print("Duration: ");
    Serial.println(runDuration);
    
    SelectMotor(motorNumber);
    delay(runDuration);
    SelectMotor(0);

}

void RunMotor(int motorNumber,int dir)
{
  //set direction
  digitalWrite(PIN_MOTOR_DIR,dir); 
  SelectMotor(motorNumber);
   
}

void StopAllMotors()
{
  SelectMotor(0);
}

//Perform cleanup steps at the end of a pouring sequence
void CleanUp()
{
  ResetAllFlavours();
}

void ReadInFlavourButtons()
{
  
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    int selectedMotor = i + 1;
    //XOR operator "^" will set a selected flavour to false if it was selected and the button is pressed again
    //It will set it to true if the flavour was not previously selected
    if(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
    {
      SelectedFlavours[i] = SelectedFlavours[i] ^ true;
      if(SelectedFlavours[i])
      {      
        HowManyFlavoursSelected++;
        //Pulse that motor
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(100);
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_UP);
        //Wait until button is released
        while(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
        {
          RunMotor(selectedMotor,DIR_DOWN);
        }
        StopAllMotors();
        
      } else
      {
        HowManyFlavoursSelected--;
        //Pulse that motor
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(1000);
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_UP);  
  
        //Wait until button is released
        while(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
        {
          RunMotor(selectedMotor,DIR_UP);
        }
        StopAllMotors();      
      }

    }
    
  }
   
}



//Returns true if the value measured at a specified input is above the 
//predetermined Threshold.
boolean IsAnalogInputThresholdMet(int analogPin)
{
  return analogRead(analogPin) > ANALOG_THRESHOLD;  
}

//motorNumber to 0 to stop nall motors
void SelectMotor(int motorNumber)
{
  Serial.print("Selecting Motor ");
  Serial.println(motorNumber);
  
  byte motorSelect = 0;
  
  if(motorNumber > 0)
    bitSet(motorSelect, motorNumber-1);
    
  motorSelect |= B00000000;
  
  Serial.print("Value of motorSelect: ");
  Serial.println(motorSelect,BIN);
    
  //Shift the value out to enable only the selected motor
  digitalWrite(PIN_MOTOR_ST, LOW);
  digitalWrite(PIN_MOTOR_SH, LOW);
  
  shiftOut(PIN_MOTOR_EN, PIN_MOTOR_SH, MSBFIRST, motorSelect);
  
  digitalWrite(PIN_MOTOR_ST, HIGH);
} 
  void setPwmFrequency(int pin, int divisor) {
    byte mode;
    if(pin == 5 || pin == 6 || pin == 9 || pin == 10) {
      switch(divisor) {
        case 1: mode = 0x01; break;
        case 8: mode = 0x02; break;
        case 64: mode = 0x03; break;
        case 256: mode = 0x04; break;
        case 1024: mode = 0x05; break;
        default: return;
      }
      if(pin == 5 || pin == 6) {
        TCCR0B = TCCR0B & 0b11111000 | mode;
      } else {
        TCCR1B = TCCR1B & 0b11111000 | mode;
      }
    } else if(pin == 3 || pin == 11) {
      switch(divisor) {
        case 1: mode = 0x01; break;
        case 8: mode = 0x02; break;
        case 32: mode = 0x03; break;
        case 64: mode = 0x04; break;
        case 128: mode = 0x05; break;
        case 256: mode = 0x06; break;
        case 1024: mode = 0x7; break;
        default: return;
      }
      TCCR2B = TCCR2B & 0b11111000 | mode;
    }
  }



