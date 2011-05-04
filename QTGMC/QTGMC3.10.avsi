#-------------------------------------------------------------------#
#                                                                   #
#                     QTGMC 3.10, by Vit, 2011                      #
#                                                                   #
# Deinterlacer using motion-compensated temporal binomial smoothing #
#          Originally based on TempGaussMC_beta2 by Didée           #
#                                                                   #
#-------------------------------------------------------------------#

# See below for "Getting Started" instructions

# --- VERSION HISTORY ---
#
# v3.10: Explicit conditions to ensure no filter is constructed that won't be used - reduces memory use
#        FPSDivisor works even if not using motion blur
# v3.05: Motion blur support, added settings FPSDivisor, MotionBlur, ShutterAngleSrc, ShutterAngleOut, MBlurLimit
#        Bug fixes: Some Sbb modes with source match, MatchEdi setting (again)
# v3.01: Support for lossless modes on InputType=2,3 - improves detail retention
#        Enabling ShowNoise automatically switches on NoiseBypass
#        Bug fixes: "Draft" mode, noise extraction with InputType=1, MatchEdi setting
# v3.0:  Introduced source-match modes and settings for higher fidelity output - supported for interlaced and progressive input
#        Most lossless settings removed - superseded by source-match, only Lossless integer remains
#        Added ProgSADMask setting for progressive repair modes (InputType=2,3) to help recover stable detail
#        Added RepChroma setting to allow disabling of chroma processing in repair stages (rep0,1,2)
#        Added DetailRestore setting for NoiseBypass - allowing denoising with some fine detail retention
#        Noise bypass with NoiseDeint="Generate" is now motion-compensated for better grain/detail restoral, NoiseDeint="Copy" removed
#        Corrected minor luma shift when using NoiseBypass (FFT3DFilter noise center is 128.5 not 128)
#        Added ShowNoise setting to display extracted noise, helps in determining Sigma
#        TDeint added as interpolator (suitable for source-match)
#        YadifPath no longer global
#        EdiMode for "Ultra Fast" changed from "TDIYadif" to "Yadif" (otherwise slower than "Super Fast" for non-threaded)
#        Bug fixes in Sbb and InputType=3
#        Complete rewrite of documentation and some script tidying
# v2.51: Changed default interpolator to "NNEDI3" for presets up to "Super Fast" and (new) lossless presets up to "Faster"
#        Range of preset tweaks including higher quality output from "Super Fast" & "Ultra Fast" but with a little speed loss
#        Support for EdiMode="EEDI3+NNEDI3": EEDI3 with sclip taken from NNEDI3
#        Added LosslessPreset and EdiThreads parameters
#        Tidied up output from ShowSettings and small bug fix
#        Fixed serious bug when using lossless modes on the higher speed presets
# v2.47: Fixed bug with default overlap when an explicit blocksize was given
# v2.46: Replaced mt_average with merge - was causing exceptions in certain MT situations
# v2.45: Tweaked use of Yadif: explicit loading is now optional, see YadifPath variable
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
#            EdiMode("NNEDI", "Yadif"), TR2(3), SLmode(3,4), SLRad, Sbb(2,3)
#        Added noise bypass (removal / restoration)
#        Added ShowSettings
# v2.00: First fully featured version
#        Supported majority of core TGMC features
#        Additional speed tweaks:
#            NNSize, SrchClipPP, SubPel, Precise
#        Added Presets system and beginnings of Tunings
# v1.00: First draft - high speed basic TGMC algorithm only


# --- REQUIREMENTS ---
#
# Download these plugins and put them in your plugin autoload folder (or load them in your calling script):
#	MVTools2 (2.58 or above)
#	MaskTools V2 (recommend 2.0a45 or above)
#	RemoveGrain + Repair
#	VerticalCleaner
#	Choice of: NNEDI3 (recommend 0.9.2 or above), NNEDI2, NNEDI, EEDI3, EEDI2, Yadif & TDeint
#	[Presets require NNEDI3 except "Ultra Fast", which requires Yadif]
#	FFT3DFilter (+FFTW3) (if using noise bypass)
#	AddGrainC (if using "Generate" mode for noise bypass)
#	[NNEDI3, EEDI3, TDeInt, FFT3DFilter and AddGrainC beyond standard TGMCb2 requirements]


#---------------------------------------

# --- GETTING STARTED ---
#
# Install AviSynth and ensure you have the plugins listed in the requirements section above. Then to use QTGMC, write a script like this:
#	YourSource("yourfile")     # DGDecode_mpeg2source, FFVideoSource, AviSource, whatever your source requires
#	QTGMC( Preset="Slow" )
#	SelectEven()               # Add this line to keep original frame rate, leave it out for smoother doubled frame rate
#
# Save this script with an ".avs" extension. You can now use it as an AVI source for encoding.
#
# The "Preset" used selects sensible settings for a given encoding speed. Choose a preset from:
#	"Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast" & "Draft"
# The default preset is "Slower". If you get crashes with the fastest presets ("Super Fast" and above) then use the SafeMode setting (described below)
#
# There are many settings for tweaking this script, full details are provided below. The settings have been divided into categories, which each having key
# points, a detailed description, settings specifications/defaults, and several examples. The key points and examples should get you going.
#
# You can display all the settings being used by a preset by using "ShowSettings":
#   QTGMC( Preset="Slow", ShowSettings=true )


#--- CORE SETTINGS ---
#
# Key Points: For basic usage, select a preset and leave the core settings alone. Most useful setting is TR2, which controls smoothness and denoising of output.
#
# The core algorithm is this:
# 0. Bob the source clip. Temporally smooth the bob to remove shimmer then analyse its motion
# 1. More accurately interpolate the source clip (e.g. NNEDI3). Use the motion analysis from previous step to temporally smooth this interpolate with motion
#    compensation. This removes shimmer whilst retaining detail. Resharpen the result to counteract any blurring
# 2. A final light temporal smooth to clean the result
#
# Stages 0 & 1 use a binomial smooth (similar to a Gaussian) to remove deinterlacing shimmer. Stage 2 uses a simple linear smoothing. So each stage involves a
# temporal smooth with the radius (number of frames involved) given in the settings "TR0", "TR1" and "TR2". The binomial smooths are critical for the algorithm
# so TR0 and TR1 should be at least 1. TR0 only affects the motion analysis and is only indirectly visible, increasing it to 2 will generally give a better
# motion match. Increasing TR1 and TR2 will create a smoother and more stable output and more strongly denoise. The downside is that you will get more blurring
# and may lose detail. The blur is counteracted by the sharpening settings described below. Also note that increased TR1 & TR2 can cause/strengthen halos where
# the motion analysis is inaccurate
#
# The deinterlacer primarily tries to reduce "bob shimmer": horizontal lines of shimmer created when interpolating an interlaced stream. Consequently any
# changes made to the initial interpolation (e.g. NNEDI3) are expected to be horizontal lines of change only. The repair stages "Rep0", "Rep1" & "Rep2"
# occur after each temporal smooth. They only allow such horizontal lines of change - shimmer fixes, discarding other changes. This prevents the motion blur
# that temporal smoothing could generate. The repX settings control the size of areas to allow through. See the RemoveNonBobDiff function comments for details.
#
# Settings:
#	TR0          (0,1,2)         : Temporal binomial smoothing radius used to create motion search clip. In general 2=quality, 1=speed, 0=don't use
#	TR1          (0,1,2)         : Temporal binomial smoothing radius used on interpolated clip for inital output.  --------------"----------------
#	TR2          (0,1,2,3)       : Temporal linear smoothing radius used for final stablization / denoising. Adjust for your denoising/smoothing requirements
#	Rep0         (>= 0)          : Repair motion search clip  (0 = off): only keep thin areas of difference from bob (see RemoveNonBobDiff function for details)
#	Rep1         (>= 0)          : Repair initial output clip (0 = off): only keep thin areas of difference from edi
#	Rep2         (>= 0)          : Repair final output clip   (0 = off): --"--
#   RepChroma    (bool)          : Whether the repair modes affect chroma
#
# The presets determine the defaults for all these settings (see table in script or use "ShowSettings"), except RepChroma which defaults to true
#
# Examples:
#	QTGMC( Preset="Slow", TR2=3 )  # Strong final smooth (e.g. noisy / shimmery source)
#	QTGMC( 2,1,3, 4,0,4 )          # TempGaussMC style


#--- INTERPOLATION ---
#
# Key Points: Interpolation affects quality and speed. The presets can be relied on to provide sensible defaults mostly using NNEDI3.
#
# The first step to create the deinterlaced output is to spatially interpolate a single half-height field into a full-height frame. A variety of interpolators
# are supported, with various settings to control the quality/speed of the output.
#
# Settings:
#	EdiMode      (string)        : Interpolation method, from "NNEDI3", "NNEDI2", "NNEDI", "EEDI3+NNEDI3" (EEDI3 with sclip from NNEDI3), "EEDI3", "EEDI2",
#	                                                          "Yadif", "TDeint" or "TDIYadif" (combined TDeInt+Yadif), anything else uses "Bob"
#	NNSize       (0-6)           : Area around each pixel used as predictor for NNEDI3. A larger area is slower with better quality, read the NNEDI3 docs to see
#	                             : the area choices. Note: area sizes are not in increasing order (i.e. increased value doesn't always mean increased quality)
#	NNeurons     (0-4)           : Controls number of neurons in NNEDI2 (0-2) & NNEDI3 (0-4), larger = slower and better quality but improvements are small
#	EdiQual      (1,2,3)         : Quality setting for NNEDI2 (1,2,3) & NNEDI3 (1,2 only). Higher values for better quality - but improvements are marginal
#	EdiMaxD      (>= 1)          : Spatial search distance for finding connecting edges in EEDI2 and EEDI3
#	EdiThreads   (>= 0)          : Number of threads to use in EEDI3 & NNEDI2/3, 0 = default = number of logical processors on system. Also affects source-match
#	                             : interpolations. Source-match can add 2 further interpolations per frame, adjusting this setting can help balance system load
#	EdiExt       (clip)          : Provide externally created interpolated clip rather than use one of the above modes
#
# The presets determine defaults for NNEDIx and EEDIx (see table in script or use "ShowSettings"). Other defaults are EdiThreads=0, EdiExt=undefined
#
# Examples:
#	QTGMC( Preset="Slow", EdiMode="EEDI3", EdiMaxD=16 ) # Use EEDI3 with an explicit search radius
#	QTGMC( Preset="Very Slow", EdiThreads=2 )           # Specify number of threads (with default NNEDI3) useful to tweak if using SetMTMode or source-match


