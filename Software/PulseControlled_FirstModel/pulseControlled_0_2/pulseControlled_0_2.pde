#include <EEPROM.h>
#include <MsTimer2.h>
#include <QueueList.h>
#include <jag_lights.h>
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

//#define PIN_INPUT_START 6
//#define PIN_INPUT_STOP 5


#define PIN_ESTOP_READ 10
#define PIN_ESTOP_LOAD 3
#define PIN_ESTOP_CLOCK 4

#define PIN_LIGHTS_SCLK 5 //blue
#define PIN_LIGHTS_CLK 6 //green
#define PIN_LIGHTS_SERIAL 7 //white

#define NUMBER_OF_SHIFT_CHIPS   2
#define DATA_WIDTH   NUMBER_OF_SHIFT_CHIPS * 8
#define PULSE_WIDTH_USEC   5
#define POLL_DELAY_MSEC   1

#define BYTES_VAL_T word

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
#define MAX_STEPS_FILL_TUBE 1400 //time running motor to a full tube

#define MOTOR_SELECT_STEPS 200
#define MOTOR_ESTOP_INCREMENT 200
int motor_prepSteps_per_flavour[6] = {4000,4000,4000,4000,4000,4000};
int motor_relieveSteps_per_flavour[6] = {4000,4000,4000,4000,4000,4000};
#define MOTOR_INTER_PULSE_DELAY 2000
#define MOTOR_RUN_STEPS_PER_CYCLE 200
#define MAX_NUMBER_OF_FLAVOURS 3
#define DRIP_DELAY 20000

#define NEW_TUBE_MOTOR_RESET 45000
#define FLAVOUR_SELECT_TIMEOUT 30000

#define MOTOR_TOPUP_STEPS 200
#define TOPUP_WAIT_DELAY 5000
#define TOPUP_DELAY 40000

#define AUTHORIZE_MODE_CHANGE_DELAY 5000

byte AvailableFlavours = byte(B00111111);
byte FlavoursInReloadPosition = byte(B00000000);
byte HowManyAvailableFlavours = NUMBER_OF_FLAVOURS;
boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
unsigned int HowManyFlavoursSelected = 0;
byte FlavoursReloading = byte(B00000000);

boolean manualModeActive = false;

BYTES_VAL_T PInputs = 0;

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

word START = word(B01000000,B00000000);
word STOP = word(B10000000,B00000000);
word AUTHORIZE = word(B00000000,B10000000);

//EEPROM ADDRESSES
#define EEPROM_WASINITIALIZED 3
#define EEPROM_FLAVOURSRELOADING 4

unsigned long LIGHT_RGB_RIB1 = 7; //               00000000 00000000 00000000 00000111
unsigned long LIGHT_RGB_RIB2 = 56; //              00000000 00000000 00000000 00111000
unsigned long LIGHT_RGB_RIB3 = 448; //             00000000 00000000 00000001 11000000
unsigned long LIGHT_RGB_RIB4 = 3584; //            00000000 00000000 00001110 00000000
unsigned long LIGHT_RGB_RIB5 = 28672; //           00000000 00000000 01110000 00000000
unsigned long LIGHT_RGB_RIB6 = 229376; //          00000000 00000011 10000000 00000000

unsigned long LIGHT_RG_START = 786432; //          00000000 00001100 00000000 00000000

unsigned long LIGHT_RG_START_R = 524288; //          00000000 00001000 00000000 00000000
unsigned long LIGHT_RG_START_Y = 262144; //          00000000 00000100 00000000 00000000

unsigned long LIGHT_WHITE_FLAVOUR1 = 1048576; //   00000000 00010000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR2 = 2097152; //   00000000 00100000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR3 = 4194304; //   00000000 01000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR4 = 8388608; //   00000000 10000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR5 = 16777216; //  00000001 00000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR6 = 33554432; //  00000010 00000000 00000000 00000000
unsigned long LIGHT_RGB_CS_TB = 469762048; //      00011100 00000000 00000000 00000000
unsigned long LIGHT_RGB_CS_CENTER = 3758096384; // 11100000 00000000 00000000 00000000

