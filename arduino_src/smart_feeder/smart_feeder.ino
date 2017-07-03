
// smart_feeder.ino
// Smart Feeder Device Software
// 
// Created by Freisthler, Andrew on 5/17/17.
// Copyright © 2017 Freisthler, Andrew. All rights reserved.
//

//
// Library Includes
//
#include <Arduino.h>
#include <Time.h>
#include <Dusk2Dawn.h>
#include <Chronos.h>
#include <SPI.h>
#include <TimeLib.h>
#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "Adafruit_BluefruitLE_UART.h"
#include "LowPower.h"

//
// I have the factory reset set to on for sanity during development.  For production we'd set 
//   0 (off).  For the LED lets show communication.  Eventualy we would set to DISABLE.
//
#define FACTORYRESET_ENABLE       1
#define MODE_LED_BEHAVIOUR        "BLEUART"

//
// We can use hardware SPI to communicate with BLE board.  Specify pins.
//
#define BLUEFRUIT_SPI_CS          8
#define BLUEFRUIT_SPI_IRQ         7
#define BLUEFRUIT_SPI_RST         4
#define BLUEFRUIT_UART_MODE_PIN   12
#define BUFSIZE                   128
#define VERBOSE_MODE              false

//
// Set device name.  This needs to match what the iOS app is looking for
//
#define DEVICE_NAME               "Adafruit Bluefruit LE"

//
// Set antenna power in DB.  Default is 0.  A lower power will save power, but reduce range
//   Allowable: -40, -20, -16, -12, -8, -4, 0, 4
//
#define ANTENNA_POWER             "0"

// 
// Start up BLE as configured
//
Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);

//
// Define Motor Vars as Control Pins.  enA is PWM.  Documenation for this board is very sparse.
//   Write PWM to enA to turn on motor.  With IN1 HIGH and IN2 LOW it spins one direction, with
//   with IN1 LOW and IN2 HIGH it spins the other.  With both LOW and enA still high with some
//   PWM value it appears to apply a break using power.  So, we set enA fully low when not in
//   use.
//
int enA = 6;
int IN1 = 5;  
int IN2 = 2; 

//
// Define Location Vars that we need globally.  The iOS app will send lat/long, utc offset, 
//   and current time to arduino as it has no internal clock.  -9999 simply indicates not 
//   initiated.  We need the time set boolean to prevent calculations from taking place until
//   time has been set that otherwise would have fired based upon event.
//
double localLatitude = 0.0;
double localLongitude = 0.0;
int utcOffset = -9999;
boolean timeSetBool = false;

//
// Define struct and array to hold run event configurations.  maxNumEvents will need to mirror
//   what is developed in the iOS app.  The limitaion is the microcontroller memory.  During
//   development there were issues but I blieve this was to all the debugging over serial port
//   with much string manipulation.  This has been helped by switching strings to not use
//   dynamic meomry where possible with F().
//
const int maxNumEvents = 10;
int numRunEvents = 0;
typedef struct {
     String type;
     int offset;
     int runSeconds;
     String datetime;
} run_event;
run_event run_events[maxNumEvents];

//
// Define array to hold run times for today and tomororw.  We never need to know more than that
//   for running or reporting.  We will recalculate on a new day boundry (midnight).  Also
//   define an array to hold their durations (would have been better to have them together in
//   a struct, but two arrays works).
//
int numPossibleRunTimes = 0;
Chronos::DateTime possibleRunTimes[maxNumEvents * 2];
int possibleRunTimesDurations[maxNumEvents * 2];

//
// These variables hold sunrise/sunset calculations used in later run time calculations
//
Chronos::DateTime todaySunrise = Chronos::DateTime();
Chronos::DateTime todaySunset = Chronos::DateTime();
Chronos::DateTime tomorrowSunrise = Chronos::DateTime();
Chronos::DateTime tomorrowSunset = Chronos::DateTime();

