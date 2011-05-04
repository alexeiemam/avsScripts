#include "stdafx.h"

#include "PlanarFilter.h"
#include "PlanarChroma.h"

namespace PlanarFilter
{


	Unary::Unary(UnaryComputePlane *_computeplane, PClip _child, AVSValue _chroma, IScriptEnvironment *env)
	: SupportFilter(_child, env), 
	computeplane(*_computeplane),
	computechroma(  *(decipherchromaargument(_chroma, makevector(_child), *_computeplane) ) )
	{
	}

	Unary::~Unary()
	{
		delete &computeplane;
		delete &computechroma;
	}

	PVideoFrame __stdcall Unary::GetFrame(int n, IScriptEnvironment *env)
	{
		PVideoFrame result = env->NewVideoFrame(vi);
		const PVideoFrame first = child->GetFrame(n, env);
		vector<const PVideoFrame> source = makevector(first);

		//This treatment of chroma is not the correct design... the problem is that 
		//AVISynth imposes a restriction on how frames can be requested efficiently
		// -- so total planar separation is not possible.

		computeplane(result, first, PLANAR_Y);
		//note that as chroma may come from an external source, frame number is needed
		computechroma(result, source, n, PLANAR_U, env);
		computechroma(result, source, n, PLANAR_V, env);

		return result;
	}


	Binary::Binary(BinaryComputePlane *_computeplane, PClip _child, PClip _secondclip, AVSValue _chroma, IScriptEnvironment *env)
	: SupportFilter(_child, env), secondclip(_secondclip), 
	computeplane(*_computeplane),
	computechroma(  *(decipherchromaargument(_chroma, makevector(_child,_secondclip), *_computeplane) ) )
	{
		if(_secondclip->GetVideoInfo().width != vi.width)
			env->ThrowError("LimitedSupport binary filter: widths do not match.");
		if(_secondclip->GetVideoInfo().height != vi.height)
			env->ThrowError("LimitedSupport binary filter: heights do not match.");
	}

	Binary::~Binary()
	{
		delete &computeplane;
		delete &computechroma;
	}

	PVideoFrame __stdcall Binary::GetFrame(int n, IScriptEnvironment *env)
	{
		PVideoFrame result = env->NewVideoFrame(vi);
		const PVideoFrame first = child->GetFrame(n, env);
		const PVideoFrame second = secondclip->GetFrame(n, env);
		vector<const PVideoFrame> source = makevector(first, second);

		//This treatment of chroma is not the correct design... the problem is that 
		//AVISynth imposes a restriction on how frames can be requested efficiently
		// -- so total planar separation is not possible.

		computeplane(result, first, second, PLANAR_Y);
		//note that as chroma may come from an external source, frame number is needed
		computechroma(result, source, n, PLANAR_U, env);
		computechroma(result, source, n, PLANAR_V, env);

		return result;
	}



	Ternary::Ternary(TernaryComputePlane *_computeplane, PClip _child, PClip _secondclip, PClip _thirdclip, AVSValue _chroma, IScriptEnvironment *env)
	: SupportFilter(_child, env), secondclip(_secondclip), thirdclip(_thirdclip),
	computeplane(*_computeplane),
	computechroma(  *(decipherchromaargument(_chroma, makevector(_child,_secondclip,_thirdclip), *_computeplane) ) )
	{
		if(_secondclip->GetVideoInfo().width != vi.width)
			env->ThrowError("LimitedSupport ternary filter: widths do not match.");
		if(_secondclip->GetVideoInfo().height != vi.height)
			env->ThrowError("LimitedSupport ternary filter: heights do not match.");
		if(_thirdclip->GetVideoInfo().width != vi.width)
			env->ThrowError("LimitedSupport Ternary filter: widths do not match.");
		if(_thirdclip->GetVideoInfo().height != vi.height)
			env->ThrowError("LimitedSupport ternary filter: heights do not match.");
	}

	Ternary::~Ternary()
	{
		delete &computeplane;
		delete &computechroma;
	}

	PVideoFrame __stdcall Ternary::GetFrame(int n, IScriptEnvironment *env)
	{
		PVideoFrame result = env->NewVideoFrame(vi);
		const PVideoFrame first = child->GetFrame(n, env);
		const PVideoFrame second = secondclip->GetFrame(n, env);
		const PVideoFrame third = thirdclip->GetFrame(n, env);
		vector<const PVideoFrame> source = makevector(first, second, third);

		//This treatment of chroma is not the correct design... the problem is that 
		//AVISynth imposes a restriction on how frames can be requested efficiently
		// -- so total planar separation is not possible.

		computeplane(result, first, second, third, PLANAR_Y);
		//note that as chroma may come from an external source, frame number is needed
		computechroma(result, source, n, PLANAR_U, env);
		computechroma(result, source, n, PLANAR_V, env);

		return result;
	}
}