unsigned long FlavourLightsArray[NUMBER_OF_FLAVOURS] = {LIGHT_WHITE_FLAVOUR1, LIGHT_WHITE_FLAVOUR2, LIGHT_WHITE_FLAVOUR3, LIGHT_WHITE_FLAVOUR4, LIGHT_WHITE_FLAVOUR5, LIGHT_WHITE_FLAVOUR6};

byte RGB_WHITE = B111;
byte RGB_OFF = B000;
byte RGB_RED = B100;
byte RGB_GREEN = B010;
byte RGB_BLUE = B001;
byte RGB_YELLOW = B110;
byte RGB_CYAN = B011;
byte RGB_MAGENTA = B101;

//Hard wire blue for 4 colours
byte RG_YELLOW_WHITE = B11;
byte RG_RED_MAGENTA = B10;
byte RG_GREEN_CYAN = B01;
byte RG_OFF_BLUE = B00;

byte W_ON = B1;
byte W_OFF = B0;

unsigned long LIGHT_ALL_ON = 4294967295;
unsigned long CurrentLightValues = LIGHT_ALL_ON; // All On 11111111 11111111 11111111 11111111

unsigned int Authorize_Count = 0;
byte Authorize_Mode = 0; //0: count based, 1:Infinite

void setup() {
  
  //Set input/output modes
  pinMode(PIN_MOTOR_ST, OUTPUT);
  pinMode(PIN_MOTOR_SH, OUTPUT);
  
  pinMode(PIN_MOTOR_EN, OUTPUT);
  pinMode(PIN_MOTOR_DIR, OUTPUT);
  pinMode(PIN_MOTOR_PULSE, OUTPUT);
  //Disable all motors
  StopAllMotors();
  
  pinMode(PIN_ESTOP_READ, INPUT);
  pinMode(PIN_ESTOP_LOAD, OUTPUT);
  pinMode(PIN_ESTOP_CLOCK, OUTPUT);
  
  pinMode(PIN_LIGHTS_SCLK, OUTPUT);
  pinMode(PIN_LIGHTS_CLK, OUTPUT);
  pinMode(PIN_LIGHTS_SERIAL, OUTPUT);
  
  
  Serial.begin(9600);
  delay(2000);
  
  //Permanently output a PWM output to the MOTOR_PIN_PULSE
  analogWrite(PIN_MOTOR_PULSE, 175);
  
  
  digitalWrite(PIN_ESTOP_CLOCK, LOW);
  digitalWrite(PIN_ESTOP_LOAD, HIGH);
  
  if(EEPROM.read(EEPROM_WASINITIALIZED) == 0)
  {
    FlavoursReloading = EEPROM.read(EEPROM_FLAVOURSRELOADING);
  }
  
  Jag_Lights::SetupLights(CurrentLightValues,PIN_LIGHTS_SCLK, PIN_LIGHTS_CLK, PIN_LIGHTS_SERIAL);
  
  InitializeSequence();
}

void loop() {
  WaitForUserInputs();
  
  Pour();
  
  TopUp();

  CleanUp();
  
  //delay(DRIP_DELAY);
  SetLightState_Completed();
  if(Authorize_Mode == 0)
  {
    Authorize_Count--;
  }
  delay(5000);
}

void InitializeSequence()
{
  ResetAllFlavours();
  ReadInputs();
  SetLightState_Test();
  SelfTest_Motors();
}

