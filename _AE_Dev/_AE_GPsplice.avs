function plus(float x)
{   return (1+float(x)/100)     }

function minus(float x)
{   return (1-float(x)/100)        }

function AudioMakerST(int channels, clip stereo) {
    Assert(channels > 0,  "AudioMaker: cannot produce audio with less than 1 channel")
    return (channels > 2 \
        ? MergeChannels(stereo, AudioMakerST(channels - 2, stereo)) \
    : (channels == 2 \
        ? stereo \
    : \
        stereo.ConvertToMono() \
    ))
}

function borderBattle(clip l, clip c, float lAR, float cAR, float PARl, int col)
    {
    wMod = Abs(Round(((l.height*cAR)-(l.Height*lAR))/(2*PARl)))
    hMod = Abs(Round(((float(l.width)/cAR)-(float(l.width)/lAR))/2*PARl)) 
    l = l.convertToRGB32 
    l = (lAR >= cAR) ? l.AddBorders(0,hMod,0,hMod, color=col)
     \ : l.AddBorders(wMod,0,wMod,0, color=col)      
    return l
}

function cropBattle (clip l, clip c, float lAR, float cAR, float PARl)
    {       
    wMod = Abs(Round(((l.height*cAR)-(l.Height*lAR))/(2*PARl)))
    hMod = Abs(Round(((float(l.width)/cAR)-(float(l.width)/lAR))/2*PARl))     
    l = l.convertToRGB32 
    l = (lAR < cAR) ? l.Crop(0,hMod,0,-hMod)
     \ : l.Crop(wMod,0,-wMod,0)    
    return l
}

