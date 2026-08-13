// For the End all quality profiles are the same as high except ultra, 
// we have the performance overhead and any less than high looks bad
// Changed low to match old default
#if cloudQuality == 1
  #define cloudUpscale 4
  #define cloudSteps 24
  #define cloudLightSteps 5
  #define cloudStepsCeil 96
  #define cloudAccumLimit 20
#elif cloudQuality == 2
  #define cloudUpscale 3
  #define cloudSteps 30
  #define cloudLightSteps 7
  #define cloudStepsCeil 112
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

#define cloudReflStepsCeil 12
#define cloudReflDist 12000.0
#define cloudMaxStep 120.0
#define cloudSkipMult 3.5

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
vec2 vcOffset16(int frame) {
	int i = (frame & 15) + 1;
	const float a1 = 0.7548776662466927;
	const float a2 = 0.5698402909980532;
	return fract(vec2(a1, a2) * float(i)) - 0.5;
}

#define bhCenterX      2000.0
#define bhCenterZ      2000.0
#define bhCenterXZ     vec2(bhCenterX, bhCenterZ)
#define diskMidY      (-400.0 + cloudAltitude)
#define diskBandHalf   100.0

#define cloudBottom      (diskMidY - diskBandHalf)
#define cloudCumulusTop  (diskMidY + diskBandHalf)
#define cloudTop         cloudCumulusTop

// radial structure
#define diskInner   480.0
#define diskRimIn   760.0 
#define diskColorOut 3000.0
#define diskRimOut  13000.0 
#define diskOuter   16000.0 

#define diskThinH    15.0
#define diskThickH   34.0

// Orbit: omega(r) = orbitSpeed * r^-1.5
#define orbitSpeed   500.0
#define orbitDir     1.0

#define spiralWind    5.0
#define patternSpeed  0.006

#define diskCloudScale 0.75
#define diskCoverage   0.9
#define diskSeparation 0.90
#define billowScale    1.60

// spiral arms
#define diskArms          2.0
#define diskArmStrength   1.0

#define coreLightBright   6.5
#define coreLightColor    vec3(1.00, 0.92, 0.85)
#define cloudMsLocal      0.55
#define cloudPowderLocal  0.55
#define diskEmissionBright 1.55
#define ambLow            vec3(0.045, 0.030, 0.085)
#define ambHigh           vec3(0.110, 0.090, 0.200)
#define endAmb            vec3(0.050, 0.035, 0.100)

// doppler beaming
#define doppler        1.0
#define dopplerScale   0.012
#define dopplerPower   3.0

// black hole
#define bhRadius     340.0
#define bhRingScale  0.85
#define bhRingWidth  0.10
#define bhRingBright 51.0
#define bhGlow       1

#define lensing       1      // 1 on 0 off
#define lensStrength  1.0
#define lensShadow    1.0
#define lensFalloff   2.0
#define lensRange     4.0s

#define diskFadeNear   6000.0
#define diskFadeFar    14000.0
#define diskMarchFar   16000.0

// Noise config.
#define cloudNoiseRes 2048.0
#define cloudNoiseYoffset 193.0
#define cloudNoiseSingleFetch
#define cloudIso 0.0795775

float vcBase  = cloudBottom;
float vcTopCu = cloudCumulusTop;

float vcBayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
#define vcBayer4(a)  (vcBayer2(0.5 * (a)) * 0.25 + vcBayer2(a))
#define vcBayer8(a)  (vcBayer4(0.5 * (a)) * 0.25 + vcBayer2(a))

float vcNoise(vec2 uv) { return texture2D(noisetex, uv).x; }
float vcBil(float v) { return abs(v * 2.0 - 1.0); }

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

float vcOmega(float r) { return orbitDir * orbitSpeed * pow(max(r, diskInner), -1.5); }

// Fixed log spiral twist
float vcSwirlAngle(float ang, float r) {
	return ang + orbitDir * (spiralWind * log(max(r, diskInner)) - patternSpeed * frameTimeCounter);
}