//Check all eStops and make flavours unavailable in case 
//eStop is triggered
void ReadInputs()
{
  BYTES_VAL_T saved_PInputs = PInputs;
  byte saved_AvailableFlavours = AvailableFlavours;
  byte saved_FlavoursInReloadPosition = FlavoursInReloadPosition;
  
  PInputs = ShiftInParallelInputs();
  
   //Flavours with at least one of the eStop triggered is made unavailable.
  AvailableFlavours = ~(lowByte(PInputs) & B00111111);
  FlavoursInReloadPosition = (highByte(PInputs) & B00111111);
  
  if(PInputs != saved_PInputs)
  {
    Serial.print("PInputs Changed: ");
    Serial.print(PInputs,BIN);
    Serial.println();
  }
  
  if(AvailableFlavours != saved_AvailableFlavours)
  {
    Serial.print("AvailableFlavours Changed: ");
    Serial.print(AvailableFlavours,BIN);
    Serial.println();
  }
  
  if(FlavoursInReloadPosition != saved_FlavoursInReloadPosition)
  {
    Serial.print("FlavoursInReloadPosition Changed: ");
    Serial.print(FlavoursInReloadPosition,BIN);
    Serial.println();
  }
  
  byte availableCount =0;
  for(int i = 0 ; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(IsFlavourAvailable(i))
     availableCount ++; 
  }
  HowManyAvailableFlavours = availableCount;
}

boolean IsStartButtonPressed()
{
  if(((word)(PInputs & START)) > 0)
  {
    //Serial.println("START Button was pressed");
    return true;
  }
  else
  {
    //Serial.println("START Button NOT pressed");
    return false;
  }
}

boolean IsStopButtonPressed()
{
  if(((word)(PInputs & STOP)) > 0)
  {
    //Serial.println("STOP Button was pressed");
    return true;
  }
  else
  {
    //Serial.println("STOP Button NOT pressed");
    return false;
  }
}

boolean IsAuthorizeButtonPressed()
{
  return ((word)(PInputs & AUTHORIZE)) > 0;
}

boolean IsFlavourAvailable(int flavourIndex)
{
  return ((unsigned int)((AvailableFlavours & ~FlavoursReloading & ~FlavoursInReloadPosition) & (B00000001 << flavourIndex)) > 0);
}

void SelfTest_Motors()
{
  Jag_Lights::Suspend();
  //Select each motor and pulse them down, then pulse them up
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    RunMotor(i + 1,MOTOR_SELECT_STEPS,DIR_DOWN);
    RunMotor(i + 1,MOTOR_SELECT_STEPS,DIR_UP);
  }
  Jag_Lights::Continue();
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

//******* new wait for Inputs code *********
void WaitForUserInputs()
{
  boolean goPour = false;
  unsigned int numberOfFlavoursSelected = 0;
  unsigned int savedNumberSelected = 0;
  boolean stateReported = false;
  unsigned long flavourSelectedTime;
  int lastLightType = -1;
  unsigned long authorized_pressed = 0;
  
  
  while(!goPour)
  {    
     //Read in estops
     ReadInputs();
     
    //look for flavour button pressed
    if(Authorize_Mode == 1 || Authorize_Count > 0)
    {
      numberOfFlavoursSelected = ReadInFlavourButtons(); 
    }
    
    if(IsStopButtonPressed())
    {
      Authorize_Count = 0;
    }
    
    //Listen for Authorize
    if(IsAuthorizeButtonPressed())
    {
      authorized_pressed = millis();
      ReadInputs();
      while(IsAuthorizeButtonPressed())
      {
        ReadInputs();
        if((millis() - authorized_pressed) > AUTHORIZE_MODE_CHANGE_DELAY )
        {
          Authorize_Mode = 1;
        }
      }
      Authorize_Count++;    
    }
    
    if(savedNumberSelected != numberOfFlavoursSelected)
    {
      stateReported = false;
      savedNumberSelected = numberOfFlavoursSelected;
    }
    
    if(numberOfFlavoursSelected == 0)
    {
      if(!stateReported)
      {
        Serial.println("Waiting for at least one flavour (checking estops for reload)");
        stateReported = true;
      }
      lastLightType = HandleNoneSelectedLights(lastLightType);
      DealWithExhaustedCartridges();
    }
    else
    {
      lastLightType = HandleFlavourSelectedLights(lastLightType);
      flavourSelectedTime = millis();
      StopAllMotors();
      while(numberOfFlavoursSelected > 0 && !goPour)
      {
        if(!stateReported)
        {
          Serial.println("One more flavour OR start button");
          stateReported = true;
        }
        
        //Read inputs to see if Start button pressed
        ReadInputs();
        goPour = IsStartButtonPressed();
        
        numberOfFlavoursSelected = ReadInFlavourButtons(); 
        if(savedNumberSelected != numberOfFlavoursSelected)
        {
          flavourSelectedTime = millis();
          savedNumberSelected = numberOfFlavoursSelected;
        }       
        lastLightType = HandleFlavourSelectedLights(lastLightType);
        
        if((millis() - flavourSelectedTime) >= FLAVOUR_SELECT_TIMEOUT || IsStopButtonPressed())
        {
          ResetAllFlavours();
          break;
        }
      }
    }
    
  }
  
  Serial.println("**** POURING ****");

}

