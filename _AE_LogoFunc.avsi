function AudioMaker(int channels, clip stereo, clip sixchannel) {
    Assert(channels > 0,  "AudioMaker: cannot produce audio with less than 1 channel")
    return channels > 6 \
        ? MergeChannels(sixchannel, AudioMaker(channels - 6, stereo, sixchannel)) \
    : (channels == 6 \
        ? sixchannel \
    : (channels > 2 \
        ? MergeChannels(stereo, AudioMaker(channels - 2, stereo, sixchannel)) \
    : (channels == 2 \
        ? stereo \
    : \
        stereo.ConvertToMono() \
    )))
}

function Logoise (clip c, float "PixelShape",  string "Position", float "ARbuffer", string "Ver", string "customFunc", bool "unSilence", float "logoPxShape", int "sRate", int "aChannels")
{   
    ######
    ##Config
    ######
    
    # Source Logo Intro Animation Audio & Video Location
    LogoV = AviSource("C:\Video Encoding\_SRC\Logo\Raindance TV Logo.avi").ConvertToRGB32
    AudioStereo = WavSource("C:\Video Encoding\_SRC\Logo\RDTV-Logo-Feature-Stereo.wav")
    Audio51 = WavSource ("C:\Video Encoding\_SRC\Logo\RDTV-Logo-Feature-51.wav")
    
    #Logo Aspect Ratio (Source DVPAL, pixelshape = 59/54, here 57/54?)
    DVPALpixel = 59.0/54.0
    logoPxShape = Default (logoPxShape, DVPALpixel)
    
    # If unspecified set destination frame as fPar
    PixelShape = Default(PixelShape, fPar)
    
    # Where should the intrologo animation be? [before | after | middle]
    # ToDo: Add Ability to add to specify frame / time location, specify whether to repeat periodically 
    Position = Default(Position, "before")
    
    # Determine whether short film or feature based on length or manually [auto | short | long]
    Ver = Default(Ver,"auto")
    
    # Add Custom Func (Unimplemented)
    customFunc = Default(customFunc, "none")
    
    # Add Audio track (Only if source lacking audio track)
    # Todo: Add "AudioOverride" var to replace source audio with silent track? 
    unSilence = Default(unSilence, false)
    unSilence = (c.AudioChannels > 0) ? false : (unSilence) ? true :  false
    sRate = Default(sRate, 48000)
    aChannels = Default(aChannels, 2)
    
    ######
    ##Operate
    ######
    
    #Add Add Audio Based on unsilence true, use BlankClip and params from Logo Audio, rate, etc 
    c = (Unsilence) ? AudioDub(c,BlankClip(c, audio_rate=sRate, channels=aChannels)) : c
   
    # True Source Aspect Ratio, taking into account pixel shape
    # e.g Anamorphic Wide: (720/576)*(1024/720)
    # e.g Square Pixels: (720/404)*(1/1)
    SourceAR = (float(c.width)/c.height)*(PixelShape)

    LogoAR = float(LogoV.width)*DVPALpixel/LogoV.height
    #Acceptable Logo Aspect Ratio error Percentage 
    ARerror = Default(ARbuffer, 1)
    #Acceptable Logo Speedup/Slowdown Percentage
    SpeedMod = 5.0
       
    MaxShortFilmMinutes = 45
    # Frame duration before which film is classified as "Short"
    MaxShortFilmFrames = (Ver == "auto") ? Round(MaxShortFilmMinutes*60*c.framerate) : (Ver == "long") ? 1 : (Ver == "short")  ? 9999999999999 : Round(MaxShortFilmMinutes*60*c.framerate)

    # Trim Intro Logo frame constants for short Film
    TrimStart=124
    TrimEnd=201

    # Match Audio Channels and Dub
    Logo = (c.AudioChannels > 0) ? AudioDub(LogoV,AudioMaker(c.AudioChannels, AudioStereo,Audio51)) : LogoV.killAudio
    # Determine Intro Type (Short/Long) & Trim accordingly
    Logo = (c.Framecount<MaxShortFilmFrames) ? Logo.Trim(TrimStart,TrimEnd) : Logo
    Logo = (customFunc == "none") ? Logo : Eval (  "Logo."+customFunc )
    # Match Framerate
    #If framerate difference greater than acceptable; change fps (decimate duplicate), otherwise, speedup / slowdown logo to match film.
    Logo = ( (c.FramerateNumerator == Logo.FramerateNumerator) && (c.FramerateDenominator == Logo.FramerateDenominator) ? Logo :
               \      (Logo.Framerate > float(c.Framerate*(1+(SpeedMod/100)))) || (Logo.Framerate < float(c.Framerate*(1-(SpeedMod/100)))) ? Logo.ChangeFPS(c.FramerateNumerator , c.FramerateDenominator, true) : Logo.AssumeFPS(c.FramerateNumerator , c.FramerateDenominator, true))
    #Match True Aspect Ratio   
    LogoModifier = Abs(Round(((Logo.Height*SourceAR)-(Logo.Height*LogoAR))/(2*LogoPxShape)))
    Logo =  (  (SourceAR < float((1-(ARerror/100))*LogoAR)) ? Logo.Crop(LogoModifier,0,-LogoModifier,0) : 
                 \ (SourceAR > float((1+(ARerror/100))*LogoAR)) ? Logo.AddBorders(LogoModifier,0,LogoModifier,0) : Logo)
    #Match Frame Dimensions                    
    Logo = Logo.Spline36Resize(c.width, c.height)
    #Match Colourspace 
    Logo = ( (c.IsYV12) ? ConvertToYV12(Logo) :
                 \ (c.IsRGB32)   ? Logo :
                 \ (c.IsRGB24) ? ConvertToRGB24(Logo) :
                 \ (c.IsYUY2)  ? ConvertToYUY2(Logo) :
                 \ (c.IsYUV)   ? ConvertToYUV(Logo) :
                 \ (c.IsRGB)   ? ConvertToRGB(Logo) : Logo)  
    #Match Sample Rate
    Logo = ((c.Audiorate == Logo.Audiorate) || (c.AudioChannels < 1)) ? Logo : Logo.ResampleAudio(c.Audiorate)
    #Match AudioBits
    Logo = ((c.AudioChannels < 1) || (c.Audiobits == Logo.Audiobits)) ? Logo :
                 \ (c.Audiobits == 16) ? Logo.ConvertAudioTo16bit :
                 \ (c.Audiobits == 24) ?Logo.ConvertAudioTo24bit :
                 \ (c.Audiobits == 32) ?Logo.ConvertAudioTo32bit :
                 \ (c.Audiobits == 8)  ?Logo.ConvertAudioTo8bit : Logo 
          
    ######
    ##Splice
    ######
                        
    c = (Position == "justLogo") ? Logo : (Position == "before") ? Logo++c : (Position == "after") ? c++Logo : (Position == "middle") ? c.Trim(0,c.framecount/2)++Logo++c.Trim(c.framecount/2, c.framecount) : Logo++c
    return c
}  

