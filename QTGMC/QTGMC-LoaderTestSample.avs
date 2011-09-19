FFVideoSource("Filmbeat-v2.0-dem.avi").ConvertToYV12.SeparateFields().Trim(1,0).Weave()
Import("C:\Video Encoding\AviSynth 2.5\plugins\QTGMC\QTGMCLoader.avsi")
QTGMC( Preset="Slower", FPSDivisor=2, ShutterBlur=1, ShutterAngleSrc=180, ShutterAngleOut=180 ) # Keep "film" look on single-rate output, "film" input