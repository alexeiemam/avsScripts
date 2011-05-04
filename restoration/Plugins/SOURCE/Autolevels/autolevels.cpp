// Copyright 2007 Theodor Anschütz
// Requires Avisynth 2.5 source code to compile
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA 
//
// Version history:
//
// 05-26-2007	Ver. 0.1	Initial version
// 06-29-2007	Ver. 0.2	Added E, S, and N modes in frameOverrides parameter
// 09-09-2007   Ver. 0.3    Moved calls to child->GetFrame into getMinMax and isSceneStart
//                          since having them in in Autolevels::GetFrame made caching pointless.
//                          Changed sceneChgThreshDefault to 20.

#include "stdafx.h"
#include "math.h"
#include "hash_map"
#include "vector"
#include "string"
#include "sstream"
#include "core/avisynth.h"

using namespace std;
using namespace stdext;

typedef pair <int, int> IntPair;
typedef pair <int, IntPair> MinMaxElement;
typedef pair <int, boolean> SceneChgElement;

const int filterRadiusDefault = 5;
const int sceneChgThreshDefault = 20;

class Autolevels : public GenericVideoFilter {
	private:
		hash_map <int, IntPair> MinMaxCache;   // Beherbergt die ymininner- und ymaxinner-Werte pro Einzelbild
		hash_map <int, boolean> sceneChgOverrides;
		vector<IntPair> excludeFrames;   // Nummern von Bildern (von/bis), die unangetastet bleiben sollen
		int filterRadius;
		int sceneChgThresh;
		IntPair getMinMax(int frameno, IScriptEnvironment* env);
		boolean Autolevels::isSceneStart(int frameno, IScriptEnvironment* env);
    public: 
		Autolevels(PClip _child, int filterRadius, int sceneChgThresh, string frmOverrides);
		PVideoFrame __stdcall GetFrame(int frameno, IScriptEnvironment* env); 
};

Autolevels::Autolevels(PClip _child, int filterRadius, int sceneChgThresh, string frmOverrides) : GenericVideoFilter(_child) {
	this->filterRadius = filterRadius;
	this->sceneChgThresh = sceneChgThresh;
 
	// excludeFrames und sceneChgOverrides befüllen
	for (int i=0; i<(int)frmOverrides.length(); i++)
		if (frmOverrides[i] == ',')
			frmOverrides[i] = ' ';
	stringstream ss(frmOverrides);
	string range;
	while (ss >> range) {
		size_t dashPos = range.find_first_of('-');
		int startFrm, endFrm;
		if (dashPos != string::npos) {   // Bereich angegeben (<von>-<bis>)
			if (!(istringstream(range.substr(1, dashPos-1)) >> startFrm))
				continue;
			if (!(istringstream(range.substr(dashPos+1)) >> endFrm))
				continue;
		}
		else {   // Einzelne Bildnummer angegeben
			if (!(istringstream(range.substr(1)) >> startFrm))
				continue;
			endFrm = startFrm;
		}
		switch(range.at(0)) {
			case 'S':   // S<frame>, d.h. neue Szene ab Bild <frame>
				for (int i=startFrm; i<=endFrm; i++) {
					SceneChgElement el = SceneChgElement(i, true);
					sceneChgOverrides.insert(el);
				}
				break;
			case 'N':   // N<frame>, d.h. keine neue Szene bei Bild <frame>
				for (int i=startFrm; i<=endFrm; i++) {
					SceneChgElement el = SceneChgElement(i, false);
					sceneChgOverrides.insert(el);
				}
				break;
			case 'E':   // E<frame>, d.h. Bilder von <startFrm> bis <endFrm> unverändert lassen
				excludeFrames.push_back(IntPair(startFrm, endFrm));
				break;
		}
	}
}

PVideoFrame __stdcall Autolevels::GetFrame(int frameno, IScriptEnvironment* env) {
	// Prüfen, ob das Bild überhaupt bearbeitet werden soll
	for (int i=0; i<(int)excludeFrames.size(); i++) {
		if (frameno >= excludeFrames[i].first && frameno <= excludeFrames[i].second)
			return child->GetFrame(frameno, env);   // Bild unverändert zurückgeben
	}

	// Bereich [avgFrom..avgTo] für die Mittelung der ymin- und ymax-Werte bestimmen
	int avgFrom = max(0, frameno-filterRadius);
	int avgTo = min(vi.num_frames-1, frameno+filterRadius);
	// Falls zwischen avgFrom u. avgTo ein Szenenwechsel vorkommt, den Bereich entspr. einschränken
	for (int i=avgFrom+1; i<=avgTo; i++) {
		boolean sceneChange = false;
		if (i > 1)
			sceneChange = isSceneStart(i, env);
		if (sceneChange) {
			if (i <= frameno)
				avgFrom = i;
			else
				avgTo = i - 1;
		}
	}
	// Mittelwert der Minima und Maxima berechnen.
	IntPair yMinMaxAccum = IntPair(0, 0);
	for (int i=avgFrom; i<=avgTo; i++) {
		IntPair yMinMaxFrame = getMinMax(i, env);
		yMinMaxAccum.first += yMinMaxFrame.first;   // ymin
		yMinMaxAccum.second += yMinMaxFrame.second;   // ymax
	}
	double ymin = (double)yMinMaxAccum.first / (avgTo-avgFrom+1);
	double ymax = (double)yMinMaxAccum.second / (avgTo-avgFrom+1);

	PVideoFrame frame = child->GetFrame(frameno, env); 
	env->MakeWritable(&frame);
	if (ymax > ymin) {
		int yLUT[256];
		// Wertetabelle yLUT befüllen (y-Intensitäten auf [ymin, ymax] strecken u. auf [16, 235] einschränken)
		double yfac = 220.0 / (ymax-ymin);   // yfac u. yoffs = Skalierungsfaktor bzw. Versatz der y-Intensitäten
		double yoffs = -ymin * yfac + 16;
		for (int y=0; y<256; y++) {
			int yNew = (int)floor(y*yfac + yoffs + 0.5);
			yLUT[y] = min(max(yNew, 0), 255);   // ggf. ungültige Werte berichtigen
		}

		// Mittels yLUT die alten auf neue y-Intensitäten abbilden
		unsigned char* pY = frame->GetWritePtr(PLANAR_Y);
		const int pitchY = frame->GetPitch(PLANAR_Y); 
		const int row_sizeY = frame->GetRowSize(PLANAR_Y);
		const int heightY = frame->GetHeight(PLANAR_Y);
		for (int y=0; y<heightY; y++) {
			for (int x=0; x<row_sizeY; x++) {
				pY[x] = yLUT[pY[x]];
			}
			pY += pitchY;
		}
	}

	return frame;
}

