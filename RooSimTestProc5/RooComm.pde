/* RooComm 0.98 adapted from RoombaComm from roombahacking.com
 book site
 *  revise AM 1804 to be instantiable class for comm to Roomba
 -- main Proc .pde sketch has user I/O methods; instances this inner
 class, calls its members for comm.  v. 0.98 revises sensor()
 handling (updating called from main sketch)
 
 *  Copyright (c) 2006 Tod E. Kurt, tod@todbot.com
 */

/*
 * This revison contains the variables & communications layer methods
 to comm with classic Roomba (400 series, maybe later) over serial
 connection, wired or BT, maybe other
 
 * Standard lifecyle of this object
 *   RooComm roo = new RooComm(); // in sketch
 roo.connect("someportid");
 *   roo.startup();
 *   roo.updateSensors();
 *   while( // connected & mode safe or something) 
 *      roomba.sensors();
 *      roomba.playNote( 53, 12 );
 *      roomba.goForward( 400 );
 *      roomba.spinRight( 45 );
 *      if( roomba.bump() ) roomba.goBackward( 100 );
 *      if power down cmd or what?, break
 *   }    
 *   roomba.disconnect(); // power down, or something
 * 
 * to do: test wakeup DTR method on wired connection, other BT
 
 NB: utility methods at end, for hex & byte to string convert, alias
 for delay, print / println,
 */


public class RooComm    // was abstract, now inner class of Papplet
{  // declare, init misc. variables, constants

  static public final String VERSION = "0.98";

  /** turns on/off showing debugging messages */
  public boolean debug = false;

  /** mm distance between classic roomba wheels 
   was int probably should be float for further operations */
  static public final float wheelbase = 258;

  /** mm/deg is circumference distance divided by 360 degrees; 
   in SPIN, rotating around center, the distance each wheel moves
   (one +, one -) per deg. in mm is d * pi/ 360, since d = 258 
   in spin. Doubt if same applies to other movement */
  public static final float 
    millimetersPerDegree = (float)(wheelbase * Math.PI / 360.0);

  /** mm/rad is distance wheel travels (circumference) divided by two pi;
   in spin, bot rotates around center axis, one wheel
   fwd, one back, so diameter of circle is wheelbase; circumference
   --> (wheelbase * PI) is same as 2 PI radians; probably only
   works in SPIN motion
   */
  public static final float 
    millimetersPerRadian = (float)(wheelbase/2);

  /** default speed for movement operations if speed isn't specified */
  public static final int defaultSpeed  =  200;

  /** default update time (ms) for auto sensors update, same as v.i.? */
  public static final int defaultSensorsUpdateTime = 300;

  /** current mode, if known */
  public int mode;

  /** current speed for movements that don't get speed param input */
  public int speed = defaultSpeed;

  /** computed boolean if Roomba is 'errored out' of safe mode 
   -- but I don't see if running mode is actually changed */
  boolean safetyFault = false;

  /** if sensor variables have been updated successfully */
  boolean sensorsValid = false;

  /** Set to true to make sensors auto-update (costs serial b/w) */
  boolean sensorsAutoUpdate = false;

  /** Time in milliseconds between Auto sensor updates, also
    sV currency test sensorsValid() */
  int sensorsUpdateTime = 50;

  /** last timestamp (System.currentTimeMillis) of valid sensor update */
  long sensorsLastUpdateTime;

  /** how many bytes we expect to read from the sensor() command */
  int readRequestLength;

  /** internal app's storage for all roomba sensor data */
  byte[] sensor_bytes = new byte[26];  // array size, need 1024 ?

  /** ? connected to a serial port (local), not necessarily to R */
  boolean connected = false;  // could make depend on sensorsValid ?

  /* ======================*/

  // 3 overloaded constructors, +/- autoUpdate

  public RooComm() {
    connected = false;
    mode = MODE_UNKNOWN;
  }

  //  public RooComm( boolean autoUpdate )
  //  {    
  //    this();  // does this load the stuff above like super()?
  //    if ( autoUpdate )
  //      startAutoUpdate(); // can't do this yet, no connection made
  //  }
  //
  //  public RooComm(boolean autoUpdate, int updateTime) {
  //    this(autoUpdate);
  //    sensorsUpdateTime = updateTime;
  //  }

  // could call from sketch, after connection validated by connect()
  // and startup sent; probably fails if called in constructor
  // calls sensors(), then sleeps; serialEvent does all the rest
  public void startAutoUpdate() {
    new Thread( new Runnable() {
      public void run() {
        try { 
          while ( sensorsUpdateTime > 0 ) {
            if ( connected() ) sensors(); // why not use the var?
            Thread.sleep( sensorsUpdateTime );
          }
        } 
        catch(InterruptedException ex) {
          errorMessage("autoUpdt", ex);
        }
      }
    }
    ).start();
  }  // end autoUpdate

  /* =========== connect, start, send()s, get/set modes ===========*/

  /* Check if there's a port -- must precede any sensor update call
   * 
   * @returns true on successful port open, false otherwise
   */
  public boolean connect()  // return T/F, if there's a port obj
  {
    if (myPort != null)  // & sensorsValid  
      connected = true; 
    else
      connected = false; // could exit here vs. going back to sketch
    return connected;
  }  // end connect

