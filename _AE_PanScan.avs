
##########################################
global destFrameAR=float(destWidth)/destHeight * destPAR
##########################################

#Source Frame Info
global cHeight = float(Main.Height)
global cWidth = float(Main.Width)
global sourcePAR = TrueAR / cWidth * cHeight
global sourceTAR = TrueAR
#Amount of width to Crop (No Zoom, only horizontal pans)
global toBeCropped = cWidth - (destFrameAR * cHeight / sourcePAR)

#LeftFocus
function rightFocus(clip c, int "left", int "top", int "right", int "bottom" )
    {     
    r = Default (right, 0)
    l = Default (left , Round(toBeCropped)-r)
    t = Default (top,0)
    b = Default (bottom,0)
        return c.Spline36Resize(destWidth,destHeight,l ,t,-r,-b)
    }
    
#RightFocus
function leftFocus(clip c, int "left", int "top", int "right", int "bottom" )
    {     
    l = Default (left , 0)
    r = Default (right, Round(ToBeCropped-l))
    t = Default (top,0)
    b = Default (bottom,0)
        return c.Spline36Resize(destWidth,destHeight,l ,t,-r,-b)
    }
    
#CenterFocus
function centerFocus(clip c, int "left", int "top", int "right", int "bottom" )
    {     
    l = Default (left , Round(toBeCropped/2))
    r = Default (right, Round(toBeCropped/2))
    t = Default (top,0)
    b = Default (bottom,0)
        return c.Spline36Resize(destWidth,destHeight,l ,t,-r,-b)
    }

function ResizeAndBorder(clip c, int "left", int "top", int "right", int "bottom")
    {
    l = Default (left , 0)
    r = Default (right, 0)
    t = Default (top,0)
    b = Default (bottom,0)
    brdrH = Round(((float(c.width - (l+r))/destFrameAR) - (float(c.width - (l+r))/((c.width - (l+r))*SourcePAR/(c.height-(t+b))))) / 2)
    return c.AddBorders(0,brdrH,0,brdrH).Spline36Resize(destWidth,destHeight, l,t,-r,-b)
    }

function inOutSquish(clip c, int "startinSq", int "endInSq", int "startOutSq", int "endOutSq", int "sleft", int "sright", int "eleft", int "eright", int "duration", int "durS", int "durE")
    {
    lng = float(c.framecount)
    Assert(lng > 10,  "Clip has to be longer than 10 frames to use this, Alexei has decided, because he is lord and master of this domain")
    sl = Default (sleft , Round(toBeCropped/2))
    sr = Default (sright, Round(toBeCropped/2))    
    el = Default (eleft , Round(toBeCropped/4))
    er = Default (eright, Round(toBeCropped/4))

    duration = Default(duration, 20)
    duration = duration > Round(lng/2) ? Round(lng/2)-1 : duration
    durS = Default(durS, Duration)
    durE =Default(durE, Duration)

    startinSq = Default (startinSq , 0)
    endInSq = Default (endInSq, startinSq+durS)
    endOutSq= Default (endOutSq,Round(lng))
    startOutSq = Default (startOutSq, endOutSq-durE)
    
    cBeg = startinSQ > 1 ? c.Trim(0,startinSQ-1).Spline36Resize(destWidth,destHeight,sl,0,-sr,0) : c
    #cBeg = cBeg.subtitle("CBEG")
    cOut = c.Trim(startinSq, endInSq)
    cOut = Animate(0,cOut.framecount,"Spline36Resize", cOut,destWidth,destHeight,sl,0,-sr,0, cOut,destWidth,destHeight,el,0,-er,0)
    #cOUt = cOut.subtitle("COUT")
    cStab = endInSq < startOutSq ? c.Trim(endInSq+1, startOutSq-1).Spline36Resize(destWidth,destHeight,el,0,-er,0) : c
    #cStab = cStab.subtitle("CSTAB")
    cIn = c.Trim(startOutSq, endOutSq)
    cIn = Animate(0,cIn.framecount,"Spline36Resize", cIn,destWidth,destHeight,el,0,-er,0, cIn,destWidth,destHeight,sl,0,-sr,0)
    #cIn = cIn.subtitle("CIN")
    cFin = endOutSq < Round(lng) ? c.Trim(endOutSq+1,Round(lng)).Spline36Resize(destWidth,destHeight,sl,0,-sr,0) : c
    #cFin = cIn.subtitle("CFIN")
    c = startinSQ > 1 ? cBeg+cOut : cOut
    c = endInSq < startOutSq ? c + cStab : c
    c = c + cIn
    c = endOutSq < Round(lng) ? c+cFin : c
    return c
    }
    
function PanIt(clip c, string "move", int "sl", int "sr", int "el", int "er", bool "easing", int "start", int "end")
    {
    #Pan Offsets implemented only in "Custom"
    # use toBeCropped minus offset to quackulate reciprocal offset
    lng = c.framecount
    start = Default(start, 0)
    end = Default(end, lng-1)
    move = Default (move, "custom")
    sl = Default (sl , -1)
    sr =Default (sr , -1) 
    el =Default (el , -1)
    er =Default (er , -1)
    easing = Default(easing, "false")   
    #Right To Left
    c = (move == "l2c" ) \
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,0,0,-toBeCropped,0, c,destWidth,destHeight,Round(toBeCropped/2),0,-Round(toBeCropped/2),0) \
    : (move == "l2r" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,0,0,-toBeCropped,0, c,destWidth,destHeight,toBeCropped,0,0,0) \
    : (move == "c2l" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,Round(toBeCropped/2),0,-Round(toBeCropped/2),0,c,destWidth,destHeight,0,0,-toBeCropped,0) \
    : (move == "c2r" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,Round(toBeCropped/2),0,-Round(toBeCropped/2),0,c,destWidth,destHeight,toBeCropped,0,0,0) \
    : (move == "r2c" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,toBeCropped,0,0,0, c,destWidth,destHeight,Round(toBeCropped/2),0,-Round(toBeCropped/2),0) \
    : (move == "r2l" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,toBeCropped,0,0,0, c,destWidth,destHeight,0,0,-toBeCropped,0) \
    : (move == "custom" )  \     
        ? Animate(start,end,"Spline36Resize", c,destWidth,destHeight,sl,0,-sr,0, c,destWidth,destHeight,el,0,-er,0) \
    : c
    return c
    }