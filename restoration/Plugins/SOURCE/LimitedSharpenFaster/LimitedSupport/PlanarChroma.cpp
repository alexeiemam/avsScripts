#include "stdafx.h"

#include "PlanarFilter.h"



namespace PlanarFilter
{
	void copyplane(PVideoFrame &result, const PVideoFrame &source, int plane, IScriptEnvironment *env)
	{
	//  void __stdcall IScriptEnvironment::BitBlt
		//(BYTE* dstp, int dst_pitch, const BYTE* srcp, int src_pitch, int row_size, int height) = 0

		unsigned char *resultpointer = result->GetWritePtr(plane);
		const unsigned char *sourcepointer = source->GetReadPtr(plane);

		const int width = source->GetRowSize(plane);
		const int height = source->GetHeight(plane);
		const int sourcepitch = source->GetPitch(plane);
		const int resultpitch = result->GetPitch(plane);

		env->BitBlt(resultpointer, resultpitch, sourcepointer, sourcepitch, width, height);
	}

}