vec3 vcMaterialPos(vec3 wpos) {
	vec2  rel = wpos.xz - bhCenterXZ;
	float r   = max(length(rel), 1e-3);
	float angM = vcSwirlAngle(atan(rel.y, rel.x), r);
	vec2  mxz  = vec2(cos(angM), sin(angM)) * r;
	return vec3(mxz.x, wpos.y, mxz.y);
}

vec3 vcLatticePos(vec3 mpos, float oct) {
	float cell = cloudDetailCell * sqrt(cloudSize) / oct;
	vec3 lp;
	lp.xz = mpos.xz / cell;
	lp.y  = mpos.y  / (cell * cloudDetailVaspect);
	return lp;
}

//	disk shape
float vcDiskRadial(float r) {
	float inner = smoothstep(diskInner,  diskRimIn,  r);
	float outer = 1.0 - smoothstep(diskRimOut, diskOuter, r);
	return inner * outer;
}
float vcDiskThickness(float r) {
	return mix(diskThinH, diskThickH, smoothstep(diskRimIn, diskColorOut, r));
}
float vcSpiralArms(vec2 rel, float r) {
	float ang = atan(rel.y, rel.x);
	float pat = diskArms * vcSwirlAngle(ang, r);
	return 0.5 + 0.5 * cos(pat);
}

float vcRadiusOut    = 0.0;
float vcCoverageOut  = 0.0;
bool  vcCheapLight   = false;
float vcReflectTrans = 1.0;

float vcCoverageDisk(vec2 rel, float r) {
	float radial = vcDiskRadial(r);
	if (radial <= 0.0) return 0.0;
	float angM = vcSwirlAngle(atan(rel.y, rel.x), r);
	vec2  mxz  = vec2(cos(angM), sin(angM)) * r;
	float sc   = cloudScale * diskCloudScale / cloudSize;
	float n  = vcNoise(mxz * sc);
	float nb = vcNoise(mxz * sc * 0.35 + 0.37);
	n = mix(n, nb, 0.45);
	float th = 1.0 - diskCoverage;
	float c  = clamp((n - th) / max(1.0 - th, 0.001), 0.0, 1.0);
	c = pow(c, diskSeparation);
	float arms = mix(1.0, vcSpiralArms(rel, r), diskArmStrength);
	return c * arms * radial;
}

float vcDensity(vec3 wpos) {
	vec2  rel = wpos.xz - bhCenterXZ;
	float r   = max(length(rel), 1e-3);
	float coverage = vcCoverageDisk(rel, r);
	vcRadiusOut = r; vcCoverageOut = coverage;
	if (coverage <= 0.0) return 0.0;

	float H  = vcDiskThickness(r);
	float dy = wpos.y - diskMidY;
	float hn = dy / H;
	float env = coverage * exp(-hn * hn) * cloudThickness;
	if (env <= 0.001) return 0.0;

	vec3 mpos = vcMaterialPos(wpos);
	float bs = billowScale;   // larger = bigger, smoother billow cells

	if (vcCheapLight) {
		float b = vcBil(vcValNoise(vcLatticePos(mpos, 1.0 / bs)));
		return clamp(env - b * b * cloudDetail * 0.4, 0.0, 1.0);
	}

	float e0 = vcValNoise(vcLatticePos(mpos, 0.5 / bs));
	float e1 = vcValNoise(vcLatticePos(mpos, 1.0 / bs));
	vec3 lp2 = vcLatticePos(mpos, 2.2 / bs);
	lp2.xz += (e1 - 0.5) * cloudSwirl;
	float e2 = vcValNoise(lp2);

	float billow = vcBil(e0) * 0.50 + vcBil(e1) * 0.32 + vcBil(e2) * 0.18;
	float carve  = cloudDetail * (0.32 + 0.38 * abs(hn));
	float d = env - billow * billow * carve;
	return clamp(d, 0.0, 1.0);
}

