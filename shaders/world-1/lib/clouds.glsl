// For the Nether all quality profiles are the same as high except ultra, 
// we have the performance overhead and any less than high looks bad
#if cloudQuality == 1
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 2
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 3
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 4
  #define cloudUpscale 2
  #define cloudSteps 30
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#endif

#if cloudUpscale == 6
const ivec2 vcCheckerTable[36] = ivec2[36](
    ivec2(3,3), ivec2(0,0), ivec2(0,3), ivec2(3,0), ivec2(1,1), ivec2(1,4),
    ivec2(2,2), ivec2(2,5), ivec2(4,1), ivec2(4,4), ivec2(5,2), ivec2(5,5),
    ivec2(0,1), ivec2(0,2), ivec2(0,4), ivec2(0,5), ivec2(1,0), ivec2(1,2),
    ivec2(1,3), ivec2(1,5), ivec2(2,0), ivec2(2,1), ivec2(2,3), ivec2(2,4),
    ivec2(3,1), ivec2(3,2), ivec2(3,4), ivec2(3,5), ivec2(4,0), ivec2(4,2),
    ivec2(4,3), ivec2(4,5), ivec2(5,0), ivec2(5,1), ivec2(5,3), ivec2(5,4));
#elif cloudUpscale == 4
const ivec2 vcCheckerTable[16] = ivec2[16](
    ivec2(0,0), ivec2(2,0), ivec2(0,2), ivec2(2,2),
    ivec2(1,1), ivec2(3,1), ivec2(1,3), ivec2(3,3),
    ivec2(1,0), ivec2(3,0), ivec2(1,2), ivec2(3,2),
    ivec2(0,1), ivec2(2,1), ivec2(0,3), ivec2(2,3));
#elif cloudUpscale == 3
const ivec2 vcCheckerTable[9] = ivec2[9](
    ivec2(0,0), ivec2(2,0), ivec2(0,2), ivec2(2,2), ivec2(1,1),
    ivec2(1,0), ivec2(1,2), ivec2(0,1), ivec2(2,1));
#elif cloudUpscale == 2
const ivec2 vcCheckerTable[4] = ivec2[4](ivec2(0,0), ivec2(1,1), ivec2(1,0), ivec2(0,1));
#endif
ivec2 vcCheckerOffset(int i) { return vcCheckerTable[i]; }

#define cloudReflStepsCeil 12
#define cloudReflDist      2000.0
#define cloudMaxStep       40.0
#define cloudSkipMult      3.0

#define netherFloorY       30.0
#define netherFogThick     14.0
#define netherCeilBottom   (netherFloorY + 1.0)
#define netherCeilTop      (netherFloorY + 1.0 + netherFogThick)
#define netherHangFalloff  4.5 
#define netherBillowScale  4.0
#define netherTendrilFade  0.20 
#define netherRiseSpeed 0.6
#define netherShear     3.5

#define netherCoverage     1
#define netherSeparation   1.0
#define netherCoverScale   0.00008

#define netherVeinScale    0.0016
#define netherVeinSharp    2.2
#define netherFireEvolve   0.03
#define netherBaseGlow     0.55
#define netherFireStrength 1.8

#define netherFireHi vec3(2.6, 0.85, 0.16)     // hottest vein colour
#define netherFireLo vec3(0.9, 0.18, 0.05)     // smoke colour
#define netherAmbLow vec3(0.14, 0.055, 0.028)   // underside, basically the lava glow
#define netherAmbTop vec3(0.06, 0.028, 0.015)   // dark soot

#define netherFogTint vec3(0.22, 0.06, 0.04) 
#define netherFadeNear 60.0
#define netherFadeFar  240.0

#define netherWindSpeed 0.25

// Noise config.
#define cloudNoiseRes 2048.0
#define cloudNoiseYoffset 193.0
#define cloudNoiseSingleFetch

float vcReflectTrans = 1.0;
bool  vcCheapLight   = false;
float vcCoverageOut  = 0.0;

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }
float vcBil(float v) { return abs(v * 2.0 - 1.0); }   // 0 at a lobe core, 1 in the crevices

float vcValNoise(vec3 pos) {
	vec3 pi = floor(pos);
	vec3 pf = fract(pos);
	pf = pf * pf * (3.0 - 2.0 * pf);
	vec2 uv = pi.xz + pf.xz + pi.y * vec2(0.0, cloudNoiseYoffset);
	vec2 coord = uv / cloudNoiseRes;
#ifdef cloudNoiseSingleFetch
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r, xy.g, pf.y);
#else
	float n0 = texture2D(noisetex, coord).x;
	float n1 = texture2D(noisetex, coord + vec2(0.0, cloudNoiseYoffset) / cloudNoiseRes).x;
	return mix(n0, n1, pf.y);
