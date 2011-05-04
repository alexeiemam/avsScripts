#include "stdafx.h"

#include "LimitedSupport.h"
#include "functions.h"

void Clamp::operator() (PVideoFrame &result, const PVideoFrame &source, const PVideoFrame &upper, const PVideoFrame &lower, int plane)
{
	const int width = source->GetRowSize(plane);
	const int widthroundedup = roundup(width, 8);
	const int height = source->GetHeight(plane);
	const int sourcepitch = source->GetPitch(plane);
	const int upperpitch = upper->GetPitch(plane);
	const int lowerpitch = lower->GetPitch(plane);
	const int resultpitch = result->GetPitch(plane);

	const unsigned char *sourcerow = source->GetReadPtr(plane);
	const unsigned char *upperrow = upper->GetReadPtr(plane);
	const unsigned char *lowerrow = lower->GetReadPtr(plane);
	unsigned char *resultrow = result->GetWritePtr(plane);

	const int blocksize = 24;
	const int bytesinblocks = (widthroundedup/blocksize) * blocksize;
	const int negativebytesinblocks = -bytesinblocks;
	const int remainingbytes = widthroundedup - bytesinblocks;

	sourcerow += bytesinblocks;
	upperrow += bytesinblocks;
	lowerrow += bytesinblocks;
	resultrow += bytesinblocks;
	
	_declspec(align(16)) unsigned char repeatedovershoot[16];
	for (int i = 0; i < 16; ++i)
		repeatedovershoot[i] = overshoot;
	_declspec(align(16)) unsigned char repeatedundershoot[16];
	for (int i = 0; i < 16; ++i)
		repeatedundershoot[i] = undershoot;

	for(int y = 0; y < height; ++y)
	{
		__asm
		{
			movq  mm6, mmword ptr [repeatedundershoot]
			movq  mm7, mmword ptr [repeatedovershoot]
			push	ebx

			mov     eax, [negativebytesinblocks]//
			mov     ebx, [remainingbytes]//
			mov     esi, [sourcerow]//
			mov     ecx, [lowerrow]//
			mov     edx, [upperrow]//
			mov     edi, [resultrow]//

horizontal:
			//load upper limit
			movq  mm0, mmword ptr [edx+eax]
			movq  mm2, mmword ptr [edx+eax+8]
			movq  mm4, mmword ptr [edx+eax+16]
			//load lower limit
			movq  mm1, mmword ptr [ecx+eax]
			movq  mm3, mmword ptr [ecx+eax+8]
			movq  mm5, mmword ptr [ecx+eax+16]
			//add overshoot to upper limit
			paddusb	mm0, mm7
			paddusb	mm2, mm7
			paddusb	mm4, mm7
			//subtract undershoot from lower limit
			psubusb	mm1, mm6
			psubusb	mm3, mm6
			psubusb	mm5, mm6

			//load the source and apply upper limit
			pminub	mm0, [esi+eax]
			pminub	mm2, [esi+eax+8]
			pminub	mm4, [esi+eax+16]
			//apply lower limit
			pmaxub	mm0, mm1
			pmaxub	mm2, mm3
			pmaxub	mm4, mm5

			//store result
			movq mmword ptr [edi+eax], mm0
			movq mmword ptr [edi+eax+8],mm2
			movq mmword ptr [edi+eax+16], mm4

			add    eax, blocksize//
			jnz horizontal

			cmp eax, ebx
			je  finished
remnant:
			movq  mm0, mmword ptr [edx+eax]
			movq  mm1, mmword ptr [ecx+eax]
			paddusb	mm0, mm7
			psubusb	mm1, mm6
			pminub	mm0, [esi+eax]
			pmaxub	mm0, mm1
			movq mmword ptr [edi+eax], mm0

			add	eax, 8
			cmp eax, ebx
			jne  remnant
finished:
			pop	ebx
		}


		sourcerow += sourcepitch;
		upperrow += upperpitch;
		lowerrow += lowerpitch;
		resultrow += resultpitch;
	}
	__asm emms
}


