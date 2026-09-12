#if cloudQuality == 1 // Low
  #define cloudUpscale 6
  #define cloudSteps 20
  #define cloudLightSteps 4
  #define cloudStepsCeil 96
  #define cloudAccumLimit 44
#elif cloudQuality == 2 // Default
  #define cloudUpscale 4
  #define cloudSteps 24
  #define cloudLightSteps 5
  #define cloudStepsCeil 96
  #define cloudAccumLimit 20
#elif cloudQuality == 3 // High
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudLightSteps 7
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 4 // Ultra
  #define cloudUpscale 2
  #define cloudSteps 30
  #define cloudLightSteps 7
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 5 // Full Resolution
  #define cloudUpscale 1
  #define cloudSteps 40
  #define cloudLightSteps 10
  #define cloudStepsCeil 160
  #define cloudAccumLimit 0
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
#elif cloudUpscale == 1
const ivec2 vcCheckerTable[1] = ivec2[1](ivec2(0,0));
#endif
ivec2 vcCheckerOffset(int i) { return vcCheckerTable[i]; }


#define cloudReflStepsCeil 12	// hard march cap for reflections
#define cloudReflDist 4000.0	// the max reflected cloud distance
#define cloudMaxStep 90.0

// Empty space skipping
#define cloudSkipMult 3.5

#define cloudRainDrop 0.0 // set to zero for now, makes the transition to rain too abrupt

vec2 vcOffset8(int frame) {
	int i = frame & 7;
	if (i == 0) return vec2( 1.0, -3.0) / 8.0 * 0.5;
	if (i == 1) return vec2(-1.0,  3.0) / 8.0 * 0.5;
	if (i == 2) return vec2( 5.0,  1.0) / 8.0 * 0.5;
	if (i == 3) return vec2(-3.0, -5.0) / 8.0 * 0.5;
	if (i == 4) return vec2(-5.0,  5.0) / 8.0 * 0.5;
	if (i == 5) return vec2(-7.0, -1.0) / 8.0 * 0.5;
	if (i == 6) return vec2( 3.0,  7.0) / 8.0 * 0.5;
	return vec2( 7.0, -7.0) / 8.0 * 0.5;
}

// 16-frame low-discrepancy jitter (R2 sequence) in [-0.5, 0.5]
vec2 vcOffset16(int frame) {
	int i = (frame & 15) + 1;
	const float a1 = 0.7548776662466927;   // 1/g
	const float a2 = 0.5698402909980532;   // 1/g^2
	return fract(vec2(a1, a2) * float(i)) - 0.5;
}

// look modifiers //
#define cloudBottom (300.0 + cloudAltitude)
// Normal cloud top
#define cloudCumulusTop (470.0 + cloudAltitude)

// settings for varied cloud heights
#define cloudHeightVar 0.55   // [0.15 0.25 0.35 0.45 0.55 0.7 0.85] how far heights vary
#define cloudHeightFreq 0.35  // [0.15 0.22 0.30 0.35 0.45 0.60 0.80] size of the tall/short zones, higher = smaller i.e. more 'mixed'
#define cloudHeightBias 0.50  // [0.40 0.45 0.50 0.55 0.60] noise midpoint, lower = more clouds are tall

// height for the current column
#define vcVariedTop (vcBase + (vcTopCu - vcBase) * vcHeightFac)

// How often clouds merge into large connected masses, this has replaced the old crummy cumulonimbus clouds and is based on the actual cloud coverage noise
#define cloudBigClouds 0.65   // [0.00 0.25 0.40 0.55 0.70 0.85 1.00] higher = more/bigger masses
#define cloudBigMerge 0.26    // [0.10 0.18 0.26 0.34 0.45] how strongly a big zone fills in (threshold drop)
// curl the stringy noise contours into distinct rounded clouds instead of long noodles, without this clouds are stupidly long connected strings
#define cloudWarp 1.0         // [0.0 0.5 0.75 1.0 1.4 1.8] destringing swirl strength

// March ceiling. Includes the headroom where taller clouds rise above the
// normal height, so they aren't clipped!!
#define cloudTop (cloudCumulusTop + (cloudCumulusTop - cloudBottom) * cloudHeightVar)

#define cloudSelfshadow 0.5

// Noise config //
#define cloudNoiseRes 2048.0
#define cloudNoiseYoffset 193.0

#define cloudNoiseSingleFetch

#define cloudIso 0.0795775   // isotropic phase value, 1/(4*pi)

