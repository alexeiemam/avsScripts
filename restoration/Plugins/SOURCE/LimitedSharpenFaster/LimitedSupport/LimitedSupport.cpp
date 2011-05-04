/*
	LimitedSupport plugin for AviSynth

	Copyright (C) 2006 Mohan
  
	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation.
	 
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
		
	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
	
	The author can be contacted at the doom9.org forum under mg262.
*/

#include "stdafx.h"
#include "LimitedSupport.h"
#include "PlanarFilter.h"


SupportFilter::SupportFilter(PClip _child, IScriptEnvironment *env) : GenericVideoFilter(_child)
{
	if (!vi.IsYV12()) 
		env->ThrowError("LimitedSupport requires YV12.");
	//if (vi.RowSize() < 128) 
	//	env->ThrowError("LimitedSupport requires frame width at least 128.");
	if((env->GetCPUFlags() & CPUF_MMX) == 0)
		env->ThrowError("LimitedSupport requires MMX.");
}


AVSValue __cdecl Create_SimpleAverage(AVSValue args, void *user_data, IScriptEnvironment *env) 
{
	return new PlanarFilter::Binary(new SimpleAverage,
		args[0].AsClip(), args[1].AsClip(), args[2], env);  
}

AVSValue __cdecl Create_Difference(AVSValue args, void *user_data, IScriptEnvironment *env) 
{
	return new PlanarFilter::Binary(new Difference,
		args[0].AsClip(), args[1].AsClip(), args[2], env);  
}

AVSValue __cdecl Create_AddDifference(AVSValue args, void *user_data, IScriptEnvironment *env) 
{
	return new PlanarFilter::Binary(new AddDifference,
		args[0].AsClip(), args[1].AsClip(), args[2], env);  
}

AVSValue __cdecl Create_Clamp(AVSValue args, void *user_data, IScriptEnvironment *env) 
{
	return new PlanarFilter::Ternary(new Clamp(args[3].AsInt(), args[4].AsInt()),
		args[0].AsClip(), args[1].AsClip(), args[2].AsClip(), args[5], env);  
}

AVSValue __cdecl Create_Prewitt(AVSValue args, void *user_data, IScriptEnvironment *env) 
{
	return new PlanarFilter::Unary(new Prewitt(args[1].AsFloat(1.0)), 
		args[0].AsClip(), args[2], env);  
}

extern "C" __declspec(dllexport) const char *__stdcall AvisynthPluginInit2(IScriptEnvironment *env) 
{
	env->AddFunction("SimpleAverage", "cc[chroma].", Create_SimpleAverage, 0);
	env->AddFunction("MakeDiff", "cc[chroma].", Create_Difference, 0);
	env->AddFunction("SubtractDiff", "cc[chroma].", Create_Difference, 0);
	env->AddFunction("AddDiff", "cc[chroma].", Create_AddDifference, 0);
	env->AddFunction("Clamp", "cccii[chroma].", Create_Clamp, 0);
	env->AddFunction("Prewitt", "c[multiplier]f[chroma].", Create_Prewitt, 0);

	//env->AddFunction("ShiftedMinimum", "cic", Create_ShiftedMinimum, 0);
	//env->AddFunction("SubtractAndSign", "cc", Create_SubtractAndSign, 0);
	//env->AddFunction("Sign", "c", Create_Sign, 0);
	//env->AddFunction("Unsign", "c", Create_Sign, 0);
		return "LimitedSupport: functions to speed up Didée's LimitedSharpen";
}
