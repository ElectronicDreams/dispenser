#include "jag_lights.h"

#include "WProgram.h"
#include "QueueList.h"
#include "MsTimer2.h"				  

	unsigned long Jag_Lights::CurrentLightValues; 
	unsigned long Jag_Lights::LightEventSliceCount;
	
	int Jag_Lights::t_PIN_LIGHTS_SCLK;
	int Jag_Lights::t_PIN_LIGHTS_CLK;
	int Jag_Lights::t_PIN_LIGHTS_SERIAL;
	byte Jag_Lights::t_RGB_OFF;
	
	QueueList<byte> Jag_Lights::q_eventType;
	QueueList<unsigned long> Jag_Lights::q_lightCode;
	QueueList<byte> Jag_Lights::q_color;
	QueueList<byte> Jag_Lights::q_slice;
	QueueList<byte> Jag_Lights::q_totalSlices;
	QueueList<byte> Jag_Lights::q_multiplier;
	QueueList<byte> Jag_Lights::q_eventCount;

	QueueList<byte> Jag_Lights::q_t_eventType;
	QueueList<unsigned long> Jag_Lights::q_t_lightCode;
	QueueList<byte> Jag_Lights::q_t_color;
	QueueList<byte> Jag_Lights::q_t_slice;
	QueueList<byte> Jag_Lights::q_t_totalSlices;	
	QueueList<byte> Jag_Lights::q_t_multiplier;	
	QueueList<byte> Jag_Lights::q_t_eventCount;	

void Jag_Lights::SetupLights(unsigned long initialValue, int pin_LIGHTS_SCLK, int pin_LIGHTS_CLK, int pin_LIGHTS_SERIAL)
{  
  // Serial.print("SCLK: ");
  // Serial.print(pin_LIGHTS_SCLK);
  // Serial.println();
 
  // Serial.print("CLK: ");
  // Serial.print(pin_LIGHTS_CLK);
  // Serial.println();

  // Serial.print("SERIAL: ");
  // Serial.print(pin_LIGHTS_SERIAL);
  // Serial.println();

	
  t_RGB_OFF = B000;
  t_PIN_LIGHTS_SCLK = pin_LIGHTS_SCLK;
  t_PIN_LIGHTS_CLK = pin_LIGHTS_CLK;
  t_PIN_LIGHTS_SERIAL = pin_LIGHTS_SERIAL;
  LightEventSliceCount = 1;
  CurrentLightValues = initialValue;
  MsTimer2::set(100, Jag_Lights::HandleLights); 
  MsTimer2::start();
}

void Jag_Lights::RegisterLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices)
{
  Jag_Lights::RegisterLightEvent( eventType, lightCode, color,  slice,  totalSlices, 1, 1);
}

void Jag_Lights::RegisterLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices, byte multiplier)
{
  Jag_Lights::RegisterLightEvent( eventType, lightCode, color,  slice,  totalSlices, multiplier, 1);
}
void Jag_Lights::RegisterLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices, byte multiplier, byte eventCount)
{
	MsTimer2::stop();
	  
	  q_eventType.push(eventType);
	  q_lightCode.push(lightCode);
	  q_color.push(color);
	  q_slice.push(slice);
	  q_totalSlices.push(totalSlices);
	  q_multiplier.push(multiplier);
	  q_eventCount.push(eventCount);
	  
	  MsTimer2::start();
	
}
void Jag_Lights::RegisterTempLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices)
{
	Jag_Lights::RegisterTempLightEvent( eventType, lightCode, color,  slice,  totalSlices, 1, 1);
}
void Jag_Lights::RegisterTempLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices, byte multiplier)
{
	Jag_Lights::RegisterTempLightEvent( eventType, lightCode, color,  slice,  totalSlices, multiplier, 1);
}
void Jag_Lights::RegisterTempLightEvent(byte eventType, unsigned long lightCode,byte color, byte slice, byte totalSlices, byte multiplier, byte eventCount)
{
  MsTimer2::stop();
  
  q_t_eventType.push(eventType);
  q_t_lightCode.push(lightCode);
  q_t_color.push(color);
  q_t_slice.push(slice);
  q_t_totalSlices.push(totalSlices);
  q_t_multiplier.push(multiplier);
  q_t_eventCount.push(eventCount);
 
  MsTimer2::start();
}

