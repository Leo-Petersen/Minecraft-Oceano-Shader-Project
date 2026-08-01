#if cloudQuality == 1
  #define cloudUpscale 6
  #define cloudSteps 20
  #define cloudLightSteps 4
  #define cloudStepsCeil 96
  #define cloudAccumLimit 44
#elif cloudQuality == 2
  #define cloudUpscale 4
  #define cloudSteps 24
  #define cloudLightSteps 5
  #define cloudStepsCeil 96
  #define cloudAccumLimit 20
#elif cloudQuality == 3
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudLightSteps 7
  #define cloudStepsCeil 112
  #define cloudAccumLimit 20
#elif cloudQuality == 4
  #define cloudUpscale 2
  #define cloudSteps 30
  #define cloudLightSteps 7
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
// Normal cloud top.
#define cloudCumulusTop (470.0 + cloudAltitude)
// Cumulonimbus
#define cloudCumulonimbus
#define cloudCbTop (900.0 + cloudAltitude)      // tower ceiling
// 'anvil' vertical profile, couldn't actually get the anvil shaping to work but this ended up looking good so...
#define cloudCbWaist 0.40     // width at the middle
#define cloudCbBase 0.10      // extra width at the base
#define cloudCbAnvil 0.75     // extra width at the top
#define cloudCbAnvilH 0.82   // height of the anvil
#define cloudCbThin 0.28     // how much thinner the top is
#define cloudCbRough 2.60     // extra erosion
#define cloudCbCover 0.40     // the coverage above which a cloud towers into cumulonimbus

// March ceiling
#ifdef cloudCumulonimbus
#define cloudTop cloudCbTop
#else
#define cloudTop cloudCumulusTop
#endif

#define cloudSelfshadow 1

// Noise config //
#define cloudNoiseRes 2048.0
#define cloudNoiseYoffset 193.0

#define cloudNoiseSingleFetch

#define cloudIso 0.0795775   // isotropic phase value, 1/(4*pi)

float vcBase = cloudBottom - cloudRainDrop * rainStrength;
float vcTopCu = cloudCumulusTop - 90.0 * rainStrength;

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }

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
	float cell = cloudDetailCell * sqrt(cloudSize) / oct;
	vec2 wind = vec2(frameTimeCounter * cloudWindSpeed, frameTimeCounter * cloudWindSpeed * 0.3);
	vec3 lp;
	lp.xz = (wpos.xz + wind) / cell;
	lp.y  = wpos.y / (cell * cloudDetailVaspect);
	return lp;
}

vec2 vcScrollXZ(vec3 wpos) {
	vec2 wind = vec2(frameTimeCounter * cloudWindSpeed, frameTimeCounter * cloudWindSpeed * 0.3);
	return wpos.xz + wind;
}

vec2 vcEvolveWarp(vec2 p) {
	float t = frameTimeCounter * cloudEvolve;
	return vec2(sin(dot(p, vec2(0.6, 0.4)) * 0.0009 + t * 0.02),
	            cos(dot(p, vec2(-0.4, 0.6)) * 0.0009 + t * 0.02)) * 900.0;
}

float vcCoverage(vec2 p) {
	// cloudEvolve controls how fast cloud shapes shift/change with time, bad approach to this but good enough for now
	float t = frameTimeCounter * cloudEvolve;
	vec2 warp = vcEvolveWarp(p);
	float n = vcNoise((p + warp) * (cloudScale / cloudSize));
	float cover = mix(cloudCoverage, 0.97, rainStrength) + 0.10 * sin(t * 0.006);
    float th = 0.5 - cover * 0.5;
    float c = clamp((n - th) / max(1.0 - th, 0.001), 0.0, 1.0);

    float sep = mix(cloudSeparation, 0.55, rainStrength);
    c = pow(c, sep);
	float broad = vcNoise((p + warp) * (cloudScale * 0.18 / cloudSize) + 0.71);
    c *= mix(1.0, 0.55 + broad * 0.9, rainStrength * 0.8);
    return max(c, rainStrength * 0.42);
}

float vcCloudType(vec2 p) {
#ifdef cloudCumulonimbus
	p += vcEvolveWarp(p);
	float n = vcNoise(p * (cloudScale * 0.25 / cloudSize) + 0.37);
	float th = 1.0 - cloudCbAmount;
	return smoothstep(th, min(th + 0.10, 0.999), n);
#else
	return 0.0;
#endif
}