void DealWithExhaustedCartridges()
{
  word motorToReset = 0;
  unsigned int motorResetConfirm = 0;
  unsigned long startTime = 0;
  int lastLightType = -1;
  
  ReadInputs();
  
  //Handle exhausted cartridges... move motor to reload position
  if((unsigned int)(~AvailableFlavours) > 0 || (unsigned int)FlavoursReloading > 0)
  {
    byte newFlavoursReloading;
    newFlavoursReloading = (FlavoursReloading & ~FlavoursInReloadPosition) | (~AvailableFlavours & ~FlavoursInReloadPosition);
    
    if(newFlavoursReloading != FlavoursReloading)
    {
      EEPROM.write(EEPROM_WASINITIALIZED, 0);
      EEPROM.write(EEPROM_FLAVOURSRELOADING, newFlavoursReloading);
    }
    //Update the FlavoursReloading bit mask and motorMask
    FlavoursReloading = newFlavoursReloading;
    RunMultipleMotors(FlavoursReloading, DIR_UP);  
  } else {
    StopAllMotors();
  }
  
  //If a flavour is in reload position and operator signals a new cartridge has
  //been inserted, then moved motor back in position
  
  motorToReset = (unsigned int)(~AvailableFlavours & FlavoursInReloadPosition);
  if(motorToReset > 0)
  {
    Serial.println("Inside motorToReset confirm");
    //Wait for confirmation
    delay(2000);
    ReadInputs();

    motorResetConfirm =(unsigned int)( ~AvailableFlavours & FlavoursInReloadPosition);
    if(motorResetConfirm > 0)
    {
      //Wait for release of button
      while((unsigned int)(motorResetConfirm & ~AvailableFlavours) > 0)
      {
        ReadInputs();
      }

      RunMultipleMotors(motorResetConfirm,DIR_DOWN);
      startTime = millis();
      delay(3000); //One second delay to allow time for the top estop to release
      while(true)
      {
        lastLightType = HandleReloadingLights(lastLightType);
        
        ReadInputs();
        if((millis() - startTime) >= NEW_TUBE_MOTOR_RESET)
        {
          StopAllMotors();
          break;
        }
        if((unsigned int)(motorResetConfirm & ~AvailableFlavours) > 0)
        {
          FlavoursReloading = motorResetConfirm;
          EEPROM.write(EEPROM_WASINITIALIZED, 0);
          EEPROM.write(EEPROM_FLAVOURSRELOADING, FlavoursReloading);
          RunMultipleMotors(FlavoursReloading, DIR_UP);
          break;            
        }
      }
    }
  }  
}
//******************************************