void Jag_Lights::ClearLightEvents()
{
  MsTimer2::stop();
  
  //Serial.println("In ClearLightEvents");
  while(!q_eventType.isEmpty())
  {
    q_eventType.pop();
    q_lightCode.pop();
    q_color.pop();
    q_slice.pop();
    q_totalSlices.pop();
	q_multiplier.pop();
	q_eventCount.pop();
  }
  MsTimer2::start();
}


unsigned long Jag_Lights::ShiftLightColorIn(unsigned long lightCode,byte color)
{
  // Serial.println("In ShiftLightColorIn");
  // Serial.print("lightCode: ");
  // Serial.print(lightCode,BIN);
  // Serial.println();

  unsigned long initialLightCode = lightCode;
  //Find the bit position
  int bitPos = 0;
  while((unsigned long)(lightCode & 1UL) == 0UL)
  {
	//Serial.println("Shifted by 1");
    lightCode = lightCode >> 1;
    bitPos += 1;
  }
 
  // Serial.print("lightcode: ");
  // Serial.print(lightCode,BIN);
  // Serial.println();

  // Serial.print("bitpos: ");
  // Serial.print(bitPos,DEC);
  // Serial.println();
  
  // Serial.print("color: ");
  // Serial.print(color,BIN);
  // Serial.println();

  
  unsigned long finalColorBits = lightCode & (unsigned long)color;
  // Serial.print("processed lightcode: ");
  // Serial.print(finalColorBits,BIN);
  // Serial.println();

  
  
  //Shift back
  finalColorBits = finalColorBits << bitPos;
  
  // Serial.print("final lightcode: ");
  // Serial.print((finalColorBits | ~initialLightCode),BIN);
  // Serial.println(); 
  
  return (finalColorBits | ~initialLightCode); 
  
  
}

//Takes the ligthValue and push it out to the 32-Bit Power register array
void Jag_Lights::UpdateLights(unsigned long lightValues)
{

  // Serial.print("SCLK: ");
  // Serial.print(t_PIN_LIGHTS_SCLK);
  // Serial.println();
 
  // Serial.print("CLK: ");
  // Serial.print(t_PIN_LIGHTS_CLK);
  // Serial.println();

  // Serial.print("SERIAL: ");
  // Serial.print(t_PIN_LIGHTS_SERIAL);
  // Serial.println();
  

  digitalWrite(t_PIN_LIGHTS_SCLK, LOW);
  digitalWrite(t_PIN_LIGHTS_CLK, LOW);
  
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 8UL);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 16UL);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 24UL);
  
  digitalWrite(t_PIN_LIGHTS_CLK, HIGH);  
  delay(1);
  digitalWrite(t_PIN_LIGHTS_CLK, LOW);  
  
}