  // add testConnectCurrent() to see if sensorsLastUpdateTime
  // is recent enough, if not run sensors() again or ??
  //  should do this in setup / draw loop

  //Disconnect from a port, clean up any memory in use

  // public abstract void disconnect();


   /*  overloaded send fx's: core (1st one) sends a byte array 
   * @param bytes = byte array of ROI commands to send
   * @return true on successful send
   */
  public boolean send(byte[] bytes)
  {
    // adapt from RCS
    if (connected)
    {
      try {
        myPort.write(bytes);
        return true;
      } 
      catch (Exception e) { 
        // null pointer or serial port dead
        //  e.printStackTrace(); done by:
        errorMessage("send fail ", e);
        return false;
      }
    }    // end if
    return false;  // wasn't connected or failed
  }  // end send

  /* Send a single byte to the Roomba 
   * (defined as int because of stupid java signed bytes)
   * @param b = byte of the ROI command to send
   * @return true on successful send
   */
  public boolean send(int b)
  {   //adapt from RCS
    try {
      myPort.write(b & 0xff);  // for good measure mask w/ &
    } 
    catch (Exception e) { // null pointer or serial port dead
      errorMessage("send ", e);
      // e.printStackTrace();
    }
    return true;
  }


  /* Wakes Roomba up, if possible, thus optional
   * To wake up the Roomba requires twiddling its DD line, often
   * wired to the serial adapter's DTR line, which may not be 
   * available in soft or hardware; Serial lib has cmd, ? works
   */
  public void wakeup() {
    myPort.setDTR(false);
    pause(500);
    myPort.setDTR(true);
  }


  /* startup Roomba in safe mode, as opposed to full mode  
   * Safe mode is the preferred running state -- provides 
   some measure of autonomous safety. If lifted or cliff
   * --> goes into passive mode and must be 'reset()'
   * @see #reset() not clear why we need startup and start()
   */

  /**  Send START command  */
  public void start() { 
    logmsg("start");
    speed = defaultSpeed;
    mode = MODE_PASSIVE;
    send( START );
  }

  /**  Send CONTROL command  */
  public void control() { 
    logmsg("control");
    mode = MODE_SAFE;
    send( CONTROL );
    // set blue dirt LED on so we know roomba is powered on & under control
    // (-- we don't forget to turn it off, and run the battery flat)
    // FIXME: first time after a poweron, the lights flash then turn off
    setLEDs(false, false, false, false, false, true, 128, 255);
  }

  /**  Send SAFE command  */
  public void safe() { 
    logmsg("safe");
    mode = MODE_SAFE;
    send( SAFE );
  }
  /**  Send FULL command  */
  public void full() { 
    logmsg("full");
    mode = MODE_FULL;
    send( FULL );
  }

  /*
   Reset Roomba after a fault. This takes it out of whatever mode 
   * it was in and puts it into safe mode -- but where is reset called
   when there's a fault detected ? I don't see it anywhere
   * This command also syncs the object's sensor state with the Roomba's
   * by calling updateSensors()
   * @see #startup()
   * @see #updateSensors()
   */
  public void reset() {
    logmsg("reset");
    stop();
    pause(300);
    start();
    pause(300);
    control();
    pause(300);
    //  test if this work
    if (sensorsValid == true) println("OK, we're back on");
  }

  /* Power off the Roomba. Once off, the only way to wake it
   * is by wakeup() v.s., if it works, or by physically pressing
   the Power button or physically grounding the DD pin on R to gnd
   * @see wakeup() above
   */
  public void powerOff() {
    logmsg("powerOff");
    mode = MODE_UNKNOWN;
    send( POWER );
  }

  // can these commands be sent from SAFE too ?
  /** Send the SPOT command */
  public void spot() {
    logmsg("spot");
    mode = MODE_PASSIVE;
    send( SPOT );
  }
  /** Send the CLEAN command */
  public void clean() {
    logmsg("clean");
    mode = MODE_PASSIVE;
    send( CLEAN );
  }
  /** Send the max command */
  public void max() {
    logmsg("max");
    mode = MODE_PASSIVE;  
    send( MAX );
  }

  /* ============  connect and mode queries  =============== */


  //returns current connected state; could just query the var
  public boolean connected() { 
    return connected;
  }

  // mode fx() Returns current mode state. ? any use now
  public int mode() { 
    return mode;
  }

  /** mode as String */
  public String modeAsString() {
    String s=null;
    switch(mode) {
    case MODE_UNKNOWN: 
      s = "unknown"; 
      break;
    case MODE_PASSIVE: 
      s = "passive"; 
      break;
    case MODE_SAFE:    
      s = "safe"; 
      break;
    case MODE_FULL:    
      s = "full"; 
      break;
    }
    return s;
  }

  /* ===========  motion command higher level ===========*/

  //
  // higher-level motion functions et. al.
  //

  /**
   * Stop motion: Sends drive(0,0),  v.i. <-- lower level method
   */
  public void stop() {
    logmsg("stop");
    drive( 0, 0 );
  }

  /** Set speed for movement commands */
  public void setSpeed( int s ) { 
    speed = Math.abs(s);
  }

  /* Get speed for movement -- speed is public already, so ? */
  public int  getSpeed() { 
    return speed;
  }