unsigned int GetMaskForSelectedFlavours()
{
    unsigned int finalBitMask = 0;
    unsigned int numberOfFlavoursSelected = 0; 
    
    for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
    {
      if(SelectedFlavours[i] && IsFlavourAvailable(i))
      {
        bitSet(finalBitMask,i);
        numberOfFlavoursSelected++;
      }
    }
    HowManyFlavoursSelected = numberOfFlavoursSelected;
    
    return finalBitMask;
}

void PrepSelectedMotors()
{
  RunMultipleMotors(GetMaskForSelectedFlavours(), motor_prepSteps_per_flavour[HowManyFlavoursSelected-1],DIR_DOWN);
}

void ResetSelectedMotors()
{
  RunMultipleMotors(GetMaskForSelectedFlavours(), motor_relieveSteps_per_flavour[HowManyFlavoursSelected-1],DIR_UP);
}


// Proceed with the pouring sequence until end reached or
// user interrupted
void Pour()
{
  SetLightState_Pouring();
  
  ReadInputs();    
  PrepSelectedMotors();
  
  //Calculate number of steps per flavour based on number of flavours selected.
  //int totalStepsPerFlavour = MAX_STEPS_FILL_TUBE / HowManyFlavoursSelected;
  
  int stepsPerformed = 0;
  boolean stopRequested = false;
  
  while(!IsStopButtonPressed() && stepsPerformed < MAX_STEPS_FILL_TUBE)
  {
    RunMultipleMotors(GetMaskForSelectedFlavours(),MOTOR_RUN_STEPS_PER_CYCLE,DIR_DOWN);    
    delay(MOTOR_INTER_PULSE_DELAY);
    stepsPerformed += MOTOR_RUN_STEPS_PER_CYCLE * HowManyFlavoursSelected;
    ReadInputs();

    if(IsStopButtonPressed() || GetMaskForSelectedFlavours() == 0)
      break;

  }

}

void TopUp()
{
  
  SetLightState_TopUp();
  unsigned long startTime = millis();
  ReadInputs();
  
  while(!IsStopButtonPressed() && (millis() - startTime < TOPUP_DELAY))
  { 
    ReadInputs();
    while(IsStartButtonPressed())
    {
      RunMultipleMotors(GetMaskForSelectedFlavours(),MOTOR_RUN_STEPS_PER_CYCLE,DIR_DOWN);
   
      delay(TOPUP_WAIT_DELAY);
      
      ReadInputs();
    }
  }
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
  
//      Serial.println("");
//      
//      Serial.print("Running Motor ");
//      Serial.println(motorNumber);
//      Serial.print("Direction: ");
//      Serial.println(dir);
//      Serial.print("Duration: ");
//      Serial.println(runDuration);
      
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
  StopAllMotors();
  delay(5000);
  ResetSelectedMotors(); 
  ResetAllFlavours();
}

