#Final Frame Aspect
global finalFrameAspect = 0
#Final Pixel Aspect Ratio (Pixelshape in logoise)
global fPar = 1.0
# Consts
global AR43 = float(4)/3
global AR169 = float(16)/9
global AR221 = 2.21

function arCalc(clip v, float "pixelShape")
{
    pixelShape = Default(pixelShape, 1.0)
    return float(v.width) * pixelShape / float(v.height)
}

function checkedCrop(clip v, int "left", int "top", int "right", int "bottom")
{
    CrLeft = Default(left, 0)
    CrTop = Default(top, 0)
    CrRight = Default(right, 0)
    CrBottom = Default(bottom, 0)
    
    v = ((CrLeft%2) == 1) || ((CrTop%2) == 1) || ((CrRight%2) == 1) || ((CrBottom%2) == 1) ? v.ConvertToRGB32.Crop(CrLeft, CrTop, -CrRight, -CrBottom) : v.Crop(CrLeft, CrTop, -CrRight, -CrBottom)
return v
}

function plus(float x)
{   return (1+float(x)/100)     }

function minus(float x)
{   return (1-float(x)/100)        }

function SetFinalFrameAR(clip v, float AR)
{   
    global finalFrameAspect = AR
    return v
}

function letterise(clip v, float DisplayAR, float TrueAR)
{
     bars = v.height*(TrueAR/DisplayAR - 1)/2
     v.letterMaker(bars)   
}
function pillarise(clip v, float DisplayAR, float TrueAR)
{
    bars = v.width*(DisplayAR/TrueAR - 1)/2
    v.pillarMaker(bars)
}

function pillarMaker(clip v, float barsize)
{
    barsize = Abs(Round(barsize))
    v = ((barsize%2) == 0) ? v : ConvertToRGB32(v)
    return v.AddBorders(barsize,0,barsize,0)
}

function letterMaker(clip v, float barsize)
{
    barsize = Abs(Round(barsize))
    v = ((barsize%2) == 0) ? v : ConvertToRGB32(v)
    return v.AddBorders(0,barsize,0,barsize)
}


function pixelBattle (clip c,float TrueAR, float Frame1, float Frame2, float "FinalWidth", float "FinalHeight")
    {
    checkFrameAspects = (Frame1 > Frame2)? Eval("""
         Temp = Frame1       
         Frame1 = Frame2
         Frame2 = Temp
         return Temp   
         """) : 0
         
    FinalWidth = Default(FinalWidth, 720.0)
    FinalHeight = Default(FinalHeight, 576.0)

    HeightMod = FinalHeight / (FinalWidth / Frame1)
    WidthMod = FinalWidth / (FinalHeight * Frame2)
    ActivePix1 = FinalWidth / TrueAR * HeightMod * FinalWidth 
    ActivePix2 = FinalHeight * TrueAR * WidthMod * FinalHeight   


    c = (ActivePix1 >= ActivePix2) ? c.letterise(Frame1, TrueAR).SetFinalFrameAR(Frame1) 
     \ : c.pillarise(Frame2, TrueAR).SetFinalFrameAR(Frame2)
          
    return c
}

# Output: DVD, non-compliant framerates allowed.
function toJoost(clip c, float TrueAR, float "buf", int "w", int "h")
{
widthFinal = Default(w, 720)
heightFinal = Default(h, 576)
x = Default(buf, 0.5)
c = (   ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c.SetFinalFrameAR(AR43) :
         \ ((TrueAR >= ((AR169)*minus(x)))  && (TrueAR <= ((AR169)*plus(x)))) ? c.SetFinalFrameAR(AR169):
         \ ((TrueAR >= ((AR221)*minus(x)))  && (TrueAR <= ((AR221)*plus(x)))) ? c.SetFinalFrameAR(AR221):
         \ (TrueAR < (AR43)) ? c.pillarise(AR43, TrueAR).SetFinalFrameAR(AR43)  : 
         \ ((TrueAR > (AR43)) && (TrueAR<AR169)) ? c.pixelBattle(TrueAR, AR43, AR169, widthFinal, heightFinal): 
         \ ((TrueAR > (AR169)) && (TrueAR<AR221)) ? c.pixelBattle(TrueAR, AR169, AR221, widthFinal, heightFinal): 
         \ (TrueAR > (AR221)) ? c.letterise(AR221, TrueAR).SetFinalFrameAR(AR221) :         
         \ c.SetFinalAR(0.0) )

global fPAR = float(finalFrameAspect)/(float(widthFinal)/(heightFinal))

return c.Spline36Resize(widthFinal, heightFinal).ConvertToYV12
}