//
// Initialze motor board, serial port, BLE module.  With the reset in place the startup time
//   is about 4 seconds.  With the factory reset disabled startup is 3 seconds.  The setup 
//   method is run a single time by the microcotroller.
//
void setup(void) {
  
  // Using serial for debugging.
  Serial.begin(115200);
  Serial.println(F("<++ Initialization Started"));

  // Motor control board pins
  Serial.println(F("<++ Configuring Stepper Motor Control Board"));
  pinMode(enA, OUTPUT);
  pinMode(IN1, OUTPUT);   
  pinMode(IN2, OUTPUT); 

  // Init the BLE module and reset if configured to do so
  Serial.println(F("<++ Initializing BLE Board"));
  ble.begin(VERBOSE_MODE);
  if (FACTORYRESET_ENABLE) {
    ble.factoryReset();
  }
  
  // Set echo to false, set LED mode behavior, advertised name, antenna power
  ble.echo(false);
  ble.sendCommandCheckOK("AT+HWModeLED=" MODE_LED_BEHAVIOUR);
  ble.sendCommandCheckOK("AT+GAPDEVNAME=" DEVICE_NAME);
  ble.sendCommandCheckOK("AT+BLEPOWERLEVEL=" ANTENNA_POWER);
  
  Serial.println(F("<++ Initialization Completed"));
}

//
// This is our main execution loop.  It does the following:
//   1) Check if it is time to run the motor base on schedule.  If so, run it.
//   2) If BLE is not connected, enter low power mode and sleep for 2 seconds.
//   3) Check for commands from connected BLE device.  If present, analyze and execute.
//   
void loop(void) {

  // See if it is time to run.  Routine to run motor will execute if so.
  testPossibleRunTimes();

  // If BLE is not connected we will enter low power mode for 2 seconds to save power
  if (!ble.isConnected()) {
      // todo: implement this.  Currently makes multiple commands per buffer issue worse.
      // LowPower.powerDown(SLEEP_2S, ADC_OFF, BOD_OFF);
  }

  // Check for a new command from connected device.  If nothing there (an OK return) we can 
  //   return which will put us back to the top of the loop.
  ble.println("AT+BLEUARTRX");
  ble.readline();
  if (strcmp(ble.buffer, "OK") == 0) {
    return;
  }
  
  // If here, data was received from BLE.  Echo to screen for debug then recognize command
  Serial.print(F("=>> ")); Serial.println(ble.buffer);
    
  // la - Latitude to set for surise calculations
  if (ble.buffer[0] ==  'l' && ble.buffer[1] ==  'a') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    syncLatitude(ble.buffer);
  } 

  // lo - longitude to set for sunrise calculations
  if (ble.buffer[0] ==  'l' && ble.buffer[1] ==  'o') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    syncLongitude(ble.buffer);
  }

  // ut - utc offset to set for sunrise calculations
  if (ble.buffer[0] ==  'u' && ble.buffer[1] ==  't') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    syncUtc(ble.buffer);
  }
  
  // ts - time to set clock with
  if (ble.buffer[0] ==  't' && ble.buffer[1] ==  's') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    syncTime(ble.buffer);
  }

  // st - request for status
  if (ble.buffer[0] ==  's' && ble.buffer[1] ==  't') {
    syncStatus();  
  }

  // ru - run motor immediately
  if (ble.buffer[0] ==  'r' && ble.buffer[1] ==  'u') {
    runMotor(3);
  }

  // cl - clear and set new # of entries 
  if (ble.buffer[0] ==  'c' && ble.buffer[1] ==  'l') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    clearRunEntries(ble.buffer);
  }

  // ty - set type for a specific run event 
  if (ble.buffer[0] ==  't' && ble.buffer[1] ==  'y') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    setType(ble.buffer);
  }

  // rm - set run duration for a specific run event 
  if (ble.buffer[0] ==  'r' && ble.buffer[1] ==  'm') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    setRunTime(ble.buffer);
  }

  // of - set offset for a specific run event 
  if (ble.buffer[0] ==  'o' && ble.buffer[1] ==  'f') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    setOffset(ble.buffer);
  }

  // da - set datetime for a specific run event 
  if (ble.buffer[0] ==  'd' && ble.buffer[1] ==  'a') {
    memmove(ble.buffer, ble.buffer+2, strlen(ble.buffer));
    setDatetime(ble.buffer);
  }

  // rc - recaluclate possible run times.  Called after all specific run events specified. 
  if (ble.buffer[0] ==  'r' && ble.buffer[1] ==  'c') {
    evalCurrentRunEvents();
  }

  // wait for BLE board to be good state then loop
  ble.waitForOK();
}

//
// The arduino has no idea what time it is when it is started.  This method is called when
//   the connected application sends the time as it knows it.  There is an assumption they
//   are in the same time zone and such since the BLE range is feet not miles.  Attempt to
//   calculate sunrise/sunset.
//
void syncTime(char* datetime) {
  Serial.println(F("<++ Sync Time Command Received"));
  String dateTimeString = String(datetime);
  setTime(dateTimeString.toInt());
  timeSetBool = true;
  calculateSunriseAndSunset();
}

