#include <EEPROM.h>

#define EEPROM_WAS_INITIALIZED 0
#define EEPROM_COUNTER 1

void setup()
{
  Serial.begin(9600);
  byte eepromWasInitialized = EEPROM.read(EEPROM_WAS_INITIALIZED);
  unsigned int counter = 0;
  
  if(eepromWasInitialized == 0)
  {
    //eeprom was initialized already so just read the 
    //value from in there
    
  }
  else
  {
  }
  
}

void loop()
{

}