  /* Go straight at the current speed for a specified distance.
   * Positive distance moves forward, negative distance moves backward.
   * This method blocks until the action is finished.
   * @param distance distance in millimeters, positive or negative
   */
  public void goStraight( int distance ) {
    float pausetime = Math.abs(distance / speed);  // mm/(mm/sec) = sec
    if (distance > 0)
      goStraightAt( speed );
    else
      goStraightAt( -speed);
    pause( (int)(pausetime*1000) );  // in mS
    stop();
  }

  // @param distance = distance in millimeters, positive 

  public void goForward( int distance ) {
    if ( distance < 0 ) return;
    goStraight( distance );
  }

  // @param distance distance in millimeters, positive 

  public void goBackward( int distance ) {
    if ( distance < 0 ) return;
    goStraight( -distance );
  }

  public void turnLeft() {
    turn(129);
  }
  public void turnRight() {
    turn(-129);
  }
  public void turn( int radius ) {
    drive( speed, radius );
  }

  /* Spin right or spin left a set number of degrees
   * @param angle angle in degrees, 
   *   positive to spin left, negative to spin right
   */
  public void spin( int angle ) {
    if ( angle > 0 )       spinLeft( angle );
    else if ( angle < 0 )  spinRight( -angle );
  }

  /* Spin right @ current speed for a specified angle 
   * @param angle angle in degrees entered as positive #
   */
  public void spinRight( int angle ) {
    if ( angle < 0 ) return;
    float pausetime = Math.abs( millimetersPerDegree * angle / speed );
    spinRightAt( Math.abs(speed) );
    pause( (int)(pausetime*1000) );
    stop();
  }

  /* Spin left a specified angle at a specified speed
   * @param angle angle in degrees, positive
   */
  public void spinLeft( int angle ) {
    if ( angle < 0 ) return;
    float pausetime = Math.abs( millimetersPerDegree * angle / speed );
    spinLeftAt( Math.abs(speed) );
    pause( (int)(pausetime*1000) );
    stop();
  }

  // if no param, Spin in place anti-clockwise, at current speed

  public void spinLeft() {
    spinLeftAt( speed );  // was speed
  }
  // if no param,Spin in place clockwise, at current speed

  public void spinRight() {
    spinRightAt( speed );
  }

  /* Spin in place anti-clockwise, at the input speed.
   * @param aspeed speed to spin at
   */
  public void spinLeftAt(int aspeed) {
    drive( aspeed, 1 );
  }

  /*
 * Spin in place clockwise, at the input speed.
   * @param aspeed speed to spin at, positive
   */
  public void spinRightAt(int aspeed) {
    drive( aspeed, -1 );
  }

  /* ===========  motion command mid-level ===========*/

  // no blocking, parameterized by speed not distance

  /* Go straight at a specified speed.  
   * Positive is forward, negative is backward
   * @param velocity = velocity of motion in mm/sec
   */
  public void goStraightAt( int velocity ) {
    //System.out.println("goStraightAt: velocity:"+velocity);
    if ( velocity > 500 ) velocity = 500;
    if ( velocity < -500 ) velocity = -500;
    drive( velocity, 0x8000 );  // no angle
  }

  // Go forward the current (positive) speed

  public void goForward() {
    goStraightAt( Math.abs(speed) );
  }

  // Go backward at the current (negative) speed

  public void goBackward() {
    goStraightAt( - Math.abs(speed) );
  }

  // Go forward at a specified speed
  public void goForwardAt( int aspeed ) {
    if ( aspeed < 0 ) return;
    goStraightAt( aspeed );
  }

  // Go backward at a specified speed
  public void goBackwardAt( int aspeed ) {
    if ( aspeed < 0 ) return;
    goStraightAt( -aspeed );
  }

  /* ===========  motion command low level ===========*/

  /* Move the Roomba via the low-level velocity + radius method.
   * See the 'Drive' section of the Roomba ROI spec for more details.
   * @param velocity  speed in millimeters/second, 
   *                  positive forward, negative backward
   * @param radius    radius of turn in millimeters
   */
  public void drive( int velocity, int radius) {
    byte cmd[] = { 
      (byte)DRIVE, (byte)(velocity>>8 & 0xff), (byte)(velocity & 0xff), 
      (byte)(radius >> 8 & 0xff), (byte)(radius & 0xff)
    };
    logmsg("drive: "+hex(cmd[0])+","+hex(cmd[1])+","+hex(cmd[2])+","+
      hex(cmd[3])+","+hex(cmd[4]));
    send( cmd );
  }

  /* ===========  other motors, lites ===========*/

  /* Turns on/off the non-drive motors (main brush, vacuum, sidebrush)
   * @param mainbrush  = mainbrush motor on/off state
   * @param vacuum  =   vacuum motor on/off state
   * @param sidebrush = sidebrush motor on/off state
   */
  public void setMotors(boolean mainbrush, boolean vacuum, boolean sidebrush) {
    byte cmd[] = { 
      (byte)MOTORS, 
      (byte)((mainbrush?0x04:0) | (vacuum?0x02:0) | (sidebrush?0x01:0))
    };
    send( cmd );
  }