//Looks at the programmed light events list (blink, stop blink, turn on, turn off, color)
//and update the lightValues + push new values accordingly
void Jag_Lights::HandleLights()
{
  MsTimer2::stop();
  unsigned long timeStart = micros();
  // Serial.println("In HandleLights");
  // Serial.println(CurrentLightValues,BIN);
  byte eventType;
  unsigned long lightCode;
  byte color;
  byte slice;
  byte totalSlices;
  byte multiplier;
  byte eventCount;
  LightEventSliceCount++;
  unsigned long savedLightValue;
  int numOfEvents = 0;
  
  while(!q_eventType.isEmpty())
  {
	numOfEvents++;
    eventType = q_eventType.pop();
    lightCode = q_lightCode.pop();
    color = q_color.pop();
    slice = q_slice.pop();
    totalSlices = q_totalSlices.pop();  
    multiplier = q_multiplier.pop(); 
	eventCount = q_eventCount.pop();
	
	// Serial.println("Event registered:");
	// Serial.print("type: ");
	// Serial.print(eventType,DEC);
	// Serial.println();
	// Serial.print("lightCode: ");
	// Serial.print(lightCode,BIN);
	// Serial.println();
	// Serial.print("color: ");
	// Serial.print(color,BIN);
	// Serial.println();
	// Serial.print("slice: ");
	// Serial.print(slice,DEC);
	// Serial.println();
	// Serial.print("totalSlices: ");
	// Serial.print(totalSlices,DEC);
	// Serial.println();
	
	// Serial.print("Multiplier: ");
	// Serial.print(multiplier,DEC);
	// Serial.println();
	
	// Serial.print("LightEventSliceCount: ");
	// Serial.print(LightEventSliceCount,DEC);
	// Serial.println();
	

	// Serial.print("CurrentLightValues: ");
	// Serial.print(CurrentLightValues,BIN);
	// Serial.println();

    switch (eventType)
    {
      case EVENT_OFF:
        CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,t_RGB_OFF);
        break;
        
      case EVENT_ON_COLOR:
        CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,color);        
        break;
       
      case EVENT_BLINK:
			// Serial.println("inside blink");
        //figure out last state
		if(LightEventSliceCount % multiplier == 0) 
		{
			// Serial.println();
			// Serial.print("Light code : ");
			// Serial.print(lightCode, BIN);
			if((unsigned long)(CurrentLightValues & lightCode) > 0UL) //That light is NOT off
			{
			  //Serial.println(" Blink OFF");
			  //light was on, turn it off
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,t_RGB_OFF);
			}
			else
			{
			  //Serial.println(" Blink ON");
			  
			  //light was off, turn it on
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,color);                  
			}
		}
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices, multiplier, eventCount);
        break;
        
      case EVENT_SLICE_ON:
		if(LightEventSliceCount % multiplier == 0) 
		{
			// Serial.println();
			// Serial.print("Light code : ");
			// Serial.print(lightCode, BIN);
			
			if(eventCount % totalSlices == slice)
			{
				//Serial.println(" Slice ON");
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,color); 
			}
			else
			{
				//Serial.println(" Slice OFF");
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,t_RGB_OFF);
			}
			eventCount++;
		}
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices, multiplier, eventCount);
        break;
        
      case EVENT_SLICE_OFF:
		if(LightEventSliceCount % multiplier == 0) 
		{
			// Serial.println();
			// Serial.print("Light code : ");
			// Serial.print(lightCode, BIN);
		
			if(eventCount % totalSlices == slice)
			{
				//Serial.println(" Slice OFF");
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,t_RGB_OFF); 
			}
			else
			{
				//Serial.println(" Slice ON");
			  CurrentLightValues = (CurrentLightValues | lightCode) & ShiftLightColorIn(lightCode,color);
			}
			eventCount++;
		}
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices, multiplier, eventCount);      
        break;
    }  
  }
  UpdateLights(CurrentLightValues);
  
  // if(CurrentLightValues != savedLightValue)
  // {
	  // Serial.print("New light value: ");
	  // Serial.print(CurrentLightValues,BIN);
	  // Serial.println();	
  // }
  
  // Serial.print("Num of events in queue: ");
  // Serial.print(numOfEvents);
  // Serial.println();
  
  numOfEvents = 0;
  
  //put the recuring events back into the light events queues (re-queue)
  while(!q_t_eventType.isEmpty())
  {
	numOfEvents++;
    q_eventType.push(q_t_eventType.pop());
    q_lightCode.push(q_t_lightCode.pop());
    q_slice.push(q_t_slice.pop());
    q_color.push(q_t_color.pop());
    q_totalSlices.push(q_t_totalSlices.pop());
	q_multiplier.push(q_t_multiplier.pop());
	q_eventCount.push(q_t_eventCount.pop());
  } 
  // Serial.print("Num of recurring events in queue: ");
  // Serial.print(numOfEvents);
  // Serial.println();	
  
  // Serial.print("New value: ");
  // Serial.print(CurrentLightValues,BIN);
  // Serial.println();
  
  // Serial.print("Total time processing lights: ");
  // Serial.print(micros() - timeStart);
  // Serial.println(" um");
  MsTimer2::start();
} 

void Jag_Lights::Suspend()
{
	MsTimer2::stop();
}

void Jag_Lights::Continue()
{
	MsTimer2::start();
}