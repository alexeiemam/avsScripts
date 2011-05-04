#pragma once


class UnaryComputePlane
{
public:
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, int plane) = 0;
};

class BinaryComputePlane
{
public:
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, int plane) = 0;
};

class TernaryComputePlane
{
public:
	virtual void operator() (PVideoFrame &result, const PVideoFrame &first, const PVideoFrame &second, const PVideoFrame &third, int plane) = 0;
};