  /* Turns on/off the  LEDs
   * Low-level command sets bits 
   * FIXME: this is too complex (doubt it could be simpler tho)
   */
  public void setLEDs( boolean status_green, boolean status_red, 
    boolean spot, boolean clean, boolean max, boolean dirt, 
    int power_color, int power_intensity ) {
    int v = (status_green?0x20:0) | (status_red?0x10:0) | 
      (spot?0x08:0) | (clean?0x04:0) | (max?0x02:0) | (dirt?0x01:0);
    logmsg("setLEDS: "+ binary(v));
    byte cmd[] = { 
      (byte)LEDS, (byte)v, 
      (byte)power_color, (byte)power_intensity
    };
    send(cmd);
  }

  /* Turn all vacuum motors on or off according to state
   * @param state true to turn on vacuum function, false to turn it off
   */
  public void vacuum(boolean state) {
    logmsg("vacuum: "+ state);
    setMotors(state, state, state);
  }


  /* ========  sensor methods, vars, constants, serialEvent ========== */


  /* Query status w/ sensor() and sync its state with this object's.
   * Should query Roomba and fill up 'sensor_bytes' with the full
   * sensor data (really needs 1024 bytes?) <-- sensor() does this
   * If a RoombaComm object has 'autoUpdate' true, 
   * calling this method is p.r.n., because a separate thread is created
   * for sensor updating calling the sensors() fx
   * e.g. reset() calls this fx
   * @return true on 'valid' i.e. current sensor update, false otherwise
   Blocks for (whatever) ms waiting for sensorsValid var to become true
   LOOKS UNECESSARY IF DRAW LOOP POLLS sensors() AS NEEDED -->
   For non-blocking, call sensors() and then poll sensorsValid()
   */
  //  public boolean updateSensors()
  //  { // ... from RCS 
  //
  //    sensorsValid = false; // assumes sV bad until proven otherwise
  //    sensors();  // sends request, incoming serialEvent has to set sV to true
  //    for (int i=0; i < 10; i++) {
  //      if ( sensorsValid ) { 
  //        logmsg("updateSensors: sensorsValid!");
  //        break;
  //      }
  //      logmsg("updateSensors: pausing...");
  //      pause( 50 );
  //    }
  //    return sensorsValid;   // does sensors() set this or what?
  //  }

  // Update sensors w/ code for specific set 

  //  public boolean updateSensors(int packetcode) {
  //    sensorsValid = false;
  //    sensors(packetcode);
  //    for (int i=0; i < 10; i++) {
  //      if ( sensorsValid ) { 
  //        logmsg("updateSensors: sensorsValid!");
  //        break;
  //      }
  //      logmsg("updateSensors: pausing...");
  //      pause( 50 );
  //    }
  //    return sensorsValid;
  //  }

  /**   overloaded sensors() fx
   * Send the SENSORS command with one of the SENSORS_ arguments
   * Typically, one does "sensors(SENSORS_ALL)" to get all sensor data
   * @param packetcode = one of SENSORS_ALL, SENSORS_PHYSICAL, 
   *      SENSORS_INTERNAL, or SENSORS_POWER, or for roomba 5xx, it
   *       is the sensor packet number (from the spec)
   // readReqLen used in serEvent to set buffer/read size
   */
  public void sensors(int packetcode ) {
    logmsg("sensor code sent: "+ packetcode);
    switch (packetcode) {
    case 0: 
      readRequestLength = 26; 
      break; // all
    case 1: 
      readRequestLength = 10; 
      break;  // physical
    case 2: 
      readRequestLength = 6; 
      break;   // internal
    case 3: 
      readRequestLength = 10; 
      break;  // power related
      // ?? what all next cases are for
    case 4: 
      readRequestLength = 14; 
      break;
    case 5: 
      readRequestLength = 12; 
      break;
    case 6: 
      readRequestLength = 52; 
      break;
    case 57: 
      readRequestLength = 2; 
      break;
    case 100: 
      readRequestLength = 80; 
      break;
    case 101: 
      readRequestLength = 28; 
      break;
    case 106: 
      readRequestLength = 12; 
      break;
    case 107: 
      readRequestLength = 9; 
      break;
    default: 
      readRequestLength = 1; 
      break;
    }

    byte cmd[] = { 
      (byte)SENSORS, (byte)packetcode
    };
    send(cmd);
    println("sensor sent:"+ packetcode);
    // response read in serialEvent()
  }  // end sensors() w/ datapacket param

  // if called w/o param, gets all sensor data
  public void sensors() {
    // readRequestLength = 26;  set above by param pass
    sensors( SENSORS_ALL );  //  0 for all sensors
  }  // end sensors() w/ no params

  // computeSensors called by good serialEvent --
  // best kept separate to do (more) stuff after good serEvent
  public void computeSensors() {
    sensorsValid = true; 
    println("sV is true");
    // sensorsLastUpdateTime = System.currentTimeMillis();(massive long)
    sensorsLastUpdateTime = millis();
    computeSafetyFault();  // supposed to set mode to Passive if
    // any fault, but does setting mode do anything ?
    // printArray(sensor_bytes);
  }

