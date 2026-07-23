#ifndef CLOUDS_GLSL
#define CLOUDS_GLSL

#ifndef VC_UPSCALE
#define VC_UPSCALE 4
#endif

#ifndef VC_QUALITY
#define VC_QUALITY 2
#endif

#ifndef VC_REFLECTIONS
#define VC_REFLECTIONS
#endif

#if VC_QUALITY == 1
  #define VC_UPSCALE 6
  #define VC_STEPS 20
  #define VC_LIGHT_STEPS 4
  #define VC_STEPS_CEIL 96
  #define VC_ACCUM_LIMIT 44
#elif VC_QUALITY == 2
  #define VC_UPSCALE 4
  #define VC_STEPS 26
  #define VC_LIGHT_STEPS 5
  #define VC_STEPS_CEIL 96
  #define VC_ACCUM_LIMIT 20
#elif VC_QUALITY == 3
  #define VC_UPSCALE 3
  #define VC_STEPS 30
  #define VC_LIGHT_STEPS 7
  #define VC_STEPS_CEIL 112
  #define VC_ACCUM_LIMIT 20
#elif VC_QUALITY == 4
  #define VC_UPSCALE 2
  #define VC_STEPS 30
  #define VC_LIGHT_STEPS 7
  #define VC_STEPS_CEIL 112
  #define VC_ACCUM_LIMIT 20
#endif

#if VC_UPSCALE == 6
const ivec2 vcCheckerTable[36] = ivec2[36](
    ivec2(3,3), ivec2(0,0), ivec2(0,3), ivec2(3,0), ivec2(1,1), ivec2(1,4),
    ivec2(2,2), ivec2(2,5), ivec2(4,1), ivec2(4,4), ivec2(5,2), ivec2(5,5),
    ivec2(0,1), ivec2(0,2), ivec2(0,4), ivec2(0,5), ivec2(1,0), ivec2(1,2),
    ivec2(1,3), ivec2(1,5), ivec2(2,0), ivec2(2,1), ivec2(2,3), ivec2(2,4),
    ivec2(3,1), ivec2(3,2), ivec2(3,4), ivec2(3,5), ivec2(4,0), ivec2(4,2),
    ivec2(4,3), ivec2(4,5), ivec2(5,0), ivec2(5,1), ivec2(5,3), ivec2(5,4));
#elif VC_UPSCALE == 4
const ivec2 vcCheckerTable[16] = ivec2[16](
    ivec2(0,0), ivec2(2,0), ivec2(0,2), ivec2(2,2),
    ivec2(1,1), ivec2(3,1), ivec2(1,3), ivec2(3,3),
    ivec2(1,0), ivec2(3,0), ivec2(1,2), ivec2(3,2),
    ivec2(0,1), ivec2(2,1), ivec2(0,3), ivec2(2,3));
#elif VC_UPSCALE == 3
const ivec2 vcCheckerTable[9] = ivec2[9](
    ivec2(0,0), ivec2(2,0), ivec2(0,2), ivec2(2,2), ivec2(1,1),
    ivec2(1,0), ivec2(1,2), ivec2(0,1), ivec2(2,1));
#elif VC_UPSCALE == 2
const ivec2 vcCheckerTable[4] = ivec2[4](ivec2(0,0), ivec2(1,1), ivec2(1,0), ivec2(0,1));
#endif
ivec2 vcCheckerOffset(int i) { return vcCheckerTable[i]; }


#ifndef VC_REFL_STEPS
#define VC_REFL_STEPS 4
#endif
#ifndef VC_MAX_STEP
#define VC_MAX_STEP 90.0
#endif

// Empty space skipping
#ifndef VC_SKIP_MULT
#define VC_SKIP_MULT 3.5
#endif

