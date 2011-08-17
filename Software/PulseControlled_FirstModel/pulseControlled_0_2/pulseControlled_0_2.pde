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

#define PIN_INPUT_START 6
#define PIN_INPUT_STOP 5

#define PIN_ESTOP_READ 10
#define PIN_ESTOP_LOAD 3
#define PIN_ESTOP_CLOCK 4

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

#define DIR_UP LOW
#define DIR_DOWN HIGH

// **** CONSTANTS ****
#define ANALOG_THRESHOLD 900
#define NUMBER_OF_FLAVOURS 6
#define MAX_STEPS_FILL_TUBE 2000 //time running motor to a full tube

#define MOTOR_SELECT_STEPS 200
#define MOTOR_ESTOP_INCREMENT 200
int motor_prepSteps_per_flavour[6] = {1000,1000,1000,0,0,0};
int motor_relieveSteps_per_flavour[6] = {1000,1000,1000,0,0,0};
#define MOTOR_INTER_PULSE_DELAY 1000
#define MOTOR_RUN_STEPS_PER_CYCLE 200
#define MAX_NUMBER_OF_FLAVOURS 3

byte AvailableFlavours = byte(B00111111);
byte FlavoursInReloadPosition = byte(B00000000);
byte HowManyAvailableFlavours = NUMBER_OF_FLAVOURS;
boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
int HowManyFlavoursSelected = 0;
byte FlavoursReloading = byte(B00000000);

boolean manualModeActive = true;

word eStops = word(B00000000,B00000000);

word ESTOP_B_1 = word(B00000000,B00000001);
word ESTOP_B_2 = word(B00000000,B00000010);
word ESTOP_B_3 = word(B00000000,B00000100);
word ESTOP_B_4 = word(B00000000,B00001000);
word ESTOP_B_5 = word(B00000000,B00010000);
word ESTOP_B_6 = word(B00000000,B00100000);

word ESTOP_T_1 = word(B00000001,B00000000);
word ESTOP_T_2 = word(B00000010,B00000000);
word ESTOP_T_3 = word(B00000100,B00000000);
word ESTOP_T_4 = word(B00001000,B00000000);
word ESTOP_T_5 = word(B00010000,B00000000);
word ESTOP_T_6 = word(B00100000,B00000000);


void setup() {
  Serial.begin(9600);
  
  //Set input/output modes
  pinMode(PIN_MOTOR_ST, OUTPUT);
  pinMode(PIN_MOTOR_SH, OUTPUT);
  
  pinMode(PIN_MOTOR_EN, OUTPUT);
  pinMode(PIN_MOTOR_DIR, OUTPUT);
  pinMode(PIN_MOTOR_PULSE, OUTPUT);
  
  pinMode(PIN_ESTOP_READ, INPUT);
  pinMode(PIN_ESTOP_LOAD, OUTPUT);
  pinMode(PIN_ESTOP_CLOCK, OUTPUT);
  
  pinMode(PIN_INPUT_START, INPUT);
  pinMode(PIN_INPUT_STOP, INPUT);

  
  pinMode(PIN_INPUT_FLAV_1, INPUT);
  pinMode(PIN_INPUT_FLAV_2, INPUT);
  pinMode(PIN_INPUT_FLAV_3, INPUT);
  pinMode(PIN_INPUT_FLAV_4, INPUT);
  pinMode(PIN_INPUT_FLAV_5, INPUT);
  pinMode(PIN_INPUT_FLAV_6, INPUT);

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
  DetectAvailableFlavours();
  
  WaitForUserInputs();
  
  Pour();
  
  CleanUp();
  
}

void InitializeSequence()
{
  ResetAllFlavours();
  DetectAvailableFlavours();
  SelfTest_Motors();
}