  /* Compute possible safety fault.
   * Called by computeSensors, could incorporate in it
   * In normal use, call updateSensors(), then this
   * @return  true if detecting an event that exited safe mode
   * @see #updateSensors()
   */
  public boolean computeSafetyFault() {  // any 1 makes it true
    safetyFault = (sensor_bytes[BUMPSWHEELDROPS] & WHEELDROP_MASK) != 0 ||
      sensor_bytes[CLIFFLEFT]==1  || sensor_bytes[CLIFFFRONTLEFT]==1 ||
      sensor_bytes[CLIFFRIGHT]==1 || sensor_bytes[CLIFFFRONTRIGHT]==1;

    if ( safetyFault & (mode == MODE_SAFE) ) mode = MODE_PASSIVE;
    // does this just change mode var or actually change bot's operation?
    return safetyFault;
  }  // end safety fault
  
    // simple serial reader works fine and fast enough
  void readResponse()  // gets serial data after sensors() called
  {
    if (myPort.available() > 0) 
    {  // puts all into this array up to size of array, 26 bytes
      myPort.readBytes(sensor_bytes);
      pause(10); // that refreshes
      if (sensor_bytes != null)
      println("response read, send to compute");
      computeSensors();  // handler for serial data, prints, etc
    }
  }


  //  void serialEvent(Serial myPort) // watch myPort for events, buffer fill
  //  -- did not get triggered from buffer fill so I abandoned
  //{

  //  println("serEvent happened ...");

  //  // size of array param limits # of bytes Read
  //  byte[] sensor_byt = new byte[readRequestLength];  
  //  myPort.readBytes(sensor_byt);
  //  // S.arraycopy(buffer, bufferIndex, outarray, 0, length);
  //   System.arraycopy(sensor_byt, 0, sensor_bytes, 0, readRequestLength);

  //  printArray((sensor_bytes));  // to console -- unparsed, untrimmed

  //  computeSensors();  // does things after a serEvent
  //}  // end serEvent

  public boolean sensorsAutoUpdate() { 
    return sensorsAutoUpdate;
  }

  public void setSensorsAutoUpdate(boolean b) { 
    sensorsAutoUpdate=b;
  }

  public int sensorsUpdateTime() { 
    return sensorsUpdateTime;
  }

  public void setSensorsUpdateTime(int i) { 
    sensorsUpdateTime=i;
  }

  public boolean safetyFault() { 
    return safetyFault;
  } 
  // this secondary validation fx (tests currency) - not called anywhere
  public boolean sensorsValid() {
    // sV var may be valid but stale, so where would this be used?
    if ( sensorsValid ) { 
      long difftime = millis() - sensorsLastUpdateTime;
      if ( difftime > 2*sensorsUpdateTime ) // give it some slack
      { 
        return false;
      } else return true;  // if still inside time window
    }   // end if
    return false;  // if (sV) var false already, skips the if()
  }  // end sV() function

  //  @return all sensor data as a string

  public String sensorsAsString() {
    String sd="";
    if ( debug ) { // fill the sd Str var with sensor hex data
      sd = "\n";
      for ( int i=0; i<26; i++ )
        sd += " "+hex(sensor_bytes[i]);
    }
    return  // this returns data as strings?
      "bump:" + 
      (bumpLeft()?"l":"_") + 
      (bumpRight()?"r":"_") +
      " wheel:" +
      (wheelDropLeft()  ?"l":"_") +
      (wheelDropCenter()?"c":"_") +
      (wheelDropLeft()  ?"r":"_") +
      " wall:" + (wall() ?"Y":"n") + 
      " cliff:" +
      (cliffLeft()       ?"l":"_") +
      (cliffFrontLeft()  ?"L":"_") +  
      (cliffFrontRight() ?"R":"_") +
      (cliffRight()      ?"r":"_") +
      " dirtL:"+ dirtLeft()+
      " dirtR:"+ dirtRight()+
      " vwal:" + virtual_wall() +
      " motr:" + motor_overcurrents() + 
      " dirt:" + dirt_left() + "," + dirt_right() +
      " remo:" + hex(remote_opcode()) +
      " butt:" + hex(buttons()) +
      " dist:" + distance() + 
      " angl:" + angle() +
      " chst:" + charging_state() + 
      " volt:" + voltage() +
      " curr:" + current() +
      " temp:" + temperature() +
      " chrg:" + charge() +
      " capa:" + capacity() +
      sd;  // if debug on, sd is hex of above?, else '\n'
  }

  /** Did we bump into anything */
  public boolean bump() {
    return (sensor_bytes[BUMPSWHEELDROPS] & BUMP_MASK) !=0;
  }
  /** Left bump sensor */
  public boolean bumpLeft() {
    return (sensor_bytes[BUMPSWHEELDROPS] & BUMPLEFT_MASK) !=0;
  }
  /** Right bump sensor */
  public boolean bumpRight() {
    return (sensor_bytes[BUMPSWHEELDROPS] & BUMPRIGHT_MASK) !=0;
  }
  /** Left wheeldrop sensor */
  public boolean wheelDropLeft() {
    return (sensor_bytes[BUMPSWHEELDROPS] & WHEELDROPLEFT_MASK) !=0;
  }
  /** Right wheeldrop sensor */
  public boolean wheelDropRight() {
    return (sensor_bytes[BUMPSWHEELDROPS] & WHEELDROPRIGHT_MASK) !=0;
  }
  /** Center wheeldrop sensor */
  public boolean wheelDropCenter() {
    return (sensor_bytes[BUMPSWHEELDROPS] & WHEELDROPCENT_MASK) !=0;
  }
  /** Can we see a wall? */
  public boolean wall() {
    return sensor_bytes[WALL] != 0;
  }

