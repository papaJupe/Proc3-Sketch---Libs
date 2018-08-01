/*
 * rooSimpleTestProc5 -- in Proc3, adds user joystick I/O to draw
 *
 * sketch does user I/O; uses RooComm class to do most comm to R
 * must have GCP's named config file in 'data' folder to use stick.
 * first, run separate listSerPort sketch to see portname/indices,
 * then paste below
 v. 4  adds user input, sensor() call in sketch, change serialEvent
 & sensor data handling in RooComm, v. 5 adds GCP(joystk) I/O, display
 of input data to applet, optional display of sensor array to console
 upon startup
 */

import processing.serial.*;
Serial myPort = null;  // Ser obj can be used by RooComm (inner class)
String portName;  // name of serial port in .list

//import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

ControlIO control;
ControlDevice stick;
// stick vars
int x, y, v;  // vars for x,y drive axes, v speed; init these 'control'
boolean stomp, lef, rite;  // vars init in setup, linking to hardware
int rad, spd; // computed sketch vars for radius, speed 
// ... sent to RC in commands

PFont f;       // to display text in applet window
RooComm roo; // must declare var global for all blox to know it exists

void setup()
{
  size(300, 130);   // set the size of the applet window
  f = createFont("Arial", 14);
  textFont(f);  // font used in applet window

  printArray(Serial.list());  // checking it's still where I thought
  portName = Serial.list()[0];  
  myPort = new Serial(this, portName, 57600);
  // myPort.bufferUntil('\n'); // R sends no terminal char, so tried
  // to use fixed len -- failed; w/o buffer() each byte triggers serEvent.
  // myPort.buffer(26); // need full dataset to trigger serEvent in RooComm
  // but serEvent in RC class does not get message from either buffer(_)
  // so simpler ser.avail used in RC now, works fine.

  // Initialise the ControlIO, make joystk instance
  control = ControlIO.getInstance(this);
  // Find a device that matches a configuration file in /data dir
  // -- this links the button and axis vars to their stick controls
  stick = control.getMatchedDevice("msRooCommStick");
  if (stick == null) {
    println("No input control matching config found");
    System.exit(-1); // End the program!
  }

  roo = new RooComm();  

  if ( !roo.connect() ) {  // just tests that port exists
    println("Couldn't connect to " + portName);
    // System.exit(1);
  }
  println("RooComm port open on " + portName);

  // needs startup before you query sensors or do any comm w/ R
  roo.wakeup();  // toggle DTR, may or may not wake from sleep; fails
  delay(1500);   // w/ HC-05,6 BT2 module which has no DTR pin
  roo.start();
  roo.pause(300);
  roo.control();
  roo.pause(300);
  roo.safe();

  // query sensors, check sensorsLastUpdateTime
  //   -- tests roo object's comm w/ R

  System.out.println("Checking Roomba sensor response ... ");

  roo.sensors(); // default param 0 --> reads (all) 26 bytes
  roo.pause(100);  // actually get response in <2 mS

  //byte[] inBuffer = new byte[26];
  //while (myPort.available() > 0) {
  //  //inBuffer = myPort.readBytes(); // both work
  //   myPort.readBytes(inBuffer);
  //  if (inBuffer != null) {
  //    roo.sensorsLastUpdateTime = millis();
  //    //String myString = new String(inBuffer);
  //    //println(myString);
  //    printArray(inBuffer);
  //  }
  //}

  // above works, but this is simpler, uses existing byte array
  roo.readResponse(); // puts R's response into byte array
  delay(10);  
  println("millis: " + (millis() +"  lastUpd: " + roo.sensorsLastUpdateTime ));
  if (roo.sensorsValid == true) // set to true by computeSensors if good data
  {
    System.out.println("Roomba found!");
    println(roo.sensorsAsString());
  } else
    System.out.println("No Roo response. Is it awake?");

  System.out.println("Playing some notes");
  roo.playNote( 72, 10 );  // C
  roo.pause( 400 );
  roo.playNote( 79, 10 );  // G
  roo.pause( 400 );
  roo.playNote( 76, 10 );  // E
  roo.pause( 1400 );

  //byte sng[] = {  // define 1 note songs
  //  (byte)140, 3, 1, (byte)72, (byte)10, 
  //  (byte)141, 3      // play it back
  //};
  //roo.send(sng);

  //roo.pause(1000);

  System.out.println("Spinning left then right");

  roo.spinLeft(45);  // send an angle, converted to time in fx()
  // G1 left spin    R1 small left spin
  //  byte cmd[] = {
  //    (byte)137, 
  //    (byte)0x00, (byte)0xba, (byte)0x00, (byte)0x01
  //  };
  roo.pause(1000);

  roo.spinRight(45);

  roo.pause(1000);

  roo.stop();

  System.out.println("Going forward, then back");
  
  roo.goForward();
  roo.pause(2000); // goes fwd 2 sec
  roo.stop();
  roo.pause(1000);
  roo.goBackward();
  roo.pause(2000); // go back 2 sec
  roo.stop();

  // power down works on all; must rewake w/ button or gnd R's DTR
  //myPort.write((byte)133); // same as sending powerOff() cmd
  //delay(30);
  //System.out.println("Disconnecting");
  //roo.disconnect();  // method not written
  //System.exit(1);

  frameRate(6); // ~6 loops/sec
}   // end setup


 // method Polls user input, called in draw()