function toBlinkbox2(clip c, float TrueAR, float "buf", int "w", int "h")
{
widthFinal = Default(w, 720)
heightFinal = Default(h, 576)
x = Default(buf, 0.5)
c = (   ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c.SetFinalFrameAR(AR43) :
         \ ((TrueAR >= ((AR169)*minus(x)))  && (TrueAR <= ((AR169)*plus(x)))) ? c.SetFinalFrameAR(AR169):
         \ (TrueAR < (AR43)) ? c.pillarise(AR43, TrueAR).SetFinalFrameAR(AR43)  : 
         \ ((TrueAR > (AR43)) && (TrueAR<AR169)) ? c.pixelBattle(TrueAR, AR43, AR169, widthFinal, heightFinal).SetFinalFrameAR(AR43) : 
         \ ((TrueAR > (AR169))) ? c.letterise(AR169, TrueAR).SetFinalFrameAR(AR169) :      
         \ c.SetFinalAR(0.0) )

global fPAR = float(finalFrameAspect)/(float(widthFinal)/(heightFinal))

return c.Spline36Resize(widthFinal, heightFinal).ConvertToYV12
}

#Output: 4:3 Frame, 640x480, square pixels
function toBlinkx(clip c, float TrueAR, float "buf", int "w", int "h")
{
    widthFinal = Default(w, 640)
    heightFinal = Default(h, 480)
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c :
     \ ( TrueAR > AR43 ) ? c.letterise(AR43, TrueAR):
     \ (TrueAR < AR43 ) ? c.pillarise(AR43, TrueAR) : c)
    
    return c.Spline36Resize(widthFinal, heightFinal).ConvertToYV12.SetFinalFrameAR(AR43)
}

#Output: 640x480 Fullscreen, 854x480 Widescreen, square pixels
function toVuze(clip c, float TrueAR, float "buf")
{
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c.Spline36Resize(640,480).ConvertToYV12.SetFinalFrameAR(AR43) :
         \ ((TrueAR >= ((AR169)*minus(x)))  && (TrueAR <= ((AR169)*plus(x))))? c.ConvertToRGB32. Spline36Resize(854,480).SetFinalFrameAR(AR169):
         \ (TrueAR > AR43 ) && (TrueAR < (AR169)) ? c.pillarise(AR169, TrueAR).ConvertToRGB32. Spline36Resize(854,480).SetFinalFrameAR(AR169):
         \ (TrueAR < AR43 ) ? c.pillarise(AR43, TrueAR).Spline36Resize(640,480).ConvertToYV12.SetFinalFrameAR(AR43) : 
         \ c.letterise(AR169, TrueAR).ConvertToRGB32. Spline36Resize(854,480).SetFinalFrameAR(AR169) )
    return c
}

#Output: borders not allowed, mod8 dimensions, width 720, square pixels
function toBlinkBox(clip c, float TrueAR, float "w")
{
    #width fixed
    widthFinal = Default(w, 720)
    # mod 8 height
    heightFinal = Round((float(widthFinal)/TrueAR)/8)*8
    #AR Error = ...
    return c.spline36Resize(widthFinal, heightFinal).ConvertToYV12.SetFinalFrameAR(TrueAR)
}

function toRDTV(clip c, float TrueAR, float "w")
{
    #width fixed
    widthFinal = Default(w, 480)
    # mod 8 height
    heightFinal = Round((float(widthFinal)/TrueAR)/8)*8
    #AR Error = ...
    return c.spline36Resize(widthFinal, heightFinal).ConvertToYV12.ResampleAudio(44100).SetFinalFrameAR(TrueAR)
}

function toNokiaVC(clip c, float "AR", float "buf", int "w", int "h")
{
    AR = Default(AR, TrueAR)
    widthFinal = Default(w, 320)
    heightFinal = Default(h, 240)
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR43)*minus(x)))  && (AR <= ((AR43)*plus(x)))) ? c :
     \ ( AR > AR43 ) ? c.letterise(AR43, AR):
     \ (AR < AR43 ) ? c.pillarise(AR43, AR) : c)
    
    return c.Spline36Resize(widthFinal, heightFinal).ConvertToYV12.ChangeFPS(15).ResampleAudio(32000).SetFinalFrameAR(AR43)
}

function to43Frame(clip c, float TrueAR, float "buf", int "w", int "h")
{
    widthFinal = Default(w, 768)
    heightFinal = Default(h, 576)
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c :
     \ ( TrueAR > AR43 ) ? c.letterise(AR43, TrueAR):
     \ (TrueAR < AR43 ) ? c.pillarise(AR43, TrueAR) : c)
    
    return c.Spline36Resize(widthFinal, heightFinal).SetFinalFrameAR(AR43)
}

