Autolevels 0.3 for Avisynth

This filter is an improvement of the ColorYUV filter's autogain feature. Basically,
it stretches the luma histogram to use the entire valid range.
Unlike ColorYUV, this filter averages the amount of "gain" over consecutive frames
to better handle flashes and to avoid flickering.
No averaging is done when a scene change is detected so no artificial fade effect
is introduced.

Syntax:
Autolevels(int filterRadius, int sceneChgThresh, string excludeFrames)

All parameters are optional.
* filterRadius specifies how many frames before and after the current frame are
  used to average the amount of gain. The default is 5.
* sceneChgThresh is the detection threshold for scene changes. This parameter takes
  values between 0 and 255. The default is 5.
* frameOverrides is a string parameter that allows special handling of certain frames.
  It is a comma-separated list; each list entry is one of the letters {S, N, E},
  followed by a frame number or frame range. A range is two frame numbers separated
  by a dash. Depending on the preceding letter code, the frame / frame range is
  treated as follows:
  S<frame>: Assume a scene start at <frame> (overrides scene change auto detection)
  N<frame> or N<start-end>:
    Assume there is no scene start at <frame> or frames <start> to <end>,
    resp. (overrides scene change auto detection)
  E<frame> or E<start-end>:
    Leave <frame> or frames <start> to <end> unchanged, resp.

Example:
Autolevels(filterRadius=8, sceneChgThresh=10, frameOverrides="E8400-8405,S62908,S63315,N8527-8540")

Future revisions may include:
 * Fade detection
 * Option to display gain factor on video frames
 * Improve scene change detection by using second rather than first
   derivative of ymin/ymax
 * Detect scenes that should be kept dark (may not be easy to do)
 * Option to change the luma cutoff (right now, it is fixed at 1/256 and 255/256)
