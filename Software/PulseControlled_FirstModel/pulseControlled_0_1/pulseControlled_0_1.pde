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

//// ***** Includes **********
#include <MsTimer2.h>
#include <QueueList.h>

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
#define MAX_STEPS_FILL_TUBE 3200 //time running motor to a full tube

#define MOTOR_SELECT_STEPS 200
#define MOTOR_ESTOP_INCREMENT 200
#define MOTOR_PREP_STEPS 1000
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

unsigned long LIGHT_WHITE_BOTTOMRIB = 1; //  00000000 00000000 00000000 00000001
unsigned long LIGHT_WHITE_TOPRIB = 2; //     00000000 00000000 00000000 00000010

unsigned long LIGHT_RGB_FLAVOUR1 = 28; //    00000000 00000000 00000000 00011100
unsigned long LIGHT_RGB_FLAVOUR2 = 224; //   00000000 00000000 00000000 11100000
unsigned long LIGHT_RGB_FLAVOUR3 = 1792; //  00000000 00000000 00000111 00000000
unsigned long LIGHT_RGB_FLAVOUR4 = 14336; // 00000000 00000000 00111000 00000000
unsigned long LIGHT_RGB_FLAVOUR5 = 114688; //00000000 00000001 11000000 00000000
unsigned long LIGHT_RGB_FLAVOUR6 = 917504; //00000000 00001110 00000000 00000000
unsigned long FlavourLightsArray[NUMBER_OF_FLAVOURS] = {LIGHT_RGB_FLAVOUR1, LIGHT_RGB_FLAVOUR2, LIGHT_RGB_FLAVOUR3, LIGHT_RGB_FLAVOUR4, LIGHT_RGB_FLAVOUR5, LIGHT_RGB_FLAVOUR6};

unsigned long LIGHT_RGB_START = 7340032; // 00000000 01110000 00000000 00000000
unsigned long LIGHT_RGB_CS1 = 58720256; //00000011 10000000 00000000 00000000
unsigned long LIGHT_RGB_CS2 = 469762048;//00011100 00000000 00000000 00000000

unsigned long LIGHT_RGB_CS3 = 3758096384; //  11100000 00000000 00000000 00000000

byte RGB_WHITE = B111;
byte RGB_OFF = B000;
byte RGB_RED = B100;
byte RGB_GREEN = B010;
byte RGB_BLUE = B001;
byte RGB_YELLOW = B110;
byte RGB_CYAN = B011;
byte RGB_MAGENTA = B101;
byte W_ON = B1;
byte W_OFF = B0;

unsigned long LIGHT_ALL_ON = 4294967295;
unsigned long CurrentLightValues = LIGHT_ALL_ON; // All On 11111111 11111111 11111111 11111111
unsigned long LightEventSliceCount = 0;


#define EVENT_OFF 0 //ONE-TIME Turns specified light OFF
#define EVENT_ON_COLOR 1 //ONE-TIME Turns specified light ON to the selected color
#define EVENT_BLINK 2 //CONTINUOUS Toggles the selected light between OFF and the color selected on each cycle
#define EVENT_SLICE_OFF 3 //CONTINUOUS Toggles Alternates between the light being the selected color and it turning off for one cycle
                      //when the slice number is matched
#define EVENT_SLICE_ON 4 //CONTINUOUS Toggles Alternates between the light being the selected color and it turning off for one cycle
                      //when the slice number is matched

QueueList<byte> q_eventType;
QueueList<word> q_lightCode;
QueueList<byte> q_color;
QueueList<byte> q_slice;
QueueList<byte> q_totalSlices;

