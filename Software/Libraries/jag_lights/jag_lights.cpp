#include "jag_lights.h"

#include "WProgram.h"
#include "QueueList.h"
#include "MsTimer2.h"				  

	unsigned long Jag_Lights::CurrentLightValues; 
	unsigned long Jag_Lights::LightEventSliceCount;
	
	byte Jag_Lights::t_PIN_LIGHTS_SCLK;
	byte Jag_Lights::t_PIN_LIGHTS_CLK;
	byte Jag_Lights::t_PIN_LIGHTS_SERIAL;
	byte Jag_Lights::t_RGB_OFF;
	
	QueueList<byte> Jag_Lights::q_eventType;
	QueueList<word> Jag_Lights::q_lightCode;
	QueueList<byte> Jag_Lights::q_color;
	QueueList<byte> Jag_Lights::q_slice;
	QueueList<byte> Jag_Lights::q_totalSlices;

	QueueList<byte> Jag_Lights::q_t_eventType;
	QueueList<word> Jag_Lights::q_t_lightCode;
	QueueList<byte> Jag_Lights::q_t_color;
	QueueList<byte> Jag_Lights::q_t_slice;
	QueueList<byte> Jag_Lights::q_t_totalSlices;	

void Jag_Lights::SetupLights(word initialValue, byte pin_LIGHTS_SCLK, byte pin_LIGHTS_CLK, byte pin_LIGHTS_SERIAL)
{
  t_RGB_OFF = B000;
  LightEventSliceCount = 0;
  CurrentLightValues = initialValue;
  MsTimer2::set(250, Jag_Lights::HandleLights); 
  MsTimer2::start();
}

void Jag_Lights::RegisterLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices)
{
  MsTimer2::stop();
  
  q_eventType.push(eventType);
  q_lightCode.push(lightCode);
  q_color.push(color);
  q_slice.push(slice);
  q_totalSlices.push(totalSlices);
  
  MsTimer2::start();
}


void Jag_Lights::RegisterTempLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices)
{
  MsTimer2::stop();
  
  q_t_eventType.push(eventType);
  q_t_lightCode.push(lightCode);
  q_t_color.push(color);
  q_t_slice.push(slice);
  q_t_totalSlices.push(totalSlices);
  
  MsTimer2::start();
}

void Jag_Lights::ClearLightEvents()
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


word Jag_Lights::ShiftLightColorIn(word lightCode,byte color)
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
void Jag_Lights::UpdateLights(unsigned long lightValues)
{
  digitalWrite(t_PIN_LIGHTS_SCLK, LOW);
  digitalWrite(t_PIN_LIGHTS_CLK, LOW);
  
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 8);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 16);
  shiftOut(t_PIN_LIGHTS_SERIAL, t_PIN_LIGHTS_SCLK, LSBFIRST, lightValues >> 24);
  
  digitalWrite(t_PIN_LIGHTS_CLK, HIGH);  
  delay(1);
  digitalWrite(t_PIN_LIGHTS_CLK, LOW);  
  
}

//Looks at the programmed light events list (blink, stop blink, turn on, turn off, color)
//and update the lightValues + push new values accordingly
void Jag_Lights::HandleLights()
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
        CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,t_RGB_OFF);
        break;
        
      case EVENT_ON_COLOR:
        CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,color);        
        break;
       
      case EVENT_BLINK:
        //figure out last state
        if(CurrentLightValues & lightCode > 0)
        {
          //light was on, turn it off
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,t_RGB_OFF);
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
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,t_RGB_OFF);
        }
        RegisterTempLightEvent(eventType,lightCode,color,slice,totalSlices);
        break;
        
      case EVENT_SLICE_OFF:
        if(LightEventSliceCount % totalSlices == slice)
        {
          CurrentLightValues = CurrentLightValues & ShiftLightColorIn(lightCode,t_RGB_OFF); 
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
    q_slice.push(q_t_slice.pop());
    q_color.push(q_t_color.pop());
    q_totalSlices.push(q_t_totalSlices.pop());
  }    
  
}