#define cloudPuff 0.30        // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80] gap depth between clouds
#define cloudDetailDist 2500.0    // max distancefor the 3rd detail octave
#define cloudDetail3Weight 0.10   // amplitude of the 3rd octave
#define cloudDetail3EnvGate 0.60  // only run 3rd octave where env < this
#define cloudDetail2Near 3000.0   // 2nd detail octave at full weight within this distance
#define cloudDetail2Far  6000.0   // 2nd octave faded out beyond this
#define cloudShapeOct 0.5         // frequency of the low 'shape' octave
#define cloudShapeWeight 0.5      // how much the shape octave dominates the carve

float vcBase = cloudBottom - cloudRainDrop * rainStrength;
float vcTopCu = cloudCumulusTop - 90.0 * rainStrength;

vec2  vcWind     = vec2(frameTimeCounter * cloudWindSpeed, frameTimeCounter * cloudWindSpeed * 0.3);
float vcSizeSqrt = sqrt(cloudSize);

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }

// Billow remap
// 0 at a lobe core (v = 0.5), 1 in the crevices between lobes.
float vcBil(float v) { return abs(v * 2.0 - 1.0); }

float vcRelH(float y) { return (y - vcBase) / (cloudTop - vcBase); }

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

vec3 vcLatticePos(vec3 wpos, float oct) {
	float cell = cloudDetailCell * vcSizeSqrt / oct;
	vec3 lp;
	lp.xz = (wpos.xz + vcWind) / cell;
	lp.y  = wpos.y / (cell * cloudDetailVaspect);
	return lp;
}

vec2 vcScrollXZ(vec3 wpos) {
	return wpos.xz + vcWind;
}

vec2 vcEvolveWarp(vec2 p) {
	float t = frameTimeCounter * cloudEvolve;
	return vec2(sin(dot(p, vec2(0.6, 0.4)) * 0.0009 + t * 0.02),
	            cos(dot(p, vec2(-0.4, 0.6)) * 0.0009 + t * 0.02)) * 450.0;
}

float vcCoverage(vec2 p) {
	// cloudEvolve controls how fast cloud shapes shift/change with time, bad approach to this but good enough for now
	float t = frameTimeCounter * cloudEvolve;
	vec2 warp = vcEvolveWarp(p);
	vec2 q = p + warp;

	// destring! this swirl curls the stringy contours of the coverage noise into distinct rounded clouds
	float wf = 0.0032;
	q += vec2(-sin(q.x * wf + 1.3) * cos(q.y * wf + 4.7),
	           cos(q.x * wf + 1.3) * sin(q.y * wf + 4.7)) * (120.0 * cloudWarp);

	float freq = cloudScale / cloudSize;
	float n0 = vcNoise(q * freq);
	float n1 = vcNoise(q * freq * 2.3 + 4.7);
	float n2 = vcNoise(q * freq * 5.1 + 8.1);
	float n = n0 * 0.6 + n1 * 0.3 + n2 * 0.1;
	float cover = mix(cloudCoverage, 0.80, rainStrength) + 0.10 * sin(t * 0.006);

	// occasional large clouds that tower because of the height coupling
	float broad  = vcNoise(q * (cloudScale * 0.18 / cloudSize) + 0.71);
	float bigLo  = mix(1.05, 0.30, cloudBigClouds);
	float bigZone = smoothstep(bigLo, bigLo + 0.16, broad);

    float th = (0.5 - cover * 0.5) - bigZone * cloudBigMerge;
    float c = clamp((n - th) / max(1.0 - th, 0.001), 0.0, 1.0);

    float sep = mix(cloudSeparation, 0.55, rainStrength);
    c = pow(c, sep);

	float gap = vcBil(n1) * 0.7 + vcBil(n2) * 0.3;
	c = clamp(c - gap * cloudPuff * (1.0 - bigZone) * (1.0 - rainStrength * 0.6), 0.0, 1.0);
	float region = vcNoise(p * (cloudScale * 0.06 / cloudSize) + 2.3);
	c *= smoothstep(0.2, 0.7, region);
    c *= mix(1.0, 0.55 + broad * 0.9, rainStrength * 0.8);
    return max(c, rainStrength * 0.42);
}

// Density Model //
float vcCoverageOut = 0.0;
float vcHeightFac = 1.0;
bool vcCheapLight = false;
float vcReflectTrans = 1.0;

float vcEnvelope(float coverage, float relH) {
	float up = max(relH - cloudBaseFlat, 0.0);
	float env = coverage * coverage * cloudThickness - up * up * up * cloudTopFall;

	env *= smoothstep(0.0, cloudBaseFlat, relH);

	if (rainStrength > 0.001) {
		float slab = coverage
		           * smoothstep(0.00, 0.28, relH)
		           * (1.0 - smoothstep(0.55, 1.0, relH));
			  slab *= 0.7 + 0.6 * coverage;  
		env = mix(env, slab * 1.7, rainStrength * 0.70);
	}

	return env;
}

