/* Proc2 Servo mega Tx Rx BT joy, stick control servo via BT
 or wired serial
 
 mod by AM for I/O w/ Ardu Mega + BT module, send bytes, get
 back ack; this mod's joystk buttons send u / d to control servo
 tilt, joystick y also control tilt, x control pan, using GCP
 libs which can read/send analog values + button bools
 
 Ardu code: Servo Mega tx rx Bluetooth
 Use: config BT mod on Ardu, enable BT on PC, Pair; for Joystk, make config
 file w/ Configurator app or text editor, then run this, ID port, click
 in applet window for joystick to work; once Paired, in BT prefs hc-xx says 
 'not connected' but when you reopen serial connection it auto-connects
 
 */

import processing.serial.*;
Serial myPort;

//import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

ControlIO control;
ControlDevice stick;
int x, y;  // vars for axes
boolean up, down, left, right;  // vars for buttons

void setup() 
{  
  size(300, 150);  // ? need to click in applet for keys/stick to work
  // get the # of your port from the serial.list.
  println(Serial.list());  // SPP port from BT2 connection et al

  String portName = Serial.list()[3]; 
  // open the serial port:
  myPort = new Serial(this, portName, 9600); // speed of dongle/Ser2
  // applet can only seize port if not in use -- USB-TTL has its own

  // set Serial to read bytes into buffer until a linefeed (ASCII 10)
  myPort.bufferUntil('\n'); // used to see ack

  // Initialise the ControlIO for joystk
  control = ControlIO.getInstance(this);
  // Find a device that matches a configuration file in /data dir
  stick = control.getMatchedDevice("MSstickServo");
  if (stick == null) {
    println("No device matching config found");
    System.exit(-1); // End the program!
  }

  frameRate(9); // ~10 loops/sec
}  // end setup

// Poll user input, called from the draw() method.
public void getUserInput() 
{  // different range for x,y makes filtering easy on Mega
  x = round(map(stick.getSlider("X").getValue(), -1, 1, 20, 30));
  y = round(map(stick.getSlider("Y").getValue(), -1, 1, 10, 0));
  up = stick.getButton("UP").pressed(); // "NAME" of input channels
  down = stick.getButton("DOWN").pressed();
  left = stick.getButton("LEFT").pressed();
  right = stick.getButton("RIGHT").pressed();
}  // end getUserInput

void draw()   // keeps sending value of buttons & stick if active
{  
    getUserInput(); // polling stick
  // sends val @ interval, ? needs 2B slower than Ardu loop
  if (up) myPort.write('u');
  if (down) myPort.write('d');
  if (left) myPort.write('l');
  if (right) myPort.write('r'); // sends ascii of char r
  // .write(char)x sends nonprinting low chars, this sends # as byte
  if (x !=25) myPort.write(x); // send axis int if not stick's 0 pt
  if (y !=5) myPort.write(y);
}  // end draw

void serialEvent(Serial myPort) // watch myPort for events, buffer fill
{ 
  // read & clear serial-in buffer -- use if data comes as str of chars
  String inputString = myPort.readString(); // was readStringUntil('\n'),
  // supposed to exclude final \n, but no difference here +/- trim

  // trim space, return, linefeed from the input string, using Java meth.
  inputString = inputString.trim(); // was trim(inputString)-failed w/ flt

  println(inputString);  // to console -- trimmed, unparsed
}  // end serEvent