#--- SHARPNESS ---
#
# Key Points: Always consider adjusting Sharpness setting to taste. The default 1.0 is fairly sharp. If using source-match default is 0.2 (see comments below)
#
# The core of the algorithm involves a binomial smooth to remove shimmer. So the result needs to be resharpened to counteract this blur. The main setting
# "sharpness" defaults to 1.0 and is designed to retain the sharpness of stable areas. However, at this level the algorithm can cause moving areas to be
# oversharpened so you may wish to reduce the level depending on source. Sharpness when using source-match behaves differently - see the section below
#
# The sharpness processing for a given setting is tweaked to remain roughly similar regardless of other settings. However, there will be minor differences, so
# always consider adjusting sharpness if you tweak other major settings.
#
# Oversharpening is limited either spatially (SLMode = 1,3) or temporally (SLMode = 2,4). Temporal limiting is more "correct" but also more aggressive in
# preventing sharpening. It's also slower. You can set a small value in the overshoot setting (SOvs) to give the temporal limiting a bit of "headroom". You can
# also perform sharpness limiting later in the algorithm (SLMode = 3,4) for more sharpness, but with the potential for minor artefacts.
#
# Settings:
#	Sharpness    (float)         : How much to resharpen the temporally blurred clip ( >= 0.0, default is always 1.0 unlike original TGMC)
#	SMode        (0,1,2)         : Resharpening mode:  0 = none, 1 = difference from 3x3 blur kernel, 2 = vertical max/min average + 3x3 kernel
#	SLMode       (0,1,2,3,4)     : Sharpness limiting: 0 = off, [1 = by spatial comparison, 2 = by temporal comparison] : done before final temporal smooth
#	                             :                              [3 = by spatial comparison, 4 = by temporal comparison] : done after final temporal smooth
#	SLRad        (>= 0)          : Temporal or spatial radius used with sharpness limiting (depends on SLMode). Temporal radius can only be 0,1 or 3
#	SOvs         (0..255)        : Amount of overshoot allowed with temporal sharpness limiting (SLMode == 2,4), i.e. allow some oversharpening
#	SVThin       (0.0...)        : How much to thin down 1-pixel wide lines that have been widened due to interpolation into neighboring field lines
#	Sbb          (0,1,2,3)       : Back blend (blurred) difference between pre & post sharpened clip (minor fidelity improvement) :
#	                             :   0 = Off, 1 = before (1st) sharpness limiting, 2 = after (1st) sharpness limiting, 3 = both
#
# The presets determine defaults for SMode, SLMode, SLRad and Sbb (see table in script or use "ShowSettings"). Other defaults are: SOvs=0, SVThin=0.0, Sbb=0
#
# Examples:
#	QTGMC( Preset="Slow", Sharpness=0.4 )           # Reduce oversharpening
#	QTGMC( Preset="Slow", Sharpness=1.2, SLMode=1 ) # Increase sharpness, use spatial sharpness limiting (which typically allows more sharpening)


#--- SOURCE-MATCH / LOSSLESS ---
# Very detailed section for new feature [documentation likely to be thinned as feature matures]
#
# Key Points: Source-match creates higher fidelity output with extra processing. Enable with SourceMatch = 1,2 & 3. Higher values are slower and more accurate.
#             Can combine with Lossless setting (especially Lossless=2) for more detail again. Tweak speed with MatchPreset (like Preset). Will honor artefacts
#             in source, so best used with quality sources. By default sharpness becomes 0.2 & sharpness limiting switched off, so adjust sharpness carefully.
#             NOTE: THE EFFECTS OF THIS FEATURE ARE BOTH SUBTLE & PRECISE, INTENDED ONLY FOR EXACTING DETAIL. MAKE SURE YOU CAN SEE EXACTING DETAIL FIRST.
#
# Quickstart: The templates below increase in both quality and slowness. Choose preset as required (very fastest presets are not suitable though). Start with
# Sharpness=0.2 and increase slightly if necessary. Set TR2=1 for clean source, set TR2=2 or TR2=3 (slower) if more denoising required or use Noise Bypass
#	QTGMC( Preset=XXXX, SourceMatch=1, Sharpness=XXX, TR2=X )             # Basic mode, fastest
#	QTGMC( Preset=XXXX, SourceMatch=1, Lossless=2, Sharpness=XXX, TR2=X ) # Good quality, efficient, minor residual combing
#	QTGMC( Preset=XXXX, SourceMatch=3, Sharpness=XXX, TR2=X )             # Good quality, slower, no combing
#	QTGMC( Preset=XXXX, SourceMatch=3, Lossless=2, Sharpness=XXX, TR2=X ) # Best quality, slowest, very minor residual combing
#
# Intuitively, a deinterlacer should just inject new fields into the source, leaving the original pixels untouched. The temporal blur/resharpen in this script
# means that doesn't happen - the source pixels are changed in the output. The (optional) source-match steps attempt to fix this and make the result closer to
# the source. They work by looking at the difference between output and source at different points in the algorithm and correcting for that difference.
#
# Matching to the source will capture more source detail and reduce oversharpening / haloing. Caveat: the default algorithm strongly temporally smooths but with
# source-matching much less so (by necessity / design). Source-matching may faithfully recreate artefacts in the source (e.g blocking, banding & some noise) so
# it's better for quality sources. The SourceMatch setting sets the mode: 0=off (standard [Q]TGMC algorithm), 1,2,3 for progressively more accurate but slower
# processing. Modes 2 & 3 restore almost exact source detail but are sensitive to noise & introduce occasional aliasing (mode 3 is less affected). Mode 1 is a
# more conservative halfway stage that rarely introduces artefacts.
#
# Since source-matching recovers sharpness, the Sharpness default is reduced to 0.2. Source-matching may initially appear less sharp than standard processing
# because it will not oversharpen. However, be careful if raising the sharpness, because ***sharpness limiting is switched off by default***. This is because
# sharpness limiting reduces the the accuracy of these modes. Use the MatchEnhance setting to exaggerate additional detail found by modes 2 & 3. This gives a
# sharpening / detail enhancing effect and works well at sensible levels - but it's a slight cheat that should be used with care as it can easily enhance noise.
# Since source-match is sensitive to source noise you may want to set TR2 to 2 or 3 and/or use noise bypass (see below) for extra denoising.
#
# The additional Lossless modes are designed to take SourceMatch to its logical conclusion: Lossless mode 1 restores the *exact* pixels of the source into the
# output (provided NoiseRestore=0). This recovers a liitle more source detail but can introduce shimmering, minor combing, noise etc. Note the Sharpness and
# MatchEnhance settings have little effect in lossless mode 1. Lossless mode 2 makes the clip lossless before the sharpening & final temporal smooth. Removes
# most of the lossless artefacts and also allows sharpness control. This mode will not give an exactly lossless output, but it will gain a little more detail.
#
# The source-match settings introduce further processing. SourceMatch mode 1 requires a second interpolation (e.g. NNEDI3), but it can use a lower quality
# settings than the main stage. SourceMatch mode 2 requires yet another interpolation, but works effectively with just a bob (but using a better interpolator
# can reduce occasional aliasing). Mode 3 adds just a little more processing and is usually worth it as it reduces artefacts. There is no exact control over
# the interpolations used (too many settings required), instead there are MatchPresets that work in a similar way to the main Preset. The extra processing
# suggests much slower speeds, but actually using higher speed presets (both MatchPreset and Preset) with source-matching can give results comparable to slower
# presets without it. Having said that, the extra detail from source-matching is too subtle to significantly affect very high speed main presets.
#
# Settings:
#	SourceMatch  (0,1,2,3)       : 0 = Source-matching off (standard algorithm), 1 = basic source-match, 2 = refined match, 3 = twice refined match
#
#---SourceMatch=1,2,3---
#	MatchPreset  (string)        : Speed/quality for basic source-match processing, select from "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast",
#                                : "Faster", "Very Fast", "Super Fast", "Ultra Fast" ("Draft" not supported). Ideal choice is the same as main preset, but
#	                             : can choose a faster setting (but not a slower setting). Default is 3 steps faster than main preset.
#	MatchEdi     (string)        : Override default interpolation method for basic source-match. Default method is same as main EdiMode setting (usually NNEDI3)
#	                             : Only need to override if using slow method for main interpolation (e.g. EEDI3) and want a faster method for source-match
#
#---SourceMatch=2,3---
#	MatchPreset2 (string)        : Speed/quality for refined source-match processing, select from "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast",
#                                : "Faster", "Very Fast", "Super Fast", "Ultra Fast" ("Draft" not supported). Default is 2 steps faster than MatchPreset.
#                                : Faster settings are often just as good, can use slower settings if you get extra aliasing in this mode
#	MatchEdi2    (string)        : Override interpolation method for refined source-match. Can be a good idea to pick MatchEdi2="Bob" for speed
#	MatchTR2     (0,1,2)         : Temporal radius for refined source-matching. 2=smoothness, 1=speed/sharper, 0=not recommended. Difference very marginal
#                                : Basic source-match doesn't need this setting as its temporal radius must match TR1 core setting (i.e. there is no MatchTR1)
#	MatchEnhance (0.0...)        : Enhance the detail found by source-match modes 2 & 3. A slight cheat - will enhance noise if set too strong. Best set <= 1.0
#
#---Optional Extras---
#	Lossless     (0,1,2)         : Puts exact source fields into result & cleans any artefacts. 0=off, 1=after final temporal smooth, 2=before resharpening.
#	                             : Get a little extra detail but: mode 1 gets shimmer / minor combing, mode 2 is more stable/tweakable but not exactly lossless
#
# The defaults are: SourceMatch=0, MatchPreset=[3 settings quicker than main Preset], MatchPreset2=[2 settings quicker than MatchPreset]
#                   MatchEdi  = same as EdiMode, except if MatchPreset="Ultra Fast" when it is "Yadif"
#                   MatchEdi2 = "NNEDI3", except if MatchPreset="Super Fast" when it is "TDeint", or if MatchPreset="Ultra Fast" when it is "" (bob)
#                   MatchTR2=1, MatchEnhance=0.5, Lossless=0
#
# Examples:
#	QTGMC( Preset="Slow", SourceMatch=1 )                # Enable basic source-match. Result somewhat closer to source.
#	QTGMC( Preset="Slow", SourceMatch=1, Sharpness=0.4 ) # Basic source-match but sharper (up from 0.2). Be careful as sharpness limiting defaults to off
#	QTGMC( Preset="Slow", SourceMatch=1, Lossless=2 )    # Basic source-match with "fake" lossless. Efficient setting for quality, may bring minor combing
#
#	QTGMC( Preset="Medium", SourceMatch=2, TR2=2 )       # Refined source-match, closer to source with no combing, slower. Increased TR2 reduces noise
#
#	QTGMC( Preset="Slower", SourceMatch=3 )              # Twice refined source-match, higher quality than mode 2, but a little bit slower again
#	QTGMC( Preset="Slower", SourceMatch=3, Lossless=2 )  # Twice refined source-match with fake lossless. Almost perfect fidelity mode with few artefacts
#	QTGMC( Preset="Slower", SourceMatch=3, Lossless=1 )  # Twice refined source-match with true lossless. Exact detail, but likely combing and shimmer
#
#	QTGMC( Preset="Slow", SourceMatch=3, Lossless=2, MatchEnhance=0.75 ) # Further enhance detail found by refined match, a little sharper, may be noisier
#	QTGMC( Preset="Slow", SourceMatch=3, Lossless=2, MatchEnhance=0.75, NoiseBypass=1, NoiseRestore=0.7, Sigma=1.5 ) # As above, denoise a little to help
#
#	QTGMC( Preset="Slower", MatchPreset="Very Fast", SourceMatch=1 ) # Faster basic source-match preset (defaults to 3 steps faster than main Preset)
#	QTGMC( Preset="Slower", MatchPreset="Faster", MatchPreset2="Ultra Fast", SourceMatch=3 ) # Faster refined source-match preset as well
#                                                                                            # (defaults to 2 steps faster than basic match Preset)
#	QTGMC( Preset="Slower", MatchPreset="Slow", MatchPreset2="Slow", SourceMatch=3 ) # Or use slower source-match presets (usually unnecessary)
#
# Very high quality SD example: use slow main preset but faster basic source-match preset. Adjust sharpness. Use detail-retaining noise bypass (see below)
#   QTGMC( Preset="Very Slow", MatchPreset="Medium", SourceMatch=3, Lossless=2, MatchEnhance=0.6, Sharpness=0.25, \
#              NoiseBypass=2, NoiseRemove=1.0, DetailRestore=0.5, NoiseRestore=0.1, Sigma=3, NoiseDeint="Generate" )