#ifndef VC_RAIN_DROP
#define VC_RAIN_DROP 130.0
#endif
#ifndef VC_RAIN_SLAB
#define VC_RAIN_SLAB 0.88
#endif
#ifndef VC_RAIN_OPACITY
#define VC_RAIN_OPACITY 2.6
#endif

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
#ifndef VC_CLOUD_BOTTOM
#define VC_CLOUD_BOTTOM (300.0 + VC_ALTITUDE)
#endif
// Normal cloud top.
#ifndef VC_CUMULUS_TOP
#define VC_CUMULUS_TOP (470.0 + VC_ALTITUDE)
#endif
// Cumulonimbus
#ifndef VC_CUMULONIMBUS
#define VC_CUMULONIMBUS 1
#endif
#ifndef VC_CB_TOP
#define VC_CB_TOP (900.0 + VC_ALTITUDE)      // tower ceiling
#endif
#ifndef VC_CB_AMOUNT
#define VC_CB_AMOUNT 0.2    // rarity
#endif
// 'anvil' vertical profile, couldn't actually get the anvil shaping to work but this ended up looking good so...
#ifndef VC_CB_WAIST
#define VC_CB_WAIST 0.40     // width at the middle
#endif
#ifndef VC_CB_BASE
#define VC_CB_BASE 0.10      // extra width at the base
#endif
#ifndef VC_CB_ANVIL
#define VC_CB_ANVIL 0.75     // extra width at the top
#endif
#ifndef VC_CB_ANVIL_H
#define VC_CB_ANVIL_H 0.82   // height of the anvil
#endif
#ifndef VC_CB_THIN
#define VC_CB_THIN 0.28     // how much thinner the top is
#endif
#ifndef VC_CB_ROUGH
#define VC_CB_ROUGH 2.60     // extra erosion
#endif
#ifndef VC_CB_COVER
#define VC_CB_COVER 0.40     // the coverage above which a cloud towers into cumulonimbus
#endif

// March ceiling
#if VC_CUMULONIMBUS == 1
#define VC_CLOUD_TOP VC_CB_TOP
#else
#define VC_CLOUD_TOP VC_CUMULUS_TOP
#endif

#ifndef VC_COVERAGE
#define VC_COVERAGE 0.40
#endif
#ifndef VC_SEPARATION
#define VC_SEPARATION 1.80
#endif
#ifndef VC_DENSITY
#define VC_DENSITY 0.50      // opacity
#endif
#ifndef VC_DETAIL
#define VC_DETAIL 1.00       // billow carve depth
#endif
#ifndef VC_SIZE
#define VC_SIZE 3.0          // overall scale
#endif

#ifndef VC_THICKNESS
#define VC_THICKNESS 3.0
#endif
#ifndef VC_TOP_FALL
#define VC_TOP_FALL 1.0
#endif
#ifndef VC_BASE_FLAT
#define VC_BASE_FLAT 0.24
#endif

// Detail
#ifndef VC_DETAIL_CELL
#define VC_DETAIL_CELL 26.0
#endif
#ifndef VC_DETAIL_VASPECT
#define VC_DETAIL_VASPECT 0.80
#endif

#ifndef VC_SELFSHADOW
#define VC_SELFSHADOW 3.20
#endif

// Multiple scattering fill
#ifndef VC_MS
#define VC_MS 0.80
#endif
// Powder/dark edge strength
#ifndef VC_POWDER
#define VC_POWDER 0.30
#endif
// Billow swirl
#ifndef VC_SWIRL
#define VC_SWIRL 0.60
#endif

#ifndef VC_SUN_BRIGHTNESS
#define VC_SUN_BRIGHTNESS 6.0
#endif
#ifndef VC_AMBIENT
#define VC_AMBIENT 0.55
#endif
#ifndef VC_WIND_SPEED
#define VC_WIND_SPEED 5.0
#endif
// Shape change over time, off for now
#ifndef VC_EVOLVE
#define VC_EVOLVE 0.0
#endif

// Noise config //
#ifndef VC_NOISE_RES
#define VC_NOISE_RES 2048.0
#endif
#ifndef VC_NOISE_YOFFSET
#define VC_NOISE_YOFFSET 193.0
#endif

#define VC_NOISE_SINGLE_FETCH

#ifndef VC_PI
#define VC_PI 3.14159265
#endif
#define VC_ISO 0.0795775   // isotropic phase value, 1/(4*pi)

float vcBase = VC_CLOUD_BOTTOM - VC_RAIN_DROP * rainStrength;
float vcTopCu = VC_CUMULUS_TOP - 90.0 * rainStrength;

const float VC_SCALE_COVERAGE = 0.0000060;

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }

float vcRelH(float y) { return (y - vcBase) / (VC_CLOUD_TOP - vcBase); }