#endif
}

// wind scrolled 3D lattice
vec3 vcLatticePos(vec3 wpos, float oct) {
	float cell = cloudDetailCell * sqrt(cloudSize) / oct;
	vec2 wind = vec2(frameTimeCounter, frameTimeCounter * 0.3) * netherWindSpeed;
	vec3 lp;
	lp.xz = (wpos.xz + wind) / cell;
	lp.y  = wpos.y / (cell * cloudDetailVaspect);
	return lp;
}

float vcCoverage(vec2 xz) {
	vec2 wind = vec2(frameTimeCounter, frameTimeCounter * 0.3) * netherWindSpeed;
	vec2 p = xz + wind;
	float t = frameTimeCounter * cloudEvolve;
	float sw = frameTimeCounter * 0.01;
	p += vec2(sin(p.y * 0.0007 + sw), cos(p.x * 0.0007 - sw * 0.8)) * 90.0;
	p += vec2(sin(dot(p, vec2( 0.6, 0.4)) * 0.0009 + t * 0.02),
	          cos(dot(p, vec2(-0.4, 0.6)) * 0.0009 + t * 0.02)) * 120.0;
	float n1 = vcNoise(p * netherCoverScale * 0.5);        // very large rolling masses
	float n2 = vcNoise(p * netherCoverScale * 1.6 + 0.37); // gentle medium variation
	float n  = n1 * 0.7 + n2 * 0.3;
	float th = 1.0 - netherCoverage;
	float c = clamp((n - th) / max(1.0 - th, 0.001), 0.0, 1.0);
	return pow(c, netherSeparation);
}

// fire veins
float netherVein(vec3 wpos) {
	vec3 lp = vcLatticePos(wpos, 0.5 / netherBillowScale);
	float t = frameTimeCounter * netherFireEvolve;
	lp.xz += vec2(t, -t * 0.6);
	float n = vcValNoise(lp);
	return smoothstep(0.35, 0.85, n);
}

float vcDensity(vec3 wpos) {
	float relH = (wpos.y - netherCeilBottom) / (netherCeilTop - netherCeilBottom);
	if (relH <= 0.0 || relH >= 1.0) return 0.0;

	float coverage = vcCoverage(wpos.xz);
	vcCoverageOut = coverage;
	if (coverage <= 0.0) return 0.0;

	float climb = frameTimeCounter * netherRiseSpeed;
	vec2  shear = vec2(sin(wpos.y * 0.12 + climb), cos(wpos.y * 0.09 - climb * 0.7)) * netherShear * relH;
	vec3  swirled = wpos;
	swirled.xz += shear;

	float depth = relH;	// 0 at the lava 1 at the top of the bank
	float bankTop = vcValNoise(vcLatticePos(swirled, 0.25 / netherBillowScale));
	float topH    = mix(0.25, 1.0, bankTop);
	float local   = clamp(relH / topH, 0.0, 1.0);

	float hang = exp(-local * netherHangFalloff);
	float env  = coverage * cloudThickness * hang;
	env *= smoothstep(1.0, 0.75, local);
	if (env <= 0.001) return 0.0;

	float bs = netherBillowScale;
	float macro = vcValNoise(vcLatticePos(swirled, 0.22 / bs));
	env *= mix(0.5, 1.5, macro);
	if (env <= 0.001) return 0.0;

	if (vcCheapLight) {
		float b = vcBil(vcValNoise(vcLatticePos(swirled, 0.55 / bs)));
		return clamp(env - b * b * cloudDetail * 0.35, 0.0, 1.0);
	}

	float meso = vcValNoise(vcLatticePos(swirled, 0.55 / bs));
	float billow = vcBil(macro) * 0.35 + vcBil(meso) * 0.65;
	float carve  = cloudDetail * 0.22 * (0.4 + 0.6 * depth);
	float d = env - billow * billow * carve;
	return clamp(d, 0.0, 1.0);
}

// cheap upward light march, basically how much lava 'glow' reaches this point from below.
float netherLightMarch(vec3 pos) {
	vec3 dir = vec3(0.0, -1.0, 0.0);	// toward the lava glow below
	float od = 0.0;
	float ss = 2.2;
	pos += dir * ss * 0.5;
	for (int i = 0; i < 4; i++) {
		pos += dir * ss;
		od  += vcDensity(pos) * ss;
		ss  *= 1.35;
	}
	return mix(0.35, 1.0, exp(-od * 2.5));
}