#--- NOISE BYPASS ---
#
# Key Points: The Noise Bypass feature is used to retain, remove or strengthen noise & very fine detail. Refer to examples below for the different methods
#
# The use of multiple temporal smooths means that this script strongly denoises by default. When noise bypass is used, noise/grain is extracted from the source
# at the start, then added back in again at the end. This allows the grain from the source to be kept and also helps retain fine detail/sharpness. There are
# two modes, NoiseBypass=1 actually denoises at the start, whereas NoiseBypass=2 just identifies the noise in the source without removing it. So NoiseBypass=1
# will denoise when the restore level is moved below 1.0, and NoiseBypass=2 will tend to strengthen/sharpen as the restore level exceeds about 0.3 or so
#
# First set a Sigma value to estimate the level of source noise. Then select how much noise to remove, NoiseRemove=1.0 is appropriate for most cases. Then
# decide how much of that noise to restore. There are two restore points called DetailRestore/NoiseRestore (see below), the amount of noise restored depends on
# their sum. A good starting point is 0.7/0.3 for NoiseBypass=1 and 0.3/0.1 for NoiseBypass=2. Note, only luma noise is considered in this script.
#
# Very fine detail can be detected as noise, but fine detail is often lost in the same way as noise. The setting DetailRestore helps restore such detail without
# restoring too much noise, it controls how much of the extracted "noise" is restored before the final temporal smooth. This smooth will remove any actual noise
# but keep fine detail that went through the bypass. By balancing the DetailRestore and NoiseRestore settings you can denoise whilst limiting the removal of
# real detail. Usually best if DetailRestore is greater than NoiseRestore unless seeking to restore actual grain/noise. Start with the values given above, then
# adjust up or down to get the grain/sharpness/detail you want. Too high restoral values will give detail/grain exaggeration and even luma changes.
#
# Settings:
#	NoiseBypass  (0,1,2)         : Noise bypass mode: 0 = disable, 1 = denoise source, storing the removed noise - add some of this noise back at end of script,
#	                             :                    2 = store noise found in source but don't remove it (let QTGMC denoise) - add some back at end of script
#	NoiseRemove  (0.0...1.0)     : How much noise/grain to extract from the source clip (before the main processing)
#	DetailRestore(0.0...1.0...)  : How much removed noise/grain to restore before final temporal smooth. Helps retain detail.
#	NoiseRestore (0.0...1.0...)  : How much removed noise/grain to restore after final temporal smooth. Helps retain detail and noise.
#	NoiseDeint   (string)        : When noise is taken from interlaced source, how to 'deinterlace' it before restoring: "Bob", "DoubleWeave", or "Generate"
#	                             :   "Bob" & "DoubleWeave" are fast but with minor issues: bob may shimmer and doubleweave lags by one frame. "Generate" is a
#	                             :   high quality mode that motion-compensates the noise, but it is slower. Any unknown value selects "DoubleWeave"
#	Sigma        (>= 0.0)        : Amount of noise known to be in the source - typical values are 1.0 - 2.5 for DV. Must be high enough to find noticable noise
#	BT           (0...5)         : Temporal window for noise removal (see FFT3DFilter docs)
#	ShowNoise    (0.0...)        : Display extracted and "deinterlaced" noise rather than normal output. 0.0=off, otherwise multiplier for display contrast, 
#	                             : set to around 6.0-12.0 to ensure noise is visible. Visualising noise helps to determine suitable value for Sigma - you want
#                                : to see noise / noisy detail, but not clean structure such as edges - pause the video when checking this.
#
# For most presets the defaults are: NoiseBypass=0, NoiseRemove=1.0, Noise/DetailRestore=0.0, NoiseDeint="DoubleWeave", Sigma=2.0 and BT varies by preset
# In "Placebo", "Very Slow" the defaults are: NoiseBypass=2, NoiseRemove=1.0, DetailRestore=0.3, NoiseRestore=0.1, Sigma=2.0 & NoiseDeint/BT varies by preset
# Be sure to override all the values you are interested in
#
# Examples:
#	QTGMC( Preset="Slower", NoiseBypass=1, NoiseRemove=1.0, NoiseRestore=1.0, Sigma=2.0 ) # Pass through all the noise of a somewhat noisy source
#	QTGMC( Preset="Slower", NoiseBypass=1, NoiseRemove=1.0, NoiseRestore=0.2, Sigma=2.5 ) # Pass through a little of the noise of a noisy source
#	QTGMC( Preset="Slower", NoiseBypass=2, NoiseRemove=1.0, NoiseRestore=0.4, Sigma=2.5 ) # Using stronger mode 2, retains noise and sharpens slightly
#	QTGMC( Preset="Slower", NoiseBypass=1, NoiseRemove=1.0, NoiseRestore=0.0, Sigma=1.5 ) # Denoise the source (sigma controls amount of denoising)
#	QTGMC( Preset="Slower", NoiseBypass=2, NoiseRemove=1.0, NoiseRestore=0.6, Sigma=1.8, NoiseDeint="Generate" ) # Strengthen with good quality grain
#	QTGMC( Preset="Slower", NoiseBypass=1, NoiseRemove=1.0, DetailRestore=0.8, NoiseRestore=0.3, Sigma=2.0 )     # Denoise, but retain some fine detail
#	QTGMC( Preset="Slower", NoiseBypass=2, NoiseRemove=1.0, DetailRestore=0.4, NoiseRestore=0.2, Sigma=1.8, NoiseDeint="Generate" ) # As above with stronger
#	                                                                                                                                # precise detail & grain

#--- MOTION ANALYSIS ---
#
# Key Points: The presets make sensible choices for motion analysis. Some sources or requirements may require tweaks, but read these and MVTools2 docs first.
#
# The bobbed source clip is sent to the MVTools2 plugin to perform motion analysis. Almost all these settings are used directly in MVTools2 functions.
# Read the MVTools2 documentation for more details on their purpose. Some settings can be altered for a speed / accuracy tradeoff. Less accurate motion search
# can result in blurring and/or oversharpening (in different circumstances) as well as slight distortions of visual elements. The faster presets gain speed by
# simplifying the motion search parameters, use the "ShowSettings" parameter or look at the table a short way into the script to see how.
#
# Settings:
#	SrchClipPP   (0,1,2)         : Pre-processing for motion search clip, 0 = none, 1 = Gauss blur (spatial), 2 = Gauss blur + edge soften
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
#	DCT          (0...10)        : Modes to use DCT (frequency analysis) or SATD as part of the block matching process - see MVTools2 documentation for choices


#--- PROGRESSIVE INPUT ---
#
# Key Points: Can remove horizontal shimmering effects from progressive sources. Experiment with InputType=1, 2 or 3 for best results. FPS will not be doubled
#
# This script is designed for deinterlacing and so by default expects an interlaced clip. However, much of its operation concerns the reduction of horizontal
# shimmering. It is possible to use the script to remove similar shimmer from a progressive clip by using the InputType setting. InputType=1 is used for
# general progressive material that contains less severe problems. InputType=2,3 are designed for badly deinterlaced material with considerable horizontal
# artefacts. These modes drop half the fields and recreate an interlaced stream from the others, which is then treated in the normal way. Mode 3 differs from
# mode 2 only in that it complements field parity of the input. Generally mode 1 will retain more detail, but repair less artefacts than modes 2,3. You may
# consider setting TR2 to a higher value (e.g. 2 or 3) when repairing progressive material.
#
# Source-match and Lossless modes are supported for progressive material. It works well for InputType=2,3, where the input is converted to an interlaced stream,
# and helps in detail retention. Source-match is much less useful for InputType=1
#
# Settings:
#	InputType    (0,1,2,3)       : Default = 0 for interlaced input. Values > 0 to accept progressive input - for deshimmer and denoising (fps not changed)
#	                             : Mode 1 is for general progressive material. Modes 2 & 3 are designed for badly deinterlaced material
# 	ProgSADMask  (0.0...)        : Only applies to InputType=2,3. If ProgSADMask > 0.0 then blend InputType modes 1 and 2/3 based on block motion SAD. Higher
#	                             : values will recover more detail, but repair less artefacts. Reasonable range about 2.0 to 20.0, or 0.0 for no blending
#
# The defaults are InputType=0, ProgSADMask = 10.0 (slower presets) or 0.0 (faster presets)
#
# Examples:
#	QTGMC( Preset="Slower", InputType=1 )                   # Process progressive source, it will be temporally smoothed / deshimmered
#	QTGMC( Preset="Slower", InputType=2, ProgSADMask=12.0 ) # Process progressive source with major artefacts, slightly favoring detail over repairs


#--- MOTION BLUR / FRAME RATE CONTROL ---
#
# Key Points: Can output video at single or double-frame rate. For smoother playback can add motion blur to simulate different shutter angles (shutter speeds)
#
# By default QTGMC outputs video at "double-rate", twice the frame rate of the source. This is because there are two separate images (fields) in every frame,
# which the deinterlacing process restores in full. By setting FPSDivisor to 2, every second frame is dropped and the output frame rate is the same as the
# source ("single-rate")
#
# Single-rate output may look a little stuttery, depending on how the source was filmed/created. Adding motion blur to each frame can help with this, smoothing
# the feel of the slower rate playback. This is done by setting MotionBlur to 1,2 or 3, then specifying the shutter angle that you wish the output to simulate.
# However, as there may be some motion blur already in the source you also need to specify/estimate the shutter angle used in the source. Shutter angles range
# from 0 to 360, with 0 being perfectly sharp and 360 being fully blurred from one frame to next (artificial output shutter angles > 360 are supported to a very
# limited degree). Motion-blur can also be applied to double-rate output, but the effect is less noticable
#
# As motion analysis is block-based, motion blur of an object can "bleed" into surrounding, more static areas. This can be reduced using the slower MotionBlur
# modes or by increasing the MBlurLimit setting (which is enabled and set to 4 by default). Both repair methods may reduce the level of motion blur a little
# though. In situations of complex motion the motion analysis can be incorrect, which can lead to inappropriate blurring.
#
# Settings:
#	FPSDivisor   (1,2...)        : 1 = Double-rate output, 2 = Single-rate output. Higher values can be used too (e.g. 60fps & FPSDivisor=3 gives 20fps output)
#	MotionBlur   (0,1,2,3)       : 0 = Off, 1 = Enable, 2,3 = Higher precisions (slower). Higher precisions reduce blur "bleeding" into static areas a little
#	ShutterAngleSrc (0..360)     : Shutter angle used in source. If necessary, estimate from motion blur seen in a single frame: 0=pin-sharp, 360=fully blurred
#	ShutterAngleOut (0..360...)  : Shutter angle to simulate in output. Extreme values may be rejected (depends on other settings). Cannot reduce motion blur
#	MBlurLimit   (0...)          : Limit motion blur where motion lower than given value. Increase to reduce blur "bleeding". 0=Off. Sensible range around 2-12
#
# The defaults are FPSDivisor=1, MotionBlur=0, ShutterAngleSrc=180, ShutterAngleOut=180, MBlurLimit=4
#
# Examples:
#	QTGMC( Preset="Slower", FPSDivisor=2, MotionBlur=1, ShutterAngleSrc=30,  ShutterAngleOut=180 ) # Smooth single-rate output, when input has little blur
#	QTGMC( Preset="Slower", FPSDivisor=2, MotionBlur=1, ShutterAngleSrc=180, ShutterAngleOut=180 ) # Keep "film" look on single-rate output, "film" input
#	QTGMC( Preset="Slower", FPSDivisor=2, MotionBlur=2, ShutterAngleSrc=180, ShutterAngleOut=180, MBlurLimit=8 ) # Same but srongly reduce blur "bleeding"
#	QTGMC( Preset="Slower", FPSDivisor=1, MotionBlur=1, ShutterAngleSrc=0,   ShutterAngleOut=720 ) # Blur some high shutter-speed footage - keep double rate
#                                                                                                  # [Use of artificially high shutter angles is limited]


