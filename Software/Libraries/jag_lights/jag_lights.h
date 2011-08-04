#ifndef _JAG_LIGHTS_H
#define _JAG_LIGHTS_H

#include "WProgram.h"
#include "QueueList.h"
#include "MsTimer2.h"				  

#define EVENT_OFF 0 //ONE-TIME Turns specified light OFF
#define EVENT_ON_COLOR 1 //ONE-TIME Turns specified light ON to the selected color
#define EVENT_BLINK 2 //CONTINUOUS Toggles the selected light between OFF and the color selected on each cycle
#define EVENT_SLICE_OFF 3 //CONTINUOUS Toggles Alternates between the light being the selected color and it turning off for one cycle
                      //when the slice number is matched
#define EVENT_SLICE_ON 4 //CONTINUOUS Toggles Alternates between the light being the selected color and it turning off for one cycle
                      //when the slice number is matched					  
					  
namespace Jag_Lights {

//private:
	extern unsigned long CurrentLightValues; 
	extern unsigned long LightEventSliceCount;
	
	extern byte t_PIN_LIGHTS_SCLK;
	extern byte t_PIN_LIGHTS_CLK;
	extern byte t_PIN_LIGHTS_SERIAL;
	extern byte t_RGB_OFF;
	
	extern QueueList<byte> q_eventType;
	extern QueueList<word> q_lightCode;
	extern QueueList<byte> q_color;
	extern QueueList<byte> q_slice;
	extern QueueList<byte> q_totalSlices;

	extern QueueList<byte> q_t_eventType;
	extern QueueList<word> q_t_lightCode;
	extern QueueList<byte> q_t_color;
	extern QueueList<byte> q_t_slice;
	extern QueueList<byte> q_t_totalSlices;	
	
	void RegisterTempLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices);
	
	word ShiftLightColorIn(word lightCode,byte color);
	void UpdateLights(unsigned long lightValues);
	
	
	
//public:
	void SetupLights(word initialValue, byte pin_LIGHTS_SCLK, byte pin_LIGHTS_CLK, byte pin_LIGHTS_SERIAL);
	void RegisterLightEvent(byte eventType, word lightCode,byte color, byte slice, byte totalSlices);
	void ClearLightEvents();
	void HandleLights();
};
#endif // _JAG_LIGHTS_H
