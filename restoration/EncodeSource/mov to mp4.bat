:: SET ffmpeg="C:\Program Files\WinFF\ffmpeg.exe"
SET ffmpeg="C:\Program Files\MeGUI\tools\ffmpeg\ffmpeg.exe"
SET inp="E:\_EncodingProfiles\UpBeat\I_LOVE_YOU_PHILLIP_MORRIS_CLIP_1.mov"
SET outp="E:\_EncodingProfiles\UpBeat\I_LOVE_YOU_PHILLIP_MORRIS_CLIP_1.mp4"


:: %ffmpeg% -i %inp% -vcodec copy -acodec copy %outp%

%ffmpeg% -i %inp% -vcodec copy -acodec libfaac -ar 48000 -ab 192kb %outp%
pause