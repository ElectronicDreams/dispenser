#define PIN_ESTOP_READ 10
#define PIN_ESTOP_LOAD 3
#define PIN_ESTOP_CLOCK 4

word eStops = word(B00000000,B00000000);

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

word CheckEStops()
  {
    //Read in all EStop Sensors
    digitalWrite(PIN_ESTOP_LOAD,LOW);
    delay(10);
    digitalWrite(PIN_ESTOP_LOAD,HIGH);
    delay(10);
    
    word valuesRead = word(B00000000,B00000000);
    //Shift EStop values in
    for(int i = 0; i <=15 ; i++)
    {
      valuesRead = valuesRead >> 1;
      valuesRead = valuesRead | (digitalRead(PIN_ESTOP_READ) << 15);
      digitalWrite(PIN_ESTOP_CLOCK,LOW);
      delay(10);
      digitalWrite(PIN_ESTOP_CLOCK,HIGH);
    }
    
    return valuesRead;
  }