float vcDensityShadow(vec3 wpos) {
	vec2  rel = wpos.xz - bhCenterXZ;
	float r   = max(length(rel), 1e-3);
	float coverage = vcCoverageDisk(rel, r);
	if (coverage <= 0.0) return 0.0;
	float H  = vcDiskThickness(r);
	float dy = wpos.y - diskMidY;
	float hn = dy / H;
	float env = coverage * exp(-hn * hn) * cloudThickness;
	if (env <= 0.001) return 0.0;
	float b = vcBil(vcValNoise(vcLatticePos(vcMaterialPos(wpos), 1.0 / billowScale)));
	return clamp(env - b * b * cloudDetail * 0.4, 0.0, 1.0);
}

float vcPhaseG(float x, float g) {
	float gg = g * g;
	return (gg * -0.25 / PI + 0.25 / PI) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5);
}
float vcPhase(float cosT) {
	return max(vcPhaseG(cosT, 0.55), vcPhaseG(cosT, 0.20) * 0.7);
}

vec3 vcDiskColor(float r) {
	float t = clamp((r - diskRimIn) / max(diskColorOut - diskRimIn, 1.0), 0.0, 1.0);
	vec3 hot  = vec3(0.80, 0.88, 1.20);
	vec3 mid  = vec3(1.25, 0.70, 0.34);
	vec3 cool = vec3(0.60, 0.20, 0.34);
	return (t < 0.5) ? mix(hot, mid, t * 2.0) : mix(mid, cool, (t - 0.5) * 2.0);
}

float vcLightMarch(vec3 pos) {
	vec3 dir = normalize(vec3(bhCenterX, diskMidY, bhCenterZ) - pos);
	float od = 0.0;
	float ss = diskThickH / float(cloudLightSteps) * 0.9;
	for (int i = 0; i < cloudLightSteps; i++) {
		pos += dir * ss;
		od  += vcDensityShadow(pos) * ss;
		ss  *= 1.55;
	}
	return od * cloudDensity;
}

