Function matchLength( clip modifyThis, clip matchThis)
{
FRmod = float(matchThis.framerate * modifyThis.framecount) / (matchThis.framecount)

return modifyThis.AssumeFPS(FRmod).ChangeFPS(matchThis.framerate, linear=FALSE)
}


### Example Usage###
Logors = AviSource("C:\Compressionism\_Video\Source\Logos\Raindance TV Logo")
Import("C:\Compressionism\_Video\Source\Features\3001_BCC\Balcancan_Source_pal_wide_6ch_subbed.avs")
Mainz = Main.BilinearResize(480,272)

c = Mainz
d = Logors

d = d.matchLength(c)
Overlay(c,d, opacity=0.5)