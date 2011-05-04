#include "stdafx.h"

#include "LimitedSupport.h"
#include "functions.h"

void SimpleAverage::operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane)
{
	const int width = first->GetRowSize(plane);
	const int widthroundedup = roundup(width, 8);
	const int height = first->GetHeight(plane);
	const int firstpitch = first->GetPitch(plane);
	const int secondpitch = second->GetPitch(plane);
	const int resultpitch = result->GetPitch(plane);

	const unsigned char *secondrow = second->GetReadPtr(plane);
	unsigned char *resultrow = result->GetWritePtr(plane);
	const unsigned char *firstrow = first->GetReadPtr(plane);

	const int blocksize = 64;
	const int bytesinblocks = (widthroundedup/blocksize) * blocksize;
	const int negativebytesinblocks = -bytesinblocks;
	const int remainingbytes = widthroundedup - bytesinblocks;

	firstrow += bytesinblocks;
	secondrow += bytesinblocks;
	resultrow += bytesinblocks;

	for(int y = 0; y < height; ++y)
	{
		__asm
		{
			mov     eax, [negativebytesinblocks]//
			mov     esi, [firstrow]//
			mov     edx, [secondrow]//
			mov     edi, [resultrow]//
			mov     ecx, [remainingbytes]//

horizontal:
			movq  mm0, mmword ptr [esi+eax]
			movq  mm1, mmword ptr [esi+eax+8]
			movq  mm2, mmword ptr [esi+eax+16]
			movq  mm3, mmword ptr [esi+eax+24]
			movq  mm4, mmword ptr [esi+eax+32]
			movq  mm5, mmword ptr [esi+eax+40]
			movq  mm6, mmword ptr [esi+eax+48]
			movq  mm7, mmword ptr [esi+eax+56]

			pavgb  mm0, mmword ptr [edx+eax]
			pavgb  mm1, mmword ptr [edx+eax+8]
			pavgb  mm2, mmword ptr [edx+eax+16]
			pavgb  mm3, mmword ptr [edx+eax+24]
			pavgb  mm4, mmword ptr [edx+eax+32]
			pavgb  mm5, mmword ptr [edx+eax+40]
			pavgb  mm6, mmword ptr [edx+eax+48]
			pavgb  mm7, mmword ptr [edx+eax+56]

			movq mmword ptr [edi+eax], mm0
			movq mmword ptr [edi+eax+8],mm1 
			movq mmword ptr [edi+eax+16], mm2
			movq mmword ptr [edi+eax+24], mm3
			movq mmword ptr [edi+eax+32], mm4
			movq mmword ptr [edi+eax+40], mm5
			movq mmword ptr [edi+eax+48], mm6
			movq mmword ptr [edi+eax+56], mm7

			add    eax, blocksize//
			jnz horizontal

			cmp eax, ecx
			je  finished
remnant:
			movq  mm0, mmword ptr [esi+eax]
			pavgb  mm0, mmword ptr [edx+eax]
			movq mmword ptr [edi+eax], mm0

			add	eax, 8
			cmp eax, ecx
			jne  remnant
finished:
		}

		firstrow += firstpitch;
		secondrow += secondpitch;
		resultrow += resultpitch;
	}
	__asm emms
}