vec4 computeVolumetricClouds(vec3 worldDir, float terrainDist, float dither, int steps, float sunElevY, out float apparentDist) {

	apparentDist = 1e6;

	vec3 core = vec3(bhCenterX, diskMidY, bhCenterZ);

	// black hole view geometry
	float D       = length(core - cameraPosition);
	vec3  dirCore = (D > 1.0) ? (core - cameraPosition) / D : vec3(0.0, 0.0, 1.0);
	float facing  = dot(worldDir, dirCore);
	float angBH   = acos(clamp(facing, -1.0, 1.0));
	float angR    = atan(bhRadius / max(D, 1.0));

	// gravitational lensing
	float shadowAng = angR;
	vec3  bentDir  = worldDir;
	float tBend    = 1e30;
	bool  captured = false;
	bool  lensed   = false;
#if lensing
	shadowAng = angR * lensShadow;
	if (facing > 0.0 && angBH > 1e-4) {
		lensed = true;
		tBend  = max(D * facing, 1.0);
		if (angBH > shadowAng) {
			float defl = lensStrength * angR * pow(shadowAng / angBH, lensFalloff);
			defl = min(defl, angBH * 0.98);
			vec3  perp = normalize(dirCore - worldDir * facing);
			bentDir = normalize(worldDir * cos(defl) + perp * sin(defl));
		} else {
			captured = true;
		}
	}
#endif
	vec3 bendPoint = cameraPosition + worldDir * min(tBend, 100000.0);

	float inside  = 1.0 - smoothstep(shadowAng * 0.97, shadowAng, angBH);
	float ringC   = shadowAng * bhRingScale;
	float ringW   = max(shadowAng * bhRingWidth, 1e-4);
	float ring    = exp(-pow((angBH - ringC) / ringW, 2.0));
	float glow    = exp(-max(angBH - ringC, 0.0) / (shadowAng * 0.9)) * bhGlow;
	float occludeCone = ringC + ringW * 2.0;
	bool  bhCone  = (facing > 0.0) && (angBH < occludeCone);
	bool  bhDraw  = (facing > 0.0);   // black hole is in front of the camera

	float transmittance = 1.0;
	vec3  scatter = vec3(0.0);
	float distSum = 0.0, distWeight = 0.0;
	float coveredDist = 0.0, entryStart = 0.0;

	float camY = cameraPosition.y;
	float dy   = worldDir.y;
	float horizonAA = smoothstep(0.0, 0.006, abs(dy));
	#if lensing
		horizonAA = 1.0;
	#endif

	bool  doMarch = true;
	float entryT = 0.0, exitT = 100000.0;
	if (abs(dy) < 1e-4) {
		if (camY <= vcBase || camY >= cloudTop) doMarch = false;
	} else {
		float t0 = (vcBase - camY) / dy;
		float t1 = (cloudTop - camY) / dy;
		entryT = max(min(t0, t1), 0.0);
		exitT  = max(t0, t1);
	}
	exitT = min(exitT, min(terrainDist, diskMarchFar));
	if (entryT >= exitT || horizonAA <= 0.001) doMarch = false;
#if lensing
	if (lensed) {
		float fgEntry = max(entryT, 0.0);
		float fgExit  = min(exitT, tBend);
		bool  fgHit   = (fgExit > fgEntry);

		if (captured) {
			entryT = fgEntry;
			exitT  = fgExit;
			doMarch = fgHit;
		} else {
			float bdy = bentDir.y;
			float bEnter, bExit;
			if (abs(bdy) < 1e-4) {
				bool inSlab = (camY > vcBase && camY < cloudTop);
				bEnter = inSlab ? tBend : 1.0;
				bExit  = inSlab ? min(terrainDist, diskMarchFar) : 0.0;
			} else {
				float ta = (vcBase   - camY) / bdy;
				float tb = (cloudTop - camY) / bdy;
				bEnter = max(min(ta, tb), tBend);
				bExit  = min(max(ta, tb), min(terrainDist, diskMarchFar));
			}
			bool bHit = (bExit > bEnter + 1.0);

			if      (fgHit && bHit) { entryT = fgEntry; exitT = bExit;  doMarch = true; }
			else if (bHit)          { entryT = bEnter;  exitT = bExit;  doMarch = true; }
			else if (fgHit)         { entryT = fgEntry; exitT = fgExit; doMarch = true; }
			else                    { doMarch = false; }
		}
	}
#endif

	if (doMarch) {
	#if !lensing
		if (bhCone) exitT = min(exitT, D);
		vec3  ocb = cameraPosition - core;
		float bbh = dot(ocb, worldDir);
		float cch = dot(ocb, ocb) - bhRadius * bhRadius;
		float dsc = bbh * bbh - cch;
		if (dsc > 0.0) { float tb = -bbh - sqrt(dsc); if (tb > 0.0) exitT = min(exitT, tb); }
	#endif

		if (entryT < exitT) {
			entryStart = entryT;
			float fine = clamp(190.0 / float(steps), 5.0, cloudMaxStep);
			float t = entryT + fine * dither;
			bool  wasEmpty = true;

			for (int i = 0; i < cloudStepsCeil; i++) {
				if (t >= exitT) break;
				if (vcCheapLight && i >= cloudReflStepsCeil) break;

				float lod     = 1.0 + max(t - 2000.0, 0.0) * (1.0 / 3000.0);
				float fineT   = min(fine * lod, cloudMaxStep);
				float coarseT = fineT * cloudSkipMult;

				vec3 pos = (t < tBend) ? (cameraPosition + worldDir * t)
				                       : (cameraPosition + bentDir  * t);
				float density = vcDensity(pos);

				if (density <= 0.0) { wasEmpty = true; t += coarseT; continue; }
				if (wasEmpty && coarseT > fineT) { t = max(entryT, t - coarseT + fineT); wasEmpty = false; continue; }
				wasEmpty = false;

				float extinction = density * cloudDensity;
				float rSamp = length(pos.xz - bhCenterXZ);

				vec3  lightDir = normalize(core - pos);
				float cosT  = dot(worldDir, lightDir);
				float phase = vcPhase(cosT);
				float odSun = vcCheapLight ? density * cloudDensity * 6.0 : vcLightMarch(pos);

				float phMid = mix(phase, cloudIso, 0.5);
				float scatterSun = exp(-odSun)        * phase
				                 + exp(-odSun * 0.4)  * phMid    * (0.55 * cloudMsLocal)
				                 + exp(-odSun * 0.15) * cloudIso * (0.28 * cloudMsLocal);

				float powder = density / (density + 0.15);
				float vh = cosT * 0.5 + 0.5;
				powder = mix(powder, 1.0, 0.8 * vh * vh);
				scatterSun *= mix(1.0, powder, cloudPowderLocal);

				vec3 tint     = vcDiskColor(rSamp);
				vec3 lightCol = coreLightColor * mix(vec3(1.0), tint / max(tint.r, 1.0), 0.4);
				vec3 direct   = lightCol * coreLightBright * scatterSun;
				vec3 emission = tint * diskEmissionBright * smoothstep(diskColorOut, diskRimIn, rSamp);

				#if doppler > 0.0
				{
					vec2  drel = pos.xz - bhCenterXZ;
					float rr   = max(length(drel), 1e-3);
					vec2  tang = vec2(-drel.y, drel.x) / rr * orbitDir;
					vec3  velDir = vec3(tang.x, 0.0, tang.y);
					float speed  = abs(vcOmega(rr)) * rr;
					float beta   = clamp(speed * dopplerScale, 0.0, 0.5);
					float mu     = dot(velDir, -worldDir);
					float dop    = pow(clamp(1.0 + beta * mu, 0.25, 3.0), dopplerPower);
					direct   *= dop;
					emission *= dop;
				}
				#endif

				vec3 ambient = mix(ambHigh, ambLow, clamp((rSamp - diskRimIn) / max(diskColorOut - diskRimIn, 1.0), 0.0, 1.0))*2;
				vec3 luminance = ambient + direct + emission;

				float stepT = exp(-extinction * fineT);
				float vis   = transmittance * (1.0 - stepT);
					  distSum    += t * vis;
					  distWeight += vis;
					  scatter += transmittance * luminance * (1.0 - stepT);
					  transmittance *= stepT;

				if (transmittance < (vcCheapLight ? 0.10 : 0.02)) break;
				t += fineT;
			}
			coveredDist = t - entryStart;
		}
	}

	float cloudAlpha = 1.0 - transmittance;
	float distFade = smoothstep(diskFadeNear, diskFadeFar, entryStart + coveredDist);
	vec3  cloudColor = (cloudAlpha > 0.0001) ? scatter / cloudAlpha : vec3(0.0);
	cloudColor = mix(cloudColor, endAmb, distFade);
	cloudAlpha *= horizonAA * (1.0 - distFade);

	// black hole overlay
	vec3  ringCol  = vcDiskColor(diskRimIn);
	vec3  ringGlow = bhDraw ? ringCol * (ring * bhRingBright + glow) * (1.0 - inside) : vec3(0.0);
	float coverBehind = bhDraw ? max(inside, clamp(ring, 0.0, 1.0)) : 0.0;

	vec3  cloudPremul = cloudColor * cloudAlpha;
	float cloudTrans  = 1.0 - cloudAlpha;
	vec3  outS = cloudPremul + cloudTrans * cloudTrans * ringGlow;
	float outT = cloudTrans * (1.0 - coverBehind * cloudTrans);

	if (bhDraw && (inside > 0.0 || ring > 0.001)) apparentDist = min(apparentDist, D);
	else if (distWeight > 0.0)                    apparentDist = distSum / distWeight;

	if (cloudAlpha <= 0.001 && (!bhDraw || (inside <= 0.001 && ring <= 0.001 && glow <= 0.001)))
		return vec4(vec3(0.0), 1.0);

	return vec4(outS, outT);
}

vec3 vcReprojectCloudAt(vec3 worldDir, float apparentDist, float dt,
                        mat4 prevMV, mat4 prevP, vec3 prevCam) {
	vec3 cloudPos = cameraPosition + worldDir * apparentDist;
	vec2  rel = cloudPos.xz - bhCenterXZ;
	float r   = max(length(rel), 1e-3);
	float a   = -orbitDir * patternSpeed * dt;
	float cs = cos(a), sn = sin(a);
	rel = mat2(cs, -sn, sn, cs) * rel;
	cloudPos.xz = bhCenterXZ + rel;

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