  // @return true if dirt present

  public boolean dirt() {
    int dl = sensor_bytes[DIRTLEFT] & 0xff;
    int dr = sensor_bytes[DIRTRIGHT] & 0xff;
    //if(debug) println("Roomba:dirt: dl,dr="+dl+","+dr);
    return (dl > 100) || (dr > 100);
  }

  // amount of dirt seen by left dirt sensor 

  public int dirtLeft() {
    return dirt_left();
  }
  // amount of dirt seen by right dirt sensor 

  public int dirtRight() {
    return dirt_right();
  }

  /** left cliff sensor */
  public boolean cliffLeft() {
    return (sensor_bytes[CLIFFLEFT] != 0);
  }  
  /** front left cliff sensor */
  public boolean cliffFrontLeft() {
    return (sensor_bytes[CLIFFFRONTLEFT] != 0);
  }  
  /** front right cliff sensor */
  public boolean cliffFrontRight() {
    return (sensor_bytes[CLIFFFRONTRIGHT] != 0);
  }  
  /** right cliff sensor */
  public boolean cliffRight() {
    return sensor_bytes[CLIFFRIGHT] != 0;
  }

  /** overcurrent on left drive wheel */
  public boolean motorOvercurrentDriveLeft() {
    return (sensor_bytes[MOTOROVERCURRENTS] & MOVERDRIVELEFT_MASK) != 0;
  }
  /** overcurrent on right drive wheel */
  public boolean motorOvercurrentDriveRight() {
    return (sensor_bytes[MOTOROVERCURRENTS] & MOVERDRIVERIGHT_MASK) != 0;
  }
  /** overcurrent on main brush */
  public boolean motorOvercurrentMainBrush() {
    return (sensor_bytes[MOTOROVERCURRENTS] & MOVERMAINBRUSH_MASK) != 0;
  }
  /** overcurrent on vacuum */
  public boolean motorOvercurrentVacuum() {
    return (sensor_bytes[MOTOROVERCURRENTS] & MOVERVACUUM_MASK) != 0;
  }
  /** overcurrent on side brush */
  public boolean motorOvercurrentSideBrush() {
    return (sensor_bytes[MOTOROVERCURRENTS] & MOVERSIDEBRUSH_MASK) !=0;
  }

  /** 'Power' button pressed state */
  public boolean powerButton() {
    return (sensor_bytes[BUTTONS] & POWERBUTTON_MASK) != 0;
  }
  /** 'Spot' button pressed state */
  public boolean spotButton() {
    return (sensor_bytes[BUTTONS] & SPOTBUTTON_MASK) != 0;
  }
  /** 'Clean' button pressed state */
  public boolean cleanButton() {
    return (sensor_bytes[BUTTONS] & CLEANBUTTON_MASK) != 0;
  }
  /** 'Max' button pressed state */
  public boolean maxButton() {
    return (sensor_bytes[BUTTONS] & MAXBUTTON_MASK) != 0;
  }

  //
  // lower-level sensor access
  //
  /** lower-level func, returns raw byte */
  public int bumps_wheeldrops() {
    return sensor_bytes[BUMPSWHEELDROPS];
  }
  /** lower-level func, returns raw byte */
  public int cliff_left() {
    return sensor_bytes[CLIFFLEFT];
  }
  /** lower-level func, returns raw byte */
  public int cliff_frontleft() {
    return sensor_bytes[CLIFFFRONTLEFT];
  }
  /** lower-level func, returns raw byte */
  public int cliff_frontright() {
    return sensor_bytes[CLIFFFRONTRIGHT];
  }
  /** lower-level func, returns raw byte */
  public int cliff_right() {
    return sensor_bytes[CLIFFRIGHT];
  }
  /** lower-level func, returns raw byte */
  public int virtual_wall() {
    return sensor_bytes[VIRTUALWALL];
  }
  /** lower-level func, returns raw byte */
  public int motor_overcurrents() {
    return sensor_bytes[MOTOROVERCURRENTS];
  }

  public int dirt_left() {
    return sensor_bytes[DIRTLEFT] & 0xff;
  }

  public int dirt_right() {
    return sensor_bytes[DIRTRIGHT] & 0xff;
  }
  /** lower-level func, returns raw byte */
  public int remote_opcode() {
    return sensor_bytes[REMOTEOPCODE];
  }
  /** lower-level func, returns raw byte */
  public int buttons() {
    return sensor_bytes[BUTTONS];
  }

  /* Distance traveled since last requested
   * units: mm
   * range: -32768 - 32767
   */
  public short distance() {
    return toShort(sensor_bytes[DISTANCE_HI], 
      sensor_bytes[DISTANCE_LO]);
  }
  /* Angle traveled since last requested
   * units: mm, diff in distance traveled by two drive wheels
   * range: -32768 - 32767
   */
  public short angle() {
    return toShort(sensor_bytes[ANGLE_HI], 
      sensor_bytes[ANGLE_LO]);
  }  
  // angle since last read, but in degrees
  // FIXME I think this should be (360 * angle())/(258 * PI)
  public float angleInDegrees() {
    return (float) angle() / millimetersPerDegree;
  }