float vcValNoise(vec3 pos) {
	vec3 pi = floor(pos);
	vec3 pf = fract(pos);
	pf = pf * pf * (3.0 - 2.0 * pf);
	vec2 uv = pi.xz + pf.xz + pi.y * vec2(0.0, VC_NOISE_YOFFSET);
	vec2 coord = uv / VC_NOISE_RES;
#ifdef VC_NOISE_SINGLE_FETCH
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r, xy.g, pf.y);
#else
	float n0 = texture2D(noisetex, coord).x;
	float n1 = texture2D(noisetex, coord + vec2(0.0, VC_NOISE_YOFFSET) / VC_NOISE_RES).x;
	return mix(n0, n1, pf.y);
#endif
}

vec3 vcLatticePos(vec3 wpos, float oct) {
	float cell = VC_DETAIL_CELL * sqrt(VC_SIZE) / oct;
	vec2 wind = vec2(frameTimeCounter * VC_WIND_SPEED, frameTimeCounter * VC_WIND_SPEED * 0.3);
	vec3 lp;
	lp.xz = (wpos.xz + wind) / cell;
	lp.y  = wpos.y / (cell * VC_DETAIL_VASPECT);
	return lp;
}

vec2 vcScrollXZ(vec3 wpos) {
	vec2 wind = vec2(frameTimeCounter * VC_WIND_SPEED, frameTimeCounter * VC_WIND_SPEED * 0.3);
	return wpos.xz + wind;
}

float vcCoverage(vec2 p) {
	// VC_EVOLVE controls how fast cloud shapes shift/change with time, bad approach to this but good enough for now
	float t = frameTimeCounter * VC_EVOLVE;
	vec2 warp = vec2(sin(dot(p, vec2(0.6, 0.4)) * 0.0009 + t * 0.02),
	                 cos(dot(p, vec2(-0.4, 0.6)) * 0.0009 + t * 0.02)) * 900.0;
	float n = vcNoise((p + warp) * (VC_SCALE_COVERAGE / VC_SIZE));
	float cover = mix(VC_COVERAGE, 0.97, rainStrength) + 0.10 * sin(t * 0.006);
    float th = 0.5 - cover * 0.5;
    float c = clamp((n - th) / max(1.0 - th, 0.001), 0.0, 1.0);

    float sep = mix(VC_SEPARATION, 0.55, rainStrength);
    c = pow(c, sep);
	float broad = vcNoise((p + warp) * (VC_SCALE_COVERAGE * 0.18 / VC_SIZE) + 0.71);
    c *= mix(1.0, 0.55 + broad * 0.9, rainStrength * 0.8);
    return max(c, rainStrength * 0.42);
}

float vcCloudType(vec2 p) {
#if VC_CUMULONIMBUS == 0
	return 0.0;
#else
	vec2 wind = vec2(frameTimeCounter * VC_WIND_SPEED, 0.0);
	float n = vcNoise((p + wind) * (VC_SCALE_COVERAGE * 0.25 / VC_SIZE) + 0.37);
	float t = 1.0 - VC_CB_AMOUNT;
	return smoothstep(t, min(t + 0.10, 0.999), n);
#endif
}


// Density Model //
float vcStormOut = 0.0;
float vcCoverageOut = 0.0;
bool vcCheapLight = false;
float vcReflectTrans = 1.0;

float vcCbProfile(float h) {
	float base  = exp(-pow((h - 0.06) / 0.22, 2.0));
	float anvil = exp(-pow((h - VC_CB_ANVIL_H) / 0.13, 2.0));
	float w = VC_CB_WAIST + VC_CB_BASE * base + VC_CB_ANVIL * anvil;
	w *= 1.0 - smoothstep(0.86, 1.06, h);
	return w;
}

