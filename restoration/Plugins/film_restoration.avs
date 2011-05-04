# film restoration script by videoFred.
# denoising, resizing, stabilising, sharpening, auto-levels and auto-white balance.
# this script needs progressive input and no duplicate frames
#====================================================================================


film="E:\Test\restoration\EncodeSource\I_LOVE_YOU_PHILLIP_MORRIS_CLIP_1.mov" # you must specify the full path of your source file here



#GENERAL PARAMETERS
#----------------------------------------------------------------------------------------------------------------------------
result="result3" # specify the wanted output here 

trim_begin=90  trim_end=6   play_speed=18   #trim frames and play speed (PAL: 16.6666 or 18.75)

numerator= 18  #numerator for the interpolator (final frame rate)
denumerator= 1 #denumerator  example: 60000/1001= 59.94fps


#COLOR AND LEVELS PARAMATERS
#----------------------------------------------------------------------------------------------------------------------------
saturation=1.6   #for all outputs

gamma=0.8 # for all outputs 

blue= -0  red=0  #manual color adjustment, when returning result3. Values can be positive or negative

AGC_max_sat=1.2  AGC_max_gain=2.8  #improves shadows and colors, for all outputs

black_level=0  white_level=255 output_black=0  output_white=255 # manual levels, when returning result4
 

#SIZE, CROP AND BORDERS PARAMETERS
#----------------------------------------------------------------------------------------------------------------------------
CLeft=20  CTop=20  CRight=20  CBottom=20  #crop values after Depan and before final resizing 

W=768  H=576 #final size after cropping 

bord_left=0  bord_top=0  bord_right=0  bord_bot=0  #720p= borders 150


#STABILISING PARAMETERS
#----------------------------------------------------------------------------------------------------------------------------
maxstabH=20 
maxstabV=20 #maximum values for the stabiliser (in pixels) 20 is a good start value

est_left=20   est_top=20  est_right=20  est_bottom=20  est_cont=1.0  #crop and contast values for special Estimate clip


#DENOISING PARAMETERS
#----------------------------------------------------------------------------------------------------------------------------
PRE_sharp_ness= 80   PRE_radi_us= 3  #presharpening (UnsharpMask) before any denoising

denoising_strenght=800  #denoising level of first denoiser: MVDegrainMulti() 
denoising_frames= 3  #number of frames for averaging (forwards and backwards) 3 is a good start value
block_size= 16  #block size of MVDegrainMulti()
block_over= 8  #block overlapping of MVDegrainMulti()

second_denoising_strenght= 300 #denoising level of second denoiser: MDegrain1()

over_lay= 0.4 # mix back from the original grain over the denoised picture, only when returning result6


#TWO STEP SHARPENING PARAMETERS
#--------------------------------------------------------------------------------------------------------------------------------
LSF_sharp_ness=200 LSF_radi_us=2  LSF_sub=1.5 #first sharpening parameters (LimitedSharpenFaster) sub=subsampling

USM_sharp_ness2= 30    USM_radi_us2=1  USM_thres_hold2=0  #second sharpening parameters (UnsharpMask)


#AUTO LEVELS PARAMETER
#--------------------------------------------------------------------------------------------------------------------------------
X=4   # X is a special parameter for reducing the autolevels effect on the whites
X2=4  # X2 is a special parameter for reducing the autolevels effest on the blacks 


#DIGITAL GRAIN PARAMETERS
#--------------------------------------------------------------------------------------------------------------------------------
grain_luma=0  grain_chroma=0 # this will add some digital grain to the final result, set it to zero if you do not want it.




# END VARIABLES, BEGIN SCRIPT
#=================================================================================================================================


SetMemoryMax(800)  #set this to 1/3 of the available memory

## the needed plugins:
#-----------------------
Loadplugin("Depan.dll")
LoadPlugin("Deflicker.dll")
LoadPlugin("DepanEstimate.dll")
LoadPlugin("AGC.dll")
LoadPlugin("MVTools.dll")
LoadPlugin("MVTools2.dll")
LoadPlugin("autolevels.dll")
LoadPlugin("AddGrainC.dll")

## needed to use limitedsharpenfaster():
#---------------------------------------
Import("LimitedSharpenFaster.avs")
LoadPlugIn("LimitedSupport_09Jan06B.dll")
Loadplugin("mt_masktools.dll")
Loadplugin("warpsharp.dll")
Loadplugin("removegrain.dll")






source1= FFsource(film).assumefps(play_speed).trim(trim_begin,0).converttoYV12()




#STABILIZING
#....................................................................................................................................................................
stab_reference= source1.crop(est_left,est_top,-est_right,-est_bottom).tweak(cont=est_cont).MT_binarize(threshold=80).greyscale().invert()

mdata=DePanEstimate(stab_reference,trust=1.0,dxmax=maxstabH,dymax=maxstabV)
stab=DePanStabilize(source1,data=mdata,cutoff=0.5,dxmax=maxstabH,dymax=maxstabV,method=1,mirror=15)
stab2= stab.crop(CLeft,CTop,-CRight,-CBottom).deflicker(border=20)
stab3=DePanStabilize(source1,data=mdata,cutoff=0.5,dxmax=maxstabH,dymax=maxstabV,method=1,info=true)

WS= width(stab)
HS= height(stab)
stab4= stab3.addborders(10,10,10,10,$B1B1B1).Lanczos4Resize(WS,HS)
stab5= Lanczos4Resize(stab2,W,H).sharpen(0.5)