unsigned int ReadInFlavourButtons()
{
  unsigned int numberOfFlavoursSelected = HowManyFlavoursSelected;
  
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    int selectedMotor = i + 1;
    //XOR operator "^" will set a selected flavour to false if it was selected and the button is pressed again
    //It will set it to true if the flavour was not previously selected
    if(IsAnalogInputThresholdMet(FlavourSelectInputs[i]))
    {

      if(!SelectedFlavours[i])
      {     
        if(IsFlavourAvailable(i))
        {
          if(HowManyFlavoursSelected >= MAX_NUMBER_OF_FLAVOURS)
          {
            //Unselect the first flavour that is selected
            //Find first selected colour
            for(int ii = 0;ii < NUMBER_OF_FLAVOURS;ii++)
            {
              if(SelectedFlavours[ii])
              {
                SelectedFlavours[ii] = false;
                HowManyFlavoursSelected--;
                //Pulse that motor
                RunMotor(ii+1,MOTOR_SELECT_STEPS,DIR_DOWN);
                delay(700);
                RunMotor(ii+1,MOTOR_SELECT_STEPS,DIR_UP);  
                break;
              }
            }
          }
          SelectedFlavours[i] = true; 
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
        SelectedFlavours[i] = false;
        HowManyFlavoursSelected--;
        //Pulse that motor
        RunMotor(selectedMotor,MOTOR_SELECT_STEPS,DIR_DOWN);
        delay(700);
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
  
  if(HowManyFlavoursSelected != numberOfFlavoursSelected)
  {
    Serial.print("Number of flavours selected changed: ");
    Serial.println(HowManyFlavoursSelected);
  }
  
  return HowManyFlavoursSelected;
   
}



//Returns true if the value measured at a specified input is above the 
//predetermined Threshold.
boolean IsAnalogInputThresholdMet(int analogPin)
{
  return analogRead(analogPin) > ANALOG_THRESHOLD;  
}

void SelectMultipleMotor(int motorBitMask)
{
   
  //Serial.print("Value of motorSelect: ");
  //Serial.println(motorBitMask,BIN);
    
  //Shift the value out to enable only the selected motor
  digitalWrite(PIN_MOTOR_ST, LOW);
  digitalWrite(PIN_MOTOR_SH, LOW);
  
  int motorCount = 0;
  
  //Check to make sure we are not running more than 3 motors at a time
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    if(bitRead(motorBitMask,i) == 1)
      motorCount++;
    
    if(motorCount > MAX_NUMBER_OF_FLAVOURS)
      bitClear(motorBitMask,i);
  }
  
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

BYTES_VAL_T ShiftInParallelInputs()
  {
    //Jag_Lights::Suspend();
    byte bitVal;
    BYTES_VAL_T bytesVal = 0;

    /* Trigger a parallel Load to latch the state of the data lines,
    */
    digitalWrite(PIN_ESTOP_LOAD, LOW);
    delayMicroseconds(PULSE_WIDTH_USEC);
    digitalWrite(PIN_ESTOP_LOAD, HIGH);

    /* Loop to read each bit value from the serial out line
     * of the SN74HC165N.
    */
    for(int i = 0; i < DATA_WIDTH; i++)
    {
        bitVal = digitalRead(PIN_ESTOP_READ);

        /* Set the corresponding bit in bytesVal.
        */
        bytesVal |= (bitVal << ((DATA_WIDTH-1) - i));

        /* Pulse the Clock (rising edge shifts the next bit).
        */
        digitalWrite(PIN_ESTOP_CLOCK, HIGH);
        delayMicroseconds(PULSE_WIDTH_USEC);
        digitalWrite(PIN_ESTOP_CLOCK, LOW);
    }
    //Jag_Lights::Continue();
    return(bytesVal);    
  }

///****** Light states ****////
int HandleNoneSelectedLights(int lastLightType)
{
  int lightType;
    lightType = ((unsigned int)(millis() /  3000)) % 3;
    if(lastLightType != lightType)
    {
      lastLightType = lightType;
      switch(lightType)
      {
        case 0:
          SetLightState_Idle1();
          break;
        case 1:
          SetLightState_Idle2();
          break;
        case 2:
          SetLightState_Idle3();
          break;
      }
    }
    return lastLightType;
}

int HandleFlavourSelectedLights(int lastLightType)
{
    int lightType;
    lightType = ((unsigned int)(millis() /  3000)) % 3;
    if(lastLightType != lightType)
    {
      lastLightType = lightType;
      switch(lightType)
      {
        case 0:
          SetLightState_AtLeastOne1();
          break;
        case 1:
          SetLightState_AtLeastOne2();
          break;
        case 2:
          SetLightState_AtLeastOne3();
          break;
      }
    }
    
    return lastLightType;
}

int HandleReloadingLights(int lastLightType)
{
    int lightType;
    lightType = ((unsigned int)(millis() /  3000)) % 3;
    if(lastLightType != lightType)
    {
      lastLightType = lightType;
      switch(lightType)
      {
        case 0:
          SetLightState_Reloading1();
          break;
        case 1:
          SetLightState_Reloading2();
          break;
        case 2:
          SetLightState_Reloading3();
          break;
      }
    }
    return lastLightType;
}

void SetupAllLightsEvents(byte eventType,byte color)
{
    Jag_Lights::ClearLightEvents();
    Jag_Lights::RegisterLightEvent(eventType, LIGHT_RG_START, color, 0, 10);
    Jag_Lights::RegisterLightEvent(eventType, LIGHT_RGB_CS_CENTER, color, 0, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_CS_TB, color, 1, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR6, color, 2, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR5, color, 3, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR4, color, 4, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR3, color, 5, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR2, color, 6, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR1, color, 7, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB6, color, 8, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB5, color, 9, 10); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB4, color, 9, 10); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB3, color, 9, 10); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB2, color, 9, 10); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB1, color, 9, 10);     
}