QueueList<byte> q_t_eventType;
QueueList<word> q_t_lightCode;
QueueList<byte> q_t_color;
QueueList<byte> q_t_slice;
QueueList<byte> q_t_totalSlices;




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

  //Disable all motors
   StopAllMotors();
  
    delay(2000);
  
  //Permanently output a PWM output to the MOTOR_PIN_PULSE
  analogWrite(PIN_MOTOR_PULSE, 175);
  
  //EStop parallel in shift register, load set to HIGH (turned LOW to LOAD)
  digitalWrite(PIN_ESTOP_LOAD, HIGH);
  
  InitializeSequence();
  
  //Setup the light timer interface
  MsTimer2::set(250, HandleLights); 
  MsTimer2::start();
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
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_WHITE_BOTTOMRIB,W_ON,0,0); 
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_WHITE_TOPRIB,W_ON,0,0);
  
  //Turn off center stage
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_CS1,0,0,0); 
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_CS2,0,0,0); 
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_CS3,0,0,0);   
  
  //Turn off start button
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_START,0,0,0);
  
  //Turn available colors green solid
  //and unavailable ones off
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    RegisterLightEvent(IsFlavourAvailable(i),FlavourLightsArray[i],RGB_GREEN,0,0); 
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
  //Turn all lights ON for 2 seconds, then flash each of them
  //off every 500 ms
  CurrentLightValues = 4294967295;
  UpdateLights(CurrentLightValues);
  delay(2000);
  
  //Build a light sequence array
  unsigned long LightSequence[12];
  LightSequence[0] = LIGHT_ALL_ON & ~LIGHT_WHITE_TOPRIB;
  LightSequence[1] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR1;
  LightSequence[2] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR2;  
  LightSequence[3] = LIGHT_ALL_ON & ~LIGHT_RGB_START;  
  LightSequence[4] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR3; 
  LightSequence[5] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR4; 
  LightSequence[6] = LIGHT_ALL_ON & ~LIGHT_RGB_CS1; 
  LightSequence[7] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR5; 
  LightSequence[8] = LIGHT_ALL_ON & ~LIGHT_RGB_FLAVOUR6; 
  LightSequence[9] = LIGHT_ALL_ON & ~LIGHT_RGB_CS2;
  LightSequence[10] = LIGHT_ALL_ON & ~LIGHT_RGB_CS3;  
  LightSequence[11] = LIGHT_ALL_ON & ~LIGHT_WHITE_BOTTOMRIB;
  
  for(int i = 0; i < 12 ; i++)
  {
    UpdateLights(LightSequence[i]);
    delay(500);
  }
  
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
  ClearLightEvents();
  
  int slice = 0;
  
  for(int i = 0; i < NUMBER_OF_FLAVOURS;i++)
  {
    if(SelectedFlavours[i] && IsFlavourAvailable(i))
    {
      RegisterLightEvent(EVENT_ON_COLOR,FlavourLightsArray[i],RGB_GREEN,0,0);
    }
    else if(!SelectedFlavours[i] & IsFlavourAvailable(i))
    {
      RegisterLightEvent(EVENT_SLICE_ON,FlavourLightsArray[i],RGB_BLUE,slice,HowManyAvailableFlavours + HowManyFlavoursSelected);
      slice++;
    }
  }
}

void WaitForUserInputs()
{
    unsigned long count = 0;
  

  
waitForFlavourOnly:
  //Turn the start button off
  ClearLightEvents();
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_START,0,0,0);

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
  RegisterLightEvent(EVENT_SLICE_ON,LIGHT_RGB_START,RGB_GREEN,0,1);
  
  //Flash the center stage to indicate the need for a tube
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS1,RGB_BLUE,0,2);
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS2,RGB_BLUE,0,2);
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS3,RGB_BLUE,0,2);

  
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
    ClearLightEvents();
    
  //Blink the start button red
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_START,RGB_RED,0,1);  

  //Blink all the flavour lights in a row
  for(int i = 0; i < NUMBER_OF_FLAVOURS;i++)
  {
      RegisterLightEvent(EVENT_SLICE_OFF,FlavourLightsArray[i],RGB_GREEN,i,NUMBER_OF_FLAVOURS);
  }
  
  //Blink center stage lights yellow
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS1,RGB_YELLOW,0,2);
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS2,RGB_YELLOW,0,2);
  RegisterLightEvent(EVENT_SLICE_OFF,LIGHT_RGB_CS3,RGB_YELLOW,0,2);

}

void SetLightsForTubeIsReadyWithTopUp()
{
   ClearLightEvents();
   
   //Turn off the flavour select lights
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    RegisterLightEvent(EVENT_OFF,FlavourLightsArray[i],0,0,0); 
  }
   
   //Light the center stage on white
   RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS1,RGB_WHITE,0,2);
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS2,RGB_WHITE,0,2);
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS3,RGB_WHITE,0,2);
  //Turn the start button on to green
  RegisterLightEvent(EVENT_SLICE_ON,LIGHT_RGB_START,RGB_GREEN,0,1);  
}
void SetLightsForTubeIsReady()
{
   ClearLightEvents();
   
   //Turn off the flavour select lights
  for(int i = 0; i < NUMBER_OF_FLAVOURS; i++)
  {
    RegisterLightEvent(EVENT_OFF,FlavourLightsArray[i],0,0,0); 
  }
   
   //Light the center stage on white
   RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS1,RGB_WHITE,0,2);
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS2,RGB_WHITE,0,2);
  RegisterLightEvent(EVENT_ON_COLOR,LIGHT_RGB_CS3,RGB_WHITE,0,2);
  //Turn the start button on to green
  RegisterLightEvent(EVENT_OFF,LIGHT_RGB_START,0,0,1);  
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
      valuesRead = valuesRead | (digitalRead(PIN_ESTOP_READ) & word(B10000000,B00000000));
      digitalWrite(PIN_ESTOP_CLOCK,LOW);
      delay(10);
      digitalWrite(PIN_ESTOP_CLOCK,HIGH);
    }
    
    return valuesRead;
  }

