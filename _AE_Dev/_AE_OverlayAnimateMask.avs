#Original Mask should be 3*3 (width*height) times larger than destination frame to allow full mask motion & coverage 
#x & y: coordinates for centre position of mask to appear on screen

Function moveMyMask(clip c1, clip c2, clip msk, float x, float y)
{
  #Check for Valid Coordinates
  x = x > msk.width ? msk.width-float(c1.width)/2 : x<0 ? 0 : x
  y = y > msk.width ? msk.height-float(c1.height)/2 : y <0? 0 : y
  #Find Mask Edges relative to centre coordinates
  left = x - float(c1.width)/2 
  right = x + float(c1.width)/2 
  top = y + float(c1.height)/2 
  bottom = y - float(c1.height)/2
  createCropW = (left <= 0 ) ? Eval("""
         Temp = "x"       
         CrpL = 0
         CrpR = msk.width-c1.width
         return Temp   
         """) \
         : (right >= msk.width) ? Eval("""
         Temp = "x"  
         CrpL = msk.width-c1.width     
         CrpR = 0
         return Temp   
         """) \
         : Eval("""
         Temp = "x"  
         CrpL = left    
         CrpR = msk.width-right
         return Temp   
         """)
  CreateCropH = (bottom <= 0 ) ? Eval("""
         Temp = "x"       
         CrpB = 0
         CrpT = msk.height-c1.height
         return Temp   
         """) \
         : (top >= msk.height) ? Eval("""
         Temp = "x"  
         CrpB = msk.height-c1.height
         CrpT = 0
         return Temp   
         """) \
         : Eval("""
         Temp = "x"  
         CrpB = Bottom    
         CrpT = msk.height-Top
         return Temp   
         """)
         
  motion_mask = msk.Spline36Resize(c1.width, c1.height, Round(CrpL), Round(CrpT), Round(-CrpR), Round(-CrpB))
  Overlay(c1,c2,mask=motion_mask )
}

### B == Base Clip
b = colorbars(320, 240, "RGB32").Trim(0,1000)
### O == Overlayed Clip
o = blankclip(1000,320,240,"RGB32")
### M == Mask Clip
m = imagereader("mask.png").ConvertToRGB32

## X & Y Values refer to the coordinates of the mask
## that will appear at the centre of the screen.
## e.g. x=20 -> x=5 creates East to West Mask Motion
## & y=5 -> y=20 creates North To South mask motion

#Moves mask diagonally
startx=b.width/2
starty=b.height/2
endx=m.width-b.width/2
endy= m.height-b.height/2

Animate(0,b.framecount,"moveMyMask",b,o,m,startx,starty,b,o,m,endx,endy)

#Moves mask sideways 
startx=m.width/2-b.width/2
starty=m.height/2
endx=m.width-b.width
endy= m.height/2

Animate(0,b.framecount,"moveMyMask",b,o,m,startx,starty, b,o,m,endx, endy)


#Chaining Linear Motion
b1 = b.trim(0,b.framecount/2)
#trim overlay if necessary
xs1 = 400
xe1 = 1000
ys1 = 200
ye1 = 500
b2 = b.trim(b.framecount/2+1, b.framecount)
#trim overlay if necessary
xe2 = 200
ye2 = 600

Animate(0, b1.framecount,"moveMyMask",b1,o,m,xs1,ys1, b1,o,m,xe1, ye1)\
++Animate(0, b2.framecount,"moveMyMask",b2,o,m,xe1,ye1, b2,o,m,xe2, ye2)