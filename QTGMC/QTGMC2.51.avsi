#------------------------------------------------------------------#
#                                                                  #
#                     QTGMC 2.51, by Vit, 2010                     #
#                                                                  #
# Deinterlacer using motion-compensated temporal gaussian blurring #
#   Reworked version of TGMC with new features and speed tweaks    #
#             Credit to Didée for the original script              #
#                                                                  #
#------------------------------------------------------------------#

# Version History:
# v2.51: Changed default interpolator to "NNEDI3" for presets up to "Super Fast" and (new) lossless presets up to "Faster"
#        Range of preset tweaks including higher quality output from "Super Fast" & "Ultra Fast" but with a little speed loss
#        Support for EdiMode="EEDI3+NNEDI3": EEDI3 with sclip taken from NNEDI3
#        Added LosslessPreset and EdiThreads parameters
#        Tidied up output from ShowSettings and small bug fix
#        Fixed serious bug when using lossless modes on the higher speed presets
# v2.47: Fixed bug with default overlap when an explicit blocksize was given
# v2.46: Replaced mt_average with merge - was causing exceptions in certain MT situations
# v2.45: MERGED: Tweaked use of Yadif: explicit loading is now optional, see YadifPath variable
# v2.41: Removed explicit Yadif plugin load
# v2.40: Support for lossless output with added parameters: Lossless, LosslessTR, LosslessEdi
#        Support for EdiMode("NNEDI3", "EEDI3")
#        Paramters NNeurons added & NNSize reworked for new -EDI3 versions
#        Minor preset tweaks for better quality/speed spread
# v2.30: Added EdiExt (edeint in original TGMC)
#        Improved progressive input modes
# v2.20: All rep values, SVThin and motion search settings supported
#        Better matching of Sbb
#        "Draft" preset. Default preset changed from "Slow" to "Slower"
#        Support for progressive input (InputType)
#        Sharpness values/defaults normalized
# v2.10: Supported most of the remaining core TGMC features:
#            EdiMode("NNEDI", "Yadif"), tr2(3), SLmode(3,4), SLRad, Sbb(2,3)
#        Added noise bypass (removal / restoration)
#        Added ShowSettings
# v2.00: First fully featured version
#        Supported majority of core TGMC features
#        Additional speed tweaks:
#            NNSize, SrchClipPP, SubPel, Precise
#        Added Presets system and beginnings of Tunings
# v1.00: First draft - high speed basic TGMC algorithm only

# Requires: 
#	MVTools2 (2.58 or above)
#	MaskTools V2 (recommend 2.0a44 or above)
#	RemoveGrain + Repair
#	VerticalCleaner
#	Choice of: NNEDI3 (recommend 0.9.2 or above), NNEDI2, NNEDI, EEDI3, EEDI2, Yadif or TDeInt+Yadif
#	[Presets require NNEDI3 except "Ultra Fast", which requires TDeint and Yadif)
#	FFT3DFilter (+FFTW3) (if using noise bypass)
#	AddGrainC (if using "Generate" mode for noise bypass)
#	[NNEDI3, EEDI3, TDeInt, FFT3DFilter and AddGrainC beyond standard TGMCb2 requirements]


#---------------------------------------