//
// Since the arduino doesn't know time it is set with the above method.  For sunrise/sunset
//   calculations we need to know the relation to UTC.  This method syncs the UTC with the
//   connected device to the arduino.  Usual assumption of same time/timezone applies.
//   Attempt to calculate sunrise/sunset.
//  
void syncUtc(char* utc) {
  Serial.println(F("<++ Sync UTC Command Received"));
  String utcString = String(utc);
  utcOffset = utcString.toInt();
  calculateSunriseAndSunset();
}

//
// The arduino does not know location.  It is gathered from the GPS of the connected device
//   and sent.  There is an assumption they are in the same location.  Attempt to calculate
//   sunrise/synset.  This caommand sets lattitude only.
//
void syncLatitude(char* latitude) {
  Serial.println(F("<++ Sync Lattitude Command Received"));
  String latitudeString = String(latitude);
  localLatitude = latitudeString.toDouble();
  calculateSunriseAndSunset();
}

//
// The arduino does not know location.  It is gathered from the GPS of the connected device
//   and sent.  There is an assumption they are in the same location.  Attempt to calculate
//   sunrise/synset.  This caommand sets longitude only.
//
void syncLongitude(char* longitude) {
  Serial.println(F("<++ Sync Longitude Command Received"));
  String longitudeString = String(longitude);
  localLongitude = longitudeString.toDouble();
  calculateSunriseAndSunset();
}

//
// When the app wants to reprogram the device it first sends this command.  It doesn't really
//  'clear' the device but sets the length indication on the array to the new length.  The
//  expectation is then that it will make subsequent calls to set all data for the new #
//  of run entries.
//
void clearRunEntries(char* num) {
  Serial.println(F("<++ Clear Run Event Array Command Received"));
  String numString = String(num);
  numRunEvents = numString.toInt();
}

//
// This command sets the type for a specific run event.  Includes row # and then the type.
//  The type will be Sunrise, Sunset, or Set Time.
//
void setType(char* indexAndType) {
  Serial.println(F("<++ Set Specific Run Event Type Command Received"));
  int i = String(indexAndType[0]).toInt();
  memmove(indexAndType, indexAndType+1, strlen(indexAndType));
  String t = String(indexAndType);
  run_events[i].type = t;
}

//
// This command sets the run duration for a specific run event.  Includes row # and then the
//   run duration.
//
void setRunTime(char* indexAndRunTime) {
  Serial.println(F("<++ Set Specific Run Event Run Duration Command Received"));
  int i = String(indexAndRunTime[0]).toInt();
  memmove(indexAndRunTime, indexAndRunTime+1, strlen(indexAndRunTime));
  String runTimeString = String(indexAndRunTime);
  run_events[i].runSeconds = runTimeString.toInt();
}

//
// This command sets the sunrise/sunset offset for a specific run event. Includes row # and
//   then the offset.
//
void setOffset(char* indexAndOffset) {
  Serial.println(F("<++ Set Specific Run Event Offset Command Received"));
  int i = String(indexAndOffset[0]).toInt();
  memmove(indexAndOffset, indexAndOffset+1, strlen(indexAndOffset));
  String offsetString = String(indexAndOffset);
  run_events[i].offset = offsetString.toInt();
}

//
// This command sets the time of day for a specific run event.  Includes row # and then the
//   datetime that includes the date of time.  The day portion is ignored.
//
void setDatetime(char* indexAndDatetime) {
  Serial.println(F("<++ Set Specific Run Event Datetime Command Received"));
  int i = String(indexAndDatetime[0]).toInt();
  memmove(indexAndDatetime, indexAndDatetime+1, strlen(indexAndDatetime));
  String datetimeString = String(indexAndDatetime);
  run_events[i].datetime = datetimeString;
}

//
// This command asks the arduino to send its status back to the connected device for display
//   to user.
//
void syncStatus() {
  Serial.println(F("<++ Sync Status Command Received"));
  
  // Send voltage.  There is a 50% voltage divider and it is tied to a 5v analog pin.
  float Vout = analogRead(A0) * (5.0/1023.0) * 2;
  sendData("v" + String(Vout));

  // Send current time.
  sendData("t" + String(now()));

  // Send next run time and duration if known.  Do some formatting with time.
  if (numPossibleRunTimes > 0) {

    String daytime = "AM";
    int hour = possibleRunTimes[0].hour();
    if (hour > 12) {
      hour = hour - 12;
      daytime = "PM";
    }

    String minstr = String(possibleRunTimes[0].minute());
    if (minstr.length() == 1) {
      minstr = "0" + minstr; 
    }

    sendData("r" + String(hour) + ":" + minstr + " " + daytime);
    sendData("d" + String(possibleRunTimesDurations[0]));    
  } else {
    sendData("rNone");
    sendData("dNone");    
  }
}