#DENOISING
#...................................................................................................................................................................

pref= stab2.blur(1.0).blur(1.0).tweak(sat=2.5)
noise_baseclip= stab2.sharpen(0.6).unsharpmask(PRE_sharp_ness,PRE_radi_us,0).coloryuv(off_U=blue,off_V=red).tweak(sat=saturation)


vectors= pref.MVAnalyseMulti(refframes=denoising_frames, pel=2, blksize=block_size, overlap=block_over, idx=1)
denoised= noise_baseclip.MVDegrainMulti(vectors, thSAD=denoising_strenght, SadMode=1, idx=1)


#HDRAGC
#...................................................................................................................................................................


leveled= denoised.HDRAGC(coef_gain=2.0,max_gain=AGC_max_gain,min_gain=0.5,max_sat=AGC_max_sat,shadows=true)


#SHARPENING
#...................................................................................................................................................................
sharp1=limitedSharpenFaster(leveled,smode=1,strength=LSF_sharp_ness,overshoot=50,radius=LSF_radi_us, ss_X=LSF_sub, SS_Y=LSF_sub, dest_x=W,dest_y=H)



super= sharp1.MSuper(pel=2)
backward_vec= MAnalyse(super,blksize=block_size, overlap=block_over, isb=true)
forward_vec= MAnalyse(super,blksize=block_size, overlap=block_over, isb= false)


denoised2= sharp1.MDegrain1(super, backward_vec,forward_vec,thSAD= second_denoising_strenght)

interpolated= denoised2.MFlowFps(super, backward_vec, forward_vec, num=numerator, den= denumerator, ml=100)

sharp3= unsharpmask(interpolated,USM_sharp_ness2,USM_radi_us2,USM_thres_hold2).addgrainC(grain_luma,grain_chroma,0.2,0.2,5)





#RESULT1: AUTOLEVELS,AUTOWHITE
#......................................................................................................................................................................
result1= sharp3.coloryuv(autowhite=true).addborders(X,0,0,0,$FFFFFF).addborders(0,0,X2,0,$000000).levels(0,gamma,255,0,255).autolevels().crop(X,0,-X2,-0).addborders(bord_left, bord_top, bord_right, bord_bot)

#RESULT2: MANUAL LEVELS, AUTOWHITE
#......................................................................................................................................................................
result2= sharp3.levels(black_level,gamma,white_level,0,255).coloryuv(autowhite=true).addborders(bord_left, bord_top, bord_right, bord_bot)

#RESULT3: AUTOLEVELS, MANUAL COLOR CORRECTIONS
#.....................................................................................................................................................................
result3= sharp3.levels(0,gamma,255,0,255).addborders(X,0,0,0,$FFFFFF).addborders(0,0,X2,0,$000000).autolevels().crop(X,0,-X2,-0).addborders(bord_left, bord_top, bord_right, bord_bot)#.changefps(59.94)

#RESULT4: MANUAL LEVELS, MANUAL COLOR CORRECTIONS
#.....................................................................................................................................................................
result4= sharp3.coloryuv(off_U=blue,off_V=red).levels(black_level,gamma,white_level,0,255).addborders(bord_left, bord_top, bord_right, bord_bot)

#RESULT5: SPECIAL SERVICE CLIP FOR RESULT 7
#.....................................................................................................................................................................
result5= overlay(source1,stab_reference,x=est_left,y=est_top).addborders(2,2,2,2,$FFFFFF).Lanczos4Resize(WS,HS)

#RESULT6: OVERLAY: RESULT3 OVER THE (STABILIZED)ORIGINAL
#.......................................................................................................................................................
result6= overlay(result3,stab5,opacity=over_lay).addborders(X,0,0,0,$FFFFFF).addborders(0,0,X2,0,$000000).autolevels().crop(X,0,-X2,-0).addborders(bord_left, bord_top, bord_right, bord_bot)#.changefps(59.94)



#PARAMETERS FOR THE COMPARISONS
#.....................................................................................................................................................................
W2= W+bord_left+bord_right
H2= H+bord_top+bord_bot



#source2=Lanczos4Resize(source1,W2,H2)
#source3=Lanczos4Resize(source1,W,H)
final_framerate= numerator/denumerator
source4=Lanczos4Resize(source1,W2,H2).changeFPS(final_framerate)



#COMPARISONS: ORIGINAL VS RESULTS
#......................................................................................................................................................................
resultS1= stackhorizontal(subtitle(source4,"original",size=28,align=2),subtitle(result1,"autolevels, autowhite",size=28,align=2))
resultS2= stackhorizontal(subtitle(source4,"original",size=28,align=2),subtitle(result2,"autowhite, manual levels correction",size=28,align=2))
resultS3= stackhorizontal(subtitle(source4,"original",size=28,align=2),subtitle(result3,"processed: deflickered, degrained, sharpened etc..",size=28,align=2))
resultS4= stackhorizontal(subtitle(source4,"original",size=28,align=2),subtitle(result4,"manual colors and levels correction",size=28,align=2))
resultS6= stackhorizontal(subtitle(source4,"original",size=28,align=2),subtitle(result6,"overlay: result3 over original",size=28,align=2))




#SPECIAL COMPARISON CLIP FOR TESTING THE STABILIZER
#.........................................................................................................................................................................
result7= stackhorizontal(subtitle(result5,"baseclip for stabiliser -only the B/W clip is used",size=32,align=2),subtitle(stab4,"test stabiliser: dx=horizontal, dy=vertical",size=32,align=5))


Eval(result)