# Parameters
# """"""""""
#-Core Settings---
#	tr0          (0,1,2)         : Temporal gaussian blur radius used to create motion search clip
#	tr1          (0,1,2)         : Temporal smoothing radius used on interpolated clip to create inital output
#	tr2          (0,1,2,3)       : Temporal smoothing radius used for final stablization / denoising
#	rep0         (>= 0)          : Repair motion search clip  (0 = off) : only keep thin areas of difference from bob
#	rep1         (>= 0)          : Repair initial output clip (0 = off) : only keep thin areas of difference from edi
#	rep2         (>= 0)          : Repair final output clip   (0 = off) : --"--
#	                             : The rep values contain both 'ed' and 'od' settings for the function RemoveNonBobDiff at end of script, go there for details
#
#-Interpolation---
#	EdiMode      (string)        : Interpolation method, from "NNEDI3", "NNEDI2", "NNEDI", "EEDI3+NNEDI3" (EEDI3 with sclip from NNEDI3), "EEDI3", "EEDI2", 
#	                                                          "Yadif" or "TDIYadif" (TDeInt+Yadif), anything else uses "Bob"
#	NNSize       (0-6)           : Area around each pixel used as predictor for NNEDI3. A larger area is slower with better quality, read the NNEDI3 docs to see
#	                             : the area choices. Note: area sizes are not in increasing order (i.e. increased value doesn't always mean increased quality)
#	NNeurons     (0-4)           : Controls number of neurons in NNEDI2 (0-2) & NNEDI3 (0-4), larger = slower and better quality but improvements are small 
#	EdiQual      (1,2,3)         : Quality setting for NNEDI2 & NNEDI3, higher values for higher quality - but improvements are marginal
#	EdiMaxD      (>= 1)          : Spatial search distance for finding connecting edges in EEDI2 and EEDI3
#	EdiThreads   (>= 0)          : Number of threads to use in EEDI3 & NNEDI2/3, 0 = default = number of logical processors on system
#	EdiExt       (clip)          : Provide externally created interpolated clip rather than use one of the above modes
#
#-Sharpness---
#	Sharpness    (float)         : Normal mode: how much to resharpen the temporal gaussian blurred clip ( >= 0.0, default always 1.0 unlike original TGMC)
#	                             : Lossless mode: sharpness of final output, 1.0 = normal, < 1.0 blurred, > 1.0 sharpened. Only 1.0 will give true lossless
#	SMode        (0,1,2)         : Resharpening mode: 0 = none, 1 = diff from 3x3 blur kernel, 2 = 3x3 kernel on vertical max/min average
#	SLMode       (0,1,2,3,4)     : Sharpness limiting: 0 = off, [1 = by spatial comparison, 2 = by temporal comparison] : done before 2nd temporal smooth
#	                             :                              [3 = by spatial comparison, 4 = by temporal comparison] : done after 2nd temporal smooth
#	SLRad        (>= 0)          : Temporal or spatial radius used with sharpness limiting (depends on SLMode). Temporal radius can only be 0,1 or 3
#	SOvs         (0..255)        : Amount of overshoot allowed with temporal sharpness limiting (SLMode == 2,4), i.e. allow some oversharpening
#	SVThin       (0.0...)        : How much to thin down 1-pixel wide lines that have been widened due to interpolation into neighboring field lines
#	Sbb          (0,1,2,3)       : Back blend (blurred) difference between pre & post sharpened clip (minor fidelity improvement) :
#	                             :   0 = Off, 1 = before sharpness limiting, 2 = after sharpness limiting, 3 = both
#
#-Lossless---
#	Lossless     (-1...3)        : Lossless output - the original source fields are retained as fields in the output (they are changed in normal TGMC algorithm)
#	                             : Modes: -1 = Disabled  0 = Fake lossless light temporal smooth  1 = Fake lossless strong temporal smooth (slower, more stable)
#	                             :                       2 = True lossless light temporal smooth  3 = True lossless strong temporal smooth (slower, more stable)
#	                             : Fake lossless uses algorithm to bring output closer to source but is not actually lossless. It doesn't suffer from combing
#	                             : like true lossless and can be very stable, but is sensitive to Lossless/TR settings (see below)
#	                             : Note the different usage for the Sharpness parameter in lossless mode (see above), leave it at default 1.0 for true lossless
#	LosslessTR   (1,2,3)         : Temporal radius for stablising lossless output. Increasing radius stabilizes more precisely, but is slower.
#	                             : True lossless: use radius 1 or 3 - difference is fairly small
#	                             : Fake lossless: radius 1 is poor, radius 2 is OK with Lossless=0, radius 3 is best choice with either Lossless mode, but slow
#	LosslessEdi    (string)      : Interpolation method for interpolating difference from source in lossless mode. Takes same values as EdiMode parameter above
#	                             : Better interpolation will give more stable result, though differences can be minor. Bob good for speed, NNEDI2/3 for quality
#	LosslessPreset (string)      : Set defaults for lossless interpolation stage. Further information about presets below
#
#-Noise Bypass---
#	NoiseBypass  (0,1,2)         : Noise bypass mode: 0 = disable, 1 = denoise source, storing the removed noise - add noise back at end of script, 
#	                             :                    2 = store noise found in source but don't remove it (let tgmc denoise) - add noise back at end of script
#	                             :                    Mode 1 softens if NoiseRemove is high & NoiseRestore is low, mode 2 sharpens if NoiseRestore is high
#	NoiseRemove  (0.0...1.0)     : How much noise/grain to extract from the source clip (before the TGMC process)
#	NoiseRestore (0.0...1.0...)  : How much of the removed noise/grain to restore (after the TGMC process), can be > 1.0 for strong effect
#	NoiseDeint   (string)        : When noise is taken from interlaced source, how to 'deinterlace' before restoring: "Bob", "DoubleWeave", "Copy" or "Generate"
#	                             :   "Bob" & "DoubleWeave" are standard, "Copy" doubles each noise line, "Generate" creates new noise lines by approximating
#	                             :   local variance. Any other value selects "DoubleWeave"
#	Sigma        (>= 0.0)        : Amount of noise known to be in the source - sensible values are 1.5 - 2.5 for DV. Must be high enough to find noticable noise
#	BT           (0...5)         : Block temporal size for noise removal (see FFT3DFilter docs)
#
#-Motion Search---
#	SrchClipPP   (0,1,2)         : Pre-processing for motion search clip, 0 = none, 1 = Gauss blur (spatial), 2 = Gauss + odd tweak from TGMC
#	SubPel       (1,2,4)         : Sub-pixel accuracy for motion analysis (1 = 1 pixel, 2 = 1/2 pixel, 4 = 1/4 pixel)
#	SubPelInterp (0,1,2)         : Interpolation used for sub-pixel motion analysis: 0 = bilinear (soft), 1 = bicubic (sharper), 2 = Weiner (sharpest)
#	Blocksize    (4,8,16,32)     : Size of blocks that are matched during motion analysis
#	Overlap      (< Blocksize/2) : How much to overlap motion analysis blocks (requires more blocks, but essential to smooth block edges in motion compenstion)
#	Search       (0...5)         : Search method used for matching motion blocks - see MVTools2 documentation for available algorithms
#	SearchParam  (0...)          : Parameter for search method chosen. For default search method (hexagon search) it is the search range
#	PelSearch    (0...)          : Search parameter (as above) for the finest sub-pixel level (see SubPel)
#	TrueMotion   (bool)          : Whether to use the 'truemotion' defaults from MAnalyse (see MVTools2 documentation)
#	Lambda       (0...)          : Motion vector field coherence - how much the motion analysis favors similar motion vectors for neighboring blocks
#	                             : Should be scaled by BlockSize*BlockSize/64
#	LSAD         (0...)          : How much to reduce need for vector coherence (i.e. Lambda above) if prediction of motion vector from neighbors is poor,
#	                             : typically in areas of complex motion. This value is scaled in MVTools (unlike Lambda)
#	PNew         (0...)          : Penalty for choosing a new motion vector for a block over an existing one - avoids chosing new vectors for minor gain
#	PLevel       (0,1,2)         : Mode for scaling lambda across different sub-pixel levels (??) - see MVTools2 documentation for choices
#	GlobalMotion (bool)          : Whether to estimate camera motion to assist in selecting block motion vectors
#	DCT          (0...10)        : Modes to use DCT (frequency analysis) as part of the block matching process - see MVTools2 documentation for choices
# 
#-Miscellaneous Features---
#	InputType    (0,1,2,3)       : Default = 0 for interlaced input. Values > 0 to accept progressive input - for stabilization and denoising (fps not changed)
#	                             : Mode 1 accepts plain progressive material. Modes 2 & 3 take deinterlaced material and recover / reweave half the fields
#	                             : to create interlaced material again. Mode 3 differs from mode 2 only in that it complements field parity of input
#	Border       (bool)          : Pad a little vertically while processing (doesn't affect output size) - use if there are artefacts on top and bottom edges
#	Precise      (bool)          : Set to false to use faster algorithms with *very* slight imprecision in places
#	Preset       (string)        : Sets a range of defaults for different encoding speeds. See below
#	Tuning       (string)        : Tweaks the defaults for different source types. See below
#	SafeMode     (bool)          : Avoid settings that potentially cause errors with other plugins
#	ShowSettings (bool)          : Display all the current parameter values - useful to find preset defaults


# Presets / Tunings
# """""""""""""""""
# The parameters "Preset",  and "Tuning" set groups of parameters at once:
#	Preset : Choose from "Placebo","Very Slow","Slower","Slow","Medium","Fast","Faster","Very Fast","Super Fast","Ultra Fast" & "Draft". Default = "Slower"
#	Tuning : Choose from "None", "DV-SD", "DV-HD". Default is "None". 
#	LosslessPreset: Only used in lossless mode. Takes same values as "Preset" but default is "Fast". Differences in quality are minor so prefer quicker settings
# See tables a short way into script below to see exact settings and to give an idea of how to tweak for speed / quality adjustments
# Manually entered parameters override presets/tunings
# Tunings are just an idea for development at the moment - need more variations for a range of source types
#
# Default settings for script are:
#	QTGMC( Preset="Slower", Tuning="None" )
# which is closely equivalent to TempGaussMC_beta2( 2,2,1, EdiMode="nnedi3", SVthin=0.0, Border=false )

# Presets "Super Fast"/"Ultra Fast" & EdiMode="TDIYadif"/"Yadif" require the Yadif plugin, which doesn't autoload. Typically the calling script would load it.
# To have this script load Yadif put it's full path in the string below (e.g. "C:\Plugins\Yadif.dll"). Leave string empty ("") if calling script will load Yadif
global YadifPath = "" # Just put "yadif.dll" if Yadif is placed in the system path (e.g. windows\system32)


# Summary of differences from TGMC
# """"""""""""""""""""""""""""""""
# New speed tweaks:
#	EdiMode("TDIYadif"), NNSize, NNeurons, SrchClipPP, SubPel, Precise 
# New features:
#	EdiMode("NNEDI3", "EEDI3", "EEDI3+NNEDI3")
#	Preset, Tuning, EdiThreads, NoiseBypass, NoiseRemove, NoiseRestore, NoiseDeint, Sigma, BT, InputType, LosslessTR, LosslessEdi, LosslessPreset, SafeMode,
# 	ShowSettings, Presets and Tuning described above
#	Noise removal/restore settings provide a method to keep grain that is lost due to the TGMC algorithm's implicit denoising
#	InputType setting allows input of progressive or previously deinterlaced content
# Unsupported:
#	pel2hr
# Variables in script, but not parameters
#	SCth1, SCth2, thSAD1, thSAD2
# Other notes:
#	Sharpness default is 1.0 regardless of settings - adjusted internally to give very roughly the same sharpness across settings / presets
#	SVThin defaults to 0, Border defaults to false
#	Lossless mode is similar but with different parameters and more consistent output
#	Lossless mode can be combined with noise bypass: noise is removed, the result matched losslessly, then the noise added back. This isn't actually lossless
#	but is quite useful as a better source match but without excess source noise. NoiseBypass=1 is the mode to use for this approach
#	Draft mode supported as a preset - same purpose but different output
#	Parameter order same up to "EdiMode", a couple of 'lesser' parameters have had name changes for consistency
#	Output will never be pixel-identical to TGMC equivalent due to bug-fixes


