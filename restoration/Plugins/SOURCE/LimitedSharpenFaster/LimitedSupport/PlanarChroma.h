#pragma once
#include "ComputePlane.h"
#include "functions.h"

//This treatment of chroma is not the correct design... the problem is that 
//AVISynth imposes a restriction on how frames can be requested 
//efficiently -- so total planar separation is not possible.

namespace PlanarFilter
{
	void copyplane(PVideoFrame &result, const PVideoFrame &source, int plane, IScriptEnvironment *env);

	class ComputeChroma
	{
	public:
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame>, int n, int plane, IScriptEnvironment *env) = 0;
		virtual ~ComputeChroma() {}
	};

	class IgnoreChroma : public ComputeChroma
	{
	public:
		IgnoreChroma() {}
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame>, int n, int plane, IScriptEnvironment *env) {}
	};

	class CopyChroma : public ComputeChroma
	{
		PClip source;
	public:
		CopyChroma(PClip _source) : source(_source) {}
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame>, int n, int plane, IScriptEnvironment *env)
		{
			copyplane(result, source->GetFrame(n, env), plane, env);
		}
	};

	template<class ComputeType>
	class ProcessChroma : public ComputeChroma
	{
	public:
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame>, int n, int plane, IScriptEnvironment *env);
	};

	template<>
	class ProcessChroma<UnaryComputePlane> : public ComputeChroma
	{
		UnaryComputePlane &computeplane;
	public:
		ProcessChroma(UnaryComputePlane &_computeplane) : computeplane(_computeplane) {}
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame> clips, int n, int plane, IScriptEnvironment *env)
		{
			computeplane(result, clips[0], plane);
		}
	};

	template<>
	class ProcessChroma<BinaryComputePlane> : public ComputeChroma
	{
		BinaryComputePlane &computeplane;
	public:
		ProcessChroma(BinaryComputePlane &_computeplane) : computeplane(_computeplane) {}
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame> clips, int n, int plane, IScriptEnvironment *env)
		{
			computeplane(result, clips[0], clips[1], plane);
		}
	};

	template<>
	class ProcessChroma<TernaryComputePlane> : public ComputeChroma
	{
		TernaryComputePlane &computeplane;
	public:
		ProcessChroma(TernaryComputePlane &_computeplane) : computeplane(_computeplane) {}
		virtual void operator() (PVideoFrame &result, vector<const PVideoFrame> clips, int n, int plane, IScriptEnvironment *env)
		{
			computeplane(result, clips[0], clips[1], clips[2], plane);
		}
	};


	template<class T>
	ComputeChroma *decipherchromaargument(AVSValue _chroma, vector<const PClip> clips, T &computeplane)
	{
		if(!_chroma.Defined())
			return new IgnoreChroma;//default behaviour is IGNORE
		else if(_chroma.IsString())
		{
			string chromastring = _chroma.AsString();
			//string chromastring;
			transform(chromastring.begin(), chromastring.end(), chromastring.begin(), tolower);
			if(chromastring == string("ignore"))
				return new IgnoreChroma;
			else if(chromastring == string("process"))
				return new ProcessChroma<T>(computeplane);
			else if(chromastring == "copyfirst" || chromastring == "copy first")
				return new CopyChroma(clips[0]);
			else if(chromastring == "copysecond" || chromastring == "copy second")
			{
				if(clips.size() < 2)
					throw AvisynthError("LimitedSupport: 'Copy Second' may only be used on functions taking two clips.");
				return new CopyChroma(clips[1]);
			}
			else if(chromastring == "copythird" || chromastring == "copy third")
			{
				if(clips.size() < 3)
					throw AvisynthError("LimitedSupport: 'Copy Third' may only be used on functions taking three clips.");
				return new CopyChroma(clips[2]);
			}
			else
				throw AvisynthError(chromastring.c_str ());//"LimitedSupport: invalid chroma argument specified.");
		}
		else if(_chroma.IsClip())
			return new CopyChroma(_chroma.AsClip());
		else
			throw AvisynthError("LimitedSupport: chroma argument must be string or clip.");		;
	}
}