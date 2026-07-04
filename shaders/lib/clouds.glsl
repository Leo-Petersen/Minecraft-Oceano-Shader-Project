#define VC_STEPS_CEIL 48

// This exists in settings.glsl, but it's needed here too for some reason otherwise it doesn't show up in the settings menu lol
#ifndef VC_REFLECTIONS
#define VC_REFLECTIONS
#endif

// 8-frame sub-cell offset table (an 8-rooks pattern, thanks to the seventh page of google for the idea).
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

#define VC_PI 3.14159265

// temp, need to fiddle with later (TO DO: ADD TO SETTINGS MENU)
const float VC_SCALE_COVERAGE = 0.0000060;
const float VC_SCALE_BASE     = 0.0000160;
const float VC_SCALE_DETAIL   = 0.0001000;

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }

float vcRemap(float v, float lo, float hi, float nlo, float nhi) {
	return nlo + (clamp(v, lo, hi) - lo) / (hi - lo) * (nhi - nlo);
}

// Rotated fractal noise. The rotation per octave breaks grid alignment
float vcFBM3(vec2 p) {
	const mat2 m = mat2(1.6, -1.2, 1.2, 1.6);   // scale ~2 plus rotation
	float f  = 0.5000 * vcNoise(p); p = m * p;
	f += 0.2500 * vcNoise(p); p = m * p;
	f += 0.1250 * vcNoise(p);
	return f / 0.8750;
}
float vcFBM2(vec2 p) {
	const mat2 m = mat2(1.6, -1.2, 1.2, 1.6);
	float f  = 0.5000 * vcNoise(p); p = m * p;
	f += 0.2500 * vcNoise(p);
	return f / 0.7500;
}

float vcRelH(float y) { return (y - VC_CLOUD_BOTTOM) / (VC_CLOUD_TOP - VC_CLOUD_BOTTOM); }

float vcHeightGradient(float relH) {
	return smoothstep(0.0, 0.09, relH) * smoothstep(1.0, 0.35, relH);
}

// Cheap 3D (ish?) detail from the 2D noisetex
float vcErode(vec3 q, float s) {
	vec2 h = mat2(0.80, 0.60, -0.60, 0.80) * q.xz;   // rotated horizontal
	float a = vcNoise(h * s);
	float b = vcNoise(vec2(h.x, q.y) * s + 0.27);
	float c = vcNoise(vec2(h.y, q.y) * s + 0.61);
	return (a + b + c) * (1.0 / 3.0);
}

vec2 vcScrollXZ(vec3 wpos) {
	vec2 wind = vec2(frameTimeCounter * VC_WIND_SPEED, frameTimeCounter * VC_WIND_SPEED * 0.3);
	return wpos.xz + wind;
}

// Cheap density for the sun march
float vcDensityCheap(vec3 wpos) {
	float relH = vcRelH(wpos.y);
	float hg = vcHeightGradient(relH);
	if (hg <= 0.0) return 0.0;

	vec2 p = vcScrollXZ(wpos);
	float cov = clamp(vcNoise(p * (VC_SCALE_COVERAGE / VC_SIZE)) + VC_COVERAGE - 0.5, 0.0, 1.0);
	if (cov <= 0.0) return 0.0;

	float shape = vcFBM2(p * (VC_SCALE_BASE / VC_SIZE));
	return clamp(vcRemap(shape, 1.0 - cov, 1.0, 0.0, 1.0), 0.0, 1.0) * hg;
}

// Full density
float vcDensity(vec3 wpos) {
	float relH = vcRelH(wpos.y);
	float hg = vcHeightGradient(relH);
	if (hg <= 0.0) return 0.0;

	vec2 p = vcScrollXZ(wpos);

	// Where do clouds cluster?
	float cov = clamp(vcNoise(p * (VC_SCALE_COVERAGE / VC_SIZE)) + VC_COVERAGE - 0.5, 0.0, 1.0);
	if (cov <= 0.0) return 0.0;

	// Fluffy multi scale shape, remapped by coverage
	float shape = vcFBM3(p * (VC_SCALE_BASE / VC_SIZE));
	float d = vcRemap(shape, 1.0 - cov, 1.0, 0.0, 1.0);
	if (d <= 0.0) return 0.0;

	// 3D billow erosion
	vec3 ep = vec3(p.x, wpos.y, p.y);
	float e1 = vcErode(ep, VC_SCALE_DETAIL / VC_SIZE);
	float e2 = vcErode(ep, VC_SCALE_DETAIL / VC_SIZE * 2.5);
	float erode = e1 * 0.62 + e2 * 0.38;
	erode = erode * erode;	// contrast for defined billows
	d = vcRemap(d, erode * VC_DETAIL, 1.0, 0.0, 1.0);

	return clamp(d, 0.0, 1.0) * hg;
}

float vcPhase(float cosT) {
	float g1 = 0.70, g2 = -0.30;
	float a = (1.0 - g1 * g1) / pow(1.0 + g1 * g1 - 2.0 * g1 * cosT, 1.5);
	float b = (1.0 - g2 * g2) / pow(1.0 + g2 * g2 - 2.0 * g2 * cosT, 1.5);
	return mix(a, b, 0.30) / (4.0 * VC_PI);
}

float vcLightMarch(vec3 pos, vec3 sunDir) {
	float od = 0.0;
	float stepSize = (VC_CLOUD_TOP - VC_CLOUD_BOTTOM) / float(VC_LIGHT_STEPS);
	for (int i = 0; i < VC_LIGHT_STEPS; i++) {
		pos += sunDir * stepSize;
		od += vcDensityCheap(pos) * VC_DENSITY * stepSize;
		stepSize *= 1.7;
	}
	return od;
}

