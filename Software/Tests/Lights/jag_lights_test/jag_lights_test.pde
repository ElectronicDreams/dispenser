#include <MsTimer2.h>
#include <QueueList.h>
#include <jag_lights.h>
//Basic program to test the jag_lights library

#define PIN_LIGHTS_SCLK 5 //blue
#define PIN_LIGHTS_CLK 6 //green
#define PIN_LIGHTS_SERIAL 7 //white

unsigned long LIGHT_RGB_RIB1 = 7; //               00000000 00000000 00000000 00000111
unsigned long LIGHT_RGB_RIB2 = 56; //              00000000 00000000 00000000 00111000
unsigned long LIGHT_RGB_RIB3 = 448; //             00000000 00000000 00000001 11000000
unsigned long LIGHT_RGB_RIB4 = 3584; //            00000000 00000000 00001110 00000000
unsigned long LIGHT_RGB_RIB5 = 28672; //           00000000 00000000 01110000 00000000
unsigned long LIGHT_RGB_RIB6 = 22976; //          00000000 00000011 10000000 00000000

unsigned long LIGHT_RG_START = 786432; //          00000000 00001100 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR1 = 1048576; //   00000000 00010000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR2 = 2097152; //   00000000 00100000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR3 = 4194304; //   00000000 01000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR4 = 8388608; //   00000000 10000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR5 = 16777216; //  00000001 00000000 00000000 00000000
unsigned long LIGHT_WHITE_FLAVOUR6 = 33554432; //  00000010 00000000 00000000 00000000
unsigned long LIGHT_RGB_CS_TB = 469762048; //      00011100 00000000 00000000 00000000
unsigned long LIGHT_RGB_CS_CENTER = 3758096384; // 11100000 00000000 00000000 00000000

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
   
  // put your setup code here, to run once:
  pinMode(PIN_LIGHTS_SCLK, OUTPUT);
  pinMode(PIN_LIGHTS_CLK, OUTPUT);
  pinMode(PIN_LIGHTS_SERIAL, OUTPUT);
  
  Jag_Lights::SetupLights(CurrentLightValues,PIN_LIGHTS_SCLK, PIN_LIGHTS_CLK, PIN_LIGHTS_SERIAL);

  Jag_Lights::ClearLightEvents();

   SetupAllLightsEvents(EVENT_BLINK,RGB_WHITE,10);
//   delay(1000);
//   SetupAllLightsEvents(EVENT_OFF,RGB_WHITE);
//   delay(1000);
//   SetupAllLightsEvents(EVENT_ON_COLOR,RGB_WHITE);   
//     Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB6, RGB_WHITE, 0, 6);
//    Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB5, RGB_WHITE, 1, 6); 
//    Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB4, RGB_WHITE, 2, 6); 
//    Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB3, RGB_WHITE, 3, 6); 
//    Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB2, RGB_WHITE, 4, 6); 
//    Jag_Lights::RegisterLightEvent(EVENT_SLICE_ON , LIGHT_RGB_RIB1, RGB_WHITE, 5, 6);     

  //Serial.println("Program started");
}

void loop() {
    

  
//  // put your main code here, to run repeatedly: 
//    Serial.println("Registering light event ON");    
//    TurnAllLightsOff();
//    SetupAllLightsEvents(EVENT_SLICE_ON,RGB_GREEN);
//    delay(10000);
//    Jag_Lights::ClearLightEvents();
//    TurnAllLightsOff();
//    SetupAllLightsEvents(EVENT_SLICE_OFF,RGB_GREEN);
//    delay(10000);
//    Jag_Lights::ClearLightEvents();
//    TurnAllLightsOff();
//    SetupAllLightsEvents(EVENT_BLINK,RGB_BLUE);
//    delay(5000);
//    Jag_Lights::ClearLightEvents();
//        
//    Serial.println("Registering light event off");    
//    TurnAllLightsOff();
//    delay(2000);
  
}

void SetupAllLightsEvents(byte eventType,byte color, byte multiplier)
{
    Jag_Lights::RegisterLightEvent(eventType, LIGHT_RGB_CS_CENTER, color, 0, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_CS_TB, color, 1, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RG_START, color, 1, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR6, color, 2, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR5, color, 3, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR4, color, 4, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR3, color, 5, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR2, color, 6, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_WHITE_FLAVOUR1, color, 7, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB6, color, 8, 10,multiplier);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB5, color, 9, 10,multiplier); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB4, color, 9, 10,multiplier); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB3, color, 9, 10,multiplier); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB2, color, 9, 10,multiplier); 
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_RIB1, color, 9, 10,multiplier);     
}

void TurnAllLightsOff()
{
  SetupAllLightsEvents(EVENT_OFF,0,1);
}