public void getUserInput() 
{  // middle of x,y range, stick 0, is neutral, no turn, 0 speed
  x = round(map(stick.getSlider("X").getValue(), -1, 1, 2, 98));
  // 50 is center (neutral), so I map difference from 50 to +/- angle

  y = round(map(stick.getSlider("Y").getValue(), -1, 1, -1, 1));
  // inverts multiplier for speed: want + for fwd, - for bak

  // v = set base speed for any drive cmd; -1 = slider full fwd
  v = round(map(stick.getSlider("V").getValue(), 1, -1, 15, 300));
  // full back (stop) is 0, full fwd is 300

  // button bools: # on MS stick stomp=2, lef=3, rite=4
  stomp = stick.getButton("S").pressed(); // "NAME" of input keys is
  lef = stick.getButton("L").pressed();  // assigned in the config file
  rite = stick.getButton("R").pressed(); // which uses its own button #'s
}  // end getUserInput

/* ----------------------------------------- */
//System.out.println("Moving via send()");
//byte cmd[] = {
//  (byte)RooComm.DRIVE, 
//  (byte)0x00, (byte)0xaa, (byte)0x00, (byte)0x00 };
//roombacomm.send( cmd ) ;
//roombacomm.pause(500);
//roombacomm.stop();

//cmd[1] = (byte)0xaa;
//cmd[2] = (byte)0x03;
//roombacomm.send( cmd ) ;
//roombacomm.pause(500);
//roombacomm.stop();

///* drive Roomba w/ low-level velocity + radius method
// * @param velocity  speed in millimeters/second, 
// *                  positive forward, negative backward
//public void drive( int velocity, int radius ) 
//{   I tweaked the bit ops a little
//    byte cmd[] = { (byte)DRIVE,(byte)(velocity>>>8),(byte)(velocity&0xff), 
//                   (byte)(radius >>> 8), (byte)(radius & 0xff) };

//    logmsg("drive: "+hex(cmd[0])+","+hex(cmd[1])+","+hex(cmd[2])+","+
//           hex(cmd[3])+","+hex(cmd[4]));
//    send( cmd );
// }

/*---------------------------------------------- */

void draw() {
  // background of app window is dk blu-gray
  background(#004466);  // put in draw loop to clear old text
  fill(#ffffff);  // white txt on blue-gray bkgnd

  // poll user input to stick, keybd
  getUserInput(); // polling stick

  // could wrap drive() in mode/connect check @ interval ... never tried
  //while(roo.mode = MODE_SAFE)
  //{
  //    if (stop) roo.stop();

  //    //if (left) myPort.write('l');
  //    //if (right) myPort.write('r'); // sends ascii of char r
  //// .write(char)x sends nonprinting low chars, this sends # as byte

  // convert stick input numbers to commands; map y to drive direction,
  // x to turn radius, v to speed
  // radius setting complex: need large # sent from small deviation
  if (x < 50) rad = x * 10; // L turn, range 2-49 => 20-490
  else if (x > 50) rad = (x-100) *10; // R turn, 51-98 => -490 to -2
  else rad = 0x8000; // straight
  text("turn radius: " + rad, 24, height/2);

  roo.setSpeed(v);  // used by RC methods that don't get speed input
  if (y < 0) spd = v;  // stick y fwd is (-)
  else if (y > 0) spd = (-1 * v); // stick y bak is +
  else spd = 0;
  text("speed: " + spd, 24, height/2 + 14);

  if (stomp) {  // emergency stop; also powers down R when done
    text("stop sent", 24, height/2 + 28); 
    roo.stop();
    // power down OK on G1, R1, G2; must rewake w/ button or gnd DTR
    myPort.write((byte)133); // same as sending powerOff() cmd
    delay(120);  // debounce
    System.out.println("Disconnecting");
  }

  roo.drive(spd, rad);

  // these 2 may need to be after drive(), else overwritten ?
  if (lef) roo.spinLeft();  //  @ current speed v

  if (rite) roo.spinRight(); // both work while driving too!

  // things I considered but never needed, never coded
  // check connected status / mode, if true/safe, send cmds to R
  // poll sensors or sensValid, every 2 loops to confirm connected
  // stick button cmd to query sensors & print
  
} // end draw

void exit()
{  // custom exit to power off when closing applet
      println("exit() is powering off Roo ");
      roo.stop();  // writing POWER byte puts R to sleep
      myPort.write((byte)133);
  super.exit();   // let processing do its regular exit()
}