function QTGMC( clip Input, int "tr0", int "tr1", int "tr2", int "rep0", int "rep1", int "rep2", string "EdiMode", int "NNSize", int "NNeurons", \
                int "EdiQual", int "EdiMaxD", int "EdiThreads", clip "EdiExt", float "Sharpness", int "SMode", int "SLMode", int "SLRad", int "SOvs", \
                float "SVThin", int "Sbb", int "SrchClipPP", int "SubPel", int "SubPelInterp", int "BlockSize", int "Overlap", int "Search", \
                int "SearchParam", int "PelSearch", bool "TrueMotion", int "Lambda", int "LSAD", int "PNew", int "PLevel", bool "GlobalMotion", int "DCT", \
                int "Lossless", int "LosslessTR", string "LosslessEdi", string "LosslessPreset", int "NoiseBypass", float "NoiseRemove", \
                float "NoiseRestore", string "NoiseDeint", float "Sigma", int "BT", int "InputType", bool "Border", bool "Precise", \
                string "Preset", string "Tuning", bool "SafeMode", bool "ShowSettings" )
{
	#---------------------------------------
	# Settings

	SafeMode = default( SafeMode, false )

	# Select preset / tuning
	Preset = default( Preset, "Slower" )
	pNum = (Preset == "Placebo"   ) ? 0 : \
	       (Preset == "Very Slow" ) ? 1 : \
	       (Preset == "Slower"    ) ? 2 : \
	       (Preset == "Slow"      ) ? 3 : \
	       (Preset == "Medium"    ) ? 4 : \
	       (Preset == "Fast"      ) ? 5 : \
	       (Preset == "Faster"    ) ? 6 : \
	       (Preset == "Very Fast" ) ? 7 : \
	       (Preset == "Super Fast") ? 8 : \
	       (Preset == "Ultra Fast") ? 9 : \
	       (Preset == "Draft"     ) ? 10 : 2
	Tuning = default( Tuning, "None" )
	tNum = (Tuning == "None"  ) ? 0 : \
	       (Tuning == "DV-SD" ) ? 1 : \
	       (Tuning == "DV-HD" ) ? 2 : 0
	
	# Tunings only affect blocksize in this version
	bs = Select( tNum,  16, 16, 32 )
	bs2 = (bs >= 16) ? 32 : bs*2
	ovf = (SafeMode) ? 2 : 4    # Overlap other than 1/2 blocksize sometimes causes crashes in MVTools (??)

	# Preset groups:                                     Placebo    V.Slow    Slower    Slow      Medium    Fast      Faster    V.Fast    S.Fast     U.Fast    Draft
	tr0          = default( tr0,          Select( pNum,  2,         2,        2,        2,        2,        2,        1,        1,        1,         1,        1      ))
	tr1          = default( tr1,          Select( pNum,  2,         2,        2,        1,        1,        1,        1,        1,        1,         1,        1      ))
	tr2          = default( tr2,          Select( pNum,  3,         2,        1,        1,        1,        0,        0,        0,        0,         0,        0      ))
	rep0         = default( rep0,         Select( pNum,  4,         4,        4,        4,        3,        3,        0,        0,        0,         0,        0      ))
	rep1         = default( rep1,         Select( pNum,  0,         0,        0,        0,        0,        0,        0,        0,        0,         0,        0      ))
	rep2         = default( rep2,         Select( pNum,  4,         4,        4,        4,        4,        4,        4,        4,        3,         3,        0      ))
	EdiMode      = default( EdiMode,      Select( pNum, "NNEDI3",  "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3",  "TDIYadif",""     ))
	NNSize       = default( NNSize,       Select( pNum,  1,         1,        1,        1,        5,        5,        4,        4,        4,         4,        4      ))
	NNeurons     = default( NNeurons,     Select( pNum,  2,         2,        1,        1,        1,        0,        0,        0,        0,         0,        0      ))
	SMode        = default( SMode,        Select( pNum,  2,         2,        2,        2,        2,        2,        2,        2,        2,         2,        0      ))
	SLMode       = default( SLMode,       Select( pNum,  2,         2,        2,        2,        2,        2,        2,        1,        0,         0,        0      ))
	SLRad        = default( SLRad,        Select( pNum,  3,         1,        1,        1,        1,        1,        1,        1,        0,         0,        0      ))
	Sbb          = default( Sbb,          Select( pNum,  3,         1,        1,        0,        0,        0,        0,        0,        0,         0,        0      ))
	NoiseBypass  = default( NoiseBypass,  Select( pNum,  2,         2,        0,        0,        0,        0,        0,        0,        0,         0,        0      ))
	NoiseDeint   = default( NoiseDeint,   Select( pNum, "Generate","Bob",     "",       "",       "",       "",       "",       "",       "",        "",       ""     ))
	BT           = default( BT,           Select( pNum,  5,         3,        3,        3,        3,        2,        1,        1,        1,         1,        1      ))
	SrchClipPP   = default( SrchClipPP,   Select( pNum,  2,         2,        2,        2,        2,        1,        1,        0,        0,         0,        0      ))
	SubPel       = default( SubPel,       Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,        1      ))
	Blocksize    = default( Blocksize,    Select( pNum,  bs,        bs,       bs,       bs,       bs,       bs,       bs2,      bs2,      bs2,       bs2,      bs2    ))
	bs = Blocksize
	Overlap      = default( Overlap,      Select( pNum,  bs/2,      bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/ovf,    bs/ovf,   bs/ovf ))
	Search       = default( Search,       Select( pNum,  5,         4,        4,        4,        4,        4,        4,        4,        0,         0,        0      ))
	SearchParam  = default( SearchParam,  Select( pNum,  2,         2,        2,        2,        2,        2,        2,        1,        1,         1,        1      ))
	PelSearch    = default( PelSearch,    Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,        1      ))
	Precise      = default( Precise,      Select( pNum,  true,      true,     false,    false,    false,    false,    false,    false,    false,     false,    false  ))

	# Lossless defaults
	Lossless       = default( Lossless,       -1     )
	LosslessTR     = default( LosslessTR,     2      )
	LosslessPreset = default( LosslessPreset, "Fast" )
	lpNum = (LosslessPreset == "Placebo"   ) ? 0 : \
	        (LosslessPreset == "Very Slow" ) ? 1 : \
	        (LosslessPreset == "Slower"    ) ? 2 : \
	        (LosslessPreset == "Slow"      ) ? 3 : \
	        (LosslessPreset == "Medium"    ) ? 4 : \
	        (LosslessPreset == "Fast"      ) ? 5 : \
	        (LosslessPreset == "Faster"    ) ? 6 : \
	        (LosslessPreset == "Very Fast" ) ? 7 : \
	        (LosslessPreset == "Super Fast") ? 8 : \
	        (LosslessPreset == "Ultra Fast") ? 9 : \
	        (LosslessPreset == "Draft"     ) ? 10 : 5
		   
	# Lossless preset groups:          Placebo   V.Slow    Slower    Slow      Medium    Fast      Faster    V.Fast     S.Fast     U.Fast   Draft
	LosslessEdiMode  = Select( lpNum, "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "TDIYadif","TDIYadif","Yadif",  ""   )
	LosslessNNSize   = Select( lpNum,  2,        6,        1,        1,        5,        5,        4,        4,         4,         4,       4    )
	LosslessNNeurons = Select( lpNum,  2,        2,        2,        1,        1,        0,        0,        0,         0,         0,       0    )
	LosslessEdiMode  = default( LosslessEdi, LosslessEdiMode )
	
	# Sharpness defaults. Sharpness parameter is normalized so default is always 1.0 and gives roughly same sharpness for all settings. Internally tweaked
	# based on temporal smooth settings, sharpening mode and sharpness limiting mode to give actual value used in algorithm below
	# Sharpness is used differently in lossless mode (see parameter notes) so main algorithm sharpness is set to default
	SMode      = (defined(Sharpness) && Sharpness == 0.0) ? 0 : SMode
	SLMode     = (SMode == 0 || SLRad <= 0) ? 0 : SLMode
	Sbb        = (SMode == 0) ? 0 : Sbb
	spatialSL  = (SLMode == 1 || SLMode == 3)
	temporalSL = (SLMode == 2 || SLMode == 4)
	Sharpness  = default( Sharpness, 1.0 )
	sharpMul   = (temporalSL) ? 2 : (spatialSL) ? 1.5 : 1  # Temporal sharpness limiting is most effective, so needs strongest sharpness
	sharpAdj   = ((Lossless < 0) ? Sharpness : 1.0) * (sharpMul * (0.2 + tr1*0.15 + tr2*0.25) + ((SMode == 1) ? 0.1 : 0)) # Denormalize sharpness setting
	SOvs       = default( SOvs, 0 )
	SVThin     = default( SVThin, 0.0 )

	# MVTools settings
	SubPelInterp = default( SubPelInterp, 2     )
	TrueMotion   = default( TrueMotion,   false )
	Lambda       = default( Lambda,       ((TrueMotion) ? 1000 : 100 ) * (BlockSize*BlockSize)/(8*8) ) 
	LSAD         = default( LSAD,          (TrueMotion) ? 1200 : 400 )
	PNew         = default( PNew,          (TrueMotion) ? 50   : 25  )
	PLevel       = default( PLevel,        (TrueMotion) ? 1    : 0   )
	GlobalMotion = default( GlobalMotion, true )
	DCT          = default( DCT,          0    )

	# Some sensitive MVTools settings are no longer parameters
	_thSAD1 = 10 * 8*8  # SAD threshold for motion block matching: for intial temporal smooth (over 8x8 block as required by MVTools)
	_thSAD2 =  4 * 8*8  # SAD threshold for motion block matching: stabilising temporal smooth (--"--)
	_thSCD1 = 180       # Scene change detection parameter
	_thSCD2 = 98        # --"--

	# Noise bypass settings
	NoiseRemove  = default( NoiseRemove,  Select( NoiseBypass, 0.0, 1.0, 1.0 ))
	NoiseRestore = default( NoiseRestore, Select( NoiseBypass, 0.0, 1.0, 0.4 )) # Mode 2 has strong sharpening effect - so reduce NoiseRestore
	Sigma        = default( Sigma, 2.0 )
	NoiseBypass  = (NoiseRemove <= 0.0) ? 0 : NoiseBypass
	NoiseRemove  = (NoiseBypass == 0) ? 0.0 : NoiseRemove
	NoiseRestore = (NoiseBypass == 0) ? 0.0 : NoiseRestore

	# Other settings
	EdiQual      = default( EdiQual,    1 )
	EdiMaxD      = default( EdiMaxD,    8 )
	EdiThreads   = default( EdiThreads, 0 )
	((EdiMode == "Yadif" || EdiMode == "TDIYadif" || (Lossless >= 0 && (LosslessEdiMode == "Yadif" || LosslessEdiMode == "TDIYadif"))) && YadifPath != "") ? \
		Load_Stdcall_Plugin( YadifPath ) : NOP() # Load Yadif as required
	InputType    = default( InputType, 0 )
	Assert( Lossless == -1 || InputType == 0, "Lossless mode is incompatible with progressive input" )
	Border       = default( Border,       false )
	ShowSettings = default( ShowSettings, false )
	NNeurons     = (EdiMode == "NNEDI2" && NNeurons > 2) ? 2 : NNeurons  # Smaller range for NNeurons in NNEDI2 (which calls it nsize)
	maxT         = (tr1 > tr2) ? tr1 : tr2                               # Maximum temporal radius needed
	maxT         = (LosslessTR > maxT) ? LosslessTR : maxT               # --"--
	maxT         = (temporalSL && SLRad > 1 && maxT < 3) ? 3 : maxT      # --"--
	rgBlur       = (Precise) ? 11 : 12                                   # Version of RemoveGrain blur to use
	epsilon      = 0.0001                                                # Error margin to avoid rounding problems

	
	#---------------------------------------
	# Pre-Processing
	
	w = Input.Width()
	h = Input.Height() 
	nullClip  = BlankClip( Input, Length=0, Width=16, Height=16 ) 

	# Extract noise/grain from source, keep removed noise for restoring later. If NoiseBypass == 2, noise is extracted and stored, but not removed from 
	# the source - allowing the TGMC process to do the denoising (avoids effectively denoising twice)
	denoise = (NoiseRemove > 0.0)  ? Input.FFT3DFilter( sigma=Sigma, beta=1.0/NoiseRemove, bt=BT, interlaced=true ) : Input
	noise   = (NoiseRestore > 0.0) ? mt_makediff( Input, denoise, U=3,V=3 ).mt_lut( "x 128 - " + string(NoiseRestore) + " * 128 +" ) : nullClip
	bypass  = (NoiseBypass == 1)   ? denoise : Input
	
	# 'Deinterlace' the extracted noise. Noise is extracted from interlaced source but will be added back to progressive, so create the missing lines of noise.
	# Methods include standard "Bob" and "DoubleWeave", "Copy" to duplicate each line, and the slowest method "Generate" that creates new noise centered on a
	# weighted local average, using the difference between local min & max as an estimate of local variance
	deintNoise = (NoiseBypass == 0 || NoiseRestore <= 0.0) ? nullClip : \
	             (InputType > 0)                           ? noise : \
	             (NoiseDeint == "Bob")                     ? noise.Bob() : \
	             (NoiseDeint == "Copy")                    ? noise.SeparateFields.BilinearResize( w,h ) : \
	             (NoiseDeint == "Generate")                ? noise.Generate2ndFieldNoise() : \
	                                                         noise.DoubleWeave()

	# Pad vertically during processing (to prevent artefacts at top & bottom edges)
	clip = (Border) ? bypass.PointResize( w,h+8, 0,-4,0,h+8+epsilon ) : bypass
	h = (Border) ? h+8 : h

										 
	#---------------------------------------
	# Motion Analysis

	# Bob the input as a starting point for motion search clip - simple upscale of current field, will not be very sharp (which helps stabilize motion search)
	bobbed = (InputType == 0) ? clip.Bob( 0,0.5 ) : \
	         (InputType == 1) ? clip : \
	                            clip.Blur( 0,1 )

	# Support already-deinterlaced progressive content - drop half the fields and reweave to get 1/2fps interlaced stream appropriate for TGMC processing
	ediInput = (InputType == 2) ? clip.SeparateFields().SelectEvery(4,0,3).Weave() : \
	           (InputType == 3) ? clip.ComplementParity().SeparateFields().SelectEvery(4,0,3).Weave() : \
			                      clip
								
	# Create interpolated image as starting point for output - typically will be sharper than the bob (except the hi-speed modes)
	edi = defined(EdiExt)             ? EdiExt.PointResize( w,h, 0,(EdiExt.Height()-h)/2, -0,h+epsilon ) : \
	      (InputType == 1)            ? ediInput : \
	      (EdiMode == "NNEDI3")       ? ediInput.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	      (EdiMode == "NNEDI2")       ? ediInput.NNEDI2( field=-2, nsize=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	      (EdiMode == "NNEDI")        ? ediInput.NNEDI( field=-2 ) : \
	      (EdiMode == "EEDI3+NNEDI3") ? ediInput.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, \
		                                                sclip=ediInput.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads ) ) : \
	      (EdiMode == "EEDI3")        ? ediInput.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads ) : \
	      (EdiMode == "EEDI2")        ? ediInput.SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ) : \
	      (EdiMode == "Yadif")        ? ediInput.Yadif( mode=1 ) : \
	      (EdiMode == "TDIYadif")     ? Merge( ediInput.Yadif( mode=1 ), ediInput.TDeInt( mode=1 ) ) : \
	                                    bobbed

	# Temporally gaussian blur the bobbed clip for better motion search. Although the bobbed clip is somewhat blurred it will shimmer due to being derived
 	# from alternating fields, which makes motion analysis erratic. Blurring over a few frames makes for more stable motion vectors. The gaussian blur ensures
	# that frames near the current one will be more prominent in the blur - making for more accuracy in the motion vectors
	ts1 = (tr0 > 0) ? bobbed.TemporalSoften( 1, 255,255, 28, 2 ) : nullClip
	ts2 = (tr0 > 1) ? bobbed.TemporalSoften( 2, 255,255, 28, 2 ) : nullClip
	tempGauss = (tr0 == 0) ? bobbed : \
	            (tr0 == 1) ? ts1.Merge( bobbed, 0.25 ) : \
	                         ts1.Merge( ts2, 0.357 ).Merge( bobbed, 0.125 )

	# Remove areas of difference between temporal blurred motion search clip and bob that are not due to bob-shimmer - improves motion search
	repair0 = (rep0 == 0) ? tempGauss : tempGauss.RemoveNonBobDiff( bobbed, rep0 )

	# Spatially gaussian blur (and tweak) motion search clip for more stable motion vectors - removing noise makes features easier to track
	spatialBlur = (SrchClipPP == 0) ? repair0 : repair0.RemoveGrain(rgBlur).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=2 ).Merge( repair0, 0.1 )
	tweaked = (SrchClipPP == 2) ? mt_lutxy( repair0, bobbed, "x 3 + y < x 3 + x 3 - y > x 3 - y ? ?", U=3,V=3 ) : nullClip
	srchclip = (SrchClipPP < 2) ? spatialBlur : spatialBlur.mt_lutxy( tweaked, "x 7 + y < x 2 + x 7 - y > x 2 - x 51 * y 49 * + 100 / ? ?", U=3,V=3 )

	#-- Infix notation for odd tweak used above when SrchClipPP == 2 (taken from original TGMC - exact rationale unknown)
	#-- ((x+3)<y)?(x+3):(((x-3)>y)?(x-3):y)                   # Tweak = orig search clip nudged towards bob
	#-- ((x+7)<y)?(x+2):(((x-7)>y)?(x-2):((x*51)+(y*49))/100) # Nudge distant spatial blur values towards Tweak, roughly average nearer values (??)

	# Calculate forward and backward motion vectors from motion search clip
	srchSuper = (maxT > 0) ? srchClip.MSuper( pel=SubPel, sharp=SubPelInterp ) : nullClip
	bVec3 = (maxT > 2) ? srchSuper.MAnalyse( isb=true,  delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip
	bVec2 = (maxT > 1) ? srchSuper.MAnalyse( isb=true,  delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip
	bVec1 = (maxT > 0) ? srchSuper.MAnalyse( isb=true,  delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip
	fVec1 = (maxT > 0) ? srchSuper.MAnalyse( isb=false, delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip
	fVec2 = (maxT > 1) ? srchSuper.MAnalyse( isb=false, delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip
	fVec3 = (maxT > 2) ? srchSuper.MAnalyse( isb=false, delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                         truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : nullClip

											 
	#---------------------------------------
	# Create Output

	# Create basic TGMC ouput: use motion vectors to blur interpolated image with motion-compensated previous and next frames. The interpolated image (edi)
	# may be a sharp high-quality image (e.g. using NNEDI3), but it will shimmer between frames due to the interpolator working on alternating fields.
	# Blurring with neighboring frames would remove the shimmer, but also create motion blur. By using motion compensated neighbors, features from the
	# current frame are blended with the same feature in the neighboring frames regardless of movement. This gives a much sharper result, whilst still
	# blurring out the shimmer. A gaussian blur ensures the current frame is most prominent in the result.
	ediSuper =  (tr1 > 0) ? edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : nullClip
	mdegrain1 = (tr1 > 0) ? edi.MDegrain1( ediSuper, bVec1,fVec1, thSAD=_thSAD1, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : nullClip
	mdegrain2 = (tr1 > 1) ? edi.MDegrain1( ediSuper, bVec2,fVec2, thSAD=_thSAD1, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : nullClip
	tgmc = (tr1 == 0) ? edi : \
	       (tr1 == 1) ? mdegrain1.Merge( edi, 0.25 ) : \
	                    mdegrain1.Merge( mdegrain2, 0.2 ).Merge( edi, 0.0625 )

	# For temporal sharpness limiting later: need the max/min value for each pixel over neighboring motion-compensated frames
	bComp1 = (temporalSL)              ? edi.MCompensate( ediSuper, bVec1, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : nullClip
	fComp1 = (temporalSL)              ? edi.MCompensate( ediSuper, fVec1, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : nullClip
	tMax =   (temporalSL)              ? edi.mt_logic( fComp1, "max", U=3,V=3 ).mt_logic( bComp1, "max", U=3,V=3 )  : nullClip
	tMin =   (temporalSL)              ? edi.mt_logic( fComp1, "min", U=3,V=3 ).mt_logic( bComp1, "min", U=3,V=3 )  : nullClip
	bComp3 = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, bVec3, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : nullClip
	fComp3 = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, fVec3, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : nullClip
	tMax =   (SLRad > 1 && temporalSL) ? tMax.mt_logic( fComp3, "max", U=3,V=3 ).mt_logic( bComp3, "max", U=3,V=3 ) : tMax
	tMin =   (SLRad > 1 && temporalSL) ? tMin.mt_logic( fComp3, "min", U=3,V=3 ).mt_logic( bComp3, "min", U=3,V=3 ) : tMin

	# Remove areas of difference between tgmc image and basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal blur
	repair1 = (rep1 == 0) ? tgmc : tgmc.RemoveNonBobDiff( edi, rep1 )

	# Resharpen to counteract temporal blur (SMode >= 1: subtract difference from 3x3 blur, SMode == 2: replace with average of vertical min/max first)
	# If using Precise mode then reduce tiny overshoot in vertical min/max average
	vresharp = (SMode == 2) ? Merge( repair1.mt_expand( mode="vertical", U=3,V=3 ), repair1.mt_inpand( mode="vertical", U=3,V=3 ) ) : nullClip
	vresharp = (Precise && SMode == 2) ? vresharp.mt_lutxy( repair1, "x y < x 1 + x y > x 1 - x ? ?", U=3,V=3 ) : vresharp  # (x<y)?(x+1):((x>y)?(x-1):x)
	resharp = (SMode == 0) ? repair1 : \
	          (SMode == 1) ? repair1.mt_lutxy( repair1.RemoveGrain(rgBlur), "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 ) : \
	                         repair1.mt_lutxy( vresharp.RemoveGrain(rgBlur), "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 )

	# Slightly thin down 1-pixel high horizontal edges that have been widened into neigboring field lines by the interpolator
	# E.g. shown horizontally, a field is: 0x4x0, the interpolator creates the missing lines: 02420 -> the line is widened over three pixels
	# First find horizontal edges that don't lie within the range defined by their vertical neighbors, i.e. the affected 1-pixel high edges
	# Blur edges and find pixels that change pre->post blur: the neighbor pixels to the horizontal edges - shift their luma away from the line luma
	SVThinSc = SVThin * 6.0 # 4 surely better for RemoveGrain(11)??
	vertMedD  = (SVthin == 0.0) ? nullClip : mt_lutxy( repair1, repair1.VerticalCleaner(mode=1), "y x - " + string(SVThinSc) + " * 128 +", U=1,V=1 ).Blur( 1,0 )
	neighborD = (SVthin == 0.0) ? nullClip : mt_lutxy( vertMedD, vertMedD.RemoveGrain( rgBlur,-1 ), "y 128 - abs x 128 - abs > y 128 ?" )
	thin      = (SVthin == 0.0) ? resharp  : resharp.mt_adddiff( neighborD, U=2,V=2 )

	# Back blend the blurred difference between sharpened & unsharpened clip, before sharpness limiting (Sbb == 1,2). A small fidelity improvement
	backBlend1 = (Sbb == 1 || Sbb == 2) \
		? thin.mt_makediff( mt_makediff( thin, repair1, U=1,V=1 ).RemoveGrain( rgBlur,-1 ).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 ) \
		: thin
		
	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original - before 2nd temporal smooth (SLMode == 1,2)
	sharpLimit1 = (SLMode == 1) ? ((SLrad < 2) ? backBlend1.Repair( edi, 1 ) : backBlend1.Repair( backBlend1.Repair( edi, 12 ), 1 )) : \
	              (SLMode == 2) ? backBlend1.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) :\
				                  backBlend1
    
	# Back blend the blurred difference between sharpened & unsharpened clip, after sharpness limiting (Sbb == 3,4). A small fidelity improvement
	backBlend2 = (Sbb == 3 || Sbb == 4) \
		? sharpLimit1.mt_makediff( mt_makediff( sharpLimit1, repair1, U=1,V=1 ).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 ) \
		: sharpLimit1

	# Second lighter temporal blur (linear, not Gaussian) for final denoising / stabilization
	stableSuper = (tr2 > 0) ? backBlend2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : nullClip
	stable  = (tr2 == 0) ? backBlend2 : \
	          (tr2 == 1) ? backBlend2.MDegrain1( stableSuper, bVec1,fVec1,                           thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : \
	          (tr2 == 2) ? backBlend2.MDegrain2( stableSuper, bVec1,fVec1, bVec2,fVec2,              thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : \
 	                       backBlend2.MDegrain3( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 )

	# Remove areas of difference between final output & basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal smooth
	repair2 = (rep2 == 0) ? stable : stable.RemoveNonBobDiff( edi, rep2 )

	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original - after 2nd temporal smooth (SLMode == 3,4)
	processed = (SLMode == 3) ? ((SLrad < 2) ? repair2.Repair( edi, 1 ) : repair2.Repair( repair2.Repair( edi, 12 ), 1 )) : \
	            (SLMode == 4) ? repair2.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) :\
			                    repair2


	#---------------------------------------
	# Post-Processing
	
	# Make result lossless, i.e. keep original fields in output and update generated "in-between" fields to better match whilst retaining stability
	lossed = (Lossless < 0)    ? processed : \
	         (LosslessTR == 1) ? processed.RestoreLossless( Source=clip, Mode=Lossless, EdiMode=LosslessEdiMode, NNSize=LosslessNNSize, \
	                                                        NNeurons=LosslessNNeurons, SubPel=SubPel, SubPelInterp=SubPelInterp, Sharpness=Sharpness, \
	                                                        EdiThreads=EdiThreads, fVec1=fVec1,bVec1=bVec1 ) : \
	         (LosslessTR == 2) ? processed.RestoreLossless( Source=clip, Mode=Lossless, EdiMode=LosslessEdiMode, NNSize=LosslessNNSize, \
	                                                        NNeurons=LosslessNNeurons, SubPel=SubPel, SubPelInterp=SubPelInterp, Sharpness=Sharpness, \
	                                                        EdiThreads=EdiThreads, fVec1=fVec1,bVec1=bVec1, fVec2=fVec2,bVec2=bVec2 ) : \
	                             processed.RestoreLossless( Source=clip, Mode=Lossless, EdiMode=LosslessEdiMode, NNSize=LosslessNNSize, \
	                                                        NNeurons=LosslessNNeurons, SubPel=SubPel, SubPelInterp=SubPelInterp, Sharpness=Sharpness, \
	                                                        EdiThreads=EdiThreads, fVec1=fVec1,bVec1=bVec1, fVec2=fVec2,bVec2=bVec2, fVec3=fVec3,bVec3=bVec3 )

	# Crop off temporary vertical padding
	cropped = (Border) ? lossed.Crop( 0, 4, -0, -4 ) : lossed
	h = (Border) ? h-8 : h

	# Add back any extracted noise
	addNoise = (NoiseRestore > 0.0) ? cropped.mt_adddiff( deintNoise, U=3,V=3 ) : cropped

	# Show settings and output
	return (ShowSettings == false) ? addNoise : \
		addNoise.Subtitle( "tr0=" + string(tr0) + " | tr1=" + string(tr1) + " | tr2=" + string(tr2) + " | rep0=" + string(rep0) + " | rep1=" + string(rep1) + \
		" | rep2=" + string(rep2) + "\nEdiMode='" + EdiMode + "' | NNSize=" + string(NNSize) + " | NNeurons=" + string(NNeurons) + " | EdiQual=" + \
		string(EdiQual) + " | EdiMaxD=" + string(EdiMaxD) + " | EdiThreads=" + string(EdiThreads) + "\nSharpness=" + string(Sharpness, "%.2f") + \
		" | SMode=" + string(SMode) + " | SLMode=" + string(SLMode) + " | SLRad=" + string(SLRad) + " | SOvs=" + string(SOvs) + " | SVThin=" +  \
		string(SVThin, "%.2f") + " | Sbb=" + string(Sbb) + "\nSrchClipPP=" + string(SrchClipPP) + " | SubPel=" + string(SubPel) + " | SubPelInterp=" + \
		string(SubPelInterp) + " | BlockSize=" + string(BlockSize) + " | Overlap=" + string(Overlap) + "\nSearch=" + string(Search) + " | SearchParam=" + \
		string(SearchParam) + " | PelSearch=" + string(PelSearch) + " | TrueMotion=" + string(TrueMotion) + "\nLambda=" + string(Lambda) + " | LSAD=" + \
		string(LSAD) + " | PNew=" + string(PNew) + " | PLevel=" + string(PLevel) + " | GlobalMotion=" + string(GlobalMotion) + " | DCT=" + string(DCT) + \
		"\nLossless=" + string(Lossless) + " | LosslessTR=" + string(LosslessTR) + " | LosslessEdi='" + LosslessEdiMode + "' | LosslessPreset='" + \
		LosslessPreset + "'\nNoiseBypass=" + string(NoiseBypass) + " | NoiseRemove=" + string(NoiseRemove, "%.2f") + " | NoiseRestore=" + \
		string(NoiseRestore, "%.2f") + "\nNoiseDeint='" + NoiseDeint + "' | Sigma=" + string(Sigma, "%.2f") + " | BT=" + string(BT) + "\nBorder=" + \
		string(Border) + " | Precise=" + string(Precise) + " | SafeMode=" + string(SafeMode) + "\nPreset='" + Preset + "' | Tuning='" + Tuning + "'", \
		font="Lucida Console", size=11, lsp=12 )
}


#---------------------------------------
# Helpers

# Functions (from original TGMC) used instead of mt_xxflate - not actually equivalent to mt_xxflate, nor are they faster any more. However, they work well
# although it may be worth testing if returning to the mt_ versions is worthwhile(??)
function TGMC_inflate( clip c, int "Y", int "U", int "V" )
{
	mtY =default( Y, 3 )
	mtU =default( U, 1 )
	mtV =default( V, 1 )
	rgY = (mtY == 3) ? 20 : -1
	rgU = (mtU == 3) ? 20 : -1
	rgV = (mtV == 3) ? 20 : -1 
	mt_logic( c, c.RemoveGrain( rgY, rgU, rgV ), "max", Y=mtY,U=mtU,V=mtV )
}

function TGMC_deflate( clip c, int "Y", int "U", int "V" )
{
	mtY =default( Y, 3 )
	mtU =default( U, 1 )
	mtV =default( V, 1 )
	rgY = (mtY == 3) ? 20 : -1
	rgU = (mtU == 3) ? 20 : -1
	rgV = (mtV == 3) ? 20 : -1 
	mt_logic( c, c.RemoveGrain( rgY, rgU, rgV ), "min", Y=mtY,U=mtU,V=mtV )
}

# Helper function: Compare processed clip with reference clip: only allow thin, horizontal areas of difference, i.e. bob shimmer
# Rough algorithm: Get difference, deflate vertically by a couple of pixels or so, then inflate again. Thin regions will be removed
#                  by this process. Restore remaining areas of difference back to as they were in reference clip.
function RemoveNonBobDiff( clip Input, clip Ref, int rep )
{
	# ed is the erosion distance - how much to deflate then reflate to remove thin areas of interest: 0 = minimum to 5 = maximum
	# od is over-dilation level  - extra inflation to ensure areas to restore back are fully caught:  0 = none to 3 = one full pixel
	# If rep < 10, then ed = rep and od = 0, otherwise ed = 10s digit and od = 1s digit (nasty method, but kept for compatibility with original TGMC)
	rep = default( rep, 1 )
	ed = (rep < 10) ? rep : rep/10  
	od = (rep < 10) ? 0   : rep%10  

	diff = mt_makediff( Ref, Input, U=3,V=3 )

	# Areas of positive difference                                                          # ed = 0 1 2 3 4 5
	choke1 =                        diff.  mt_inpand( mode="vertical", U=3,V=3 )            #      x x x x x x    1 pixel   \
	choke1 = (ed > 2)             ? choke1.mt_inpand( mode="vertical", U=3,V=3 ) : choke1   #      . . . x x x    1 pixel    | Deflate to remove thin areas
	choke1 = (ed != 0 && ed != 3) ? choke1.TGMC_deflate( U=3,V=3 )               : choke1   #      . x x . x x    a bit more |
	choke1 = (ed == 2 || ed == 5) ? choke1.RemoveGrain(4)                        : choke1   #      . . x . . x    & more(?) / [median - may actually inflate??]
	
	choke1 =                        choke1.mt_expand( mode="vertical", U=3,V=3 )            #      x x x x x x    1 pixel  \
	choke1 = (ed > 1)             ? choke1.mt_expand( mode="vertical", U=3,V=3 ) : choke1   #      . . x x x x    1 pixel   | Reflate again
	choke1 = (ed > 4)             ? choke1.mt_expand( mode="vertical", U=3,V=3 ) : choke1   #      . . . . . x    1 pixel  /
	
	# Over-dilation - extra reflation up to 1 pixel
	choke1 = (od == 0)            ? choke1 : \
	         (od == 1)            ? choke1.TGMC_inflate( U=3,V=3 ) : \                      
	         (od == 2)            ? choke1.TGMC_inflate( U=3,V=3 ).TGMC_inflate( U=3,V=3 ) : \
	                                choke1.mt_expand( U=3,V=3 )
	
	# Areas of negative difference (similar to above)
	choke2 =                        diff.  mt_expand( mode="vertical", U=3,V=3 )
	choke2 = (ed > 2)             ? choke2.mt_expand( mode="vertical", U=3,V=3 ) : choke2
	choke2 = (ed != 0 && ed != 3) ? choke2.TGMC_inflate( U=3,V=3 )               : choke2
	choke2 = (ed == 2 || ed == 5) ? choke2.RemoveGrain(4)                        : choke2
	choke2 =                        choke2.mt_inpand( mode="vertical", U=3,V=3 )
	choke2 = (ed > 1)             ? choke2.mt_inpand( mode="vertical", U=3,V=3 ) : choke2
	choke2 = (ed > 4)             ? choke2.mt_inpand( mode="vertical", U=3,V=3 ) : choke2
	choke2 = (od == 0)            ? choke2 : \
	         (od == 1)            ? choke2.TGMC_deflate( U=3,V=3 ) : \  
	         (od == 2)            ? choke2.TGMC_deflate( U=3,V=3 ).TGMC_deflate( U=3,V=3 ) : \  
	                                choke2.mt_inpand( U=3,V=3 )
	
	# Combine above areas to find those areas of difference to restore
	restore = diff.mt_lutxy( choke1, "x 129 < x y 128 < 128 y ? ?", U=3,V=3 ).mt_lutxy( choke2, "x 127 > x y 128 > 128 y ? ?", U=3,V=3 )
	
	return Input.mt_adddiff( restore, U=3,V=3 )
}


# Given the TGMC output, make result lossless with respect to the source: the original source fields occur unchanged in the output and the TGMC generated
# "in-between" fields are updated to better match them, whilst retaining stability. Can also produce "fake" lossless output, which just updates both fields to 
# better match source but isn't actually lossless - gives better stability though.
# Parameters are essentially same as equivalent values in main script except:
# Mode (0-3)        : 0 = Fake lossless slight temporal smooth  1 = Fake lossless strong temporal smooth (slower, more stable)
#                   : 2 = Lossless slight temporal smooth       3 = Lossless strong temporal smooth
# Sharpness (float) : Sharpness of final result, 1.0 = no change, > 1.0 = more sharp, < 1.0 = more blurred. Values other than 1.0 will give "fake" lossless
function RestoreLossless( clip TGMC, clip "Source", clip "fVec1", clip "bVec1", clip "fVec2", clip "bVec2", clip "fVec3", clip "bVec3", \
                          int "Mode", string "EdiMode", int "NNSize", int "NNeurons", int "EdiQual", int "EdiMaxD", int "EdiThreads", \
						  int "SubPel", int "SubPelInterp", float "Sharpness" )
{
	# Set defaults [the settings marked * cannot be currently be altered from outside the script - they have a very minor effect overall]
	Mode         = default( Mode,         2        )
	EdiMode      = default( EdiMode,      "NNEDI3" ) 
	NNSize       = default( NNSize,       5        )
	NNeurons     = default( NNeurons,     0        )
	EdiQual      = default( EdiQual,      1        ) # *
	EdiMaxD      = default( EdiMaxD,      8        ) # *
	EdiThreads   = default( EdiThreads,   0        )
	SubPel       = default( SubPel,       1        )
	SubPelInterp = default( SubPelInterp, 2        )
	Sharpness    = default( Sharpness,    1.0      )
	
	# Set motion vector defaults - will reuse nearer neighbors if not supplied. Note that motion vectors to neighboring same-parity field are only used in
	# "fake" lossless mode where they enhance stability. Replace with vectors to nearest opposite parity field for true lossless - temporal blending with same
	# parity field will reduce likelyhood of stable match with source fields. This it at the expense of slightly more combing effects afterwards
	fVec2 = default( fVec2, fVec1 )
	bVec2 = default( bVec2, bVec1 )
	fVec2 = (Mode < 2) ? fVec2 : fVec1
	bVec2 = (Mode < 2) ? bVec2 : bVec1
	fVec3 = default( fVec3, fVec2 )
	bVec3 = default( bVec3, bVec2 )

	# Other MVTools settings (as main script)
	_thSAD =  4 * 8*8  # SAD threshold for motion block matching
	_thSCD1 = 180      # Scene change detection parameter
	_thSCD2 = 98       # --"--
	
	# Get the fields from the original source and the corresponding (now updated) fields in the TGMC result, as well as the newly generated in-between fields 
	srcFields     = Source.SeparateFields()
	tgmcFields    = TGMC.SeparateFields()
	tgmcSrcFields = tgmcFields.SelectEvery( 4, 0,3 )
	tgmcNewFields = tgmcFields.SelectEvery( 4, 1,2 )

	# Find the difference between the source fields and their updated TGMC counterparts. Interpolate this difference to get a starting point for the difference
	# between the TGMC result and the lossless output required. However, this initial result, whilst fine for a single frame will exhibit bob-shimmer due to
	# interpolating alternating fields (same problem that TGMC solves), so further processing is required
	srcFieldsDiff = mt_makediff( srcFields, tgmcSrcFields, U=3,V=3 ).Weave()
	ediDiff = (EdiMode == "NNEDI3")       ? srcFieldsDiff.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	          (EdiMode == "NNEDI2")       ? srcFieldsDiff.NNEDI2( field=-2, nsize=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	          (EdiMode == "NNEDI")        ? srcFieldsDiff.NNEDI( field=-2 ) : \
			  (EdiMode == "EEDI3+NNEDI3") ? srcFieldsDiff.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, \
			                                    sclip=srcFieldsDiff.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads )) : \
	          (EdiMode == "EEDI3")        ? srcFieldsDiff.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads ) : \
	          (EdiMode == "EEDI2")        ? srcFieldsDiff.SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ) : \
	          (EdiMode == "Yadif")        ? srcFieldsDiff.Yadif( mode=1 ) : \
	          (EdiMode == "TDIYadif")     ? Merge( srcFieldsDiff.Yadif( mode=1 ), srcFieldsDiff.TDeInt( mode=1 ) ) : \
	                                        srcFieldsDiff.Bob()

	# Temporally smooth the lossless difference to remove bob-shimmer. Use already calculated motion vectors to do this motion compensated (retain sharpness)
	diffSuper   = ediDiff.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 )
	diffDegrain = (Mode % 2 == 0) ? ediDiff.MDegrain2( diffSuper, bVec1,fVec1, bVec2,fVec2,              thSAD=_thSAD, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : \
	                                ediDiff.MDegrain3( diffSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, thSAD=_thSAD, thSCD1=_thSCD1,thSCD2=_thSCD2 )

	# Resharpen the smoothed difference and then spatially limit the sharpening - for a small visual improvement
	diffResharp = diffDegrain.mt_adddiff( mt_makediff( diffDegrain, diffDegrain.RemoveGrain(12), U=3,V=3 ))
	diffSLimit  = diffResharp.Repair( diffDegrain, 1 )

	# Different result for fake or real lossless mode
	lossless = (Mode > 1) ? Eval( """
	
		# Extract just the 'in-between' fields from the difference calculated above. Add it back on to the TGMC in-between fields to get corrected fields that
		# should be a good match to weave with the original source fields, but with stability from the smoothing above. Weave together for a lossless result
		newFieldsDiff = diffSLimit.SeparateFields().SelectEvery( 4, 1,2 )
		newFieldsCorr = tgmcNewFields.mt_adddiff( newFieldsDiff, U=3,V=3 )
		lossless = Interleave( srcFields, newFieldsCorr ).SelectEvery( 4, 0,1,3,2 ).Weave()

		# However, inevitable small errors in the motion compensation will mean the temporally smoothed fields won't exactly match the source fields. There will
		# be some slight residual combing. Use vertical medians to clean a little of this away
		vertMedian  = lossless.VerticalCleaner( mode=1 )
		vertMedDiff = mt_makediff( lossless, vertMedian, U=3,V=3 )
		vmNewDiff1  = vertMedDiff.SeparateFields().SelectEvery( 4, 1,2 )
		vmNewDiff2  = vmNewDiff1.VerticalCleaner( mode=1 ).mt_lutxy( vmNewDiff1, "x 128 - y 128 - * 0 < 128 x 128 - abs y 128 - abs < x y ? ?", U=3,V=3 )
		vmNewDiff3  = vmNewDiff2.Repair( vmNewDiff2.removegrain(2), 1 )
		
		# Reweave final result
		return Interleave( srcFields, newFieldsCorr.mt_makediff( vmNewDiff3, U=3,V=3 )).SelectEvery( 4, 0,1,3,2 ).Weave()
		
	""" ) : Eval( """
	
		# Fake lossless mode: use temporally smoothed difference to update tgmc input and return. Don't insert original source fields. Result will be closer to
		# source than original tgmc but not actually lossless. Avoids residual combing and can be more stable given decent temporal radius
		return TGMC.mt_adddiff( diffSLimit, U=3,V=3 )
		
	""" )
	
	# Sharpen final output if required
	(Sharpness == 1.0) ? lossless : lossless.mt_lutxy( lossless.RemoveGrain(12), "x x y - "+ string(Sharpness-1.0) + " * +", U=3,V=3 ).Repair( lossless, 1 )
}


# Given noise extracted from an interlaced source (i.e. the noise is interlaced), generate "progressive" noise with a new "field" of noise injected. The new
# noise is centered on a weighted local average and uses the difference between local min & max as an estimate of local variance
function Generate2ndFieldNoise( clip Input )
{
	origNoise = Input.SeparateFields()
	noiseMax  = origNoise.mt_expand( mode="square", U=3,V=3 ).mt_expand( mode="horizontal", U=3,V=3 )
	noiseMin  = origNoise.mt_inpand( mode="square", U=3,V=3 ).mt_inpand( mode="horizontal", U=3,V=3 )
	random    = BlankClip( origNoise, color_yuv=$808080 ).AddGrain( var=256 )
	varRandom = mt_makediff( noiseMax, noiseMin, U=3,V=3 ).mt_lutxy( random, "x 128 - y 128 - * 128 / 128 +", U=3,V=3 )
	newNoise  = origNoise.RemoveGrain(12).mt_adddiff( varRandom, U=3,V=3 )
	return Interleave( origNoise, newNoise ).Weave()
}