float vcEnvelope(float coverage, float relH, float storm) {
	float up = max(relH - VC_BASE_FLAT, 0.0);
	float covH = coverage * mix(1.0, vcCbProfile(relH), storm);

	float topFall = VC_TOP_FALL * (1.0 - storm * 0.75);
	float env = covH * covH * VC_THICKNESS - up * up * up * topFall;

	env *= 1.0 - storm * relH * VC_CB_THIN;
	env *= smoothstep(0.0, VC_BASE_FLAT, relH);
	
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

#if VC_CUMULONIMBUS == 1
	float storm = vcCloudType(wpos.xz) * (1.0 - rainStrength * 0.92);
	vcStormOut = storm;
	coverage = max(coverage, storm * 0.9);
	vcCoverageOut = coverage;
#else
	float storm = 0.0;
	vcStormOut = 0.0;
#endif
	if (coverage <= 0.0) return 0.0;

	float localTop = mix(vcTopCu, VC_CB_TOP, pow(storm, 0.45));
	float relH = (wpos.y - vcBase) / (localTop - vcBase);
	if (relH <= 0.0 || relH >= 1.0) return 0.0;

	float env = vcEnvelope(coverage, relH, storm);
	if (env <= 0.0) return 0.0;

	float e1 = vcValNoise(vcLatticePos(wpos, 1.0));
	vec3 lp2 = vcLatticePos(wpos, 3.0);
	lp2.xz += (e1 - 0.5) * VC_SWIRL; // warp fine detail, WIP, kinda ass
	float e2 = vcValNoise(lp2);
	float n = (1.0 - e1) + (0.5 - e2 * 0.5);
	n /= 1.5;
	n = n * n;
	// Erosion "based on height"* for cumulonimbus, so cumulonimbus clouds are not just a big ol' smooth bricks
	float carve = VC_DETAIL * (0.2 + relH * (1.0 + storm * VC_CB_ROUGH)) * (1.0 - rainStrength * 0.22);
	float d = env - n * n * carve; // noise^4 carve
	return clamp(d, 0.0, 1.0);
}

float vcDensityShadowFast(vec3 wpos, float coverage, float storm) {
    if (coverage <= 0.0) return 0.0;
    float localTop = mix(vcTopCu, VC_CB_TOP, pow(storm, 0.45));
    float relH = (wpos.y - vcBase) / (localTop - vcBase);
    if (relH <= 0.0 || relH >= 1.0) return 0.0;
    float env = vcEnvelope(coverage, relH, storm);
    if (env <= 0.0) return 0.0;
    float n = 1.0 - vcValNoise(vcLatticePos(wpos, 1.0));
    n = n * n;
    float d = env - n * n * VC_DETAIL * (0.2 + relH);
    return clamp(d, 0.0, 1.0);
}


// Lighting //
float vcKleinNishina(float x, float e) {	// silver lining
    return e / (2.0 * VC_PI * (e - e * x + 1.0) * log(2.0 * e + 1.0));
}
float vcPhaseG(float x, float g) {
	float gg = g * g;
	return (gg * -0.25 / VC_PI + 0.25 / VC_PI) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5);
}