  // angle since last read, but in radians

  // FIXME I think this should be (2 * angle())/258
  public float angleInRadians() {
    return (float) angle() / millimetersPerRadian;
  }

  /* Charging state
   * units: enumeration
   * range: 
   */
  public int charging_state() {
    return sensor_bytes[CHARGINGSTATE] & 0xff;
  }
  /* Voltage of battery
   * units: mV
   * range: 0 - 65535
   */
  public int voltage() {
    return toUnsignedShort(sensor_bytes[VOLTAGE_HI], 
      sensor_bytes[VOLTAGE_LO]);
  } 
  /* Current in or out of battery
   * units: mA
   * range: -32768 - 32767
   */
  public short current() {
    return toShort(sensor_bytes[CURRENT_HI], 
      sensor_bytes[CURRENT_LO]);
  }
  /* temperature of battery
   * units: degrees Celcius
   * range: -128 - 127
   */
  public byte temperature() {
    return sensor_bytes[TEMPERATURE];
  }
  /* Current charge of battery
   * units: mAh 
   * range: 0-65535
   */
  public int charge() {
    return toUnsignedShort(sensor_bytes[CHARGE_HI], 
      sensor_bytes[CHARGE_LO]);
  }
  /* Estimated charge capacity of battery
   * units: mAh
   * range: 0-65535
   */
  public int capacity() {
    return toUnsignedShort(sensor_bytes[CAPACITY_HI], 
      sensor_bytes[CAPACITY_LO]);
  }

  // end sensor meth, var

  /* ========== note / song functions ============*/

  /* Play a musical note by defining a one-note song & playing it
   * Use song slot 15
   * A new note cuts off an old one if it's not finished
   * @param note =  a note number from 31 (G0) to 127 (G8)
   * @param duration duration of note in 1/64ths of a second
   */
  public void playNote( int note, int duration ) {
    logmsg("playnote: "+note+":"+duration);
    byte cmd[] = {
      (byte)SONG, 3, 1, (byte)note, (byte)duration, // define song
      (byte)PLAY, 3
    };              
    send( cmd );
  }
  // play it back
  public void playSong( int songnum ) {
    byte cmd[] = { 
      (byte)PLAY, (byte)songnum
    };
    send(cmd);
  }

  /**
   * Make a song
   * @param songnum = number of song to define
   * @param song  = array of songnotes, 
   *              even entries are notenums, odd are duration of 1/6ths
   */
  public void createSong( int songnum, int song[] ) {
    int len = song.length;
    int songlen = len/2;
    logmsg("createSong: songnum:"+songnum+", songlen:"+songlen);
    byte cmd[] = new byte[len+3]; 
    cmd[0] = (byte) SONG;
    cmd[1] = (byte) songnum;
    cmd[2] = (byte) songlen;
    for ( int i=0; i < len; i++ ) {
      cmd[3+i] = (byte)song[i];
    }
    send(cmd);
  }
  /* Make a song w/ array of notes
   * @param songnum number of song to define
   * @param song  array of Notes <-- type not found
   */
  //  public void createSong( int songnum, Note song[] ) {
  //    int songlen = song.length;
  //    logmsg("createSong: songnum:"+songnum+", songlen:"+songlen);
  //    byte cmd[] = new byte[songlen+3]; 
  //    cmd[0] = (byte) SONG;
  //    cmd[1] = (byte) songnum;
  //    cmd[2] = (byte) songlen;
  //    int j=3;
  //    for ( int i=0; i < songlen; i++ ) {
  //      cmd[j++] = (byte)song[i].notenum;
  //      cmd[j++] = (byte)song[i].toSec64ths();
  //    }
  //    send(cmd);
  //  }


  // possible modes
  public static final int MODE_UNKNOWN = 0;
  public static final int MODE_PASSIVE = 1;
  public static final int MODE_SAFE    = 2;
  public static final int MODE_FULL    = 3;

  // Roomba ROI opcodes
  // these should all be bytes, but Java bytes are signed = stupid
  public static final int START   =  128;  // 0
  public static final int BAUD    =  129;  // 1
  public static final int CONTROL =  130;  // 0
  public static final int SAFE    =  131;  // 0
  public static final int FULL    =  132;  // 0
  public static final int POWER   =  133;  // 0
  public static final int SPOT    =  134;  // 0
  public static final int CLEAN   =  135;  // 0
  public static final int MAX     =  136;  // 0
  public static final int DRIVE   =  137;  // 4
  public static final int MOTORS  =  138;  // 1
  public static final int LEDS    =  139;  // 3
  public static final int SONG    =  140;  // 2N+2
  public static final int PLAY    =  141;  // 1
  public static final int SENSORS =  142;  // 1
  public static final int DOCK    =  143;  // 0
  public static final int PWMMOTORS = 144; // 3
  public static final int DRIVEWHEELS = 145;  // 4
  public static final int DRIVEPWM = 146;      // 4
  public static final int STREAM  =  148;       // N+1
  public static final int QUERYLIST = 149;       // N+1
  public static final int STOPSTARTSTREAM = 150;  // 1
  public static final int SCHEDULINGLEDS = 162;   // 2
  public static final int DIGITLEDSRAW = 163;    // 4
  public static final int DIGITLEDSASCII = 164;  // 4
  public static final int BUTTONSCMD  =  165;   // 1
  public static final int SCHEDULE =  167;     // n
  public static final int SETDAYTIME = 168;   // 3

