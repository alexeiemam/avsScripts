Import("E:\_Video\Source\Features\3004_FI\3004_FilmIdol_Source_pal_wide_2ch.avs")

#################################
### SET GLOBALS FRAME VARS BEFORE IMPORT ##
#Final Width
global destWidth = 720
#Final height
global destHeight = 576
# Final Pixel Shape
global destPAR = 768.0/720
#################################
#################################

Import("C:\Video Encoding\AviSynth 2.5\plugins\_AE_PanScan.avs")

#Available Functions: #
# CenterFocus, LeftFocus, RightFocus [ Static: Focus ]
# Resize&Border [Static: Black BG scenes]
# inOutSquish [Animate: Disproportionate squeeze stretch]
# PanIt [Animate: Move Frame, use crop values]
# variable "toBeCropped" is the magic float. 
Tweak( 
## Example Usage ###
P1 = Main.Trim(0,136).ResizeAndBorder(left=61, right=61)    #Static, Animate Left to Right / Black
P2 = Main.Trim(137,242).CenterFocus
P3 = Main.Trim(243,596).ResizeAndBorder(left=78, right=70) # Resize, AddBorders
P4 = Main.Trim(597,3938).CenterFocus
P5 = Main.Trim(3939,4054).ResizeAndBorder(left=90, right=65) # Resize, AddBorders
P6 = Main.Trim(4055,5514).CenterFocus
P7 = Main.Trim(5515,5738).ResizeAndBorder(left=86, right=65) # Resize AddBorders
P8 = Main.Trim(5739,7139).CenterFocus #Focus Centre
P9 = Main.Trim(7140,7961).ResizeAndBorder(left=68, right=68) # Resize AddBorder
P10 = Main.Trim(7962,8695).CenterFocus #Focus Centre
P11= Main.Trim(8696,8801).panIt(move="l2r") # Animate Left Right
P12= Main.Trim(8802,9065).CenterFocus #Focus Centre
P13= Main.Trim(9066,9108).RightFocus # FocusRight
P14= Main.Trim(9109,9125).panIt(move="r2l") # Animate FocusRight to FocusLeft
P15= Main.Trim(9126,9183).leftFocus #FocusLeft
P16= Main.Trim(9184,9208).panIt(move="l2c") # Animate FocusLeft to FocusCentre
P17= Main.Trim(9209,12174).CenterFocus # FocusCentre
P18= Main.Trim(12175,12393).leftFocus(left=35)# FocusLeft-ish
P19= Main.Trim(12394,13256).CenterFocus # FocusCentre
P20= Main.Trim(13257,13370).CenterFocus# Resize, AddBorder
P21 = Main.Trim(13371,13702).inOutSquish(startOutSq=284, endOutSq=330)#<--- !!MOD!! ---> !!!
P215 = Main.Trim(13703,14337).CenterFocus
P22= Main.Trim(14338,14456).leftFocus(left=35)
P23= Main.Trim(14457,14511).panIt(sl=35, sr=Round(toBeCropped-35), el=Round(toBeCropped/2), er=Round(toBeCropped/2)) #Animate FocusLeft -> FocusCentre 
P24= Main.Trim(14512,15374).CenterFocus # FocusCentre
P25= Main.Trim(15375,15493).leftFocus(left=35)# FocusLeft
P26= Main.Trim(15494,16042).CenterFocus # FocusCentre
P27= Main.Trim(16043,16186).leftFocus(left=35)# Animate Focus Left to FocusCentre (PartialAnimate)
P28= Main.Trim(16187,18831).CenterFocus # CenterFocus
P29= Main.Trim(18832,19121).panIt(start=280, end=290, move="custom", sl=35, sr=Round(toBeCropped-35), el=Round(toBeCropped/2), er=Round(toBeCropped/2)) # Animate LeftFocus CenterFocus !!!
P30= Main.Trim(19122,23173).CenterFocus #CenterFocus
P31= Main.Trim(23174,23487).CenterFocus#(right=88, left=88) #<--- !!MOD!! ---> !!!
P32= Main.Trim(23488,24237).CenterFocus #CenterFocus
P33= Main.Trim(24238,24309).leftFocus(left=35)# LeftFocus
P34= Main.Trim(24310,24925).CenterFocus#CenterFocus  
P35= Main.Trim(24926,25005).panIt(start=64, sl=35, sr=Round(toBeCropped-35), el=Round(toBeCropped/2), er=Round(toBeCropped/2))# Animate LeftFocus ->CenterFocus Partial !!!
P36= Main.Trim(25006,25468).CenterFocus#centerFocus
P37= Main.Trim(25469,25616).ResizeAndBorder(left=58, right=56)#Resize+Border
P38= Main.Trim(25617,27906).CenterFocus#centerFocus
P39= Main.Trim(27907,28281).ResizeAndBorder(left=68, right=68)#resizeAddborder
P40= Main.Trim(28282,32987).CenterFocus#CenterFocus
P41= Main.Trim(32988,33129).panIt(move="l2r", start=40)
P42= Main.Trim(33130,33338).RightFocus#CenterFocus
P422 = Main.Trim(33339,33483).LeftFocus(left=35)
P425 = Main.Trim(33484,33498).LeftFocus(left=35)#panIt(move="c2l")
P43= Main.Trim(33499,33567).panIt(sl=35, sr=Round(toBeCropped-35), el=Round(toBeCropped-60), er=60)
P44= Main.Trim(33568,33873).CenterFocus#CenterFocus
P45= Main.Trim(33874,33982).CenterFocus#panIt(move="c2r", start=100)
P46= Main.Trim(33983,33996).CenterFocus#.panIt(move="r2c")
P47= Main.Trim(33997,35496).CenterFocus#CenterFocus
P48= Main.Trim(35497,35578).leftFocus(left=35)
P49= Main.Trim(35579, 39643).CenterFocus#CenterFocus
P50= Main.Trim(39644,39774).panIt(move="l2c", start=35)
P51= Main.Trim(39775,41899).CenterFocus#CenterFocus
P52= Main.Trim(41900,42824).CenterFocus(left=76, right=68)#Squish to Subs
P53= Main.Trim(42825,42945).leftFocus(left=35)#LeftFocus
P54= Main.Trim(42946,43963).CenterFocus#CenterFocus
P55= Main.Trim(43964,46433).CenterFocus(left=58, right=60)#Squish
P56= Main.Trim(46434,46606).CenterFocus# CenterFocus
P57= Main.Trim(46607,46711).leftFocus(left=35)#LeftFocus
P58= Main.Trim(46712,48177).CenterFocus#CenterFocus
P59= Main.Trim(48178,49711).CenterFocus(left=64, right=64)#Squish
P60= Main.Trim(49712,54901).CenterFocus#CenterFocus
P61= Main.Trim(54902,55186).leftFocus(left=35)#LeftFocus
P62= Main.Trim(55187,55832).CenterFocus(left=80, right=80)#Squish
P63= Main.Trim(55833,58568).CenterFocus#CenterFocus
P64= Main.Trim(58569,58962).leftFocus(left=35)#LeftFocus to subs ish
P65= Main.Trim(58963,62374).CenterFocus#centerfocus
P66= Main.Trim(62375,62544).leftFocus(left=35)#panIt(move="l2c")
P67= Main.Trim(62545,64077).CenterFocus#CenterFocus
P68= Main.Trim(64078,64911).CenterFocus(left=56, right=56)#Animate Squish in Squish out / Pan Subs !!!
P69= Main.Trim(64912,68833).CenterFocus#CenterFocus
P70= Main.Trim(68834,69268).CenterFocus(left=68, right=68) # / Pan OverSubs
#############ALTERNATIVELY SQUISH >
P71= Main.Trim(69269,69614).CenterFocus # CenterFocus
P72= Main.Trim(69615,70341).CenterFocus(left=66, right=66)
P73= Main.Trim(70342,70826).CenterFocus(left=66, right=66)
P74= Main.Trim(70827, 70903).CenterFocus(left=66, right=66)
P75= Main.Trim(70904,71383).CenterFocus(left=66, right=66)# Squish
#############ALTERNATIVELY SQUISH />
P76= Main.Trim(71384, 79293).CenterFocus # CenterFocus
P77= Main.Trim(79294,79354).leftFocus(left=35)#LeftFocus
P78= Main.Trim(79355,90175).CenterFocus#centerFocus
P79= Main.Trim(90176,90389).leftFocus(left=35)#LeftFocus
P80= Main.Trim(90390,92720).CenterFocus#centerFocus
P81= Main.Trim(92721,93062).leftFocus(left=35)#LeftFocus
P82= Main.Trim(93063, 102880).CenterFocus#CenterFocus
P83= Main.Trim(102881,103067).panIt(move="l2r")#Animate LeftFocus -> RightFocus !!!
P84= Main.Trim(103068,104974).RightFocus# RightFocus
P85= Main.Trim(104975,119403).CenterFocus#CenterFocus
P86= Main.Trim(119404,121915).leftFocus(left=35)
P87= Main.Trim(121916,121971).CenterFocus#centerfocus
P873 = Trim(121972, 122223).LeftFocus(left=65)
P876 = Trim(122224, 126287).CenterFocus
P88= Main.Trim(126288,126456).ResizeAndBorder(left=88, right=87)#RezieAddborder
P89= Main.Trim(126457,127770).CenterFocus#CenterFocus
P90= Main.Trim(127771,131434).CenterFocus(left=60, right=20)#Squish


P1+P2+P3+P4+P5+P6+P7+P8+P9+P10+P11+P12+P13+P14+P15+P16+P17+P18+P19\
+P20+P21+P215+P22+P23+P24+P25+P26+P27+P28+P29+P30+P31+P32+P33+P34\
+P35+P36+P37+P38+P39+P40+P41+P42+P422+P425+P43+P44+P45+P46+P47+P48+P49\
+P50+P51+P52+P53+P54+P55+P56+P57+P58+P59+P60+P61+P62+P63+P64+P65+P66\
+P67+P68+P69+P70+P71+P72+P73+P74+P75+P76+P77+P78+P79+P80+P81+P82+P83\
+P84+P85+P86+P87+P873+P876+P88+P89+P90

Logoise(pixelshape=destPar)
