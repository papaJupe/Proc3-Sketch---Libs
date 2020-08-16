/*
 * rooSimpleTestProc4
 *
 * sketch does user I/O; uses RooComm class to send / read to Roo
 *
 * first, run separate listSerPort sketch to see portname/indices,
 then paste below
 -- test of serial connection, wired, BT (HC05) -- both OK to 
 send bytes from sketch
 v. 4  adds user input, sensor() call in sketch, change serialEvent
 & sensor data handling in RooComm, 
 */

import processing.serial.*;
Serial myPort = null;  // Ser obj can be used by RooComm (inner class)
String portName;  // name of serial port in .list


void setup()
{
  printArray(Serial.list());  // checking it's still where I thought
  portName = Serial.list()[2];  
  myPort = new Serial(this, portName, 57600);
  // myPort.bufferUntil('\n'); // R sends no terminal ch, so try
  // use fixed len, or ???; w/o buffer() each byte triggers serEvent
  // myPort.buffer(26);  // needs full dataset to trigger serEvent in RooComm

  RooComm roo = new RooComm();  

  if ( !roo.connect() ) {  // just tests that port was created above
    println("Couldn't connect to " + portName);
    System.exit(1);
  }
  println("RooComm port open on " + portName);

  // needs startup before you query sensors or do anything
  roo.wakeup();  // toggle DTR, may or may not wake from sleep;; fails
  delay(1500);   // w/ HC-05 BT2 module
  roo.start();
  roo.pause(300);
  roo.control();
  roo.pause(300);

  // query sensors, check sensorsLastUpdateTime
  //   -- tests roo object's comm w/ R

  System.out.println("Checking Roomba sensor response ... ");

  roo.sensors(); // default param 0 --> reads 26 (all)
  roo.pause(100);

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
  // above works fine, this is simpler, uses existing byte array
  roo.readResponse(); // puts R response into byte array
  println("millis:" + (millis() +"  lastUpd:" + roo.sensorsLastUpdateTime ));
  if (millis() - roo.sensorsLastUpdateTime < 100)
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

  byte sng[] = {  // define 1 note songs
    (byte)140, 3, 1, (byte)72, (byte)10, 
    (byte)141, 3      // play it back
  };
  roo.send(sng);

  roo.pause(1000);

  System.out.println("Spinning left then right");

  roo.spinLeft(45);  // send an angle, converts to time
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
  roo.pause(2000); // go back for this time
  roo.stop();


  //System.out.println("Moving via send()");
  // should be straight fwd slow but gray1 = turn R; 
  // R1 small fwd


  //roo.send( cmd ) ;
  // myPort.write( cmd );

  // delay(500);
  //roo.pause(1000);

  //roo.stop();

  // should be straight back but is gray 1:120+ turn L
  // R1 small back

  //roo.stop();
  // go back?
  //cmd[1] = (byte)0xff;
  //cmd[2] = (byte)0xaa;
  //myPort.write( cmd );
  //delay(1000);

  // stop -- yes

  // power down OK on G1, R1, G2; must rewake w/ button or gnd DTR
  myPort.write((byte)133); // same as sending powerOff() cmd
  delay(30);
  System.out.println("Disconnecting");
  //roo.disconnect();
  System.exit(1);
  
  // set frame rate for draw 6/sec? faster
}

void draw() {
  
  // poll user input via stick, keys, keybd
  
  // convert numbers to commands
  
  // check connected status / mode, if true/safe, send cmds to R
  
  // query sensors to print from some cmd
  
  
  
  
}