void SetLightState_Test()
{
  Jag_Lights::ClearLightEvents();
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_RED);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_GREEN);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_BLUE);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_YELLOW);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_CYAN);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_MAGENTA);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_WHITE);
  delay(500);
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_OFF); 
  delay(500); 
  SetupAllLightsEvents(EVENT_ON_COLOR,RGB_WHITE);
}

void RegisterFlavoursLightsToSelect(byte eventType, byte multiplier)
{
  int totalSlice = HowManyAvailableFlavours - HowManyFlavoursSelected;
  
  for(int i = NUMBER_OF_FLAVOURS - 1; i >= 0; i--)
  {
    if(IsFlavourAvailable(i))
    {
      if (!SelectedFlavours[i])
      {
        Jag_Lights::RegisterLightEvent(eventType , FlavourLightsArray[i], W_ON, (i + 1) % 3, totalSlice ,multiplier);
      }
      else
      {
        Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR , FlavourLightsArray[i], W_ON, 0, 0,0);
      }
    }
    else
    {
      Jag_Lights::RegisterLightEvent(EVENT_OFF , FlavourLightsArray[i], W_ON, 0, 0,0);
    }
  }
}

void AllFlavourButtonsOff()
{
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR6, 0, 2, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR5, 0, 3, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR4, 0, 4, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR3, 0, 5, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR2, 0, 6, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_FLAVOUR1, 0, 7, 10);
}

void SetLightState_Idle1()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR, LIGHT_RG_START, RG_YELLOW_WHITE, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_RED, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS_TB, RGB_RED, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_RED, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_RED, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_RED, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_RED, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_RED, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_RED, 2, 3,4);     
}

void SetLightState_Idle2()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR, LIGHT_RG_START, RG_YELLOW_WHITE, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_GREEN, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS_TB, RGB_GREEN, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_GREEN, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_GREEN, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_GREEN, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_GREEN, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_GREEN, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_GREEN, 2, 3,4);     
}

void SetLightState_Idle3()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR, LIGHT_RG_START, RG_YELLOW_WHITE, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_BLUE, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS_TB, RGB_BLUE, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_BLUE, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_BLUE, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_BLUE, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_BLUE, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_BLUE, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_BLUE, 2, 3,4);     
}

void SetLightState_AtLeastOne1()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_BLINK, LIGHT_RG_START, RG_GREEN_CYAN, 0, 10,2);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_GREEN, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS_TB, RGB_GREEN, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_RED, 0, 3,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_RED, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_RED, 2, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_RED, 0, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_RED, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_RED, 2, 3,2);     
}

void SetLightState_AtLeastOne2()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_BLINK, LIGHT_RG_START, RG_GREEN_CYAN, 0, 10,2);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_GREEN, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_TB, RGB_GREEN, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_GREEN, 0, 3,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_GREEN, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_GREEN, 2, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_GREEN, 0, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_GREEN, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_GREEN, 2, 3,2);     
}