//Check all eStops and make flavours unavailable in case 
//eStop is triggered
void DetectAvailableFlavours()
{
  eStops = CheckEStops();
  
  //Flavours with at least one of the eStop triggered is made unavailable.
  AvailableFlavours = ~(highByte(eStops));
  FlavoursInReloadPosition = lowByte(eStops);
  byte availableCount =0;
  for(int i = 0 ; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(IsFlavourAvailable(i))
     availableCount ++; 
  }
  HowManyAvailableFlavours = availableCount;
}

boolean IsFlavourAvailable(int flavourIndex)
{
  return (AvailableFlavours & ~FlavoursReloading) & (B00000001 << flavourIndex) != 0;
}

boolean IsTopEStopTriggered(int flavourIndex)
{
  return highByte(eStops) & (B00000001 << flavourIndex) > 0;
}

boolean IsBottomEStopTriggered(int flavourIndex)
{
  return lowByte(eStops) & (B00000001 << flavourIndex) > 0;
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
  Serial.print("AvailableFlavours:");
  Serial.print(AvailableFlavours,BIN);
  Serial.println();
  Serial.print("FlavoursInReloadPosition:");
  Serial.print(FlavoursInReloadPosition,BIN);
  Serial.println();
  Serial.print("FlavoursReloading:");
  Serial.print(FlavoursReloading,BIN);
  Serial.println();  
  
  //Are any flavours unavailable? If so then start reload process
  if(~AvailableFlavours > 0 || FlavoursReloading > 0)
  {
    //initiate the reload sequence for those flavours
    FlavoursReloading = FlavoursReloading | (~AvailableFlavours & ~FlavoursInReloadPosition);
    RunMultipleMotors(FlavoursReloading, DIR_UP);
  }
  
waitForFlavourOnly:
  //First, wait for at least one flavour to be selected
  while(HowManyFlavoursSelected < 1)
  {
    DetectAvailableFlavours();
    //Update the FlavoursReloading bit mask and motorMask
    FlavoursReloading = FlavoursReloading & ~FlavoursInReloadPosition;
    RunMultipleMotors(FlavoursReloading, DIR_UP);    
    
    Serial.print("FlavoursReloading:");
    Serial.print(FlavoursReloading,BIN);
    Serial.println();
    
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
  StopAllMotors();
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

int GetMaskForSelectedFlavours()
{
    unsigned int finalBitMask = 0; 
    
    for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
    {
      if(SelectedFlavours[i] && IsFlavourAvailable(i))
        bitSet(finalBitMask,i);
    }
    
    return finalBitMask;
}

void PrepSelectedMotors()
{
  
  RunMultipleMotors(GetMaskForSelectedFlavours(), motor_prepSteps_per_flavour[HowManyFlavoursSelected-1],DIR_DOWN);
//  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
//  {
//    if(SelectedFlavours[i])
//    {
//      RunMotor(i + 1,MOTOR_PREP_STEPS, DIR_DOWN);
//    }
//  }
}

void ResetSelectedMotors()
{
  RunMultipleMotors(GetMaskForSelectedFlavours(), motor_relieveSteps_per_flavour[HowManyFlavoursSelected-1],DIR_UP);
// 
//  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
//  {
//    if(SelectedFlavours[i])
//    {
//      RunMotor(i + 1,MOTOR_PREP_STEPS, DIR_UP);
//    }
//  }
}


// Proceed with the pouring sequence until end reached or
// user interrupted
void Pour()
{
  DetectAvailableFlavours();    
  PrepSelectedMotors();
  
  //Calculate number of steps per flavour based on number of flavours selected.
  //int totalStepsPerFlavour = MAX_STEPS_FILL_TUBE / HowManyFlavoursSelected;
  
  int stepsPerformed = 0;
  boolean stopRequested = false;
  
  while(digitalRead(PIN_INPUT_STOP) == LOW && stepsPerformed < MAX_STEPS_FILL_TUBE)
  {
    
    RunMultipleMotors(GetMaskForSelectedFlavours(),MOTOR_RUN_STEPS_PER_CYCLE,DIR_DOWN);    
//    for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
//    {
//      if(digitalRead(PIN_INPUT_STOP) == HIGH)
//        goto stop_Pouring;
//      if(SelectedFlavours[i])
//      {
//        RunMotor(i+1,MOTOR_RUN_STEPS_PER_CYCLE, DIR_DOWN);
    delay(MOTOR_INTER_PULSE_DELAY);
    stepsPerformed += MOTOR_RUN_STEPS_PER_CYCLE * HowManyFlavoursSelected;
//      }
    DetectAvailableFlavours();

    if(digitalRead(PIN_INPUT_STOP) == HIGH || GetMaskForSelectedFlavours() == 0)
      goto stop_Pouring;
        
//    }

  }

stop_Pouring:  
  StopAllMotors();
  delay(5000);
  ResetSelectedMotors(); 
}

void RunMultipleMotors(int motorMask, unsigned long runDuration, int dir)
{
  //set direction
  digitalWrite(PIN_MOTOR_DIR,dir);

  unsigned long startTime = millis();
  unsigned long timeNow = millis();
  unsigned int stepCount = 0;

    Serial.println("");
    
    Serial.print("Running Motor mask:");
    Serial.print(motorMask, BIN);
    Serial.println();
    Serial.print("Direction: ");
    Serial.println(dir);
    Serial.print("Duration: ");
    Serial.println(runDuration);
    
    SelectMultipleMotor(motorMask);
    delay(runDuration);
    SelectMotor(0);  
}

void RunMotor(int motorNumber, unsigned long runDuration, int dir)
{
  if(IsFlavourAvailable(motorNumber - 1))
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

}

void RunMotor(int motorNumber,int dir)
{

  //set direction
  digitalWrite(PIN_MOTOR_DIR,dir); 
  SelectMotor(motorNumber);
   
}

void RunMultipleMotors(int motorMask,int dir)
{

  //set direction
  digitalWrite(PIN_MOTOR_DIR,dir); 
  SelectMultipleMotor(motorMask);
   
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

      if(SelectedFlavours[i] ^ true)
      {     
        if(HowManyFlavoursSelected < MAX_NUMBER_OF_FLAVOURS && IsFlavourAvailable(i))
        {
          SelectedFlavours[i] = SelectedFlavours[i] ^ true; 
          HowManyFlavoursSelected++;
          //Pulse that motor
          RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_DOWN);
          delay(100);
          RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_UP);
          //Wait until button is released
          while(manualModeActive && IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
          {
            RunMotor(selectedMotor,DIR_DOWN);
          }
          StopAllMotors();
        }
      } else
      {
        SelectedFlavours[i] = SelectedFlavours[i] ^ true;
        HowManyFlavoursSelected--;
        //Pulse that motor
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(1000);
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_UP);  
  
        //Wait until button is released
        while(manualModeActive && IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
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

void SelectMultipleMotor(int motorBitMask)
{
   
  Serial.print("Value of motorSelect: ");
  Serial.println(motorBitMask,BIN);
    
  //Shift the value out to enable only the selected motor
  digitalWrite(PIN_MOTOR_ST, LOW);
  digitalWrite(PIN_MOTOR_SH, LOW);
  
  shiftOut(PIN_MOTOR_EN, PIN_MOTOR_SH, MSBFIRST, motorBitMask);
  
  digitalWrite(PIN_MOTOR_ST, HIGH);
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

  word CheckEStops()
  {
    //Read in all EStop Sensors
    digitalWrite(PIN_ESTOP_LOAD,LOW);
    delay(10);
    digitalWrite(PIN_ESTOP_LOAD,HIGH);
    delay(10);
    
    word valuesRead = word(B00000000,B00000000);
    //Shift EStop values in
    for(int i = 0; i <=15 ; i++)
    {
      valuesRead = valuesRead >> 1;
      valuesRead = valuesRead | (digitalRead(PIN_ESTOP_READ) << 15);
      digitalWrite(PIN_ESTOP_CLOCK,LOW);
      delay(10);
      digitalWrite(PIN_ESTOP_CLOCK,HIGH);
    }
    
    return valuesRead;
  }


