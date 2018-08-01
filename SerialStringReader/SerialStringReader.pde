/* 
 Serial String Reader, Igoe MTT ch2, proj2
 Context: Processing
 
 Pairs with Ardu doing SensorReader sending int data strings; Ardu sends a string
 when it gets a char sent from Proc; v.i. KeyPressed code; mod to send/recv repeatedly;
 Also reads strings sent from Energia sketch like ReadBattVolt2LCD for rough monitor
 of batt dc, 2waySerial on Mega
 
 Reads in a string of characters from a serial port until it gets a linefeed (ASCII 10).
 Then splits the string into sections separated by commas. Then converts the sections 
 to ints, and prints them. Handshaking possible so Ardu just sends when key pressed
 
 created 19 July 2010 by Tom Igoe -- minor mods by AM 1506, 1611
 */

import processing.serial.*;     // import the Processing serial library

Serial myPort;                 // init the serial port
String inputString;
String resultString;          // string receives the input data
PFont f;                  // to display text in window

void setup() 
{
  size(300, 130);             // set the size of the applet window
  f = createFont("Arial", 14);
  textFont(f);  // font used in applet window
  printArray(Serial.list());     // prints (available) serial ports to console

  // get the # of your port from the serial.list.
  // The first port in the serial list on (mac-pro) 
  // is generally the Arduino module, so I open Serial.list()[0].
  // Use correct # for your machine; on Win7 seems to be [1] 
  // on iMac msp6989 is cu.usbmodFD1__ or tty.usbmodFD1__ (use higher #)
  //    and Ardu is [1]cu or [3]tty

  String portName = Serial.list()[6];
  // open the serial port:
  myPort = new Serial(this, portName, 9600);
  // applet can only seize port if not in use: close Ardu IDE or set it
  // to use different port than the board is using;
  // when you Quit Proc. applet releases port, so Ardu can reconnect

  // set Serial to read bytes into a buffer until you get a linefeed (ASCII 10)
  // or N # of bytes
   myPort.bufferUntil('\n');// trigger serEvent when gets \n; print(x) doesn't
   // myPort.buffer(16);  // triggers serEvent when __ bytes comes; must match 
  // length exactly or will over/underrun; str.len + 2 if sending println
}  // end setup

void draw() 
{
  // set the background for the app window to dk blu-gray, w/ white text:
  background(#004466);  // why not in setup? because in draw loop it clears,
  // otherwise text just overwrites, but doesn't clear old text
  fill(#ffffff);  // text is white against blue-gray

  if (keyPressed)  // any key press sends char to stimulate Ardu
  {         // to send a line; not used if Ardu sending autonomously
    myPort.write('z');
    delay(120);  // avoids repeat reads of key & repeat sends by Ardu
  }

  // display parsed result string in appl window if anything to show:
  if (resultString != null) 
    text(resultString, 24, height/2);  // what,x,y
  // else  text(inputString, 24, height/2);
  delay(200);
}  // end draw

// serialEvent  method is run automatically by the Processing sketch
// whenever the buffer reaches the byte value/len set in the bufferUntil() 
// or buffer(#) method in setup()
// does this param name need to be the actual Ser object?
void serialEvent(Serial myPort) // watch myPort for events, buffer filled
{ 
    // read the serial buffer -- use if data comes as str of chars
  String inputString = myPort.readString(); // was readStringUntil('\n')
    // (supposed to exclude final \n), but no difference here +/- trim
    
//  String inputString = "";
//  byte[] inBite = new byte[12];  // size of array limits # of bytes read
//  myPort.readBytes(inBite);
//  if (inBite != null) {
//    inputString = new String(inBite);
//  }

  //while (myPort.read() > 0) myPort.clear();   // didn't work before
  // trim space, return, linefeed, from the input string, using Java meth.
  inputString = inputString.trim(); // was =trim(inputString)-- didn't work w/ flt
  // clear the resultString
  resultString = "";

  // split the input string at commas
  // and put the tokens into [int,flt,str] array sensors[]: all types work, but
  String sensors[] = split(inputString, ',');    // str best for getting floats

  // add the values to the result string: name + value
  // for (int sensorNum = 0; sensorNum < sensors.length; sensorNum++) 
  //  {
  //    resultString += "Sensor " + sensorNum + ": ";
  //    resultString += sensors[sensorNum] + "\t";
  //  }  // end for

  //  draw loop prints this to applet window
  resultString += "elapsed min. ";  //  just the numbers with spaces
  for (int sensorNum = 0; sensorNum < sensors.length; sensorNum++) 
  {
    resultString += sensorNum + ": ";
    resultString += sensors[sensorNum] + "  ";  // spaces work, tabs don't
  }  // end for

  // print resultStr to the console
  // println(resultString);
  println(inputString);  // to console -- unparsed, untrimmed
  inputString = "";
    // Clear the serial buffer, or available() will still be > 0:
   myPort.clear();  // didn't clear it
  // while (myPort.available() > 0) myPort.read(); // nor did this
}  // end serEvent