float vcDensity(vec3 wpos) {
	float coverage = vcCoverage(vcScrollXZ(wpos));

	// Simplified density function for reflections
	if (vcCheapLight) {
		if (coverage <= 0.0) return 0.0;
		float relH = (wpos.y - vcBase) / (vcTopCu - vcBase);
		if (relH <= 0.0 || relH >= 1.0) return 0.0;
		float env = vcEnvelope(coverage, relH);
		if (env <= 0.0) return 0.0;
		float e1 = vcValNoise(vcLatticePos(wpos, 1.0));	// single octave, no swirl
		float b = vcBil(e1);
		float d = env - b * b * cloudDetail * (0.2 + relH);
		return clamp(d, 0.0, 1.0);
	}

	vcCoverageOut = coverage;
	if (coverage <= 0.0) return 0.0;

	float hn = vcNoise(vcScrollXZ(wpos) * (cloudScale * cloudHeightFreq / cloudSize) + 11.7);
	float hz = smoothstep(cloudHeightBias - 0.20, cloudHeightBias + 0.20, hn);
	float hc = smoothstep(0.10, 0.55, coverage);
	float dev = clamp(mix(hc, hz, 0.5), 0.0, 1.0);
	vcHeightFac = mix(1.0 - cloudHeightVar, 1.0 + cloudHeightVar, dev);

	float relH = (wpos.y - vcBase) / (vcVariedTop - vcBase);
	if (relH <= 0.0 || relH >= 1.0) return 0.0;

	float env = vcEnvelope(coverage, relH);
	if (env <= 0.0) return 0.0;

	vec3 dvec = wpos - cameraPosition;
	float dist2 = dot(dvec, dvec);

	float e0 = vcValNoise(vcLatticePos(wpos, cloudShapeOct));
	float e1 = vcValNoise(vcLatticePos(wpos, 1.0));
	float billow = vcBil(e0) * cloudShapeWeight + vcBil(e1) * 0.28;

	// 2nd detail octave, fade out with distance, skip the fetch once it's gone. This skip should save performance
	float w2 = 1.0 - smoothstep(cloudDetail2Near * cloudDetail2Near,
	                            cloudDetail2Far  * cloudDetail2Far, dist2);
	if (w2 > 0.001) {
		vec3 lp2 = vcLatticePos(wpos, 2.2);
		lp2.xz += (e1 - 0.5) * cloudSwirl; // warp fine detail
		billow += vcBil(vcValNoise(lp2)) * 0.12 * w2;
	}

	// Height based erosion, so clouds aren't just big smooth bricks
	float carve = cloudDetail * (0.2 + relH) * (1.0 - rainStrength * 0.22);
	float d = env - billow * billow * carve; // squared keeps lobe cores round and dense

	// Gated 3rd octave
	if (dist2 < cloudDetailDist * cloudDetailDist && env < cloudDetail3EnvGate) {
		float e3 = vcValNoise(vcLatticePos(wpos, 5.0));
		billow += vcBil(e3) * cloudDetail3Weight;
		d = env - billow * billow * carve;
	}

	return clamp(d, 0.0, 1.0);
}

float vcDensityShadowFast(vec3 wpos, float coverage) {
    if (coverage <= 0.0) return 0.0;
    float relH = (wpos.y - vcBase) / (vcVariedTop - vcBase);
    if (relH <= 0.0 || relH >= 1.0) return 0.0;
    float env = vcEnvelope(coverage, relH);
    if (env <= 0.0) return 0.0;
    float b = vcBil(vcValNoise(vcLatticePos(wpos, 1.0)));
    float d = env - b * b * cloudDetail * (0.2 + relH);
    return clamp(d, 0.0, 1.0);
}


// Lighting //
float vcPhaseG(float x, float g) {
	float gg = g * g;
	return (gg * -0.25 / PI + 0.25 / PI) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5);
}
float hg(float c, float g){
    float g2 = g*g;
    return (1.0 - g2) / (4.0*3.14159265 * pow(1.0 + g2 - 2.0*g*c, 1.5));
}
float vcPhase(float c) {
    float g = 0.8;
    return mix(vcPhaseG(c, g), vcPhaseG(c, -g * 0.5), 0.35);
}