function Dimensionise (clip c, float "PixelShape",  string "Position", float "ARbuffer", string "Ver", string "customFunc", bool "unSilence", float "logoPxShape", int "sRate", int "aChannels")
{   
    ######
    ##Config
    ######
    
    # Source Logo Intro Animation Audio & Video Location
    LogoV = AviSource("C:\Video Encoding\_SRC\Logo\Raindance TV Logo.avi").ConvertToRGB32
    AudioStereo = WavSource("C:\Video Encoding\_SRC\Logo\RDTV-Logo-Feature-Stereo.wav")
    Audio51 = DirectShowSource ("C:\Video Encoding\_SRC\Logo\RDTV-Logo-Feature-51.wav")
    
    #Logo Aspect Ratio (Source DVPAL, pixelshape = 59/54, here 57/54?)
    DVPALpixel = 59.0/54.0
    logoPxShape = Default (logoPxShape, DVPALpixel)
    
    # If unspecified set destination frame as fPar
    PixelShape = Default(PixelShape, fPar)
    
    # Where should the intrologo animation be? [before | after | middle]
    # ToDo: Add Ability to add to specify frame / time location, specify whether to repeat periodically 
    Position = Default(Position, "before")
    
    # Determine whether short film or feature based on length or manually [auto | short | long]
    Ver = Default(Ver,"auto")
    
    # Add Custom Func (Unimplemented)
    customFunc = Default(customFunc, "none")
    
    # Add Audio track (Only if source lacking audio track)
    # Todo: Add "AudioOverride" var to replace source audio with silent track? 
    unSilence = Default(unSilence, false)
    unSilence = (c.AudioChannels > 0) ? false : (unSilence) ? true :  false
    sRate = Default(sRate, 48000)
    aChannels = Default(aChannels, 2)
    
    ######
    ##Operate
    ######
    
    #Add Add Audio Based on unsilence true, use BlankClip and params from Logo Audio, rate, etc 
    c = (Unsilence) ? AudioDub(c,BlankClip(c, audio_rate=sRate, channels=aChannels)) : c
   
    # True Source Aspect Ratio, taking into account pixel shape
    # e.g Anamorphic Wide: (720/576)*(1024/720)
    # e.g Square Pixels: (720/404)*(1/1)
    SourceAR = (float(c.width)/c.height)*(PixelShape)

    LogoAR = float(LogoV.width)*DVPALpixel/LogoV.height
    #Acceptable Logo Aspect Ratio error Percentage 
    ARerror = Default(ARbuffer, 1)
    #Acceptable Logo Speedup/Slowdown Percentage
    SpeedMod = 5.0
       
    MaxShortFilmMinutes = 45
    # Frame duration before which film is classified as "Short"
    MaxShortFilmFrames = (Ver == "auto") ? Round(MaxShortFilmMinutes*60*c.framerate) : (Ver == "long") ? 1 : (Ver == "short")  ? 9999999999999 : Round(MaxShortFilmMinutes*60*c.framerate)

    # Trim Intro Logo frame constants for short Film
    TrimStart=124
    TrimEnd=201

    # Match Audio Channels and Dub
    Logo = (c.AudioChannels > 0) ? AudioDub(LogoV,AudioMaker(c.AudioChannels, AudioStereo,Audio51)) : LogoV.killAudio
    # Determine Intro Type (Short/Long) & Trim accordingly
    Logo = (c.Framecount<MaxShortFilmFrames) ? Logo.Trim(TrimStart,TrimEnd) : Logo
    Logo = (customFunc == "none") ? Logo : Eval (  "Logo."+customFunc )
    # Match Framerate
    #If framerate difference greater than acceptable; change fps (decimate duplicate), otherwise, speedup / slowdown logo to match film.
    Logo = ( (c.FramerateNumerator == Logo.FramerateNumerator) && (c.FramerateDenominator == Logo.FramerateDenominator) ? Logo :
               \      (Logo.Framerate > float(c.Framerate*(1+(SpeedMod/100)))) || (Logo.Framerate < float(c.Framerate*(1-(SpeedMod/100)))) ? Logo.ChangeFPS(c.FramerateNumerator , c.FramerateDenominator, true) : Logo.AssumeFPS(c.FramerateNumerator , c.FramerateDenominator, true))
    #Match True Aspect Ratio   
    LogoModifier = Abs(Round(((Logo.Height*SourceAR)-(Logo.Height*LogoAR))/(2*LogoPxShape)))
    Logo =  (  (SourceAR < float((1-(ARerror/100))*LogoAR)) ? Logo.Crop(LogoModifier,0,-LogoModifier,0) : 
                 \ (SourceAR > float((1+(ARerror/100))*LogoAR)) ? Logo.AddBorders(LogoModifier,0,LogoModifier,0) : Logo)
    #Match Frame Dimensions                    
    Logo = Logo.Spline36Resize(c.width, c.height)
    #Match Colourspace 
    Logo = ( (c.IsYV12) ? ConvertToYV12(Logo) :
                 \ (c.IsRGB32)   ? Logo :
                 \ (c.IsRGB24) ? ConvertToRGB24(Logo) :
                 \ (c.IsYUY2)  ? ConvertToYUY2(Logo) :
                 \ (c.IsYUV)   ? ConvertToYUV(Logo) :
                 \ (c.IsRGB)   ? ConvertToRGB(Logo) : Logo)  
    #Match Sample Rate
    Logo = ((c.Audiorate == Logo.Audiorate) || (c.AudioChannels < 1)) ? Logo : Logo.ResampleAudio(c.Audiorate)
    #Match AudioBits
    Logo = ((c.AudioChannels < 1) || (c.Audiobits == Logo.Audiobits)) ? Logo :
                 \ (c.Audiobits == 16) ? Logo.ConvertAudioTo16bit :
                 \ (c.Audiobits == 24) ?Logo.ConvertAudioTo24bit :
                 \ (c.Audiobits == 32) ?Logo.ConvertAudioTo32bit :
                 \ (c.Audiobits == 8)  ?Logo.ConvertAudioTo8bit : Logo 
          
    ######
    ##Splice
    ######
							
	c =  (Position == "before") ? Logo++c : (Position == "after") ? c++Logo : (Position == "middle") ? c.Trim(0,c.framecount/2)++Logo++c.Trim(c.framecount/2, c.framecount) : Logo++c
    return c
}  