#define PIN_DAC 0

void setup() {
  // put your setup code here, to run once:
  
  Serial.begin(9600);
}

void loop() {
  // put your main code here, to run repeatedly: 
  
  int value = analogRead(PIN_DAC);
  
  Serial.print("DAC VALUE: ");
  Serial.print(value);
  
  
}