// Density Model //
float vcStormOut = 0.0;
float vcCoverageOut = 0.0;
bool vcCheapLight = false;
float vcReflectTrans = 1.0;

float vcCbProfile(float h) {
	float base  = exp(-pow((h - 0.06) / 0.22, 2.0));
	float anvil = exp(-pow((h - cloudCbAnvilH) / 0.13, 2.0));
	float w = cloudCbWaist + cloudCbBase * base + cloudCbAnvil * anvil;
	w *= 1.0 - smoothstep(0.86, 1.06, h);
	return w;
}

float vcEnvelope(float coverage, float relH, float storm) {
	float up = max(relH - cloudBaseFlat, 0.0);
	float covH = coverage * mix(1.0, vcCbProfile(relH), storm);

	float topFall = cloudTopFall * (1.0 - storm * 0.75);
	float env = covH * covH * cloudThickness - up * up * up * topFall;

	env *= 1.0 - storm * relH * cloudCbThin;
	env *= smoothstep(0.0, cloudBaseFlat, relH);
	
	if (rainStrength > 0.001) {
		float slab = coverage
		           * smoothstep(0.00, 0.20, relH)
		           * (1.0 - smoothstep(0.42, 0.96, relH));
		env = mix(env, slab * 1.7, rainStrength * 0.70);
	}

	return env;
}

// Two octave noise^4 erosion, this seems to work best from what I've found. Revisit later
float vcDensity(vec3 wpos) {
	float coverage = vcCoverage(vcScrollXZ(wpos));

	// Simplified density function for reflections
	if (vcCheapLight) {
		vcStormOut = 0.0;
		if (coverage <= 0.0) return 0.0;
		float relH = (wpos.y - vcBase) / (vcTopCu - vcBase);
		if (relH <= 0.0 || relH >= 1.0) return 0.0;
		float env = vcEnvelope(coverage, relH, 0.0);
		if (env <= 0.0) return 0.0;
		float e1 = vcValNoise(vcLatticePos(wpos, 1.0));	// single octave, no swirl
		float n = 1.0 - e1; n = n * n;
		float d = env - n * n * cloudDetail * (0.2 + relH);
		return clamp(d, 0.0, 1.0);
	}

#ifdef cloudCumulonimbus
	float storm = vcCloudType(vcScrollXZ(wpos)) * (1.0 - rainStrength * 0.92);
	vcStormOut = storm;
	coverage = max(coverage, storm * 0.9);
	vcCoverageOut = coverage;
#else
	float storm = 0.0;
	vcStormOut = 0.0;
#endif
	if (coverage <= 0.0) return 0.0;

	float localTop = mix(vcTopCu, cloudCbTop, pow(storm, 0.45));
	float relH = (wpos.y - vcBase) / (localTop - vcBase);
	if (relH <= 0.0 || relH >= 1.0) return 0.0;

	float env = vcEnvelope(coverage, relH, storm);
	if (env <= 0.0) return 0.0;

	float e1 = vcValNoise(vcLatticePos(wpos, 1.0));
	vec3 lp2 = vcLatticePos(wpos, 3.0);
	lp2.xz += (e1 - 0.5) * cloudSwirl; // warp fine detail, WIP, kinda ass
	float e2 = vcValNoise(lp2);
	float n = (1.0 - e1) + (0.5 - e2 * 0.5);
	n /= 1.5;
	n = n * n;
	// Erosion "based on height"* for cumulonimbus, so cumulonimbus clouds are not just a big ol' smooth bricks
	float carve = cloudDetail * (0.2 + relH * (1.0 + storm * cloudCbRough)) * (1.0 - rainStrength * 0.22);
	float d = env - n * n * carve; // noise^4 carve
	return clamp(d, 0.0, 1.0);
}

