#include "filter.h"

using namespace Filtering;

void Filtering::MaskTools::Filters::Support::AddDiff::adddiff_c(Byte *pDst, int nDstPitch, const Byte *pSrc, int nSrcPitch, int nWidth, int nHeight)
{
   for ( int y = 0; y < nHeight; y++, pDst += nDstPitch, pSrc += nSrcPitch )
      for ( int x = 0; x < nWidth; x++ )
         pDst[x] = clip<int, int>( int(pDst[x]) + pSrc[x] - 128, 0, 255 );
}