// Depth toward the sun through the eroded density
float vcLightMarch(vec3 pos, vec3 sunDir, float coverage) {
	if (rainStrength > 0.6) {
        float toTop = max(vcVariedTop - pos.y, 0.0) / max(abs(sunDir.y), 0.15);
        return toTop * coverage * cloudDensity * cloudSelfshadow * 0.11 * (1.0 + rainStrength * 2.6);
    }
    float od = 0.0;
    float stepSize = (vcTopCu - vcBase) / float(cloudLightSteps) * 0.6;
    for (int i = 0; i < cloudLightSteps; i++) {
        pos += sunDir * stepSize;
        od += vcDensityShadowFast(pos, coverage) * stepSize;
        stepSize *= 1.7;
    }
    return od * cloudDensity * cloudSelfshadow;
}

vec4 computeVolumetricClouds(vec3 worldDir, float terrainDist, float dither, int steps, float sunElevY, out float apparentDist) {

    apparentDist = 1e6;

	vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

	vec2 res         = vec2(viewWidth, viewHeight);
	vec3 sunDirTrue  = normalize(mat3(gbufferModelViewInverse) * sunPosition);

	vec3  backScatter = vec3(0.0);
	float backTrans   = 1.0;

	float camY = cameraPosition.y;
	float dy   = worldDir.y;

	float entryT, exitT;
	if (abs(dy) < 1e-4) {
		if (camY <= vcBase || camY >= cloudTop) return vec4(backScatter, backTrans);
		entryT = 0.0;
		exitT  = 100000.0;
	} else {
		float t0 = (vcBase - camY) / dy;
		float t1 = (cloudTop    - camY) / dy;
		entryT = min(t0, t1);
		exitT  = max(t0, t1);
	}
	entryT = max(entryT, 0.0);
	exitT  = min(exitT, terrainDist);
	if (entryT >= exitT) return vec4(backScatter, backTrans);

	float horizon = smoothstep(0.0, 0.11, abs(dy));
	if (horizon <= 0.001) return vec4(backScatter, backTrans);

	float cosT  = dot(worldDir, sunDir);
	float phase = mix(vcPhase(cosT), cloudIso, rainStrength * 0.9);

	vec3 sunColor = (atmSunHue * atmDN * transitionFade + atmMoonLight * atmMoon * 0.4)
	          		* cloudSunBrightness * transitionFade * (1.0 - rainStrength * 0.97);

	vec3 skyAmb  = atmSkyAmbient(colortex15, res, sunDirTrue);
	float skyLum = max(dot(skyAmb, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
	float lowSun = 1.0 - smoothstep(0.0, 0.40, sunDirTrue.y);

	float sunL   = max(dot(sunColor, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
	vec3  sunHue = sunColor / sunL;

	#define duskOnset  0.16   // warm colour begins fading in below this sun height
	#define duskPeak   0.00   // warm is full at/below this
	#define duskEnd   -0.12   // warm fades back out once the sun is well under

	float goldenHour = smoothstep(duskOnset, duskPeak, sunDirTrue.y)
	                 * smoothstep(duskEnd,   duskPeak, sunDirTrue.y);

	vec3 ambBase = skyAmb;

	float sunFacing = max(dot(normalize(vec3(worldDir.x,   0.0, worldDir.z)   + 1e-4),
	                          normalize(vec3(sunDirTrue.x, 0.0, sunDirTrue.z) + 1e-4)), 0.0);

	float warmDir = pow(sunFacing, 1.6); 
	float duskAmt = goldenHour;
	vec3  warmLit = sunHue * skyLum;

	vec3 ambTop = ambBase * cloudAmbient * 1.35 * (1.0 - 0.6 * duskAmt);
	     ambTop += warmLit * cloudAmbient * (2.6 * duskAmt);

	vec3 ambBot = ambBase * cloudAmbient * mix(0.55, 0.85, lowSun);
	    // ambBot += warmLit * (0.8 * duskAmt);

	vec3 nightAmb = atmMoonSky(vec3(0.0, 1.0, 0.0), -sunDirTrue) * atmMoon;
		 ambTop += nightAmb;
		 ambBot += nightAmb * 0.55;

    float oa = smoothstep(0.0, 0.55, rainStrength);
    if (oa > 0.001) {
        vec3 ocAmb = atmosOvercastTint * atmOvercastLum(sunElevY);
        ambBot = mix(ambBot, ocAmb * 0.38, oa);
        ambTop = mix(ambTop, ocAmb * 1.45, oa);
    }

    float vcTransDim = mix(cloudTransitionDim, 1.0, transitionFade);
    ambBot *= vcTransDim;
    ambTop *= vcTransDim;

	float pathLen = exitT - entryT;
	// Adaptive stepping
	float fine   = clamp(190.0 / float(steps), 5.0, cloudMaxStep);
	float coarse = fine * cloudSkipMult;
	float t = entryT + fine * dither;
	bool  wasEmpty = true;

	float transmittance = 1.0;
	vec3  scatter       = vec3(0.0);
	float distSum = 0.0;
	float distWeight = 0.0;

	float phMid      = mix(phase, cloudIso, 0.5);
	float vh         = cosT * 0.5 + 0.5;	// is 0 away from sun, 1 is toward it
	float powderMix  = 0.8 * vh * vh;
	float powderStr  = cloudPowder * (1.0 - rainStrength);
	float msW1       = 0.80 * cloudMs;
	float msW2       = 0.45 * cloudMs;
	vec3  directBase = sunColor * (2.4 + 2.2 * goldenHour);
	float densMul    = cloudDensity * (1.0 + rainStrength * 1.1);

	for (int i = 0; i < cloudStepsCeil; i++) {
		if (t >= exitT) break;
		if (vcCheapLight && i >= cloudReflStepsCeil) break;

		// Distance LOD, keep clouds that are closer at the normal step, reduce far ones
		float lod     = 1.0 + max(t - 2000.0, 0.0) * (1.0 / 3000.0);
		float fineT   = min(fine * lod, cloudMaxStep);
		float coarseT = fineT * cloudSkipMult;

		vec3 pos = cameraPosition + worldDir * t;
		float density = vcDensity(pos);

		if (density <= 0.0) {
			wasEmpty = true;
			t += coarseT;	// skip empty air
			continue;
		}

		if (wasEmpty && coarseT > fineT) {
			t = max(entryT, t - coarseT + fineT);
			wasEmpty = false;
			continue;
		}
		wasEmpty = false;
		
        float extinction = density * densMul;

		float relH = clamp((pos.y - vcBase) / (vcVariedTop - vcBase), 0.0, 1.0);

		// Contribution-gated lighting, switched to using the cheap analytic estimate instead of a
		// full light march.
		float odSun = (vcCheapLight || transmittance < 0.2)
		            ? density * cloudDensity * 24.0
		            : vcLightMarch(pos, sunDir, vcCoverageOut);

		// Multiple scattering
		float scatterSun = exp(-odSun)          * phase
		                 + exp(-odSun * 0.40) * phMid   * msW1
		                 + exp(-odSun * 0.08) * cloudIso * msW2;

		// Powder
        float powder = density / (density + 0.15);
        powder = mix(powder, 1.0, powderMix);
        scatterSun *= mix(1.0, powder, powderStr);

		vec3 ambient = mix(ambBot, ambTop, relH);
		vec3 direct = directBase * scatterSun;
		vec3 luminance = ambient + direct;

		float stepT = exp(-extinction * fineT);
		float vis   = transmittance * (1.0 - stepT);
			  distSum    += t * vis;
			  distWeight += vis;
			  scatter += transmittance * luminance * (1.0 - stepT);
			  transmittance *= stepT;

		if (transmittance < (vcCheapLight ? 0.10 : 0.02)) break;
			t += fineT;
	}

	float coveredDist = t - entryT;

	float cloudAlpha = 1.0 - transmittance;
	if (cloudAlpha <= 0.001) return vec4(backScatter, backTrans);

	apparentDist = (distWeight <= 0.0) ? 1e6 : distSum / distWeight;

	vec3 cloudColor = scatter / cloudAlpha;

	float distFade = smoothstep(3000.0, 13000.0, entryT + coveredDist);
	vec3 farCol = mix(atmSky(colortex15, res, worldDir, sunDirTrue), atmosOvercastTint * atmOvercastLum(sunElevY) * 0.333, rainStrength) * vcTransDim;
    cloudColor = mix(cloudColor, farCol, distFade * 0.85);
	cloudAlpha *= horizon * (1.0 - distFade * 0.75) * max(transitionFade, 0.85);

	float cumT = 1.0 - cloudAlpha;
	vec3  cumS = cloudColor * cloudAlpha;
	vec3  outS = cumS + cumT * backScatter;
	float outT = cumT * backTrans;
	return vec4(outS, outT);
}

vec3 vcReprojectCloudAt(vec3 worldDir, float apparentDist, float dt,
                        mat4 prevMV, mat4 prevP, vec3 prevCam) {
    vec3 cloudPos = cameraPosition + worldDir * apparentDist;

    vec2 windPerSec = vec2(cloudWindSpeed, cloudWindSpeed * 0.3);
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
