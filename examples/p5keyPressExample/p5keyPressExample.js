var pressed;
var colors = [];

function setup() {
  createCanvas(640, 480);
  background(0);
  colors = [ 
    [204, 51, 204], [51, 102, 204], [153, 51, 204], [204, 204, 153], [255, 51, 204], [51, 153, 255], 
    [00, 51, 204], [255, 204, 153]];
}


function draw() {
  if (pressed === true) { // one true on each press
    var randInd = int(random(colors.length));
    var randSz = random (188);

    fill(colors[randInd]);
  }
  ellipse(random(width), random(height), randSz, randSz);
  pressed = false;
}  // end draw

function keyPressed() {  // true once each press, does not repeat
  pressed = true;
}
