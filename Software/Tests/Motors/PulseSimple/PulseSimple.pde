void setup() {
  // put your setup code here, to run once:
  pinMode(11, OUTPUT);
  pinMode(12, OUTPUT);
}
 
void loop() {
  // put your main code here, to run repeatedly: 
  
  digitalWrite(12, HIGH);
  
  analogWrite(11,127);
  analogWrite(9,127);
  
  delay(2000);
  digitalWrite(12, LOW);
  
  delay(2000);
  
  
  
}