vec4 computeVolumetricClouds(vec3 worldDir, float terrainDist, float dither, int steps, float sunElevY, out float apparentDist) {

	apparentDist = 1e6;

	float transmittance = 1.0;
	vec3  scatter  = vec3(0.0);
	float distSum = 0.0, distWeight = 0.0;

	float camY = cameraPosition.y;
	float dy   = worldDir.y;

	// fade rays that graze the horizontal so there is no hard 'band' at the horizon
	// float horizonAA = smoothstep(0.0, 0.02, abs(dy));
	// if (horizonAA <= 0.001) return vec4(vec3(0.0), 1.0);
	float horizonAA = 1.0;

	float entryT, exitT;
	if (abs(dy) < 1e-4) {
		if (camY <= netherCeilBottom || camY >= netherCeilTop) return vec4(vec3(0.0), 1.0);
		entryT = 0.0;
		exitT  = 100000.0;
	} else {
		float t0 = (netherCeilBottom - camY) / dy;
		float t1 = (netherCeilTop    - camY) / dy;
		entryT = max(min(t0, t1), 0.0);
		exitT  = max(t0, t1);
	}
	exitT = min(exitT, netherFadeFar);	// stop at the bedrock / walls
	if (entryT >= exitT) return vec4(vec3(0.0), 1.0);

	float fine = clamp((netherCeilTop - netherCeilBottom) / 10.0, 2.5, cloudMaxStep);
	float t = entryT + fine * dither;
	float entryStart = entryT;
	bool  wasEmpty = true;

	for (int i = 0; i < cloudStepsCeil; i++) {
		if (t >= exitT) break;
		if (vcCheapLight && i >= cloudReflStepsCeil) break;

		float fineT   = fine;
		float coarseT = fineT * cloudSkipMult;

		vec3 pos = cameraPosition + worldDir * t;
		float density = vcDensity(pos);
		float nearFade = smoothstep(5.0, 30.0, t);	// t is distance along the ray from the eye
		density *= nearFade;
		if (density <= 0.0) { wasEmpty = true; t += coarseT; continue; }
		if (wasEmpty && coarseT > fineT) { t = max(entryT, t - coarseT + fineT); wasEmpty = false; continue; }
		wasEmpty = false;

		float relH = clamp((pos.y - netherCeilBottom) / (netherCeilTop - netherCeilBottom), 0.0, 1.0);
		float extinction = density;

		vec3  ambient = mix(netherAmbLow, netherAmbTop, relH);
		float shadow  = netherLightMarch(pos); 
		vec3  lit     = netherFireHi * shadow * netherFireStrength;
		float vein    = netherVein(pos);
		vec3  luminance = ambient + lit * (0.4 + 0.6 * vein);

		float stepT = exp(-extinction * fineT);
		float vis   = transmittance * (1.0 - stepT);
			  distSum    += t * vis;
			  distWeight += vis;
			  scatter    += transmittance * luminance * (1.0 - stepT);
			  transmittance *= stepT;

		if (transmittance < (vcCheapLight ? 0.15 : 0.05)) break;
		t += fineT;
	}

	float coveredDist = t - entryStart;
	float cloudAlpha  = 1.0 - transmittance;
	if (cloudAlpha <= 0.001) return vec4(vec3(0.0), 1.0);

	apparentDist = (distWeight > 0.0) ? distSum / distWeight : 1e6;

	vec3 cloudColor = scatter / cloudAlpha;

	float distFade = smoothstep(netherFadeNear, netherFadeFar, entryStart + coveredDist);
	cloudColor = mix(cloudColor, netherFogTint, distFade);
	cloudAlpha *= horizonAA * (1.0 - distFade * 0.85);

	return vec4(cloudColor * cloudAlpha, 1.0 - cloudAlpha);
}

vec3 vcReprojectCloudAt(vec3 worldDir, float apparentDist, float dt,
                        mat4 prevMV, mat4 prevP, vec3 prevCam) {
	vec3 cloudPos = cameraPosition + worldDir * apparentDist;

	vec2 windPerSec = vec2(1, 0.3) * netherWindSpeed;
	cloudPos.xz += windPerSec * dt;

	vec4 clip = prevP * prevMV * vec4(cloudPos - prevCam, 1.0);
	if (clip.w <= 0.0) return vec3(0.0);
	vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
	float valid = float(all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0))));
	return vec3(uv, valid);
}

vec3 vcReflectClouds(vec3 baseReflSky, vec3 reflWorldDir, float dither, float sunElevY) {
	if (reflWorldDir.y <= 0.0) return baseReflSky;
	vcCheapLight = true;
	float ignoredDist;
	vec4 c = computeVolumetricClouds(reflWorldDir, cloudReflDist, dither, cloudReflSteps, sunElevY, ignoredDist);
	vcCheapLight = false;
	vcReflectTrans = c.a;
	return baseReflSky * c.a + c.rgb;
}
