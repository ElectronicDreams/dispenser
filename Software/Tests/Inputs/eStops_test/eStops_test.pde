
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

#define BYTES_VAL_T word

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
  // put your setup code here, to run once:
  Serial.begin(9600);
  
  pinMode(PIN_ESTOP_READ, INPUT);
  pinMode(PIN_ESTOP_LOAD, OUTPUT);
  pinMode(PIN_ESTOP_CLOCK, OUTPUT);
  
  //EStop parallel in shift register, load set to HIGH (turned LOW to LOAD)
  digitalWrite(PIN_ESTOP_LOAD, HIGH);
}

void loop() {
  delay(1000);
  
  eStops = CheckEStops();
  Serial.println(eStops,BIN);
  
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

