#include "stdafx.h"

#include "LimitedSupport.h"
#include "functions.h"

void AddDifference::operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane)
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

	const int blocksize = 24;
	const int bytesinblocks = (widthroundedup/blocksize) * blocksize;
	const int negativebytesinblocks = -bytesinblocks;
	const int remainingbytes = widthroundedup - bytesinblocks;

	firstrow += bytesinblocks;
	secondrow += bytesinblocks;
	resultrow += bytesinblocks;

	_declspec(align(16)) unsigned char shift[16] = {128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128};
	for(int y = 0; y < height; ++y)
	{
		__asm
		{
			mov     eax, [negativebytesinblocks]//
			mov     esi, [firstrow]//
			mov     edx, [secondrow]//
			mov     edi, [resultrow]//
			mov     ecx, [remainingbytes]//
			movq  mm7, mmword ptr [shift]

horizontal:
			//load
			movq  mm0, mmword ptr [esi+eax]
			movq  mm1, mmword ptr [esi+eax+8]
			movq  mm2, mmword ptr [esi+eax+16]

			movq  mm4, mmword ptr [edx+eax]
			movq  mm5, mmword ptr [edx+eax+8]
			movq  mm6, mmword ptr [edx+eax+16]

			//Convert all input values from [0, 255] to [-128, 127]
			psubb  mm0, mm7
			psubb  mm1, mm7
			psubb  mm2, mm7

			psubb  mm4, mm7
			psubb  mm5, mm7
			psubb  mm6, mm7

			//add
			paddsb  mm0, mm4
			paddsb  mm1, mm5
			paddsb  mm2, mm6

			//Convert back to [0, 255]
			paddb  mm0, mm7
			paddb  mm1, mm7
			paddb  mm2, mm7

			//store
			movq mmword ptr [edi+eax], mm0
			movq mmword ptr [edi+eax+8],mm1 
			movq mmword ptr [edi+eax+16], mm2

			add    eax, blocksize//
			jnz horizontal

			cmp eax, ecx
			je  finished
remnant:
			movq  mm0, mmword ptr [esi+eax]
			movq  mm4, mmword ptr [edx+eax]
			psubb  mm0, mm7
			psubb  mm4, mm7
			paddsb  mm0, mm4
			paddb  mm0, mm7
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