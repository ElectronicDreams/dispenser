#include <MsTimer2.h>
#include <QueueList.h>
#include <jag_lights.h>
//Basic program to test the jag_lights library

#define PIN_LIGHTS_SCLK 3
#define PIN_LIGHTS_CLK 2
#define PIN_LIGHTS_SERIAL 7

unsigned long LIGHT_WHITE_BOTTOMRIB = 1; //  00000000 00000000 00000000 00000001
unsigned long LIGHT_WHITE_TOPRIB = 2; //     00000000 00000000 00000000 00000010

unsigned long LIGHT_RGB_FLAVOUR1 = 28; //    00000000 00000000 00000000 00011100
unsigned long LIGHT_RGB_FLAVOUR2 = 224; //   00000000 00000000 00000000 11100000
unsigned long LIGHT_RGB_FLAVOUR3 = 1792; //  00000000 00000000 00000111 00000000
unsigned long LIGHT_RGB_FLAVOUR4 = 14336; // 00000000 00000000 00111000 00000000
unsigned long LIGHT_RGB_FLAVOUR5 = 114688; //00000000 00000001 11000000 00000000
unsigned long LIGHT_RGB_FLAVOUR6 = 917504; //00000000 00001110 00000000 00000000
//unsigned long FlavourLightsArray[NUMBER_OF_FLAVOURS] = {LIGHT_RGB_FLAVOUR1, LIGHT_RGB_FLAVOUR2, LIGHT_RGB_FLAVOUR3, LIGHT_RGB_FLAVOUR4, LIGHT_RGB_FLAVOUR5, LIGHT_RGB_FLAVOUR6};

unsigned long LIGHT_RGB_START = 7340032; // 00000000 01110000 00000000 00000000
unsigned long LIGHT_RGB_CS1 = 58720256; //00000011 10000000 00000000 00000000
unsigned long LIGHT_RGB_CS2 = 469762048;//00011100 00000000 00000000 00000000

unsigned long LIGHT_RGB_CS3 = 3758096384; //  11100000 00000000 00000000 00000000

byte RGB_WHITE = B111;
byte RGB_OFF = B000;
byte RGB_RED = B100;
byte RGB_GREEN = B001;
byte RGB_BLUE = B010;
byte RGB_YELLOW = B101;
byte RGB_CYAN = B011;
byte RGB_MAGENTA = B110;
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

  
  Serial.println("Program started");
}

void loop() {
  // put your main code here, to run repeatedly: 
    Serial.println("Registering light event ON");    
    TurnAllLightsOff();
    SetupAllLightsEvents(EVENT_SLICE_ON,RGB_GREEN);
    delay(10000);
    Jag_Lights::ClearLightEvents();
    TurnAllLightsOff();
    SetupAllLightsEvents(EVENT_SLICE_OFF,RGB_GREEN);
    delay(10000);
    Jag_Lights::ClearLightEvents();
    TurnAllLightsOff();
    SetupAllLightsEvents(EVENT_BLINK,RGB_BLUE);
    delay(5000);
    Jag_Lights::ClearLightEvents();
        
    Serial.println("Registering light event off");    
    TurnAllLightsOff();
    delay(2000);
  
}

void SetupAllLightsEvents(byte eventType,byte color)
{
    Jag_Lights::RegisterLightEvent(eventType, LIGHT_RGB_CS3, color, 0, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_CS2, color, 1, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_CS1, color, 2, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_START, color, 3, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR6, color, 4, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR5, color, 5, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR4, color, 6, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR3, color, 7, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR2, color, 8, 10);
    Jag_Lights::RegisterLightEvent(eventType , LIGHT_RGB_FLAVOUR1, color, 9, 10); 
}

void TurnAllLightsOff()
{
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS3, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS2, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_CS1, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_START, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR6, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR5, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR4, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR3, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR2, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_RGB_FLAVOUR1, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_TOPRIB, RGB_GREEN, 0, 3);
    Jag_Lights::RegisterLightEvent(EVENT_OFF , LIGHT_WHITE_BOTTOMRIB, RGB_GREEN, 0, 3);  
}