function gpSplice(clip c, clip l, float "PARc", float "PARl", float "MaxARError" \
 , float "MaxSpeedMod", bool "silence", bool "keepAudioC", bool "keepAudioL" \
 , string "customFuncC", string "customFuncL", string "Resampler", int "BGcolour" \
 , string "Resizer", int "destW", int "destH", string "Position", int "sRate", int "aChannels"\
 , clip "ReplacementAudioTrack", string "mod")
 
 {
    PARc = Default(PARc, 1.0)
    PARl = Default(PARl, 1.0)
    MaxARError = Default(MaxARError, 0)
    MaxSpeedMod = Default(MaxSpeedMod, 5.0)
    silent = (c.AudioChannels == 0) ? True : False
    silence = Default(silence, silent)
    keepAudioC = Default(keepAudioC, (!silence))
    keepAudioL = Default(keepAudioL, (!silence))
    dftRate = c.hasAudio ? c.AudioRate \
                : l.hasAudio ? l.audioRate : 48000
    sRate = Default(sRate, dftRate)
    dftChans = c.hasAudio ? c.AudioChannels \
                : l.hasAudio ? l.AudioChannels :  2
    aChannels = Default(aChannels, dftChans)
    Resizer = Default(Resizer, "Spline36Resize")
    Resampler = Default (Resampler, "ResampleAudio")
    customFuncC = Default(customFuncC, "none")
    customFuncL = Default(customFuncL, "none")
    Position = Default(Position, "before")
    BGcolour = Default(BGcolour, 000000)
    destW = Default(destW, c.width)
    destH = Default(destH, c.Height)
    ReplacementAudioTrack = Default(ReplacementAudioTrack, BlankClip.killAudio)
    #Mod =  [  Crop | Pad (AddBorders) ]
    mod = Default(mod, "pad")
    cAR = float(c.width)/c.height * PARc
    lAR = float(l.width)/l.height * PARl
    #parC=
    #parL=
   
       
    #Eval User defined func   
    l = (customFuncL == "none") ? l : Eval ("l."+customFuncL)
    c = (customFuncC == "none") ? c : Eval ("c."+customFuncC)
    
    # If replacement audio track exists, kill All Audio
    # If l does not have audio but want to keep audio of c, dub silent audio to l
    # If l has audio && want to keep c audio but not l audio, replace l audio with silent audio
    # All other cases, keep original l audio (or original lack of audio)     
    l = (!(l.hasAudio) && (KeepAudioC || KeepAudioL)) \
     || ((l.hasAudio) && KeepAudioC && !KeepAudioL) ? \
     AudioDub(l.KillAudio,BlankClip(l, audio_rate=sRate, channels=aChannels)) \
     : (ReplacementAudioTrack.hasAudio) || (!KeepAudioC && !KeepAudioL) ? l.killAudio\ 
     : l
     
    # If replacement audio track exists, kill audio 
    # If c does not have audio but want to keep audio of l, dub silent audio to c
    # If c has audio && want to keep l audio but not c audio, replace c audio with silent audio
    # All other cases, keep original c audio (or lack of audio) 
    c = ((!(c.hasAudio) && (KeepAudioC || KeepAudioL)) \
     || ((c.hasAudio) && KeepAudioL && !KeepAudioC )) ? \
     AudioDub(c.KillAudio,BlankClip(c, audio_rate=sRate, channels=aChannels)) \
     : (ReplacementAudioTrack.hasAudio) || (!KeepAudioC && !KeepAudioL) ? c.killAudio\ 
     : c
   
    #Match Audio Channels
    ##############################################
    #Expand this.

    l = (c.AudioChannels == l.audioChannels) ? l: \
        (c.hasAudio) && (l.AudioChannels==2) ? \
         AudioDub(l.killAudio,AudioMakerST(c.AudioChannels, l)) \
        : !(c.hasAudio) ? l.killAudio \
        : Assert("Need Stereo Audio to use AudioMaker, Hope to fix soon")
    ##############################################
    
    # Match Framerate
    #If framerate difference greater than acceptable; change fps (decimate duplicate), 
#else speedup / slowdown to match film.
    l =  (c.FramerateNumerator == l.FramerateNumerator) && (c.FramerateDenominator == l.FramerateDenominator) ? l \
                :  (l.Framerate > c.Framerate*(plus(maxSpeedMod)) \
               || (l.Framerate < c.Framerate*(minus(maxSpeedMod))) ? \
               l.ChangeFPS(c.FramerateNumerator , c.FramerateDenominator, true) \
               : l.AssumeFPS(c.FramerateNumerator , c.FramerateDenominator, true))
    
    # Is AR discrepancy acceptable?
    mod =    (cAR < lAR*minus(maxARError)) \
            || (cAR > lAR*plus(maxARError)) ? \
            mod :  "none"
            
    #Crop or Pad to match Source AR        
    l = (mod == "none") ? l \
        : (mod == "pad") ? l.borderBattle(c, lAR,cAr, PARl, BGcolour) \
        : (mod=="crop") ? l.cropBattle(c, lAR, cAR, PARl) \
        : l
        
    #Match Frame Dimensions                    
    l  = Eval ("l."+Resizer+"(destW,destH)")
    c  = Eval ("c."+Resizer+"(destW,destH)")
    
    #Match Colourspace 
    l = ( (c.IsYV12) ? ConvertToYV12(l) :
                 \ (c.IsRGB32)   ? ConvertToRGB32(l) :
                 \ (c.IsRGB24) ? ConvertToRGB24(l) :
                 \ (c.IsYUY2)  ? ConvertToYUY2(l) :
                 \ (c.IsYUV)   ? ConvertToYUV(l) :
                 \ (c.IsRGB)   ? ConvertToRGB(l) : l)  
                 
    #Match Sample Rate
    c = !(c.hasAudio) ? c : Eval ("c."+Resampler+"(sRate)")
    l = (!(c.hasAudio) || (c.Audiorate == l.Audiorate)) ? l : Eval ("l."+Resampler+"(sRate)")
    
    #Match AudioBits
    l = (!(c.hasAudio) || (c.Audiobits == l.Audiobits)) ? l:
                 \ (c.Audiobits == 16) ? l.ConvertAudioTo16bit :
                 \ (c.Audiobits == 24) ?l.ConvertAudioTo24bit :
                 \ (c.Audiobits == 32) ?l.ConvertAudioTo32bit :
                 \ (c.Audiobits == 8)  ?l.ConvertAudioTo8bit : l 
          
    ######
    ##Splice
    ######                     
    c = (Position == "before") ? l++c \
        : (Position == "after") ? c++l \
        : (Position == "middle") ? c.Trim(0,c.framecount/2)++l++c.Trim(c.framecount/2+1, c.framecount) \
        : l++c

     c = (ReplacementAudioTrack.hasAudio) ? Eval ("AudioDubEx(c,ReplacementAudioTrack)."+Resampler+"(sRate)") : c
     return c
 }