float vcDensityShadowFast(vec3 wpos, float coverage, float storm) {
    if (coverage <= 0.0) return 0.0;
    float localTop = mix(vcTopCu, cloudCbTop, pow(storm, 0.45));
    float relH = (wpos.y - vcBase) / (localTop - vcBase);
    if (relH <= 0.0 || relH >= 1.0) return 0.0;
    float env = vcEnvelope(coverage, relH, storm);
    if (env <= 0.0) return 0.0;
    float n = 1.0 - vcValNoise(vcLatticePos(wpos, 1.0));
    n = n * n;
    float d = env - n * n * cloudDetail * (0.2 + relH);
    return clamp(d, 0.0, 1.0);
}


// Lighting //
float vcKleinNishina(float x, float e) {	// silver lining
    return e / (2.0 * PI * (e - e * x + 1.0) * log(2.0 * e + 1.0));
}
float vcPhaseG(float x, float g) {
	float gg = g * g;
	return (gg * -0.25 / PI + 0.25 / PI) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5);
}

/* // Technically a better method, but breaks clouds. Can't figure out why but the visual improvement with this method is minimal so... idk
float vcPhase(float cosT) {
    float fwdA = vcKleinNishina(cosT, 2600.0);
    float fwdB = vcPhaseG(cosT, 0.70);
    return 0.8 * max(fwdA, fwdB)
         + 0.2 * vcPhaseG(cosT, -0.20);
}
*/
float vcPhase(float cosT) {
    return max(vcPhaseG(cosT, 0.55), vcPhaseG(cosT, 0.20) * 0.7);
}

// Depth toward the sun through the eroded density
float vcLightMarch(vec3 pos, vec3 sunDir, float coverage, float storm) {
	if (rainStrength > 0.6) {
        float localTop = mix(vcTopCu, cloudCbTop, pow(storm, 0.45));
        float toTop = max(localTop - pos.y, 0.0) / max(abs(sunDir.y), 0.15);
        return toTop * coverage * cloudDensity * cloudSelfshadow * 0.11 * (1.0 + rainStrength * 2.6);
    }
    float od = 0.0;
    float stepSize = (vcTopCu - vcBase) / float(cloudLightSteps) * 0.6;
    for (int i = 0; i < cloudLightSteps; i++) {
        pos += sunDir * stepSize;
        od += vcDensityShadowFast(pos, coverage, storm) * stepSize;
        stepSize *= 1.7;
    }
    return od * cloudDensity * cloudSelfshadow;
}

vec4 computeVolumetricClouds(vec3 worldDir, float terrainDist, float dither, int steps, float sunElevY, out float apparentDist) {

    apparentDist = 1e6;

	vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

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

	vec3 sunColor = sunlightCol * cloudSunBrightness * transitionFade * (1.0 - time[5] * 0.8) * (1.0 - rainStrength * 0.97);

	vec3 ambBot = atmoColor * cloudAmbient * 0.62 + vec3(0.03, 0.045, 0.09) * time[5] * 0.86;
	vec3 ambTop = mix(atmoColor, cloudFogCol, 0.15) * cloudAmbient * 1.3;
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
		
        float extinction = density * cloudDensity * (1.0 + rainStrength * 1.1);

		float ambTopY = mix(vcTopCu, cloudCbTop, pow(vcStormOut, 0.45));
		float relH = clamp((pos.y - vcBase) / (ambTopY - vcBase), 0.0, 1.0);

		float odSun = vcCheapLight ? density * cloudDensity * 24.0 : vcLightMarch(pos, sunDir, vcCoverageOut, vcStormOut);

		// Multiple scattering
		float phMid = mix(phase, cloudIso, 0.5);
		float scatterSun = exp(-odSun)          * phase
		                 + exp(-odSun * 0.40) * phMid  * (0.55 * cloudMs)
		                 + exp(-odSun * 0.15) * cloudIso * (0.28 * cloudMs);

		// Powder
        float powder = density / (density + 0.15);
        float vh = cosT * 0.5 + 0.5;               // 0 away from sun, 1 toward it
        powder = mix(powder, 1.0, 0.8 * vh * vh);
        scatterSun *= mix(1.0, powder, cloudPowder * (1.0 - rainStrength));

		vec3 ambient = mix(ambBot, ambTop, relH);
		vec3 direct  = sunColor * scatterSun * 2.4;
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
	vec3 farCol = mix(atmoColor * 1.6, atmosOvercastTint * atmOvercastLum(sunElevY) * 0.333, rainStrength) * vcTransDim;
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