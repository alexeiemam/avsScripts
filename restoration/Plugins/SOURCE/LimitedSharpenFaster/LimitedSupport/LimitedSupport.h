#pragma once

#include "ComputePlane.h"

class SupportFilter : public GenericVideoFilter //run the standard colour space, etc checks
{
public:
	SupportFilter(PClip _child, IScriptEnvironment *env);
};

class Difference : public BinaryComputePlane
{   
public:
	Difference() {}
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane);
};

class AddDifference : public BinaryComputePlane  
{   
public:
	AddDifference() {}
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane);
};

class SimpleAverage : public BinaryComputePlane  
{   
public:
	SimpleAverage() {}
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane);
};

class Clamp : public TernaryComputePlane 
{   
	unsigned char overshoot, undershoot;
public:
	Clamp(int _overshoot, int _undershoot) : overshoot(_overshoot), undershoot(_undershoot) {}
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, const PVideoFrame &third, int plane);
};

/*
class Clamp : public GenericVideoFilter 
{   
	PClip upper, lower;
	unsigned char overshoot, undershoot;
public:
	Clamp(PClip _child, PClip _second, PClip _lower, int _overshoot, int _undershoot, IScriptEnvironment *env);
	PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment *env);
};*/

class Prewitt : public UnaryComputePlane 
{  
	double multiplier;
public:
	Prewitt(double _multiplier) : multiplier(_multiplier) {}
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, int plane);
};