/* // Technically a better method, but breaks clouds. Can't figure out why but the improvement with this method is minimal so... idk
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
        float localTop = mix(vcTopCu, VC_CB_TOP, pow(storm, 0.45));
        float toTop = max(localTop - pos.y, 0.0) / max(abs(sunDir.y), 0.15);
        return toTop * coverage * VC_DENSITY * VC_SELFSHADOW * 0.11 * (1.0 + rainStrength * VC_RAIN_OPACITY);
    }
    float od = 0.0;
    float stepSize = (vcTopCu - vcBase) / float(VC_LIGHT_STEPS) * 0.6;
    for (int i = 0; i < VC_LIGHT_STEPS; i++) {
        pos += sunDir * stepSize;
        od += vcDensityShadowFast(pos, coverage, storm) * stepSize;
        stepSize *= 1.7;
    }
    return od * VC_DENSITY * VC_SELFSHADOW;
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
		if (camY <= vcBase || camY >= VC_CLOUD_TOP) return vec4(backScatter, backTrans);
		entryT = 0.0;
		exitT  = 100000.0;
	} else {
		float t0 = (vcBase - camY) / dy;
		float t1 = (VC_CLOUD_TOP    - camY) / dy;
		entryT = min(t0, t1);
		exitT  = max(t0, t1);
	}
	entryT = max(entryT, 0.0);
	exitT  = min(exitT, terrainDist);
	if (entryT >= exitT) return vec4(backScatter, backTrans);

	float horizon = smoothstep(0.0, 0.11, abs(dy));
	if (horizon <= 0.001) return vec4(backScatter, backTrans);

	float cosT  = dot(worldDir, sunDir);
	float phase = mix(vcPhase(cosT), VC_ISO, rainStrength * 0.9);

	vec3 sunColor = sunlightCol * VC_SUN_BRIGHTNESS * transitionFade * (1.0 - time[5] * 0.8) * (1.0 - rainStrength * 0.97);

    vec3 ambBot = mix(atmoColor, cloudFogCol, 0.5) * VC_AMBIENT * 0.42;
    vec3 ambTop = mix(cloudFogCol, atmoColor, 0.20) * VC_AMBIENT * 1.3 * (1.0 - time[5] * 0.5);
    float oa = smoothstep(0.0, 0.55, rainStrength);
    if (oa > 0.001) {
        vec3 ocAmb = ATMOS_OVERCAST_TINT * atmOvercastLum(sunElevY);
        ambBot = mix(ambBot, ocAmb * 0.38, oa);
        ambTop = mix(ambTop, ocAmb * 1.45, oa);
    }

	float pathLen = exitT - entryT;
	// Adaptive stepping
	float fine   = clamp(190.0 / float(steps), 5.0, VC_MAX_STEP);
	float coarse = fine * VC_SKIP_MULT;
	float t = entryT + fine * dither;
	bool  wasEmpty = true;

	float transmittance = 1.0;
	vec3  scatter       = vec3(0.0);
	float distSum = 0.0;
	float distWeight = 0.0;

	for (int i = 0; i < VC_STEPS_CEIL; i++) {
		if (t >= exitT) break;
		vec3 pos = cameraPosition + worldDir * t;
		float density = vcDensity(pos);

		if (density <= 0.0) {
			wasEmpty = true;
			t += coarse;	// skip empty air
			continue;
		}

		if (wasEmpty && coarse > fine) {
			t = max(entryT, t - coarse + fine);
			wasEmpty = false;
			continue;
		}
		wasEmpty = false;
		
        float extinction = density * VC_DENSITY * (1.0 + rainStrength * 1.1);

		float ambTopY = mix(vcTopCu, VC_CB_TOP, pow(vcStormOut, 0.45));
		float relH = clamp((pos.y - vcBase) / (ambTopY - vcBase), 0.0, 1.0);

		float odSun = vcCheapLight ? density * VC_DENSITY * 24.0 : vcLightMarch(pos, sunDir, vcCoverageOut, vcStormOut);

		// Multiple scattering
		float phMid = mix(phase, VC_ISO, 0.5);
		float scatterSun = exp(-odSun)          * phase
		                 + exp(-odSun * 0.40) * phMid  * (0.55 * VC_MS)
		                 + exp(-odSun * 0.15) * VC_ISO * (0.28 * VC_MS);

		// Powder
        float powder = density / (density + 0.15);
        float vh = cosT * 0.5 + 0.5;               // 0 away from sun, 1 toward it
        powder = mix(powder, 1.0, 0.8 * vh * vh);
        scatterSun *= mix(1.0, powder, VC_POWDER * (1.0 - rainStrength));

		vec3 ambient = mix(ambBot, ambTop, relH);
		vec3 direct  = sunColor * scatterSun * 2.4;
		vec3 luminance = ambient + direct;

		float stepT = exp(-extinction * fine);
		float vis   = transmittance * (1.0 - stepT);
			  distSum    += t * vis;
			  distWeight += vis;
			  scatter += transmittance * luminance * (1.0 - stepT);
			  transmittance *= stepT;

		if (transmittance < 0.02) break;
			t += fine;
	}

	float coveredDist = t - entryT;

	float cloudAlpha = 1.0 - transmittance;
	if (cloudAlpha <= 0.001) return vec4(backScatter, backTrans);

	apparentDist = (distWeight <= 0.0) ? 1e6 : distSum / distWeight;

	vec3 cloudColor = scatter / cloudAlpha;

	float distFade = smoothstep(3000.0, 13000.0, entryT + coveredDist);
	vec3 farCol = mix(atmoColor * 1.6, ATMOS_OVERCAST_TINT * atmOvercastLum(sunElevY) * 0.333, rainStrength);
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

    vec2 windPerSec = vec2(VC_WIND_SPEED, VC_WIND_SPEED * 0.3);
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
    vec4 c = computeVolumetricClouds(reflWorldDir, 1e9, dither, VC_REFL_STEPS, sunElevY, ignoredDist);
    vcCheapLight = false;
    vcReflectTrans = c.a;
    return baseReflSky * c.a + c.rgb;
}

#endif
