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

#define PIN_INPUT_START 6
#define PIN_INPUT_STOP 5
  
#define PIN_ESTOP_READ 10
#define PIN_ESTOP_LOAD 3
#define PIN_ESTOP_CLOCK 4

#define PIN_LIGHTS_SCLK 1
#define PIN_LIGHTS_CLK 2
#define PIN_LIGHTS_SERIAL 7

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
#define MOTOR_PREP_STEPS 3000
#define MOTOR_RUN_STEPS_PER_CYCLE 200
#define MOTOR_TOPUP_STEPS 200
#define TOPUP_WAIT_DELAY 5000
#define TOPUP_DELAY 40000

boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
byte AvailableFlavours = byte(B00111111);
byte HowManyAvailableFlavours = NUMBER_OF_FLAVOURS;
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
int HowManyFlavoursSelected = 0;
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

unsigned long LIGHT_RGB_RIB1 = 7; //               00000000 00000000 00000000 00000111
unsigned long LIGHT_RGB_RIB2 = 56; //              00000000 00000000 00000000 00111000
unsigned long LIGHT_RGB_RIB3 = 448; //             00000000 00000000 00000001 11000000
unsigned long LIGHT_RGB_RIB4 = 3584; //            00000000 00000000 00001110 00000000
unsigned long LIGHT_RGB_RIB5 = 28672; //           00000000 00000000 01110000 00000000
unsigned long LIGHT_RGB_RIB6 = 229376; //          00000000 00000011 10000000 00000000

unsigned long LIGHT_RG_START = 786432; //          00000000 00001100 00000000 00000000
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
byte RGB_GREEN = B001;
byte RGB_BLUE = B010;
byte RGB_YELLOW = B101;
byte RGB_CYAN = B011;
byte RGB_MAGENTA = B110;

//Hard wire blue for 4 colours
byte RG_YELLOW_WHITE = B11;
byte RG_RED_MAGENTA = B10;
byte RG_GREEN_CYAN = B01;
byte RG_OFF_BLUE = B00;

byte W_ON = B1;
byte W_OFF = B0;

unsigned long LIGHT_ALL_ON = 4294967295;
unsigned long CurrentLightValues = LIGHT_ALL_ON; // All On 11111111 11111111 11111111 11111111

void setup() {
  Serial.begin(9600);
  
  //Set input/output modes
  pinMode(PIN_MOTOR_ST, OUTPUT);
  pinMode(PIN_MOTOR_SH, OUTPUT);
  
  pinMode(PIN_MOTOR_EN, OUTPUT);
  pinMode(PIN_MOTOR_DIR, OUTPUT);
  pinMode(PIN_MOTOR_PULSE, OUTPUT);
  
  pinMode(PIN_LIGHTS_SCLK, OUTPUT);
  pinMode(PIN_LIGHTS_CLK, OUTPUT);
  pinMode(PIN_LIGHTS_SERIAL, OUTPUT);

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

  //Disable all motors
   StopAllMotors();
  
    delay(2000);
  
  //Permanently output a PWM output to the MOTOR_PIN_PULSE
  analogWrite(PIN_MOTOR_PULSE, 175);
  
  //EStop parallel in shift register, load set to HIGH (turned LOW to LOAD)
  digitalWrite(PIN_ESTOP_LOAD, HIGH);
  
  Jag_Lights::SetupLights(CurrentLightValues,PIN_LIGHTS_SCLK, PIN_LIGHTS_CLK, PIN_LIGHTS_SERIAL);
  InitializeSequence();
  
  
}

void loop() {
  
  SetLightsInitialState();
  
  WaitForUserInputs();
  
  Pour();
  
  TopUp();
  
  CleanUp();
  
}

void SetLightsInitialState()
{
  //Turn on top and bottom rib
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB1,RGB_WHITE,0,0); 
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB2,RGB_WHITE,0,0);
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB3,RGB_WHITE,0,0); 
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB4,RGB_WHITE,0,0); 
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB5,RGB_WHITE,0,0); 
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_RIB6,RGB_WHITE,0,0); 
  
  //Turn off center stage
  Jag_Lights::RegisterLightEvent(EVENT_OFF,LIGHT_RGB_CS_TB,0,0,0); 
  Jag_Lights::RegisterLightEvent(EVENT_OFF,LIGHT_RGB_CS_CENTER,0,0,0); 
  
  //Turn off start button
  Jag_Lights::RegisterLightEvent(EVENT_OFF,LIGHT_RG_START,0,0,0);
  
  //Turn available colors green solid
  //and unavailable ones off
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    Jag_Lights::RegisterLightEvent(IsFlavourAvailable(i),FlavourLightsArray[i],RGB_GREEN,0,0); 
  }

}

void InitializeSequence()
{
  ResetAllFlavours();
  
  DetectAvailableFlavours();
  
  SelfTest_Lights();
  
  SelfTest_Motors();
}

