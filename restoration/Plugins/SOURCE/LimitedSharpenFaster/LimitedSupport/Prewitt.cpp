#include "stdafx.h"
#include "Limitedsupport.h"
#include <cmath>

using namespace std;

void fillborder(PVideoFrame &frame, int plane)
{
	const unsigned char borderColor = (plane == PLANAR_Y) ? 0 : 128;

	const int width = frame->GetRowSize(plane);
	const int height = frame->GetHeight(plane);
	const int pitch = frame->GetPitch(plane);

	unsigned char *row = frame->GetWritePtr(plane);

	for (int x = 0; x < width; ++x)  
		row[x] = borderColor;
	row += pitch; 

	for (int y = 1; y < height-1; ++y) 
	{  
		row[0] = borderColor;
		row[width-1] = borderColor;

		row += pitch;   
	}
	for (int x  = 0; x < width; ++x) 
		row[x] = borderColor;
	//row += pitch; 
}

void Prewitt::operator() (PVideoFrame &result, const PVideoFrame &source, int plane)
{
	const int scaledmultiplier = static_cast<int>(multiplier*256);

	const int width = source->GetRowSize(plane);
	const int height = source->GetHeight(plane);
	const int sourcepitch = source->GetPitch(plane);
	const int resultpitch = result->GetPitch(plane);

	const unsigned char* sourcerow = source->GetReadPtr(plane);
	unsigned char* resultrow = result->GetWritePtr(plane);

	for (int y = 0; y < height-2; ++y) 
	{
		for (int x  = 0; x < width-2; ++x) 
		{
			// 00 01 02
			// 10  12
			// 20 21 22
			int x00, x01, x02, x10, x12, x20, x21, x22;
			x00 = sourcerow[x + 0];
			x01 = sourcerow[x + 1];
			x02 = sourcerow[x + 2];

			x10 = sourcerow[x + 0 + sourcepitch];		
			x12 = sourcerow[x + 2 + sourcepitch];

			x20 = sourcerow[x + 0 + sourcepitch * 2];		
			x21 = sourcerow[x + 1 + sourcepitch * 2];		
			x22 = sourcerow[x + 2 + sourcepitch * 2];

			int p90  = x00 + x01 + x02       - x20 - x21 - x22;
			int p45  =    x01 + x02 - x10 + x12    - x20 - x21;//silly bug spotted by @kassandro
			int p180 = x00    - x02 + x10 - x12 + x20    - x22;
			int p135 = x00 + x01    + x10 - x12    - x21 - x22;

			int maxa = max( abs(p90), abs(p45));
			int maxb = max( abs(p180), abs(p135));
			int maxvalue = max(maxa, maxb);
			int multipliedmaxvalue = (maxvalue*scaledmultiplier)>>8;

			resultrow[x + 1 + resultpitch] = min(multipliedmaxvalue, 255);
		}
		sourcerow += sourcepitch;   
		resultrow += resultpitch;   
	}

	fillborder(result, plane);
}
