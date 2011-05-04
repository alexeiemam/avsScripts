#pragma once
#include "ComputePlane.h"
#include "functions.h"
#include "LimitedSupport.h"

namespace PlanarFilter
{
	class ComputeChroma;


	class Unary : public SupportFilter 
	{   
		UnaryComputePlane &computeplane;
		ComputeChroma &computechroma;
	public:
		Unary(UnaryComputePlane *_computeplane, PClip _child, AVSValue _chroma, IScriptEnvironment *env);
		~Unary();
		PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment *env);
	};

	class Binary : public SupportFilter 
	{   
		PClip secondclip;
		BinaryComputePlane &computeplane;
		ComputeChroma &computechroma;
	public:
		Binary(BinaryComputePlane *_computeplane, PClip _child, PClip _secondclip, AVSValue _chroma, IScriptEnvironment *env);
		~Binary();
		PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment *env);
	};

	class Ternary : public SupportFilter 
	{   
		PClip secondclip;
		PClip thirdclip;
		TernaryComputePlane &computeplane;
		ComputeChroma &computechroma;
	public:
		Ternary(TernaryComputePlane *_computeplane, PClip _child, PClip _secondclip, PClip _thirdclip, AVSValue _chroma, IScriptEnvironment *env);
		~Ternary();
		PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment *env);
	};
}
