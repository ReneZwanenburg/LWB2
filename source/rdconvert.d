module rdconvert;

import std.algorithm : reduce;
import std.math : pow;

import kgl3n.vector : vec2d;

vec2d gpsToRd (double latitude, double longitude) nothrow {
	const deltaLat  = 0.36 * (latitude  - originLatitude);
	const deltaLong = 0.36 * (longitude - originLongitude);
	
	auto weighting = (double acc, PQR s) => acc + s.R * pow(deltaLat, s.p) * pow(deltaLong, s.q);
	
	return vec2d(
		reduce!weighting(originX, XpqR),
		reduce!weighting(originY, YpqR)
	);
}

vec2d rdToGps(double x, double y) nothrow {
	const deltaX = 1e-5 * (x - originX);
	const deltaY = 1e-5 * (y - originY);
	
	auto weighting = (double acc, PQR s) => acc + s.R * pow(deltaX, s.p) * pow(deltaY, s.q);
	
	return vec2d(
		originLatitude + reduce!weighting(0.0, LatpqR) / 3600,
		originLongitude + reduce!weighting(0.0, LongpqR) / 3600
	);
}

private {
	enum originLatitude  = 52.15517440;
	enum originLongitude = 5.38720621;

	enum originX = 155000.0;
	enum originY = 463000.0;

	struct PQR {
		double p;
		double q;
		double R;
	}

	enum XpqR = [
		PQR(0, 1, 190094.945),
		PQR(1, 1, -11832.228),
		PQR(2, 1, -114.221),
		PQR(0, 3, -32.391),
		PQR(1, 0, -0.705),
		PQR(3, 1, -2.340),
		PQR(1, 3, -0.608),
		PQR(0, 2, -0.008),
		PQR(2, 3, 0.148)
	];

	enum YpqR = [
		PQR(1, 0, 309056.544),
		PQR(0, 2, 3638.893),
		PQR(2, 0, 73.077),
		PQR(1, 2, -157.984),
		PQR(3, 0, 59.788),
		PQR(0, 1, 0.433),
		PQR(2, 2, -6.439),
		PQR(1, 1, -0.032),
		PQR(0, 4, 0.092),
		PQR(1, 4, 0.054)
	];
	
	enum LatpqR = [
		PQR(0, 1, 3235.65389),
		PQR(2, 0, -32.58297),
		PQR(0, 2, -0.2475),
		PQR(2, 1, -0.84978),
		PQR(0, 3, -0.0665),
		PQR(2, 2, -0.01709),
		PQR(1, 0, -0.00738),
		PQR(4, 0, 0.0053),
		PQR(2, 3, -3.9E-4),
		PQR(4, 1, 3.3E-4),
		PQR(1, 1, -1.2E-4)
	];
	
	enum LongpqR = [
		PQR(1, 0, 5260.52916),
		PQR(1, 1, 105.94684),
		PQR(1, 2, 2.45656),
		PQR(3, 0, -0.81885),
		PQR(1, 3, 0.05594),
		PQR(3, 1, -0.05607),
		PQR(0, 1, 0.01199),
		PQR(3, 2, -0.00256),
		PQR(1, 4, 0.00128),
		PQR(0, 2, 2.2E-4),
		PQR(2, 0, -2.2E-4),
		PQR(5, 0, 2.6E-4)
	];
}