  // offsets (indices) of sensor_bytes data
  public static final int BUMPSWHEELDROPS     = 0;
  public static final int WALL                = 1;
  public static final int CLIFFLEFT           = 2;
  public static final int CLIFFFRONTLEFT      = 3;
  public static final int CLIFFFRONTRIGHT     = 4;
  public static final int CLIFFRIGHT          = 5;
  public static final int VIRTUALWALL         = 6;
  public static final int MOTOROVERCURRENTS   = 7;
  public static final int DIRTLEFT            = 8;
  public static final int DIRTRIGHT           = 9;
  public static final int REMOTEOPCODE        = 10;
  public static final int BUTTONS             = 11;
  public static final int DISTANCE_HI         = 12;
  public static final int DISTANCE_LO         = 13;  
  public static final int ANGLE_HI            = 14;
  public static final int ANGLE_LO            = 15;
  public static final int CHARGINGSTATE       = 16;
  public static final int VOLTAGE_HI          = 17;
  public static final int VOLTAGE_LO          = 18;  
  public static final int CURRENT_HI          = 19;
  public static final int CURRENT_LO          = 20;
  public static final int TEMPERATURE         = 21;
  public static final int CHARGE_HI           = 22;
  public static final int CHARGE_LO           = 23;
  public static final int CAPACITY_HI         = 24;
  public static final int CAPACITY_LO         = 25;

  // bitmasks for various things
  public static final int WHEELDROP_MASK      = 0x1C;
  public static final int BUMP_MASK           = 0x03;
  public static final int BUMPRIGHT_MASK      = 0x01;
  public static final int BUMPLEFT_MASK       = 0x02;

  public static final int WHEELDROPRIGHT_MASK = 0x04;
  public static final int WHEELDROPLEFT_MASK  = 0x08;
  public static final int WHEELDROPCENT_MASK  = 0x10;

  public static final int MOVERDRIVELEFT_MASK = 0x10;
  public static final int MOVERDRIVERIGHT_MASK= 0x08;
  public static final int MOVERMAINBRUSH_MASK = 0x04;
  public static final int MOVERVACUUM_MASK    = 0x02;
  public static final int MOVERSIDEBRUSH_MASK = 0x01;

  public static final int POWERBUTTON_MASK    = 0x08;  
  public static final int SPOTBUTTON_MASK     = 0x04;  
  public static final int CLEANBUTTON_MASK    = 0x02;  
  public static final int MAXBUTTON_MASK      = 0x01;  

  // which sensor packet to get, argument for sensors(int)
  public static final int SENSORS_ALL         = 0;
  public static final int SENSORS_PHYSICAL    = 1;
  public static final int SENSORS_INTERNAL    = 2;
  public static final int SENSORS_POWER       = 3;

  public static final int REMOTE_NONE         = 0xff;
  public static final int REMOTE_POWER        = 0x8a;
  public static final int REMOTE_PAUSE        = 0x89;
  public static final int REMOTE_CLEAN        = 0x88;
  public static final int REMOTE_MAX          = 0x85;
  public static final int REMOTE_SPOT         = 0x84;
  public static final int REMOTE_SPINLEFT     = 0x83;
  public static final int REMOTE_FORWARD      = 0x82;
  public static final int REMOTE_SPINRIGHT    = 0x81;


  //
  // utility method, conversion, alias for prints, shortcut
  //  ? need most of these

  public final short toShort(byte hi, byte lo) {
    return (short)((hi << 8) | (lo & 0xff));
  }

  public final int toUnsignedShort(byte hi, byte lo) {
    return (int)(hi & 0xff) << 8 | lo & 0xff;
  }

  public void print(String s) {
    System.out.print(s);
  }

  public void println(String s) {
    System.out.println(s);
  }

  public String hex(byte b) {
    return Integer.toHexString(b&0xff);
  }

  public String hex(int i) {
    return Integer.toHexString(i);
  }

  public String binary(int i) {
    return Integer.toBinaryString(i);
  }

  // delay is Aliased to pause fx, v.i.pause(int)
  public void delay( int millis ) {  
    pause( millis );
  }

  /* Just a simple pause function, which makes the thread block
   with Thread.sleep()
   * @param millis = number of milliseconds to wait
   */
  public void pause(int millis) {
    try { 
      Thread.sleep(millis);
    } 
    catch(Exception e) {
    }
  }  // end sleep

  // if debug enabled, prints the various cmd messages 
  public void logmsg(String msg) {
    if (debug) 
      System.err.println("RooComm ("+System.currentTimeMillis()+"):"+
        msg);
  }

  // Exceptn / error reporting

  public void errorMessage(String where, Throwable e) {
    e.printStackTrace();
    throw new RuntimeException("Error inside " + where + "()");
  }   // end error report
}  // end RC class