/*
Clamp::Clamp(PClip _child, PClip _upper, PClip _lower, int _overshoot, int _undershoot, IScriptEnvironment *env)
: GenericVideoFilter(_child), upper(_upper), lower(_lower), overshoot(_overshoot), undershoot(_undershoot)
{
	if (!vi.IsYV12()) 
		env->ThrowError("Clamp requires YV12.");
	if (vi.RowSize() < 128) 
		env->ThrowError("Clamp requires frame width at least 128.");
	if((env->GetCPUFlags() & CPUF_SSE) == 0)
		env->ThrowError("Clamp requires SSE.");

	if(upper->GetVideoInfo().width != vi.width)
		env->ThrowError("Clamp: widths do not match.");
	if(upper->GetVideoInfo().height != vi.height)
		env->ThrowError("Clamp: heights do not match.");
	if(lower->GetVideoInfo().width != vi.width)
		env->ThrowError("Clamp: widths do not match.");
	if(lower->GetVideoInfo().height != vi.height)
		env->ThrowError("Clamp: heights do not match.");

}

PVideoFrame __stdcall Clamp::GetFrame(int n, IScriptEnvironment *env) 
{
	PVideoFrame source = child->GetFrame(n, env);
	PVideoFrame upperframe = upper->GetFrame(n, env);
	PVideoFrame lowerframe = lower->GetFrame(n, env);
	//const bool writable = false;//source->IsWritable();
	//PVideoFrame created = (writable ? 0 : (env->NewVideoFrame(vi)));
	//PVideoFrame &result = (writable ? source : created);
	PVideoFrame &result = env->NewVideoFrame(vi);

	//env->MakeWritable(&source);

	const int width = source->GetRowSize();
	const int widthroundedup = source->GetRowSize(PLANAR_Y_ALIGNED);
	const int height = source->GetHeight();
	const int sourcepitch = source->GetPitch();
	const int upperpitch = upperframe->GetPitch();
	const int lowerpitch = lowerframe->GetPitch();
	const int resultpitch = result->GetPitch();

	//{const unsigned char *sourcerow = source->GetReadPtr();
	//unsigned char *resultrow = result->GetWritePtr();
	//for(int y = 0; y < height; ++y)
	//{
	//	for(int x = 0; x < width; ++x)
	//	{
	//		resultrow[x] = 0;
	//	}
	//	sourcerow += sourcepitch;
	//	resultrow += resultpitch;
	//}}

	const unsigned char *upperrow = upperframe->GetReadPtr();
	const unsigned char *lowerrow = lowerframe->GetReadPtr();
	unsigned char *resultrow = result->GetWritePtr();
	//const unsigned char *sourcerow = (writable ? resultrow : source->GetReadPtr());
	const unsigned char *sourcerow = source->GetReadPtr();

	const int blocksize = 24;
	const int bytesinblocks = (widthroundedup/blocksize) * blocksize;
	const int negativebytesinblocks = -bytesinblocks;
	const int remainingbytes = widthroundedup -bytesinblocks;

	sourcerow += bytesinblocks;
	upperrow += bytesinblocks;
	lowerrow += bytesinblocks;
	resultrow += bytesinblocks;

	
	_declspec(align(16)) unsigned char repeatedovershoot[16];
	for (int i = 0; i < 16; ++i)
		repeatedovershoot[i] = overshoot;
	_declspec(align(16)) unsigned char repeatedundershoot[16];
	for (int i = 0; i < 16; ++i)
		repeatedundershoot[i] = undershoot;

	for(int y = 0; y < height; ++y)
	{
		__asm
		{
			movq  mm6, mmword ptr [repeatedundershoot]
			movq  mm7, mmword ptr [repeatedovershoot]
			push	ebx

			mov     eax, [negativebytesinblocks]//
			mov     ebx, [remainingbytes]//
			mov     esi, [sourcerow]//
			mov     ecx, [lowerrow]//
			mov     edx, [upperrow]//
			mov     edi, [resultrow]//

horizontal:
			//load upper limit
			movq  mm0, mmword ptr [edx+eax]
			movq  mm2, mmword ptr [edx+eax+8]
			movq  mm4, mmword ptr [edx+eax+16]
			//load lower limit
			movq  mm1, mmword ptr [ecx+eax]
			movq  mm3, mmword ptr [ecx+eax+8]
			movq  mm5, mmword ptr [ecx+eax+16]
			//add overshoot to upper limit
			paddusb	mm0, mm7
			paddusb	mm2, mm7
			paddusb	mm4, mm7
			//subtract undershoot from lower limit
			psubusb	mm1, mm6
			psubusb	mm3, mm6
			psubusb	mm5, mm6

			//load the source and apply upper limit
			pminub	mm0, [esi+eax]
			pminub	mm2, [esi+eax+8]
			pminub	mm4, [esi+eax+16]
			//apply lower limit
			pmaxub	mm0, mm1
			pmaxub	mm2, mm3
			pmaxub	mm4, mm5

			//store result
			movq mmword ptr [edi+eax], mm0
			movq mmword ptr [edi+eax+8],mm2
			movq mmword ptr [edi+eax+16], mm4

			add    eax, blocksize//
			jnz horizontal

			cmp eax, ebx
			je  finished
remnant:
			movq  mm0, mmword ptr [edx+eax]
			movq  mm1, mmword ptr [ecx+eax]
			paddusb	mm0, mm7
			psubusb	mm1, mm6
			pminub	mm0, [esi+eax]
			pmaxub	mm0, mm1
			movq mmword ptr [edi+eax], mm0

			add	eax, 8
			cmp eax, ebx
			jne  remnant
finished:
			pop	ebx
		}


		sourcerow += sourcepitch;
		upperrow += upperpitch;
		lowerrow += lowerpitch;
		resultrow += resultpitch;
	}
	__asm emms

	return result;
}*/