void SetLightState_AtLeastOne3()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_BLINK, LIGHT_RG_START, RG_GREEN_CYAN, 0, 10, 2);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_GREEN, 0, 10);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_TB, RGB_GREEN, 1, 10);
  RegisterFlavoursLightsToSelect(EVENT_SLICE_OFF,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_BLUE, 0, 3,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_BLUE, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_BLUE, 2, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_BLUE, 0, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_BLUE, 1, 3,2); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_BLUE, 2, 3,2);     
}

void SetLightState_Pouring()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR, LIGHT_RG_START_R, W_ON, 0, 2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON, LIGHT_RG_START_Y, W_ON, 0, 2); 
  
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON, LIGHT_RGB_CS_CENTER, RGB_RED, 0, 2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON, LIGHT_RGB_CS_TB, RGB_YELLOW, 1, 2);
  RegisterFlavoursLightsToSelect(EVENT_OFF,1);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_RED, 0, 3,1);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_RED, 1, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_RED, 2, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_RED, 0, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_RED, 1, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_RED, 2, 3,1);    
}

void SetLightState_TopUp()
{
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_BLINK, LIGHT_RG_START, RG_YELLOW_WHITE, 0, 2);
  
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON, LIGHT_RGB_CS_CENTER, RGB_RED, 0, 2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON, LIGHT_RGB_CS_TB, RGB_YELLOW, 1, 2);
  RegisterFlavoursLightsToSelect(EVENT_OFF,1);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_RED, 0, 3,1);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_RED, 1, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_RED, 2, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_RED, 0, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_RED, 1, 3,1); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_RED, 2, 3,1);   
}

void SetLightState_Completed()
{
  Jag_Lights::ClearLightEvents();
  
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RG_START, RG_GREEN_CYAN, 0, 10, 2);
  
  Jag_Lights::RegisterLightEvent(EVENT_BLINK, LIGHT_RGB_CS_CENTER, RGB_BLUE, 0, 4,4);
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR, LIGHT_RGB_CS_TB, RGB_WHITE, 1, 2);
  
  RegisterFlavoursLightsToSelect(EVENT_ON_COLOR,1);
  
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB6, RGB_BLUE, 0, 6,4);
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB5, RGB_BLUE, 1, 6,4); 
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB4, RGB_BLUE, 2, 6,4); 
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB3, RGB_BLUE, 3, 6,4); 
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB2, RGB_BLUE, 4, 6,4); 
  Jag_Lights::RegisterLightEvent(EVENT_BLINK , LIGHT_RGB_RIB1, RGB_BLUE, 5, 6,4);  
}

void SetLightState_Reloading1()
{
  Jag_Lights::ClearLightEvents();
  
  AllFlavourButtonsOff();
  
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_BLUE, 0, 4,4);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_TB, RGB_WHITE, 1, 2);
  
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_RED, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_RED, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_RED, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_RED, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_RED, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_RED, 2, 3,4);
}

void SetLightState_Reloading2()
{
  Jag_Lights::ClearLightEvents();
  
  AllFlavourButtonsOff();
  
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_BLUE, 0, 4,4);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_TB, RGB_WHITE, 1, 2);
  
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_GREEN, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_GREEN, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_GREEN, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_GREEN, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_GREEN, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_GREEN, 2, 3,4);
}

void SetLightState_Reloading3()
{
  Jag_Lights::ClearLightEvents();
  
  AllFlavourButtonsOff();
  
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_CENTER, RGB_BLUE, 0, 4,4);
  Jag_Lights::RegisterLightEvent(EVENT_OFF, LIGHT_RGB_CS_TB, RGB_WHITE, 1, 2);
  
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_BLUE, 0, 3,4);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_BLUE, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_BLUE, 2, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_BLUE, 0, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_BLUE, 1, 3,4); 
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_BLUE, 2, 3,4);
}