void ClearLightEvents()
{
  MsTimer2::stop();
  while(!q_eventType.isEmpty())
  {
    q_eventType.pop();
    q_lightCode.pop();
    q_color.pop();
    q_slice.pop();
    q_totalSlices.pop();
  }
  MsTimer2::start();
}

void RegisterLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices)
{
  MsTimer2::stop();
  
  q_eventType.push(eventType);
  q_lightCode.push(lightCode);
  q_color.push(color);
  q_slice.push(slice);
  q_totalSlices.push(totalSlices);
  
  MsTimer2::start();
}

void RegisterTempLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices)
{
  MsTimer2::stop();
  
  q_t_eventType.push(eventType);
  q_t_lightCode.push(lightCode);
  q_t_color.push(color);
  q_t_slice.push(slice);
  q_t_totalSlices.push(totalSlices);
  
  MsTimer2::start();
}

//Looks at the programmed light events list (blink, stop blink, turn on, turn off, color)
//and update the lightValues + push new values accordingly
void HandleLights()
{

  byte eventType;
  word lightCode;
  byte color;
  byte slice;
  byte totalSlices;
  LightEventSliceCount++;
  
  while(!q_eventType.isEmpty())
  {
    eventType = q_eventType.pop();
    lightCode = q_lightCode.pop();
    color = q_color.pop();
    slice = q_slice.pop();
    totalSlices = q_totalSlices.pop();  
    
    switch (eventType)
    {
      case EVENT_OFF:
        CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,RGB_OFF);
        break;
        
      case EVENT_ON_COLOR:
        CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,color);        
        break;
       
      case EVENT_BLINK:
        //figure out last state
        if(CurrentLightValues & lightCode > 0)
        {
          //light was on, turn it off
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,RGB_OFF);
        }
        else
        {
          //light was off, turn it on
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,color);                  
        }
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices);
        break;
        
      case EVENT_SLICE_ON:
        if(LightEventSliceCount % totalSlices == slice)
        {
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,color); 
        }
        else
        {
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,RGB_OFF);
        }
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices);
        break;
        
      case EVENT_SLICE_OFF:
        if(LightEventSliceCount % totalSlices == slice)
        {
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,RGB_OFF); 
        }
        else
        {
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,color);
        }
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices);      
        break;
    }  
  }
  UpdateLights(CurrentLightValues);
  
  //put the recuring events back into the light events queues (re-queue)
  while(!q_t_eventType.isEmpty())
  {
    q_eventType.push(q_t_eventType.pop());
    q_lightCode.push(q_t_lightCode.pop());
    q_color.push(q_t_color.pop());
    q_slice.push(q_t_slice.pop());
    q_totalSlices.push(q_t_totalSlices.pop());
  }    
  
}


word ShiftLightColorIn(word lightCode,byte color)
{
  //Find the bit positionb
  int bitPos = 0;
  while(lightCode & 1 != 1)
  {
    lightCode = lightCode >> 1;
    bitPos++;
  }
 
   
  word finalColorBits = lightCode & color;
  
  //Shift back
  finalColorBits = finalColorBits << bitPos;
  
  return finalColorBits; 
  
  
}

//Takes the ligthValue and push it out to the 32-Bit Power register array
void UpdateLights(unsigned long lightValues)
{
  digitalWrite(PIN_LIGHTS_SCLK, LOW);
  digitalWrite(PIN_LIGHTS_CLK, LOW);
  
  shiftOut(PIN_LIGHTS_SERIAL, PIN_LIGHTS_SCLK, LSBFIRST, lightValues);
  shiftOut(PIN_LIGHTS_SERIAL, PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 8);
  shiftOut(PIN_LIGHTS_SERIAL, PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 16);
  shiftOut(PIN_LIGHTS_SERIAL, PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 24);
  
  digitalWrite(PIN_LIGHTS_CLK, HIGH);  
  delay(1);
  digitalWrite(PIN_LIGHTS_CLK, LOW);  
  
}