//Check all eStops and make flavours unavailable in case 
//eStop is triggered
void DetectAvailableFlavours()
{
  eStops = CheckEStops();
  
  //Flavours with at least one of the eStop triggered is made unavailable.
  AvailableFlavours = ~(highByte(eStops) | lowByte(eStops));
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
  return AvailableFlavours & (B00000001 << flavourIndex) != 0;
}

boolean IsTopEStopTriggered(int flavourIndex)
{
  return highByte(eStops) & (B00000001 << flavourIndex) > 0;
}

boolean IsBottomEStopTriggered(int flavourIndex)
{
  return lowByte(eStops) & (B00000001 << flavourIndex) > 0;
}

void SelfTest_Lights()
{
  //Need to convert to using library
  
//  //Turn all lights ON for 2 seconds, then flash each of them
//  //off every 500 ms
//  CurrentLightValues = 4294967295;
//  UpdateLights(CurrentLightValues);
//  delay(2000);
//  
//  //Build a light sequence array
//  unsigned long LightSequence[12];
//  LightSequence[0] = LIGHT_ALL_ON & ~LIGHT_WHITE_TOPRIB;
//  LightSequence[1] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR1;
//  LightSequence[2] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR2;  
//  LightSequence[3] = LIGHT_ALL_ON & ~LIGHT_RGB_START;  
//  LightSequence[4] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR3; 
//  LightSequence[5] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR4; 
//  LightSequence[6] = LIGHT_ALL_ON & ~LIGHT_RGB_CS1; 
//  LightSequence[7] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR5; 
//  LightSequence[8] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR6; 
//  LightSequence[9] = LIGHT_ALL_ON & ~LIGHT_RGB_CS2;
//  LightSequence[10] = LIGHT_ALL_ON & ~LIGHT_RGB_CS3;  
//  LightSequence[11] = LIGHT_ALL_ON & ~LIGHT_WHITE_BOTTOMRIB;
//  
//  for(int i = 0; i < 12 ; i++)
//  {
//    UpdateLights(LightSequence[i]);
//    delay(500);
//  }
  
}

void SelfTest_Motors()
{
  //Select each motor and pulse them down, then pulse them up
  for(int i = 1; i <= NUMBER_OF_FLAVOURS; i++)
  {
    if(IsFlavourAvailable(i - 1))
    {
      RunMotor(i,MOTOR_SELECT_STEPS,DIR_DOWN);
      RunMotor(i,MOTOR_SELECT_STEPS,DIR_UP);
    }
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

//Registers the cycle on event based on the available flavour
//and the selected flavour
void CycleFlavourButtons()
{
  Jag_Lights::ClearLightEvents();
  
  int slice = 0;
  
  for(int i = 0; i < NUMBER_OF_FLAVOURS;i++)
  {
    if(SelectedFlavours[i] && IsFlavourAvailable(i))
    {
      Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,FlavourLightsArray[i],RGB_GREEN,0,0);
    }
    else if(!SelectedFlavours[i] & IsFlavourAvailable(i))
    {
     Jag_Lights:: RegisterLightEvent(EVENT_SLICE_ON,FlavourLightsArray[i],RGB_BLUE,slice,HowManyAvailableFlavours + HowManyFlavoursSelected);
      slice++;
    }
  }
}

void WaitForUserInputs()
{
    unsigned long count = 0;
  

  
waitForFlavourOnly:
  //Turn the start button off
  Jag_Lights::ClearLightEvents();
  Jag_Lights::RegisterLightEvent(EVENT_OFF,LIGHT_RG_START,0,0,0);

  //First, wait for at least one flavour to be selected
  int savedNumberOfFlavourSelected = HowManyFlavoursSelected;
  while(HowManyFlavoursSelected < 1)
  {
    ReadInFlavourButtons(); 
    if(HowManyFlavoursSelected != savedNumberOfFlavourSelected)
    {
      savedNumberOfFlavourSelected = HowManyFlavoursSelected;
      CycleFlavourButtons();
    }
    
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
  
  //Turn the start button on to green
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON,LIGHT_RG_START,RG_GREEN_CYAN,0,1);
  
  //Flash the center stage to indicate the need for a tube
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS_TB,RGB_BLUE,0,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS_CENTER,RGB_BLUE,0,2);

  
  while(digitalRead(PIN_INPUT_START) != HIGH)
  {
    ReadInFlavourButtons();
    if(HowManyFlavoursSelected != savedNumberOfFlavourSelected)
    {
      savedNumberOfFlavourSelected = HowManyFlavoursSelected;
      CycleFlavourButtons();
    }
    
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
    if(SelectedFlavours[i] && IsFlavourAvailable(i))
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
    if(SelectedFlavours[i] && IsFlavourAvailable(i))
    {
      RunMotor(i + 1,MOTOR_PREP_STEPS, DIR_UP);
    }
  }
}