vec4 computeVolumetricClouds(vec3 worldDir, float terrainDist, float dither, int steps) {

	float camY = cameraPosition.y;
	float dy   = worldDir.y;

	float entryT, exitT;
	if (abs(dy) < 1e-4) {
		if (camY <= VC_CLOUD_BOTTOM || camY >= VC_CLOUD_TOP) return vec4(0.0, 0.0, 0.0, 1.0);
		entryT = 0.0;
		exitT  = 100000.0;
	} else {
		float t0 = (VC_CLOUD_BOTTOM - camY) / dy;
		float t1 = (VC_CLOUD_TOP    - camY) / dy;
		entryT = min(t0, t1);
		exitT  = max(t0, t1);
	}
	entryT = max(entryT, 0.0);
	exitT  = min(exitT, terrainDist);
	if (entryT >= exitT) return vec4(0.0, 0.0, 0.0, 1.0);

	// Wide horizon fade, clouds go transparent approaching the horizon
	float horizon = smoothstep(0.0, 0.11, abs(dy));
	if (horizon <= 0.001) return vec4(0.0, 0.0, 0.0, 1.0);

	vec3 sunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
	float cosT  = dot(worldDir, sunDir);
	float phase = vcPhase(cosT);

	// Cloud colouring using the existing parameters in lightCol.glsl
	vec3 sunColor = sunlightCol * VC_SUN_BRIGHTNESS * (1.0 - time[5] * 0.5);
	vec3 ambTop = cloudFogCol * VC_AMBIENT * 1.25;
	vec3 ambBot = cloudFogCol * VC_AMBIENT * 0.45;

	float pathLen  = exitT - entryT;
	float stepSize = min(pathLen / float(steps), VC_MAX_STEP);
	vec3  rayStep  = worldDir * stepSize;
	vec3  pos      = cameraPosition + worldDir * (entryT + stepSize * dither);
	float coveredDist = float(steps) * stepSize;

	float transmittance = 1.0;
	vec3  scatter       = vec3(0.0);

	for (int i = 0; i < VC_STEPS_CEIL; i++) {
		if (i >= steps) break;
		float density = vcDensity(pos);
		if (density > 0.01) {
			float extinction = density * VC_DENSITY;
			float relH = clamp(vcRelH(pos.y), 0.0, 1.0);

			float odSun  = vcLightMarch(pos, sunDir);
			float beer   = exp(-odSun);
			float powder = 1.0 - exp(-odSun * 2.0);

			// Multiplescattering(-ish), keep a bright floor so cores are not black.
			float sunEnergy = beer * mix(powder * 2.0, 1.0, 0.5) + beer * 0.15;

			vec3 direct  = sunColor * sunEnergy * (phase + 0.12);
			vec3 ambient = mix(ambBot, ambTop, relH);
			vec3 luminance = direct + ambient;

			float stepT = exp(-extinction * stepSize);
			scatter += transmittance * luminance * (1.0 - stepT);
			transmittance *= stepT;
			if (transmittance < 0.02) break;
		}
		pos += rayStep;
	}

	float cloudAlpha = 1.0 - transmittance;
	if (cloudAlpha <= 0.001) return vec4(0.0, 0.0, 0.0, 1.0);

	vec3 cloudColor = scatter / cloudAlpha;

	// Aerial perspective, basically distant clouds tint toward the horizon haze color and
	// lose opacity, matching the existing fog rather than sitting on top of it, 
	// this is necessary to properly blend with the skybox and distant terrain
	// TO DO: This fades the clouds out far earlier than they are being rendered, there's performance to be gained by not marching as far
	float distFade = smoothstep(3000.0, 13000.0, entryT + coveredDist);
	cloudColor = mix(cloudColor, atmoColor * 1.6, distFade * 0.85);
	cloudAlpha *= horizon * (1.0 - distFade * 0.75) * transitionFade;

	return vec4(cloudColor * cloudAlpha, 1.0 - cloudAlpha);
}

// Reproject a cloud layer direction to where it appeared on screen last frame
vec3 vcReprojectCloud(vec3 worldDir, mat4 prevMV, mat4 prevP, vec3 prevCam) {
	if (worldDir.y <= 0.0) return vec3(0.0);
	float midY = (VC_CLOUD_BOTTOM + VC_CLOUD_TOP) * 0.5;
	float t = (midY - cameraPosition.y) / worldDir.y;
	if (t <= 0.0) return vec3(0.0);
	vec3 wpos = cameraPosition + worldDir * t;
	vec4 pc = prevP * prevMV * vec4(wpos - prevCam, 1.0);
	if (pc.w <= 0.0) return vec3(0.0);
	vec2 uv = pc.xy / pc.w * 0.5 + 0.5;
	float valid = float(all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0))));
	return vec3(uv, valid);
}

//Clouds for a reflected ray (water, puddles). Marches the cloud layer
//along the mirror direction and composites over the reflected sky color
//Cheaper step count since reflections are lower-priority and TAA-smoothed (This saves a decent amount on performance!).
//Returns the sky color unchanged when the reflected ray points downward
vec3 vcReflectClouds(vec3 baseReflSky, vec3 reflWorldDir, float dither) {
	if (reflWorldDir.y <= 0.0) return baseReflSky;
	vec4 c = computeVolumetricClouds(reflWorldDir, 1e9, dither, VC_REFL_STEPS);
	return baseReflSky * c.a + c.rgb;
}