#--- MISCELLANEOUS ---
#
# Settings not covered above. Note that Border is false by default, which differs from TempGaussMC
#
# Settings:
#	Border       (bool)          : Pad a little vertically while processing (doesn't affect output size) - set true you see flickering on the very top or bottom
#	                             : line of the output. If you have wider edge effects than that, you should crop afterwards instead
#	Precise      (bool)          : Set to false to use faster algorithms with *very* slight imprecision in places
#	Preset       (string)        : Sets a range of defaults for different encoding speeds. Select from "Placebo", "Very Slow", "Slower", "Slow", "Medium",
#	                             : "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast" & "Draft"
#	Tuning       (string)        : Tweaks the defaults for different source types. Choose from "None", "DV-SD", "DV-HD". Default is "None".
#	                             : An idea for development based on the x264 approach, but as I don't work with many source types it has seen little development
#	SafeMode     (bool)          : Avoid settings that potentially cause errors with other plugins. Use if "Ultra Fast" preset causes crashes.
#	ShowSettings (bool)          : Display all the current parameter values - useful to find preset defaults


# --- TempGaussMC NOTES ---
#
# In its default setup this script is very similar in operation to TempGaussMC_beta2. The call QTGMC() is almost exactly the same as:
#   TempGaussMC_beta2( 2,2,1, EdiMode="nnedi3", Border=false, SVthin=0.0 )
# There are a few key differences:
#	Sharpness default is always 1.0 (or 0.2 if using source-match) - adjusted internally to give very roughly the same sharpness across settings / presets
#	SVThin defaults to 0, Border defaults to false
#	Lossless and Draft modes are supported but in a different way
#	The parameter order is the same up to "EdiMode", a couple of 'lesser' parameters have had name changes for consistency


