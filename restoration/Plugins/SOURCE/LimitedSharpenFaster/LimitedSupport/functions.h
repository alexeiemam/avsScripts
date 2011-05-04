#pragma once

inline int roundup(int number, int to)
{
	if (number % to == 0)
		return number;
	else
		return number - number % to + to;
}

template<class T> 
vector<const T> makevector(const T first)
{
	vector<const T> result;
	result.push_back(first);
	return result;
}

template<class T> 
vector<const T> makevector(const T first, const T second)
{
	vector<const T> result;
	result.push_back(first);
	result.push_back(second);
	return result;
}

template<class T> 
vector<const T> makevector(const T first, const T second, const T third)
{
	vector<const T> result;
	result.push_back(first);
	result.push_back(second);
	result.push_back(third);
	return result;
}