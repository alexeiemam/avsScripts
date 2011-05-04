v = DGDecode_mpeg2source("E:\_Video\Source\Shorts\358_DigitalShorts\358_TheRiver.d2v",info=3).ColorMatrix(hints=true)
a = NicAC3Source("E:\_Video\Source\Shorts\358_DigitalShorts\358_TheRiver T01 2_0ch 192Kbps DELAY 0ms.ac3")

###Audio Correction###
##Audio Skew
#a = a.DelayAudio(-0.4) 
##Duplicate Channels
#ch = GetChannel(a, 1)
#a = MergeChannels(ch,ch)
###

###Dub###
Main = AudioDub(v,a)
###

###Deinterlace / IVTC###
##Yadif #tfm.tdecimate
#Load_Stdcall_Plugin("C:\Video Encoding\megui\tools\yadif\yadif.dll")
#Main = Main.Yadif
###

###Crop###
##CropConstants
Left = 0
Top = 0
Right = 0
Bottom = 0
pixelShape = float(1024)/720
Main = Main.checkedCrop(left = Left, top = Top, right = Right, bottom = Bottom)
###

###Subs
##Warning: Sub After Crop unless subs within crop area
##Sub Before any timebased video manipulation
##Correct Sub shape and position in .idx file
#Main = Main.VobSub("abc")
###

###Trim
##TrimConstants
#FromHere = 0
#ToHere = Main.framecount
#Main = Main.Trim(FromHere, ToHere)
###

###Calculate AR###
TrueAR = Main.arCalc(pixelShape=pixelShape)
###ARoverride, 
#TrueAR = (16.0/9)
###

###CreateFinalOutput(e.g Trim & Splice Main)###
Main
###

###Resize To Output Specification###
#toBlinkbox(TrueAR)
###

###Splice Logo###
#Logoise
###

###Check Frame Aspect (Usefl For anamorphic output)
#Subtitle(String(FinalFrameAspect))
###