//
// This is a utility method to use time, latitude, longitude, utc offset to calculate the 
//   sunrise and sunset times for the current day and the following day.  The values are 
//   stored in the global variables.  This uses the Dusk2Dawn library which implements
//   a version of the National Oceanic & Atmospheric Administration calculator.
//
void calculateSunriseAndSunset() {
  if (localLatitude != 0 && localLongitude != 0 && utcOffset != -9999 && timeSetBool) {
    Dusk2Dawn pcb(localLatitude, localLongitude, utcOffset);
  
    Chronos::DateTime timeRightNow = Chronos::DateTime(year(), month(), day(), hour(), minute(), second()) + Chronos::Span::Hours(utcOffset);
    Chronos::DateTime today = Chronos::DateTime(timeRightNow.year(), timeRightNow.month(), timeRightNow.day());
    Chronos::DateTime tomorrow = today + Chronos::Span::Days(1);
    
    int pcbSunriseToday = pcb.sunrise(today.year(), today.month(), today.day(), false);
    int pcbSunsetToday = pcb.sunset(today.year(), today.month(), today.day(), false);
    int pcbSunriseTomorrow = pcb.sunrise(tomorrow.year(), tomorrow.month(), tomorrow.day(), false);
    int pcbSunsetTomorrow = pcb.sunset(tomorrow.year(), tomorrow.month(), tomorrow.day(), false);
  
    todaySunrise = today + Chronos::Span::Minutes(pcbSunriseToday);
    todaySunset = today + Chronos::Span::Minutes(pcbSunsetToday);
    tomorrowSunrise = tomorrow + Chronos::Span::Minutes(pcbSunriseTomorrow);
    tomorrowSunset = tomorrow + Chronos::Span::Minutes(pcbSunsetTomorrow);

    Serial.println(F("<++ Sunrise and Sunset Set"));
  }
}

//
// This is a utility method to evaluate the current configured run event settings to 
//   calculate possible run times for the current day and next.  These will be used 
//   to launch actual motor run events.
//
void evalCurrentRunEvents() {

  Serial.println(F("<++ Recalculating possible run times based upon sent run event information"));
  
  numPossibleRunTimes = 0;

  // loop through each config to calculate times
  for (int i=0; i < numRunEvents; i++) {
    
    // Initialize datetime objects that will be used in calculations
    Chronos::DateTime timeRightNow = Chronos::DateTime(year(), month(), day(), hour(), minute(), second()) + Chronos::Span::Hours(utcOffset);
    Chronos::DateTime calculatedTimeForToday = Chronos::DateTime();
    Chronos::DateTime calculatedTimeForTomorrow = Chronos::DateTime();
    Chronos::DateTime dateObj = Chronos::DateTime(String(run_events[i].datetime).toInt()) + Chronos::Span::Hours(utcOffset);

    // Calculate based upon type
    if (run_events[i].type == "Sunrise") {
      calculatedTimeForToday = todaySunrise + Chronos::Span::Minutes(run_events[i].offset);
      calculatedTimeForTomorrow = tomorrowSunrise + Chronos::Span::Minutes(run_events[i].offset);
    } else if (run_events[i].type == "Sunset") {
      calculatedTimeForToday = todaySunset + Chronos::Span::Minutes(run_events[i].offset);
      calculatedTimeForTomorrow = tomorrowSunset + Chronos::Span::Minutes(run_events[i].offset);
    } else if (run_events[i].type == "Set Time") {
      calculatedTimeForToday = Chronos::DateTime(timeRightNow.year(), timeRightNow.month(), timeRightNow.day(), dateObj.hour(), dateObj.minute(), dateObj.second());
      calculatedTimeForTomorrow = calculatedTimeForToday + Chronos::Span::Days(1);
    }
    
    // If the calculated times are later then now add them to the array.  Otherwise 
    //   they are in the past and we do not care.  Yeah, yeah... the tommorrow time
    //   probably can't ever be in the past.  We enter this information in two
    //   arrays.  One holds the datetime objects and one holds durations.  They are
    //   held in parallel.
    
    if (calculatedTimeForToday > timeRightNow) {
      possibleRunTimes[numPossibleRunTimes] = calculatedTimeForToday;
      possibleRunTimesDurations[numPossibleRunTimes] = run_events[i].runSeconds;
      numPossibleRunTimes += 1;
    }

    if (calculatedTimeForTomorrow > timeRightNow) {
      possibleRunTimes[numPossibleRunTimes] = calculatedTimeForTomorrow;
      possibleRunTimesDurations[numPossibleRunTimes] = run_events[i].runSeconds;
      numPossibleRunTimes += 1;
    }  
  }

  // The run events don't necessarily come in an order that would have them be in
  //   the order of the day so we need to sort them.
  sortPossibleRunTimes();

  Serial.println(F("<++ Recalculating possible run times complete"));
}