function QTGMC( clip Input, int "TR0", int "TR1", int "TR2", int "Rep0", int "Rep1", int "Rep2", bool "RepChroma", string "EdiMode", int "NNSize", \
                int "NNeurons", int "EdiQual", int "EdiMaxD", int "EdiThreads", clip "EdiExt", float "Sharpness", int "SMode", int "SLMode", int "SLRad", \
                int "SOvs", float "SVThin", int "Sbb", int "SrchClipPP", int "SubPel", int "SubPelInterp", int "BlockSize", int "Overlap", int "Search", \
                int "SearchParam", int "PelSearch", bool "TrueMotion", int "Lambda", int "LSAD", int "PNew", int "PLevel", bool "GlobalMotion", int "DCT", \
                int "SourceMatch", string "MatchPreset", string "MatchEdi", string "MatchPreset2", string "MatchEdi2", int "MatchTR2", \
                float "MatchEnhance", int "Lossless", int "NoiseBypass", float "NoiseRemove", float "DetailRestore", float "NoiseRestore", \
                string "NoiseDeint", float "Sigma", int "BT", int "InputType", float "ProgSADMask",  int "FPSDivisor", int "MotionBlur", \
                float "ShutterAngleSrc", float "ShutterAngleOut", int "MBlurLimit", bool "Border", bool "Precise", string "Preset", string "Tuning", \
                bool "SafeMode", float "ShowNoise", bool "ShowSettings" )
{
	# The preset "Ultra Fast" & EdiMode="TDIYadif"/"Yadif" require the Yadif plugin, which doesn't autoload. Typically the calling script would load it.
	# To have this script load Yadif put it's full path in string below (e.g. "C:\Plugins\Yadif.dll"). Use empty string ("") if calling script will load Yadif
	YadifPath = "" # Or just enter "yadif.dll" if Yadif is placed in the system path (e.g. windows\system32)


	#---------------------------------------
	# Presets

	SafeMode = default( SafeMode, false )

	# Select presets / tuning
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
	       (Preset == "Draft"     ) ? 10 : 11
	Assert( pNum  < 11, "'Preset' is invalid" )
	mpNum1 = (!defined(MatchPreset))       ? ((pNum + 3 <= 9) ? (pNum + 3) : 9) : \
	         (MatchPreset == "Placebo"   ) ? 0 : \
	         (MatchPreset == "Very Slow" ) ? 1 : \
	         (MatchPreset == "Slower"    ) ? 2 : \
	         (MatchPreset == "Slow"      ) ? 3 : \
	         (MatchPreset == "Medium"    ) ? 4 : \
	         (MatchPreset == "Fast"      ) ? 5 : \
	         (MatchPreset == "Faster"    ) ? 6 : \
	         (MatchPreset == "Very Fast" ) ? 7 : \
	         (MatchPreset == "Super Fast") ? 8 : \
	         (MatchPreset == "Ultra Fast") ? 9 : \
	         (MatchPreset == "Draft"     ) ? 10 : 11
	Assert( mpNum1 < 10, "'MatchPreset' is invalid/unsupported" )
	MatchPreset = Select( mpNum1, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )
	mpNum2 = (!defined(MatchPreset2))       ? ((mpNum1 + 2 <= 9) ? (mpNum1 + 2) : 9) : \
	         (MatchPreset2 == "Placebo"   ) ? 0 : \
	         (MatchPreset2 == "Very Slow" ) ? 1 : \
	         (MatchPreset2 == "Slower"    ) ? 2 : \
	         (MatchPreset2 == "Slow"      ) ? 3 : \
	         (MatchPreset2 == "Medium"    ) ? 4 : \
	         (MatchPreset2 == "Fast"      ) ? 5 : \
	         (MatchPreset2 == "Faster"    ) ? 6 : \
	         (MatchPreset2 == "Very Fast" ) ? 7 : \
	         (MatchPreset2 == "Super Fast") ? 8 : \
	         (MatchPreset2 == "Ultra Fast") ? 9 : \
	         (MatchPreset2 == "Draft"     ) ? 10 : 11
	Assert( mpNum2 < 10, "'MatchPreset2' is invalid/unsupported" )
	MatchPreset2 = Select( mpNum2, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )
	Tuning = default( Tuning, "None" )
	tNum = (Tuning == "None"  ) ? 0 : \
	       (Tuning == "DV-SD" ) ? 1 : \
	       (Tuning == "DV-HD" ) ? 2 : 3
	Assert( tNum < 3, "'Tuning' is invalid" )

	# Tunings only affect blocksize in this version
	bs = Select( tNum,  16, 16, 32 )
	bs2 = (bs >= 16) ? 32 : bs * 2
	ovf = (SafeMode) ? 2 : 4    # Overlap other than 1/2 blocksize sometimes causes crashes in MVTools (??)

	#                                                               Very                                                        Very      Super      Ultra
	# Preset groups:                                     Placebo    Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast       Fast      Draft
	TR0          = default( TR0,          Select( pNum,  2,         2,        2,        2,        2,        2,        1,        1,        1,         1,        1      ))
	TR1          = default( TR1,          Select( pNum,  2,         2,        2,        1,        1,        1,        1,        1,        1,         1,        1      ))
	TR2          = default( TR2,          Select( pNum,  3,         2,        1,        1,        1,        0,        0,        0,        0,         0,        0      ))
	Rep0         = default( Rep0,         Select( pNum,  4,         4,        4,        4,        3,        3,        0,        0,        0,         0,        0      ))
	Rep1         = default( Rep1,         Select( pNum,  0,         0,        0,        0,        0,        0,        0,        0,        0,         0,        0      ))
	Rep2         = default( Rep2,         Select( pNum,  4,         4,        4,        4,        4,        4,        4,        4,        3,         3,        0      ))
	EdiMode      = default( EdiMode,      Select( pNum, "NNEDI3",  "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3",  "Yadif",   ""     ))
	NNSize       = default( NNSize,       Select( pNum,  1,         1,        1,        1,        5,        5,        4,        4,        4,         4,        4      ))
	NNeurons     = default( NNeurons,     Select( pNum,  2,         2,        1,        1,        1,        0,        0,        0,        0,         0,        0      ))
	EdiMaxD      = default( EdiMaxD,      Select( pNum,  12,        10,       8,        7,        7,        6,        6,        5,        4,         4,        4      ))
	EdiQual      = default( EdiQual,      Select( pNum,  1,         1,        1,        1,        1,        1,        1,        1,        1,         1,        1      ))
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
	ProgSADMask  = default( ProgSADMask,  Select( pNum,  10.0,      10.0,     10.0,     10.0,     10.0,     0.0,      0.0,      0.0,      0.0,       0.0,      0.0    ))

	# The basic source-match step corrects and re-runs the interpolation of the input clip. So it initialy uses same interpolation settings as the main preset
	SourceMatch   = default( SourceMatch, 0 )
	MatchNNSize   = NNSize
	MatchNNeurons = NNeurons
	MatchEdiMaxD  = EdiMaxD
	MatchEdiQual  = EdiQual

	# However, can use a faster initial interpolation when using source-match allowing the basic source-match step to "correct" it with higher quality settings
	Assert( SourceMatch == 0 || mpNum1 >= pNum, "'MatchPreset' cannot use a slower setting than 'Preset'" )
	#                                                                    Very                                                        Very      Super     Ultra
	# Basic source-match presets                                Placebo  Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
	NNSize   = (SourceMatch == 0) ? NNSize   : Select( mpNum1,  1,       1,        1,        1,        5,        5,        4,        4,        4,        4     )
	NNeurons = (SourceMatch == 0) ? NNeurons : Select( mpNum1,  2,       2,        1,        1,        1,        0,        0,        0,        0,        0     )
	EdiMaxD  = (SourceMatch == 0) ? EdiMaxD  : Select( mpNum1,  12,      10,       8,        7,        7,        6,        6,        5,        4,        4     )
	EdiQual  = (SourceMatch == 0) ? EdiQual  : Select( mpNum1,  1,       1,        1,        1,        1,        1,        1,        1,        1,        1     )
	TempEdi  = EdiMode # Main interpolation is actually done by basic-source match step when enabled, so a little swap and wriggle is needed
	EdiMode  = (SourceMatch == 0) ? EdiMode  : default( MatchEdi, ((mpNum1 < 9) ?  EdiMode : "Yadif") ) # Force Yadif for "Ultra Fast" basic source match
	MatchEdi = TempEdi 
    
	#                                                Very                                                        Very      Super     Ultra
	# Refined source-match presets                   Placebo   Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
	MatchEdi2 = default( MatchEdi2, Select( mpNum2, "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "TDeint",  ""    ) )
	MatchNNSize2                  = Select( mpNum2,  1,        1,        1,        1,        5,        5,        4,        4,        4,        4     )
	MatchNNeurons2                = Select( mpNum2,  2,        2,        1,        1,        1,        0,        0,        0,        0,        0     )
	MatchEdiMaxD2                 = Select( mpNum2,  12,       10,       8,        7,        7,        6,        6,        5,        4,        4     )
	MatchEdiQual2                 = Select( mpNum2,  1,        1,        1,        1,        1,        1,        1,        1,        1,        1     )


	#---------------------------------------
	# Settings

	# Core and Interpolation defaults
	RepChroma  = default( RepChroma,  true )
	EdiThreads = default( EdiThreads, 0    )
	NNeurons   = (EdiMode == "NNEDI2" && NNeurons > 2) ? 2 : NNeurons # Smaller range for NNeurons in NNEDI2 (which calls it nsize)
	EdiQual    = (EdiMode == "NNEDI3" && EdiQual > 2 ) ? 2 : EdiQual  # Smaller range for EdiQual in NNEDI3
	((FindStr( EdiMode, "Yadif" ) != 0 || FindStr( MatchEdi, "Yadif" ) != 0 || FindStr( MatchEdi2, "Yadif" ) != 0  ) && YadifPath != "") ? \
		Load_Stdcall_Plugin( YadifPath ) : NOP() # Load Yadif as required

	# Source-match / lossless defaults
	MatchTR1     = TR1
	MatchTR2     = default( MatchTR2,     1   )
	MatchEnhance = default( MatchEnhance, 0.5 )
	Lossless     = default( Lossless,     0   )
	Assert( Lossless <= 2, "Lossless setting only supports mode 1 ('true lossless') and mode 2 ('fake lossless') - see documentation in script and consider source-match settings" )

	# Sharpness defaults. Sharpness default is always 1.0 (0.4 with source-match), but adjusted to give roughly same sharpness for all settings
	SMode      = (defined(Sharpness) && Sharpness == 0.0) ? 0 : SMode
	SLMode     = (SourceMatch > 0 || SLRad <= 0)          ? 0 : SLMode  # ***Sharpness limiting disabled for source-match***
	spatialSL  = (SLMode == 1 || SLMode == 3)
	temporalSL = (SLMode == 2 || SLMode == 4)
	Sharpness  = default( Sharpness, (SMode == 0) ? 0.0 : ((SourceMatch > 0) ? 0.2 : 1.0) )      # Default sharpness is 1.0, or 0.2 if using source-match
	sharpMul   = (temporalSL) ? 2 : (spatialSL) ? 1.5 : 1                                        # Adjust sharpness based on other settings
	sharpAdj   = Sharpness * (sharpMul * (0.2 + TR1*0.15 + TR2*0.25) + ((SMode == 1) ? 0.1 : 0)) # [This needs a bit more refinement]
	Sbb        = (SMode == 0) ? 0 : Sbb
	SOvs       = default( SOvs,   0   )
	SVThin     = default( SVThin, 0.0 )

	# Noise bypass settings
	ShowNoise     = default( ShowNoise, 0.0 )
	NoiseBypass   = (ShowNoise > 0.0) ? 2 : NoiseBypass
	NoiseRemove   = default( NoiseRemove,   Select( NoiseBypass, 1.0, 1.0, 1.0 ))
	DetailRestore = default( DetailRestore, Select( NoiseBypass, 0.0, 0.7, 0.3 ))
	NoiseRestore  = default( NoiseRestore,  Select( NoiseBypass, 0.0, 0.3, 0.1 ))
	Sigma         = default( Sigma, 2.0 )
	NoiseBypass   = (NoiseRemove <= 0.0) ? 0   : NoiseBypass
	NoiseRemove   = (NoiseBypass == 0)   ? 0.0 : NoiseRemove
	DetailRestore = (NoiseBypass == 0)   ? 0.0 : DetailRestore
	NoiseRestore  = (NoiseBypass == 0)   ? 0.0 : NoiseRestore
	totalRestore  = DetailRestore + NoiseRestore

	# MVTools settings
	SubPelInterp = default( SubPelInterp, 2     )
	TrueMotion   = default( TrueMotion,   false )
	Lambda       = default( Lambda,      ((TrueMotion) ? 1000 : 100 ) * (BlockSize*BlockSize)/(8*8) )
	LSAD         = default( LSAD,         (TrueMotion) ? 1200 : 400 )
	PNew         = default( PNew,         (TrueMotion) ? 50   : 25  )
	PLevel       = default( PLevel,       (TrueMotion) ? 1    : 0   )
	GlobalMotion = default( GlobalMotion, true  )
	DCT          = default( DCT,          0     )

	# Some sensitive MVTools settings are no longer parameters
	_thSAD1 = 10 * 8*8  # SAD threshold for motion block matching: for intial temporal smooth (over 8x8 block as required by MVTools)
	_thSAD2 =  4 * 8*8  # SAD threshold for motion block matching: stabilising temporal smooth (--"--)
	_thSCD1 = 180       # Scene change detection parameter
	_thSCD2 = 98        # --"--

	# Motion blur settings
	FPSDivisor = default( FPSDivisor, 1 )
	MotionBlur = default( MotionBlur, 0 )
	ShutterAngleSrc = default( ShutterAngleSrc, 180 )
	ShutterAngleOut = default( ShutterAngleOut, 180 )
	MBlurLimit = default( MBlurLimit, 4 )
	MotionBlur = (ShutterAngleOut * FPSDivisor == ShutterAngleSrc) ? 0 : MotionBlur  # If motion blur output is same as input
    
	# Miscellaneous
	InputType    = default( InputType,    0     )
	Border       = default( Border,       false )
	ShowSettings = default( ShowSettings, false )
	ProgSADMask  = (InputType != 2 && InputType != 3) ? 0.0 : ProgSADMask
	useMCNoise   = (InputType == 0 && totalRestore > 0.0 && NoiseDeint == "Generate")
	rgBlur       = (Precise) ? 11 : 12  # Version of RemoveGrain blur to use

	# Get maximum temporal radius needed
	maxTR = (temporalSL)       ? SLRad : 0
	maxTR = (MatchTR2 > maxTR) ? MatchTR2 : maxTR
	maxTR = (TR1 > maxTR)      ? TR1 : maxTR 
   	maxTR = (TR2 > maxTR)      ? TR2 : maxTR
	maxTR = (ProgSADMask > 0.0 || useMCNoise || MotionBlur > 0) ? (maxTR > 1 ? maxTR : 1) : maxTR

	
	#---------------------------------------
	# Pre-Processing

	w = Input.Width()
	h = Input.Height()
	epsilon = 0.0001   # Error margin to avoid rounding problems

	# Reverse "field" dominance for progressive repair mode 3 (only difference from mode 2)
	compl = (InputType == 3) ? Input.ComplementParity() : Input

	# Pad vertically during processing (to prevent artefacts at top & bottom edges)
	bordered = (Border) ? compl.PointResize( w,h+8, 0,-4,0,h+8+epsilon ) : compl
	h = (Border) ? h+8 : h

	# Extract noise/grain from source, keep removed noise for restoring later. If NoiseBypass == 2, the noise is extracted and stored but not removed from
	# the source - allowing the QTGMC process to do the denoising (avoids effectively denoising twice)
	denoised = (NoiseBypass > 0)    ? bordered.FFT3DFilter( sigma=Sigma, beta=1.0 / NoiseRemove, bt=BT, interlaced=(InputType == 0), plane=0 ) : bordered
	noise    = (totalRestore > 0.0) ? mt_makediff( bordered, denoised, U=1,V=1 ) : NOP()
	clip     = (NoiseBypass == 1)   ? denoised : bordered

	# 'Deinterlace' the extracted noise. Noise is extracted from interlaced source but will be added back to progressive, so create the missing lines of noise.
	deintNoise = (NoiseBypass == 0 || totalRestore == 0.0) ? NOP() : \
	             (InputType != 0)                          ? noise : \
	             (NoiseDeint == "Bob")                     ? noise.Bob( 0,0.5 ) : \
	             (NoiseDeint == "Generate")                ? noise.Generate2ndFieldNoise() : \
	                                                         noise.DoubleWeave()

															 
	#---------------------------------------
	# Motion Analysis

	# Bob the input as a starting point for motion search clip
	bobbed = (InputType == 0) ? clip.Bob( 0,0.5 ) : \
	         (InputType == 1) ? clip : \
	                            clip.Blur( 0,1 )

	# Support badly deinterlaced progressive content - drop half the fields and reweave to get 1/2fps interlaced stream appropriate for QTGMC processing
	ediInput = (InputType == 2 || InputType == 3) ? clip.SeparateFields().SelectEvery(4,0,3).Weave() : clip

	# Create interpolated image as starting point for output
	edi = defined(EdiExt) ? EdiExt.PointResize( w,h, 0,(EdiExt.Height()-h)/2, -0,h+epsilon ) : \
	                        Interpolate( ediInput, InputType, EdiMode, NNSize, NNeurons, EdiQual, EdiMaxD, EdiThreads, bobbed )

	# WARNING: Excessively long comment to precisely capture the algorithm
	# The bobbed clip will shimmer due to being derived from alternating fields, which makes motion analysis erratic. Blurring the image over a few frames will
	# remove the shimmer if done precisely. The shimmer will be an alternating effect between even and odd fields. We can guarantee to remove a shimmer of this
	# frequency by giving equal overall weight to the even and odd fields in the temporal average. For example, give the three frames centered on the current
	# frame the weights: 1, 2, 1 - this gives 50% weight to the central frame, and *a total* of 50% weight for the previous/next (opposite parity) frames. The
	# alternating shimmer is averaged away by such a kernel and for a temporal radius of 1 it's actually the only choice. For a wider temporal radius of 2, we
	# have a few choices of kernel, e.g. 1,3,4,3,1 or 1,4,6,4,1 or 2,3,2,3,2 etc. Any kernel where the odd values total to the same as the even values.
	# Now, a gaussian temporal blur is a decent pre-filter before a motion search - keeping the central frame prominent, but also removing high frequency noise
	# that would disturb the search. The kernel 1,4,6,4,1 above is a close approximation to a Gaussian kernel, so is chosen for the default temporal radius of 2
	# Actually the kernels 1,2,1 and 1,4,6,4,1 are *not* Gaussian kernels, but *Binomial* kernels. The kernel weights are taken from the coefficients of the
	# polynomial (x+1)^n, where n = (temporal radius * 2). Or more simply odd rows taken from "Pascal's Triangle". All Binomial kernels satisfy the "sum of odd
	# weights = sum of even weights" concept and they are all good approximations to Gaussian kernels. But it does imply that this script (and the original)
	# should properly be called (Q)TBMC: Temporal Binomial smooth with Motion-Compensation

	# Create linear weightings of neighbors first                            -2    -1     0    1     2
	ts1 = (TR0 > 0) ? bobbed.TemporalSoften( 1, 255,255, 28, 2 ) : NOP()  # 0.00  0.33  0.33  0.33  0.00
	ts2 = (TR0 > 1) ? bobbed.TemporalSoften( 2, 255,255, 28, 2 ) : NOP()  # 0.20  0.20  0.20  0.20  0.20

	# Combine linear weightings to give binomial weightings - TR0=0: (1), TR0=1: (1:2:1), TR0=2: (1:4:6:4:1)
	binomial0 = (TR0 == 0) ? bobbed : \
	            (TR0 == 1) ? ts1.Merge( bobbed, 0.25 ) : \
	                         ts1.Merge( ts2, 0.357 ).Merge( bobbed, 0.125 )

	# Remove areas of difference between temporal blurred motion search clip and bob that are not due to bob-shimmer - removes general motion blur
	repair0 = (Rep0 == 0) ? binomial0 : binomial0.RemoveNonBobDiff( bobbed, Rep0, RepChroma )

	# Soften edges to assist in motion matching of edge blocks. Blocks are matched by SAD (sum of absolute differences between blocks), but even a slight
	# difference around an edge from frame to frame will give a high SAD due to the higher contrast of edges
	spatialBlur = (SrchClipPP > 0)  ? repair0.RemoveGrain(rgBlur).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=2 ).Merge( repair0, 0.1 ) : NOP()
	tweaked     = (SrchClipPP > 1)  ? mt_lutxy( repair0, bobbed, "x 3 + y < x 3 + x 3 - y > x 3 - y ? ?", U=3,V=3 ) : NOP()
	srchClip    = (SrchClipPP == 0) ? repair0 : \
	              (SrchClipPP == 1) ? spatialBlur : \
	                                  spatialBlur.mt_lutxy( tweaked, "x 7 + y < x 2 + x 7 - y > x 2 - x 51 * y 49 * + 100 / ? ?", U=3,V=3 )

	# Calculate forward and backward motion vectors from motion search clip
	srchSuper =  (maxTR > 0) ? srchClip.MSuper( pel=SubPel, sharp=SubPelInterp ) : NOP()
	bVec3 = (maxTR > 2) ? srchSuper.MAnalyse( isb=true,  delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()
	bVec2 = (maxTR > 1) ? srchSuper.MAnalyse( isb=true,  delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()
	bVec1 = (maxTR > 0) ? srchSuper.MAnalyse( isb=true,  delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()
	fVec1 = (maxTR > 0) ? srchSuper.MAnalyse( isb=false, delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()
	fVec2 = (maxTR > 1) ? srchSuper.MAnalyse( isb=false, delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()
	fVec3 = (maxTR > 2) ? srchSuper.MAnalyse( isb=false, delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, pelsearch=PelSearch, \
	                                          truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, global=GlobalMotion, DCT=DCT ) : NOP()

	# InputType=2,3: use motion mask to blend luma between original clip & reweaved clip based on ProgSADMask setting. Use chroma from original clip in any case
	inputTypeBlend = (ProgSADMask > 0.0) ? MMask( srchClip, bVec1, kind=1, ml=ProgSADMask ) : NOP()
	edi = (InputType != 2 && InputType != 3) ? edi : \
	      (ProgSADMask <= 0.0)               ? edi.MergeChroma( clip ) : \
	                                           mt_merge( clip, edi, inputTypeBlend, U=2,V=2 )

	# Get the max/min value for each pixel over neighboring motion-compensated frames - used for temporal sharpness limiting
	ediSuper = (TR1 > 0) ? edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	bComp1   = (temporalSL)              ? edi.MCompensate( ediSuper, bVec1, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : NOP()
	fComp1   = (temporalSL)              ? edi.MCompensate( ediSuper, fVec1, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : NOP()
	tMax     = (temporalSL)              ? edi.mt_logic( fComp1, "max", U=3,V=3 ).mt_logic( bComp1, "max", U=3,V=3 )  : NOP()
	tMin     = (temporalSL)              ? edi.mt_logic( fComp1, "min", U=3,V=3 ).mt_logic( bComp1, "min", U=3,V=3 )  : NOP()
	bComp3   = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, bVec3, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : NOP()
	fComp3   = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, fVec3, thSCD1=_thSCD1,thSCD2=_thSCD2 )          : NOP()
	tMax     = (SLRad > 1 && temporalSL) ? tMax.mt_logic( fComp3, "max", U=3,V=3 ).mt_logic( bComp3, "max", U=3,V=3 ) : tMax
	tMin     = (SLRad > 1 && temporalSL) ? tMin.mt_logic( fComp3, "min", U=3,V=3 ).mt_logic( bComp3, "min", U=3,V=3 ) : tMin

	# Motion-compensate generated noise
	noiseSuper = (useMCNoise) ? deintNoise.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, chroma=false ) : NOP()
	mcNoise    = (useMCNoise) ? deintNoise.MCompensate( noiseSuper, bVec1, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : NOP()
	finalNoise = (useMCNoise) ? mt_lutxy( deintNoise, mcNoise, "x 128 - abs y 128 - abs > x y ? 0.6 * x y + 0.2 * +", U=1,V=1 ) : deintNoise


	#---------------------------------------
	# Create Output

	# Create basic ouput: use motion vectors to blur interpolated image (edi) with motion-compensated previous and next frames. As above, this is done to
	# remove shimmer from alternate frames so the same binomial kernels are used. However, by using motion-compensated smoothing this time we avoid motion blur.
	# The use of MDegrain1 (motion compensated) rather than TemporalSmooth makes the weightings *look* different, but they evaluate to the same values
	# Create linear weightings of neighbors first                                                                           -2    -1     0    1     2
	degrain1 = (TR1 > 0) ? edi.MDegrain1( ediSuper, bVec1,fVec1, thSAD=_thSAD1, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : NOP()  # 0.00  0.33  0.33  0.33  0.00
	degrain2 = (TR1 > 1) ? edi.MDegrain1( ediSuper, bVec2,fVec2, thSAD=_thSAD1, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : NOP()  # 0.33  0.00  0.33  0.00  0.33

	# Combine linear weightings to give binomial weightings - TR1=0: (1), TR1=1: (1:2:1), TR1=2: (1:4:6:4:1)
	binomial1 = (TR1 == 0) ? edi : \
	            (TR1 == 1) ? degrain1.Merge( edi, 0.25 ) : \
	                         degrain1.Merge( degrain2, 0.2 ).Merge( edi, 0.0625 )

	# Remove areas of difference between smoothed image and interpolated image that are not bob-shimmer fixes: repairs residual motion blur from temporal smooth
	repair1 = (Rep1 == 0) ? binomial1 : binomial1.RemoveNonBobDiff( edi, Rep1, RepChroma )

	# Apply source match - use difference between output and source to succesively refine output [extracted to function to clarify main code path]
	match = (SourceMatch == 0) ? repair1 : \
	                             repair1.ApplySourceMatch( InputType, EdiInput, bVec1, fVec1, bVec2, fVec2, SubPel, SubPelInterp, _thSAD1, _thSCD1, _thSCD2, \
	                                                       SourceMatch, MatchTR1, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads, \
	                                                       MatchEnhance, MatchTR2, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2 )
    
	# Lossless=2 - after preparing an interpolated, de-shimmered clip, restore the original source fields into it and clean up any artefacts.
	# This mode will not give a true lossless result because the resharpening and final temporal smooth are still to come, but it will add further detail.
	# However, it can introduce minor combing. This setting is best used together with source-match (it's effectively the final source-match stage).
	lossed1 = (Lossless == 2) ? MakeLossless( match, clip, InputType ) : match

	# Resharpen to counteract temporal blurs. Little sharpening needed for source-match mode since already as sharp as source
	vresharp1 = (SMode == 2) ? Merge( lossed1.mt_expand( mode="vertical", U=3,V=3 ), lossed1.mt_inpand( mode="vertical", U=3,V=3 ) ) : NOP()
	vresharp  = (Precise && SMode == 2) ? vresharp1.mt_lutxy( lossed1, "x y < x 1 + x y > x 1 - x ? ?", U=3,V=3 ) : vresharp1 # Precise mode: reduce tiny overshoot
	resharp   = (SMode == 0) ? lossed1 : \
	            (SMode == 1) ? lossed1.mt_lutxy( lossed1.RemoveGrain(rgBlur),  "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 ) : \
	                           lossed1.mt_lutxy( vresharp.RemoveGrain(rgBlur), "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 )

	# Slightly thin down 1-pixel high horizontal edges that have been widened into neigboring field lines by the interpolator
	SVThinSc  = SVThin * 6.0
	vertMedD  = (SVthin > 0.0) ? mt_lutxy( lossed1, lossed1.VerticalCleaner(mode=1), "y x - " + string(SVThinSc) + " * 128 +", U=1,V=1 ).Blur( 1,0 ) : NOP()
	neighborD = (SVthin > 0.0) ? mt_lutxy( vertMedD, vertMedD.RemoveGrain( rgBlur,-1 ), "y 128 - abs x 128 - abs > y 128 ?" ) : NOP()
	thin      = (SVthin > 0.0) ? resharp.mt_adddiff( neighborD, U=2,V=2 ) : resharp

	# Back blend the blurred difference between sharpened & unsharpened clip, before (1st) sharpness limiting (Sbb == 1,3). A small fidelity improvement
	backBlend1 = (Sbb != 1 && Sbb != 3) ? thin \
		: thin.mt_makediff( mt_makediff( thin, lossed1, U=1,V=1 ).RemoveGrain( rgBlur, -1 ).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 )

	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
	# Occurs here (before final temporal smooth) if SLMode == 1,2. This location will restrict sharpness more, but any artefacts introduced will be smoothed
	sharpLimit1 = (SLMode == 1) ? backBlend1.Repair( ((SLrad <= 1) ? edi : backBlend1.Repair( edi, 12 )), 1 ) : \
	              (SLMode == 2) ? backBlend1.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) : \
	                              backBlend1

	# Back blend the blurred difference between sharpened & unsharpened clip, after (1st) sharpness limiting (Sbb == 2,3). A small fidelity improvement
	backBlend2 = (Sbb < 2) ? sharpLimit1 \
		: sharpLimit1.mt_makediff( mt_makediff( sharpLimit1, lossed1, U=1,V=1 ).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 )

	# Add back any extracted noise, prior to final temporal smooth - this will restore detail that was removed as "noise" without restoring the noise itself
	# Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
	addNoise1 = (DetailRestore > 0.0) ? backBlend2.mt_adddiff( deintNoise.mt_lut( "x 128.5 - " + string(DetailRestore) + " * 128 +", U=1,V=1 ), U=2,V=2 ) : backBlend2

	# Final light linear temporal smooth for denoising
	stableSuper = (TR2 > 0) ? addNoise1.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	stable  = (TR2 == 0) ? addNoise1 : \
	          (TR2 == 1) ? addNoise1.MDegrain1( stableSuper, bVec1,fVec1,                           thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : \
	          (TR2 == 2) ? addNoise1.MDegrain2( stableSuper, bVec1,fVec1, bVec2,fVec2,              thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : \
 	                       addNoise1.MDegrain3( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, thSAD=_thSAD2, thSCD1=_thSCD1,thSCD2=_thSCD2 )

	# Remove areas of difference between final output & basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal smooth
	repair2 = (Rep2 == 0) ? stable : stable.RemoveNonBobDiff( edi, Rep2, RepChroma )

	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
	# Occurs here (after final temporal smooth) if SLMode == 3,4. Allows more sharpening here, but more prone to introducing minor artefacts
	sharpLimit2 = (SLMode == 3) ? repair2.Repair( ((SLrad <= 1) ? edi : repair2.Repair( edi, 12 )), 1 ) : \
	              (SLMode == 4) ? repair2.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) : \
	                              repair2


	#---------------------------------------
	# Post-Processing

	# Lossless=1 - inject source fields into result and clean up inevitable artefacts. Provided NoiseRestore=0, this mode will make the script result properly
	# lossless, but it will strongly retain source artefacts
	lossed2 = (Lossless == 1) ? MakeLossless( sharpLimit1, clip, InputType ) : sharpLimit1

	# Add back any extracted noise, after final temporal smooth. This will appear as noise/grain in the output
	# Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
	addNoise2 = (NoiseRestore > 0.0) ? lossed2.mt_adddiff( deintNoise.mt_lut( "x 128.5 - " + string(NoiseRestore) + " * 128 +", U=1,V=1 ), U=2,V=2 ) : lossed2

	# Motion blur - get level of blur depending on output framerate and blur already in source
	blurLevel = (ShutterAngleOut * FPSDivisor - ShutterAngleSrc) * 100.0 / 360.0
	Assert( blurLevel >= 0, "Cannot reduce motion blur already in source: increase ShutterAngleOut or FPSDivisor" )
	Assert( blurLevel <= 200, "Exceeded maximum motion blur level: decrease ShutterAngleOut or FPSDivisor" )

	# MotionBlur mode 2,3 - get finer resolution motion vectors to reduce blur "bleeding" into static areas
	rBlockSize = BlockSize / Select( MotionBlur, 1, 1, 2, 4 )
	rOverlap   = Overlap   / Select( MotionBlur, 1, 1, 2, 4 )
	rBlockSize = (rBlockSize < 4) ? 4 : rBlockSize
	rOverlap   = (rOverlap   < 2) ? 2 : rOverlap
	mbBVec1 = (MotionBlur > 1) ? srchSuper.MRecalculate( bVec1, thSAD=_thSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, \
	                                                     searchparam=SearchParam, truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT ) : bVec1
	mbFVec1 = (MotionBlur > 1) ? srchSuper.MRecalculate( fVec1, thSAD=_thSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, \
                                                         searchparam=SearchParam, truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT ) : fVec1

	# Motion blur - use MFlowBlur to blur along motion vectors
	mblurSuper = (MotionBlur > 0) ? addNoise2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	mblur =      (MotionBlur > 0) ? addNoise2.MFlowBlur( mblurSuper, mbBVec1, mbFVec1, blur=blurLevel, thSCD1=_thSCD1,thSCD2=_thSCD2 ) : NOP()
    
	# Motion blur - use motion mask to reduce blurring in areas of low motion - also helps reduce blur "bleeding" into static areas, then select blur type
	mbMotionMask = (MotionBlur > 0 && MBlurLimit > 0) ? MMask( srchClip, bVec1, kind=0, ml=MBlurLimit ) : NOP()
	mblurred     = (MotionBlur == 0) ? addNoise2 : \
	               (MBlurLimit == 0) ? mblur : \
	                                   mt_merge( addNoise2, mblur, mbMotionMask, U=3,V=3 )
	# Reduce frame rate
	decimated = (FPSDivisor != 1) ? mblurred.SelectEvery( FPSDivisor, 0 ) : mblurred
    
	# Crop off temporary vertical padding
	cropped = Border ? decimated.Crop( 0, 4, -0, -4 ) : decimated
	h = Border ? h-8 : h

	# Show output of choice + settings
	output = (ShowNoise == 0.0) ? cropped : deintNoise.mt_lut( "x 128 - " + string(ShowNoise) + " * 128 +", U=-128,V=-128 )
	return (ShowSettings == false) ? output : \
		output.Subtitle( "TR0=" + string(TR0) + " | TR1=" + string(TR1) + " | TR2=" + string(TR2) + " | Rep0=" + string(Rep0) + " | Rep1=" + string(Rep1) + \
		" | Rep2=" + string(Rep2) + " | RepChroma=" + string(RepChroma) + "\nEdiMode='" + EdiMode + "' | NNSize=" + string(NNSize) + " | NNeurons=" + \
		string(NNeurons) + " | EdiQual=" + string(EdiQual) + " | EdiMaxD=" + string(EdiMaxD) + " | EdiThreads=" + string(EdiThreads) + "\nSharpness=" + \
		string(Sharpness, "%.2f") + " | SMode=" + string(SMode) + " | SLMode=" + string(SLMode) + " | SLRad=" + string(SLRad) + " | SOvs=" + string(SOvs) + \
		" | SVThin=" + string(SVThin, "%.2f") + " | Sbb=" + string(Sbb) + "\nSrchClipPP=" + string(SrchClipPP) + " | SubPel=" + string(SubPel) + \
		" | SubPelInterp=" + string(SubPelInterp) + " | BlockSize=" + string(BlockSize) + " | Overlap=" + string(Overlap) + "\nSearch=" + string(Search) + \
		" | SearchParam=" + string(SearchParam) + " | PelSearch=" + string(PelSearch) + " | TrueMotion=" + string(TrueMotion) + "\nLambda=" + string(Lambda) + \
		" | LSAD=" + string(LSAD) + " | PNew=" + string(PNew) + " | PLevel=" + string(PLevel) + " | GlobalMotion=" + string(GlobalMotion) + " | DCT=" + \
		string(DCT) + "\nSourceMatch=" + string(SourceMatch) + " | MatchPreset='" + MatchPreset + "' | MatchEdi='" + MatchEdi + "'\nMatchPreset2='" + \
		MatchPreset2 + "' | MatchEdi2='" + MatchEdi2 + "' | MatchTR2=" + string(MatchTR2) + " | MatchEnhance=" + string(MatchEnhance, "%.2f") + \
		" | Lossless=" + string(Lossless) + "\nNoiseBypass=" + string(NoiseBypass) + " | NoiseRemove=" + string(NoiseRemove, "%.2f") + " | DetailRestore=" + \
		string(DetailRestore, "%.2f") + " | NoiseRestore=" + string(NoiseRestore, "%.2f") + "\nNoiseDeint='" + NoiseDeint + "' | Sigma=" + \
		string(Sigma, "%.2f") + " | BT=" + string(BT) + " | ShowNoise=" + string(ShowNoise, "%.2f") + " | InputType=" + string(InputType) + \
		" | ProgSADMask=" + string(ProgSADMask, "%.2f") + "\nFPSDivisor=" + string(FPSDivisor) + " | MotionBlur=" + string(MotionBlur) + \
		" | ShutterAngleSrc=" + string(ShutterAngleSrc, "%.2f") +  " | ShutterAngleOut=" + string(ShutterAngleOut, "%.2f") + " | MBlurLimit=" + \
		string(MBlurLimit) + "\nBorder=" + string(Border) + " | Precise=" + string(Precise) + " | SafeMode=" + string(SafeMode) + "\nPreset='" + Preset + \
		"' | Tuning='" + Tuning + "'", font="Lucida Console", size=11, lsp=12 )
}


#---------------------------------------
# Helpers

# Interpolate input clip using method given in EdiMode. Use Fallback clip as result if mode is not in list. Used by main interpolation and source-match
function Interpolate( clip Input, int InputType, string EdiMode, int NNSize, int NNeurons, int EdiQual, int EdiMaxD, int EdiThreads, clip "Fallback" )
{
	return (InputType == 1)            ? Input : \
	       (EdiMode == "NNEDI3")       ? Input.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	       (EdiMode == "NNEDI2")       ? Input.NNEDI2( field=-2, nsize=NNeurons, qual=EdiQual, threads=EdiThreads ) : \
	       (EdiMode == "NNEDI")        ? Input.NNEDI( field=-2 ) : \
	       (EdiMode == "EEDI3+NNEDI3") ? Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, \
		                                              sclip=Input.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads ) ) : \
	       (EdiMode == "EEDI3")        ? Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads ) : \
	       (EdiMode == "EEDI2")        ? Input.SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ) : \
	       (EdiMode == "Yadif")        ? Input.Yadif( mode=3 ) : \
	       (EdiMode == "TDeint")       ? Input.TDeInt( mode=1 ) : \
	       (EdiMode == "TDIYadif")     ? Merge( Input.Yadif( mode=3 ), Input.TDeInt( mode=1 ) ) : \
	                                     default( Fallback, Input.Bob( 0,0.5 ) )
}


# Functions (from original TGMC) used instead of mt_xxflate with similar operation but a somewhat stronger result. Originally added for speed, they are
# no longer faster due to improvements in masktools. Difference (visual and speed) is small so may be reverted in a later version.
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
function RemoveNonBobDiff( clip Input, clip Ref, int Rep, bool Chroma )
{
	# ed is the erosion distance - how much to deflate then reflate to remove thin areas of interest: 0 = minimum to 5 = maximum
	# od is over-dilation level  - extra inflation to ensure areas to restore back are fully caught:  0 = none to 3 = one full pixel
	# If Rep < 10, then ed = Rep and od = 0, otherwise ed = 10s digit and od = 1s digit (nasty method, but kept for compatibility with original TGMC)
	Rep    = default( Rep,    1    )
	Chroma = default( Chroma, true )
	ed = (Rep < 10) ? Rep : Rep / 10
	od = (Rep < 10) ? 0   : Rep % 10
	uvT = Chroma ? 3 : 1
	uvO = Chroma ? 3 : 2

	diff = mt_makediff( Ref, Input, U=3,V=3 )

	# Areas of positive difference                                                          # ed = 0 1 2 3 4 5
	choke1 =                        diff.  mt_inpand( mode="vertical", U=uvT,V=uvT )            #      x x x x x x    1 pixel   \
	choke1 = (ed > 2)             ? choke1.mt_inpand( mode="vertical", U=uvT,V=uvT ) : choke1   #      . . . x x x    1 pixel    | Deflate to remove thin areas
	choke1 = (ed != 0 && ed != 3) ? choke1.TGMC_deflate( U=uvT,V=uvT )               : choke1   #      . x x . x x    a bit more |
	choke1 = (ed == 2 || ed == 5) ? choke1.RemoveGrain(4)                        : choke1   #      . . x . . x    & more(?) / [median - may actually inflate??]

	choke1 =                        choke1.mt_expand( mode="vertical", U=uvT,V=uvT )            #      x x x x x x    1 pixel  \
	choke1 = (ed > 1)             ? choke1.mt_expand( mode="vertical", U=uvT,V=uvT ) : choke1   #      . . x x x x    1 pixel   | Reflate again
	choke1 = (ed > 4)             ? choke1.mt_expand( mode="vertical", U=uvT,V=uvT ) : choke1   #      . . . . . x    1 pixel  /

	# Over-dilation - extra reflation up to 1 pixel
	choke1 = (od == 0)            ? choke1 : \
	         (od == 1)            ? choke1.TGMC_inflate( U=uvT,V=uvT ) : \
	         (od == 2)            ? choke1.TGMC_inflate( U=uvT,V=uvT ).TGMC_inflate( U=uvT,V=uvT ) : \
	                                choke1.mt_expand( U=uvT,V=uvT )

	# Areas of negative difference (similar to above)
	choke2 =                        diff.  mt_expand( mode="vertical", U=uvT,V=uvT )
	choke2 = (ed > 2)             ? choke2.mt_expand( mode="vertical", U=uvT,V=uvT ) : choke2
	choke2 = (ed != 0 && ed != 3) ? choke2.TGMC_inflate( U=uvT,V=uvT )               : choke2
	choke2 = (ed == 2 || ed == 5) ? choke2.RemoveGrain(4)                        : choke2
	choke2 =                        choke2.mt_inpand( mode="vertical", U=uvT,V=uvT )
	choke2 = (ed > 1)             ? choke2.mt_inpand( mode="vertical", U=uvT,V=uvT ) : choke2
	choke2 = (ed > 4)             ? choke2.mt_inpand( mode="vertical", U=uvT,V=uvT ) : choke2
	choke2 = (od == 0)            ? choke2 : \
	         (od == 1)            ? choke2.TGMC_deflate( U=uvT,V=uvT ) : \
	         (od == 2)            ? choke2.TGMC_deflate( U=uvT,V=uvT ).TGMC_deflate( U=uvT,V=uvT ) : \
	                                choke2.mt_inpand( U=uvT,V=uvT )

	# Combine above areas to find those areas of difference to restore
	restore = diff.mt_lutxy( choke1, "x 129 < x y 128 < 128 y ? ?", U=uvT,V=uvT ).mt_lutxy( choke2, "x 127 > x y 128 > 128 y ? ?", U=uvT,V=uvT )

	return Input.mt_adddiff( restore, U=uvO,V=uvO )
}


# Given noise extracted from an interlaced source (i.e. the noise is interlaced), generate "progressive" noise with a new "field" of noise injected. The new
# noise is centered on a weighted local average and uses the difference between local min & max as an estimate of local variance
function Generate2ndFieldNoise( clip Input )
{
	origNoise = Input.SeparateFields()
	noiseMax  = origNoise.mt_expand( mode="square", U=3,V=3 ).mt_expand( mode="horizontal", U=1,V=1 )
	noiseMin  = origNoise.mt_inpand( mode="square", U=3,V=3 ).mt_inpand( mode="horizontal", U=1,V=1 )
	random    = BlankClip( origNoise, color_yuv=$808080 ).AddGrain( var=256 )
	varRandom = mt_makediff( noiseMax, noiseMin, U=3,V=3 ).mt_lutxy( random, "x 128 - y 128 - * 128 / 128 +", U=1,V=1 )
	newNoise  = origNoise.RemoveGrain(12).mt_adddiff( varRandom, U=1,V=1 )
	return Interleave( origNoise, newNoise ).Weave()
}


# Insert the source lines into the result to create a true lossless output. However, the other lines in the result have had considerable processing and won't
# exactly match source lines. There will be some slight residual combing. Use vertical medians to clean a little of this away
function MakeLossless( clip Input, clip Source, int InputType )
{
	Assert( InputType != 1, "Lossless modes are incompatible with InputType=1" )
	
	# Weave the source fields and the "new" fields that have generated in the input
	srcFields = (InputType == 0) ? Source.SeparateFields() : Source.SeparateFields().SelectEvery( 4, 0,3 )
	newFields = Input.SeparateFields().SelectEvery( 4, 1,2 )
	processed = Interleave( srcFields, newFields ).SelectEvery(4, 0,1,3,2 ).Weave()

	# Clean some of the artefacts caused by the above - creating a second version of the "new" fields
	vertMedian  = processed.VerticalCleaner( mode=1 )
	vertMedDiff = mt_makediff( processed, vertMedian, U=3,V=3 )
	vmNewDiff1  = vertMedDiff.SeparateFields().SelectEvery( 4, 1,2 )
	vmNewDiff2  = vmNewDiff1.VerticalCleaner( mode=1 ).mt_lutxy( vmNewDiff1, "x 128 - y 128 - * 0 < 128 x 128 - abs y 128 - abs < x y ? ?", U=3,V=3 )
	vmNewDiff3  = vmNewDiff2.Repair( vmNewDiff2.removegrain(2), 1 )

	# Reweave final result
	return Interleave( srcFields, newFields.mt_makediff( vmNewDiff3, U=3,V=3 )).SelectEvery( 4, 0,1,3,2 ).Weave()
}



# Source-match, a three stage process that takes the difference between deinterlaced input and the original interlaced source, to shift the input more towards
# the source without introducing shimmer. All other arguments defined in main script
function ApplySourceMatch( clip Deinterlace, int InputType, val Source, val bVec1, val fVec1, val bVec2, val fVec2, \
                           int SubPel, int SubPelInterp, int thSAD1, int thSCD1, int thSCD2, \
                           int SourceMatch, int MatchTR1, string MatchEdi, int MatchNNSize, int MatchNNeurons, int MatchEdiQual, int MatchEdiMaxD, int EdiThreads, \
                           float MatchEnhance, int MatchTR2, string MatchEdi2, int MatchNNSize2, int MatchNNeurons2, int MatchEdiQual2, int MatchEdiMaxD2 )
{
	# Basic source-match. Find difference between source clip & equivalent fields in interpolated/smoothed clip (called the "error" in formula below). Ideally
	# there should be no difference, we want the fields in the output to be as close as possible to the source whilst remaining shimmer-free. So adjust the
	# *source* in such a way that smoothing it will give a result closer to the unadjusted source. Then rerun the interpolation (edi) and binomial smooth with
	# this new source. Result will still be shimmer-free and closer to the original source.
	# Formula used for correction is P0' = P0 + (P0-P1)/(k+S(1-k)), where P0 is original image, P1 is the 1st attempt at interpolation/smoothing , P0' is the
	# revised image to use as new source for interpolation/smoothing, k is the weighting given to the current frame in the smooth, and S is a factor indicating
	# "temporal similarity" of the error from frame to frame, i.e. S = average over all pixels of [neighbor frame error = S * current frame error] . Decreasing
	# S will make the result sharper, sensible range is about -0.25 to 1.0. Empirically, S=0.5 is effective [will do deeper analysis later]
	errorTemporalSimilarity = 0.5  # S in formula described above
	errorAdjust1   = Select( MatchTR1, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
	match1Clip     = (SourceMatch < 1 || InputType == 1) ? Deinterlace : Deinterlace.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
	match1Update   = (SourceMatch < 1 || MatchTR1 == 0) \
						? Source : mt_lutxy( Source, match1Clip, "x " + string(errorAdjust1 + 1) + " * y " + string(errorAdjust1) + " * -", U=3,V=3 )
	match1Edi      = (SourceMatch > 0) ? Interpolate( match1Update, InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads ) : NOP()
	match1Super    = (SourceMatch > 0 && MatchTR1 > 0) ? match1Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? match1Edi.MDegrain1( match1Super, bVec1,fVec1, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? match1Edi.MDegrain1( match1Super, bVec2,fVec2, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match1         = (SourceMatch < 1) ? Deinterlace : \
	                 (MatchTR1 == 0)   ? match1Edi : \
	                 (MatchTR1 == 1)   ? match1Degrain1.Merge( match1Edi, 0.25 ) : \
	                                     match1Degrain1.Merge( match1Degrain2, 0.2 ).Merge( match1Edi, 0.0625 )

	# Enhance effect of source-match stages 2 & 3 by sharpening clip prior to refinement (source-match tends to underestimate so this will leave result sharper)
	match1Shp = (SourceMatch > 1 && MatchEnhance > 0.0) ? match1.mt_lutxy( match1.RemoveGrain(12), "x x y - "+ string(MatchEnhance) + " * +", U=3,V=3 ) : match1

	# Source-match refinement. Find difference between source clip & equivalent fields in (updated) interpolated/smoothed clip. Interpolate & binomially smooth
	# this difference then add it back to output. Helps restore differences that the basic match missed. However, as this pass works on a difference rather than
	# the source image it can be prone to occasional artefacts (difference images are not ideal for interpolation). In fact a lower quality interpolation such
	# as a simple bob often performs nearly as well as advanced, slower methods (e.g. NNEDI3)
	match2Clip     = (SourceMatch < 2 || InputType == 1) ? match1Shp : match1Shp.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
	match2Diff     = (SourceMatch > 1) ? mt_makediff( Source, match2Clip, U=3,V=3 ) : NOP()
	match2Edi      = (SourceMatch > 1) ? Interpolate( match2Diff, InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, EdiThreads ) : NOP()
	match2Super    = (SourceMatch > 1 && MatchTR2 > 0) ? match2Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? match2Edi.MDegrain1( match2Super, bVec1,fVec1, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? match2Edi.MDegrain1( match2Super, bVec2,fVec2, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match2         = (SourceMatch < 2) ? match1 : \
	                 (MatchTR2 == 0)   ? match2Edi : \
	                 (MatchTR2 == 1)   ? match2Degrain1.Merge( match2Edi, 0.25 ) : \
	                                     match2Degrain1.Merge( match2Degrain2, 0.2 ).Merge( match2Edi, 0.0625 )

	# Source-match second refinement - correct error introduced in the refined difference by temporal smoothing. Similar to error correction from basic step
	errorAdjust2   = Select( MatchTR2, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
	match3Update   = (SourceMatch < 3 || MatchTR2 == 0) \
	                     ? match2Edi : mt_lutxy( match2Edi, match2, "x " + string(errorAdjust2 + 1) + " * y " + string(errorAdjust2) + " * -", U=3,V=3 )
	match3Super    = (SourceMatch > 2 && MatchTR2 > 0) ? match3Update.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1 ) : NOP()
	match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? match3Update.MDegrain1( match3Super, bVec1,fVec1, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? match3Update.MDegrain1( match3Super, bVec2,fVec2, thSAD=thSAD1, thSCD1=thSCD1,thSCD2=thSCD2 ) : NOP()
	match3         = (SourceMatch < 3) ? match2 : \
	                 (MatchTR2 == 0)   ? match3Update : \
	                 (MatchTR2 == 1)   ? match3Degrain1.Merge( match3Update, 0.25 ) : \
	                                     match3Degrain1.Merge( match3Degrain2, 0.2 ).Merge( match3Update, 0.0625 )

	# Apply difference calculated in source-match refinement
	return (SourceMatch < 2) ? match1 : match1Shp.mt_adddiff( match3, U=3,V=3 )
}
