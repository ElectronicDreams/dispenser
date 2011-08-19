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



#define NUMBER_OF_SHIFT_CHIPS   2
#define DATA_WIDTH   NUMBER_OF_SHIFT_CHIPS * 8
#define PULSE_WIDTH_USEC   5
#define POLL_DELAY_MSEC   1

#define BYTES_VAL_T unsigned int

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

#define NEW_TUBE_MOTOR_RESET 45000

int PIN_ESTOP_READ = 10;
int PIN_ESTOP_LOAD = 3;
int PIN_ESTOP_CLOCK = 4;

byte AvailableFlavours = byte(B00111111);
byte FlavoursInReloadPosition = byte(B00000000);
byte HowManyAvailableFlavours = NUMBER_OF_FLAVOURS;
boolean SelectedFlavours[NUMBER_OF_FLAVOURS] = {false, false, false, false, false, false};
int FlavourSelectInputs[NUMBER_OF_FLAVOURS] = {PIN_INPUT_FLAV_1, PIN_INPUT_FLAV_2, PIN_INPUT_FLAV_3, PIN_INPUT_FLAV_4, PIN_INPUT_FLAV_5, PIN_INPUT_FLAV_6};
int HowManyFlavoursSelected = 0;
byte FlavoursReloading = byte(B00000000);

boolean manualModeActive = true;

BYTES_VAL_T eStops = 0;

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


  //Set speed
  //setPwmFrequency(9,4);
  
  //Disable all motors
   StopAllMotors();
  
    delay(2000);
  
  //Permanently output a PWM output to the MOTOR_PIN_PULSE
  analogWrite(PIN_MOTOR_PULSE, 175);
  
  
  digitalWrite(PIN_ESTOP_CLOCK, LOW);
  digitalWrite(PIN_ESTOP_LOAD, HIGH);
  
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
  AvailableFlavours = ~(lowByte(eStops));
  FlavoursInReloadPosition = (highByte(eStops));
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
  return ((unsigned int)((AvailableFlavours & ~FlavoursReloading & ~FlavoursInReloadPosition) & (B00000001 << flavourIndex)) > 0);
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
  
waitForFlavourOnly:
  //First, wait for at least one flavour to be selected
  while(HowManyFlavoursSelected < 1)
  {
    DetectAvailableFlavours();
    
    //Handle exhausted cartridges... move motor to reload position
    if((unsigned int)(~AvailableFlavours) > 0 || (unsigned int)FlavoursReloading > 0)
    {
      //Update the FlavoursReloading bit mask and motorMask
      FlavoursReloading = (FlavoursReloading & ~FlavoursInReloadPosition) | (~AvailableFlavours & ~FlavoursInReloadPosition);
      RunMultipleMotors(FlavoursReloading, DIR_UP);  
    } else {
      StopAllMotors();
    }
    
    //If a flavour is in reload position and operator signals a new cartridge has
    //been inserted, then moved motor back in position
    unsigned int motorToReset = (unsigned int)(~AvailableFlavours & FlavoursInReloadPosition);
    if(motorToReset > 0)
    {
      Serial.println("Inside motorToReset confirm");
      //Wait for confirmation
      delay(2000);
      DetectAvailableFlavours();
      unsigned int motorResetConfirm = motorToReset & (~AvailableFlavours & FlavoursInReloadPosition);
      if(motorResetConfirm > 0)
      {
        //Wait for release of button
        while((unsigned int)(motorResetConfirm & ~AvailableFlavours) > 0)
        {
          DetectAvailableFlavours();
        }
        unsigned long startTime = millis();
        RunMultipleMotors(motorResetConfirm,DIR_DOWN);
        delay(3000); //One second delay to allow time for the top estop to release
        while(true)
        {
          DetectAvailableFlavours();
          if(millis() - startTime >= NEW_TUBE_MOTOR_RESET)
          {
            StopAllMotors();
            break;
          }
          if((unsigned int)(motorResetConfirm & ~AvailableFlavours) > 0)
          {
            FlavoursReloading = motorResetConfirm & ~AvailableFlavours;
            RunMultipleMotors(FlavoursReloading, DIR_UP);
            break;            
          }
        }
      }
    }
    
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

BYTES_VAL_T CheckEStops()
  {
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

    return(bytesVal);    
  }