//
// This is a utility method to sort the run events.  The datetime library supports
//   standard comparisons.  This is a simple bubble sort as the # items will be
//   small and performance is not of concern.  We do need to keep the items in
//   both arrays in sync.
//
void sortPossibleRunTimes() {

  Serial.println(F("<++ Sorting possible run times"));
  
  // Simple bubble sort.  It is a small list.
  for(int i=0; i<(numPossibleRunTimes-1); i++) {
    for(int j=0; j<(numPossibleRunTimes-(i+1)); j++) {
      if (possibleRunTimes[j] > possibleRunTimes[j+1]) {
        Chronos::DateTime temp = possibleRunTimes[j];
        int tempDuration = possibleRunTimesDurations[j];
        possibleRunTimes[j] = possibleRunTimes[j+1];
        possibleRunTimesDurations[j] = possibleRunTimesDurations[j+1];
        possibleRunTimes[j+1] = temp;
        possibleRunTimesDurations[j+1] = tempDuration;
      }
    }
  }
}

//
// This is a utility method to compare the current time to the array of possible run 
//   times that are waiting to run.  If the current time is after an entry, it is
//   executed (the motor is run) for the correct duration and that possible run time
//   is then removed from the array.
//
// If an event fired we will go ahead and recalcuate everything.  This is simpler
//   (although slightly more expensive) then recalculating on day boundary as I had
//   originally planned.  Doing this should ensure that we always have times calculated
//   for the current day and next day.
//
// This routine runs basically every loop iteration so there is no debug statement
//  for its execution like the other routines have.
//
void testPossibleRunTimes() {

  // Need current time
  Chronos::DateTime timeRightNow = Chronos::DateTime(year(), month(), day(), hour(), minute(), second()) + Chronos::Span::Hours(utcOffset);
  boolean recalculate = false;

  int numToRemove = 0;
  for (int i=0; i < numPossibleRunTimes; i++) {
    if (possibleRunTimes[i] < timeRightNow) {
      runMotor(possibleRunTimesDurations[i]);
      numToRemove += 1;
      recalculate = true;
    }
  }

  // Remove entries that ran
  while (numToRemove > 0) {    
    for (int i=0; i < (numPossibleRunTimes - 1); i++) {
      possibleRunTimes[i] = possibleRunTimes[i + 1];
      possibleRunTimesDurations[i] = possibleRunTimesDurations[i + 1];
    }
    numPossibleRunTimes = numPossibleRunTimes - 1;
    numToRemove = numToRemove - 1;  
  }

  // If we ran any, recalculate possible run times.
  if (recalculate) {
    calculateSunriseAndSunset();
    evalCurrentRunEvents();
  }
}

//
// This is a utility method to run the DC motor.  It is currently set to a PWM value
//   that evaluates to full power (255).  This can be adjusted down if it is too strong
//   as might be required since we are running at voltage of ~1.5v higher than the 
//   original power source.
//
void runMotor(int seconds) {

  Serial.println(F("<++ Running motor"));
    
  // Motor on.  If this is the wrong direction flip IN1/IN2 HIGH/LOW
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  analogWrite(enA, 255); 
  delay(1000 * seconds);
    
  // Motor off.  Need a LOW to enA or it engages a break and uses significant power.
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  analogWrite(enA, LOW); 
}

//
// This is a utility method to transmit data with BLE UART service.  Using BLEUARTTXF
//   means payload must be less than 20 bytes (i'm not checking) but ensures the 
//   buffer is immediately flushed which helps with messages not combining onto the 
//   same buffer.  If need to switch back use BLEUARTTX and add a delay in.
//
// The methods that call this have debuggins statements so no debugging statement is
//  present here unless an error occurs.
//
void sendData(String payload) {
    ble.print("AT+BLEUARTTXF=");
    ble.println(payload);

    // check response stastus
    if (!ble.waitForOK()) {
      Serial.println(F("Error sending data"));
    }    
}