void SetLightsInPouringMode()
{
    Jag_Lights::ClearLightEvents();
    
  //Blink the start button red
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RG_START,RG_RED_MAGENTA,0,1);  

  //Blink all the flavour lights in a row
  for(int i = 0; i < NUMBER_OF_FLAVOURS;i++)
  {
      Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,FlavourLightsArray[i],RGB_GREEN,i,NUMBER_OF_FLAVOURS);
  }
  
  //Blink center stage lights yellow
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS_TB,RGB_YELLOW,0,2);
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS_CENTER,RGB_YELLOW,0,2);

}

void SetLightsForTubeIsReadyWithTopUp()
{
   Jag_Lights::ClearLightEvents();
   
   //Turn off the flavour select lights
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    Jag_Lights::RegisterLightEvent(EVENT_OFF,FlavourLightsArray[i],0,0,0); 
  }
   
   //Light the center stage on white
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS_TB,RGB_WHITE,0,2);
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS_CENTER,RGB_WHITE,0,2);
  
  //Turn the start button on to green
  Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON,LIGHT_RG_START,RG_GREEN_CYAN,0,1);  
}
void SetLightsForTubeIsReady()
{
   Jag_Lights::ClearLightEvents();
   
   //Turn off the flavour select lights
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    Jag_Lights::RegisterLightEvent(EVENT_OFF,FlavourLightsArray[i],0,0,0); 
  }
   
   //Light the center stage on white
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS_TB,RGB_WHITE,0,2);
  Jag_Lights::RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS_CENTER,RGB_WHITE,0,2);

  //Turn the start button on to green
  Jag_Lights::RegisterLightEvent(EVENT_OFF,LIGHT_RG_START,0,0,1);  
}


// Proceed with the pouring sequence until end reached or
// user interrupted
void Pour()
{
  SetLightsInPouringMode();
  
  DetectAvailableFlavours();
  
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
      if(SelectedFlavours[i] && IsFlavourAvailable(i))
      {
        RunMotor(i+1,MOTOR_RUN_STEPS_PER_CYCLE, DIR_DOWN);
        stepsPerformed += MOTOR_RUN_STEPS_PER_CYCLE;
      }
      if(digitalRead(PIN_INPUT_STOP) == HIGH)
        goto stop_Pouring;
        
    }
    
    DetectAvailableFlavours();
    //if all flavours are exhausted, simply exit (avoids infinite loop)
    if((lowByte(eStops) | highByte(eStops)) & B00111111 > 0)
      goto stop_Pouring;

  }
  
  //After the initial pour, wait and hold for 40 seconds
  //but monitor the GO button
  

stop_Pouring:  
  return;
}

void TopUp()
{
  SetLightsForTubeIsReadyWithTopUp();
  
  unsigned long startTime = millis();
  while(digitalRead(PIN_INPUT_STOP) == LOW && (millis() - startTime < TOPUP_DELAY))
  { 

    while(digitalRead(PIN_INPUT_START) == HIGH)
    {
      DetectAvailableFlavours();
      for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
      {
        if(SelectedFlavours[i] && IsFlavourAvailable(i))
        {
          RunMotor(i+1,MOTOR_TOPUP_STEPS / HowManyFlavoursSelected, DIR_DOWN);
        }
        
      }
      delay(TOPUP_WAIT_DELAY);
    }
  }
  SetLightsForTubeIsReady();
  
  //TODO: wait till door opens
  while(digitalRead(PIN_INPUT_STOP) == LOW)
  {
  }
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
  if(IsFlavourAvailable(motorNumber - 1))
  {
    //set direction
    digitalWrite(PIN_MOTOR_DIR,dir); 
    SelectMotor(motorNumber);
  }
   
}

void StopAllMotors()
{
  SelectMotor(0);
}

//Perform cleanup steps at the end of a pouring sequence
void CleanUp()
{
  StopAllMotors();
  ResetSelectedMotors(); 
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
      if(IsFlavourAvailable(i))
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
      } else //This flavour is not available because one of it's eStops is triggered
      {
        //Check it's top eStop, if it is triggered then assume that we are reloading
        //so move motor down until released
        //Make this Flavour Available
        AvailableFlavours = AvailableFlavours | (B00000001 << i);
        if(IsTopEStopTriggered(i))
        {
          //Wait until button is released or the bottom eStop is triggered
          while(IsAnalogInputThresholdMet(FlavourSelectInputs[i]) || IsBottomEStopTriggered(i))
          {
            RunMotor(selectedMotor,DIR_DOWN);
            eStops = CheckEStops();
          }
          StopAllMotors();        
        }
        else if(IsBottomEStopTriggered(i))
        {
         //Wait until button is released or top eStop is triggered
          while(IsAnalogInputThresholdMet(FlavourSelectInputs[i]) || IsTopEStopTriggered(i))
          {
            RunMotor(selectedMotor,DIR_UP);
            eStops = CheckEStops();
          }
          StopAllMotors();              
        }
        DetectAvailableFlavours();
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