function to169Frame(clip c, float TrueAR, float "buf", int "w", int "h")
{
    widthFinal = Default(w, 1024)
    heightFinal = Default(h, 576)
    
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR169)*minus(x)))  && (TrueAR <= ((AR169)*plus(x)))) ? c :
     \ ( TrueAR > AR169 ) ? c.letterise(AR169, TrueAR):
     \ (TrueAR < AR169 ) ? c.pillarise(AR169, TrueAR) : c)
    
    return c.Spline36Resize(widthFinal, heightFinal).SetFinalFrameAR(AR169)
}

function toBabelgum(clip c, float TrueAR, float "w", float "buf")
{
    x = Default(buf, 0.5)
    c = (  ((TrueAR >= ((AR43)*minus(x)))  && (TrueAR <= ((AR43)*plus(x)))) ? c.to43Frame(TrueAR).SetFinalFrameAR(AR43) :
         \ ((TrueAR >= ((AR169)*minus(x)))  && (TrueAR <= ((AR169)*plus(x))))? c.to169Frame(TrueAR).SetFinalFrameAR(AR169):
         \ (TrueAR > AR43 ) && (TrueAR < (AR169)) ? c.pillarise(AR169, TrueAR).toMaxHeight(16.0/9).ConvertToYV12.SetFinalFrameAR(AR169):
         \ (TrueAR < AR43 ) ? c.pillarise(AR43, TrueAR).toMaxHeight(4.0/3).ConvertToYV12.SetFinalFrameAR(AR43) : 
         \ c.letterise(AR169, TrueAR).toMaxHeight(16.0/9).ConvertToYV12.SetFinalFrameAR(AR169) )
    return c
}

function toMaxHeight(clip c, float TrueAR, float "h")
{
    heightFinal = default(h, c.height)
    heightFinal = Round(float(heightFinal)/8)*8
    widthFinal =  Round((heightFinal * TrueAR) / 8)*8
    return c.Spline36Resize(widthFinal, heightFinal).ConvertToYV12
}

#
function toZvue()
{}

# 4:3 Frame, 640x480, 480x360, 320x240 square pixels
function toJalipo()
{}

# 368x288, mod for mobile, square pixels
function toTmob(clip c)
{return c.spline36Resize(368,288).ConvertToYV12}

function toArvato(clip c)
{return c.spline36Resize(320,240).ChangeFPS(12).ResampleAudio(22050).ConvertToYV12}

function toMofilm(clip c, float TrueAR)
{
    # mod 8 height
    heightFinal = Round((float(c.width)/TrueAR)/8)*8
    #Min height: 456px
    heightFinal = (heightFinal < 456) ? 456 : heightfinal 
    #mod8Width
    widthFinal = Round(float(heightFinal)*TrueAR/8)*8
     #AR Error = ...
    return c.spline36Resize(widthFinal, heightFinal).ConvertToYV12.SetFinalFrameAR(TrueAR)
}

function specThumbs(clip c, float "TAR", int "W", int "H", float "divideby", int "framenum", float "inPX", float "outpx")
{
	W = Default(W, 640)
	H = Default(H, 352)
	## Frame Aspect Ratio 
	potensAR = float(c.width)/float(c.height)
	TAR = Default(TAR, potensAR)
	TAR = (TrueAR > 0) ? TrueAR : TAR
	
	#randframe = Rand(c.framecount)
	randframe = Round(float(c.framecount)/4)
	framenum = Default(framenum,randframe)	
	divideby = Default(divideby,1.0)
    framenum = (divideby > 1) ? Round(float(c.framecount)/divideby) : framenum
    	
	potensinPX = float(TAR)/(float(c.width)/float(c.height))
	inPX = Default(inPX, potensinPX)
	outPX = Default(outPX, 1.0)

    ARsource = float(c.width)/c.height * inPX
    ARout =   float(W)/float(H) * outPX
    
    ChopMod = (ARsource > ARout) ? Abs(Round(((c.Height*ARout)-(c.Height*ARsource))/(2*inPX))) \
    : (ARout > ARsource) ? Abs(Round((((c.Width/ARout)-(c.width/ARsource))/(2))/inPX))  \
    : 0  
    
    L = (ARsource > ARout) ? ChopMod \
        : 0 
    R = (ARsource > ARout) ? ChopMod \
        : 0 
    T = (ARout > ARsource) ? ChopMod \
        : 0  
    B = (ARout > ARsource) ? ChopMod \
        : 0  
    
	c = c.killAudio.spline36Resize(W,H, L,T,-R,-B).Trim(framenum,framenum).ConvertToYV12.Coloryuv(autogain=true, autowhite=true)#.ConverttoRGB32
	return c
	
}