// Liefert nicht das Minimum und Maximum, sondern das 1/256tel- und das 255/256tel-
// Quantil der Luma-Werte des übergebenen Bildes zurück.
// Dadurch werden Störungen herausgefiltert.
IntPair Autolevels::getMinMax(int frameno, IScriptEnvironment* env) {
	int ymininner, ymaxinner;
	hash_map<int, IntPair>::const_iterator mmIter = MinMaxCache.find(frameno);

	if (mmIter == MinMaxCache.end()) {   // ymin- und ymaxinner nur berechnen, wenn noch nicht bekannt
		PVideoFrame frame = child->GetFrame(frameno, env);
		const unsigned char* pY = frame->GetReadPtr(PLANAR_Y);
		const int row_sizeY = frame->GetRowSize(PLANAR_Y);
		const int heightY = frame->GetHeight(PLANAR_Y); 
		const int pitchY = frame->GetPitch(PLANAR_Y); 
		unsigned char ymin = 255;
		unsigned char ymax = 0;
		int yhisto[256];
		int sumOutliers, numPixels256;

		// y-Maximum u. -Minimum suchen, Histogramm befüllen
		for (int i=0; i<256; i++)
			yhisto[i] = 0;
		for (int y=0; y<heightY; y++) {
			for (int x=0; x<row_sizeY; x++) {
				int yval = pY[x];
				if (yval < ymin) ymin = yval;
				if (yval > ymax) ymax = yval;
				yhisto[yval]++;
			}
			pY += pitchY;
		}

		// [1/256, 255/256]-Quantil bestimmen ("innerer" Histogrammbereich)
		ymininner = ymin;
		ymaxinner = ymax;
		numPixels256 = vi.width * vi.height / 256;
		sumOutliers = yhisto[ymininner];
		while (sumOutliers < numPixels256) {
			ymininner++;
			sumOutliers += yhisto[ymininner];
		}
		sumOutliers = yhisto[ymaxinner];
		while (sumOutliers < numPixels256) {
			ymaxinner--;
			sumOutliers += yhisto[ymaxinner];
		}
		ymininner = max(ymininner, 16);   // Zu skalierenden Bereich in gültigen Bereich legen,
		ymaxinner = min(ymaxinner, 235);   // sonst werden manche Schwarztöne (z.B. y=16) zu Dunkelgrau

		IntPair ip = IntPair(ymininner, ymaxinner);
		MinMaxElement el = MinMaxElement(frameno, ip);
		MinMaxCache.insert(el);
	}
	else {
		IntPair ip = mmIter->second;
		ymininner = ip.first;
		ymaxinner = ip.second;
	}
	return IntPair(ymininner, ymaxinner);
}

// Dies ist keine Szenenwechselerkennung im eigentlichen Sinne, sondern prüft nur,
// ob sich das Luma-Minimum oder -Maximum stark ändert.
// Dieser einfache Ansatz reicht aber hier vollkommen aus, denn ein Szenenwechsel ohne
// Änderung des Minimums / Maximums kann ignoriert werden.
boolean Autolevels::isSceneStart(int frameno, IScriptEnvironment* env) {
	hash_map<int, boolean>::const_iterator scgIter = sceneChgOverrides.find(frameno);
	if (scgIter != sceneChgOverrides.end())   // Prüfen, ob Benutzervorgabe vorhanden
		return scgIter->second;
	else
		if (frameno > 1) {
			IntPair minMax1 = getMinMax(frameno-1, env);
			IntPair minMax2 = getMinMax(frameno, env);
			int minDiff = abs(minMax2.first - minMax1.first);
			int maxDiff = abs(minMax2.second - minMax1.second);
			boolean sceneChange = (minDiff >= sceneChgThresh) || (maxDiff >= sceneChgThresh);
			return sceneChange;
		}
		else
			return false;
}

AVSValue __cdecl Create_Autolevels(AVSValue args, void* user_data, IScriptEnvironment* env) {
	return new Autolevels(args[0].AsClip(), args[1].AsInt(filterRadiusDefault), args[2].AsInt(sceneChgThreshDefault), args[3].AsString("")); 
}

extern "C" __declspec(dllexport) const char* __stdcall AvisynthPluginInit2(IScriptEnvironment* env) {
	env->AddFunction("Autolevels", "c[filterRadius]i[sceneChgThresh]i[frameOverrides]s", Create_Autolevels, 0);
	return "`Autolevels' Histogram stretch plugin";
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
    return TRUE;
}

#ifdef _MANAGED
#pragma managed(pop)
#endif

