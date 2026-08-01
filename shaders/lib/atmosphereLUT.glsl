#define atmosPi 3.14159265

#define atmosRainMie 2.2
#define atmosRainG 0.30
#define atmosOvercast
#define atmosOvercastTint vec3(0.94, 0.97, 1.03)
#define atmosOvercastGain 0.62
#define atmosOvercastBlend 0.98
#define atmosOvercastNight 0.2

bool atmWantBand = true;

#define atmosSkyBrightness 20.0   // overall sky radiance
#define atmosSunBrightness 22.0   // direct sunlight strength
#define atmosFogDensity 0.0011    // aerial perspective density (per block)

// LUT Dimensions //
const vec2 atmosTransSize = vec2(256.0, 64.0);
const vec2 atmosMsSize    = vec2(32.0, 32.0);
const vec2 atmosSkySize   = vec2(192.0, 108.0);

const vec2 atmosTransOrg = vec2(0.0, 0.0);  // colortex14 (top-left)
const vec2 atmosMsOrg    = vec2(0.0, 64.0); // colortex14 (just below transmittance)
const vec2 atmosSkyOrg   = vec2(0.0, 0.0);  // colortex15 (top-left)

// medium //
const float atmosRg = 6360.0;    // ground radius (in km)
const float atmosRt = 6460.0;    // top of atmosphere (in km)

const vec3  atmosRayS = vec3(5.802e-3, 13.558e-3, 33.10e-3);
const float atmosMieS = 3.996e-3;
const float atmosMieE = 4.440e-3;
const vec3  atmosOzoA = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float atmosHr = 8.0;
const float atmosHm = 1.2;
const float atmosMieG = 0.80;

void atmMedium(float h, out vec3 rayS, out float mieS, out vec3 extinction) {
    h = max(h, 0.0);
    float dRay = exp(-h / atmosHr);

    float dMie = exp(-h / atmosHm) + rainStrength * exp(-h / 0.6) * 0.35;
    float dOzo = max(0.0, 1.0 - abs(h - 25.0) / 15.0);

    float mieMul = mix(1.0, atmosRainMie, rainStrength);

    rayS = atmosRayS * dRay;
    mieS = atmosMieS * dMie * mieMul;
    extinction = rayS + vec3(atmosMieE * dMie * mieMul) + atmosOzoA * dOzo * (1.0 - rainStrength * 0.8);
}

float atmRaySphere(vec3 ro, vec3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad * rad;
    float d = b * b - c;
    if (d < 0.0) return -1.0;
    d = sqrt(d);
    float t0 = -b - d;
    float t1 = -b + d;
    if (t1 < 0.0) return -1.0;
    return (t0 < 0.0) ? t1 : t0;
}

float atmPhaseR(float mu) { return 3.0 / (16.0 * atmosPi) * (1.0 + mu * mu); }
float atmPhaseM(float mu, float g) {
    float g2 = g * g;
    float num = 3.0 * (1.0 - g2) * (1.0 + mu * mu);
    float den = 8.0 * atmosPi * (2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-4), 1.5);
    return num / den;
}

// convert a LUT uv into a normalised buffer coord
vec2 atmLutCoord(vec2 uv, vec2 org, vec2 size, vec2 res) {
    uv = clamp(uv, 0.5 / size, 1.0 - 0.5 / size);
    return (org + uv * size) / res;
}

// Transmittance LUT //
vec3 atmTransmittanceToTop(float r, float mu) {
    vec3 ro = vec3(0.0, r, 0.0);
    vec3 rd = vec3(sqrt(max(1.0 - mu * mu, 0.0)), mu, 0.0);
    float t = atmRaySphere(ro, rd, atmosRt);
    if (t <= 0.0) return vec3(1.0);
    const int STEPS = 40;
    float seg = t / float(STEPS);
    vec3 od = vec3(0.0);
    for (int i = 0; i < STEPS; i++) {
        vec3 p = ro + rd * (float(i) + 0.5) * seg;
        float h = length(p) - atmosRg;
        vec3 rayS; float mieS; vec3 ext;
        atmMedium(h, rayS, mieS, ext);
        od += ext * seg;
    }
    return exp(-od);
}

void atmTransUvToRMu(vec2 uv, out float r, out float mu) {
    float H = sqrt(atmosRt * atmosRt - atmosRg * atmosRg);
    float rho = H * uv.y;
    r = sqrt(rho * rho + atmosRg * atmosRg);
    float dMin = atmosRt - r;
    float dMax = rho + H;
    float d = dMin + uv.x * (dMax - dMin);
    mu = (d == 0.0) ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = clamp(mu, -1.0, 1.0);
}
vec2 atmTransRMuToUv(float r, float mu) {
    float H = sqrt(atmosRt * atmosRt - atmosRg * atmosRg);
    float rho = sqrt(max(r * r - atmosRg * atmosRg, 0.0));
    float d = -mu * r + sqrt(max(r * r * (mu * mu - 1.0) + atmosRt * atmosRt, 0.0));
    float dMin = atmosRt - r;
    float dMax = rho + H;
    float xMu = (dMax - dMin <= 0.0) ? 0.0 : (d - dMin) / (dMax - dMin);
    float xR = rho / H;
    return clamp(vec2(xMu, xR), 0.0, 1.0);
}

vec3 atmGenTransmittance(vec2 uv) {
    float r, mu;
    atmTransUvToRMu(uv, r, mu);
    return atmTransmittanceToTop(r, mu);
}

vec3 atmFetchTrans(sampler2D tex, vec2 res, float r, float mu) {
    vec2 uv = atmTransRMuToUv(r, mu);
    return texture2D(tex, atmLutCoord(uv, atmosTransOrg, atmosTransSize, res)).rgb;
}

// Inline transmittance from point p toward dir
vec3 atmTransmittanceInline(vec3 p, vec3 dir) {
    float t = atmRaySphere(p, dir, atmosRt);
    if (t <= 0.0) return vec3(1.0);
    const int N = 12;
    float seg = t / float(N);
    vec3 od = vec3(0.0);
    for (int i = 0; i < N; i++) {
        vec3 s = p + dir * (float(i) + 0.5) * seg;
        float h = length(s) - atmosRg;
        vec3 rs; float ms; vec3 ext;
        atmMedium(h, rs, ms, ext);
        od += ext * seg;
    }
    return exp(-od);
}

// Multiple Scatter LUT //
vec3 atmGenMultiScatter(vec2 uv) {
    float cosSun = uv.x * 2.0 - 1.0;
    float r = mix(atmosRg + 0.001, atmosRt, uv.y);
    vec3 sunDir = vec3(sqrt(max(1.0 - cosSun * cosSun, 0.0)), cosSun, 0.0);
    vec3 ro = vec3(0.0, r, 0.0);

    const int SQ = 4;
    const int STEPS = 12;
    vec3 lumTotal = vec3(0.0);
    vec3 fmsTotal = vec3(0.0);
    float invN = 1.0 / float(SQ * SQ);

    for (int i = 0; i < SQ; i++)
    for (int j = 0; j < SQ; j++) {
        float u0 = (float(i) + 0.5) / float(SQ);
        float u1 = (float(j) + 0.5) / float(SQ);
        float cosT = 1.0 - 2.0 * u0;
        float sinT = sqrt(max(1.0 - cosT * cosT, 0.0));
        float phi = 2.0 * atmosPi * u1;
        vec3 rd = vec3(sinT * cos(phi), cosT, sinT * sin(phi));

        float tEnd = atmRaySphere(ro, rd, atmosRt);
        float tG = atmRaySphere(ro, rd, atmosRg);
        if (tG > 0.0) tEnd = min(tEnd, tG);
        if (tEnd <= 0.0) continue;
        float seg = tEnd / float(STEPS);

        vec3 tr = vec3(1.0);
        vec3 lum = vec3(0.0);
        vec3 fms = vec3(0.0);
        for (int s = 0; s < STEPS; s++) {
            vec3 p = ro + rd * (float(s) + 0.5) * seg;
            float rp = length(p);
            float h = rp - atmosRg;
            vec3 rayS; float mieS; vec3 ext;
            atmMedium(h, rayS, mieS, ext);
            vec3 sampleTr = exp(-ext * seg);
            vec3 scat = rayS + vec3(mieS);

            vec3 sInt = (scat - scat * sampleTr) / max(ext, vec3(1e-6));
            fms += tr * sInt;

            float muSun = dot(normalize(p), sunDir);
            vec3 sunTr = atmTransmittanceInline(p, sunDir);
            float shadow = (atmRaySphere(p, sunDir, atmosRg) > 0.0) ? 0.0 : 1.0;
            lum += tr * shadow * sunTr * scat * (1.0 / (4.0 * atmosPi))
                 * (vec3(1.0) - sampleTr) / max(ext, vec3(1e-6));

            tr *= sampleTr;
        }
        lumTotal += lum * invN;
        fmsTotal += fms * invN;
    }

    return lumTotal / max(vec3(1.0) - fmsTotal, vec3(1e-4));
}

vec3 atmFetchMS(sampler2D tex, vec2 res, float r, float cosSun) {
    vec2 uv = vec2(cosSun * 0.5 + 0.5, clamp((r - atmosRg) / (atmosRt - atmosRg), 0.0, 1.0));
    return texture2D(tex, atmLutCoord(uv, atmosMsOrg, atmosMsSize, res)).rgb;
}

// Skyview LUT //
vec3 atmSkyViewDir(vec2 uv) {
    float az = uv.x * 2.0 * atmosPi;
    float l = uv.y * 2.0 - 1.0;
    float elev = sign(l) * (l * l) * (atmosPi * 0.5);
    float ce = cos(elev);
    return vec3(ce * cos(az), sin(elev), ce * sin(az));
}
vec2 atmSkyViewUv(vec3 rd) {
    float elev = asin(clamp(rd.y, -1.0, 1.0));
    float l = sqrt(abs(elev) / (atmosPi * 0.5)) * sign(elev);
    float az = atan(rd.z, rd.x);
    if (az < 0.0) az += 2.0 * atmosPi;
    return clamp(vec2(az / (2.0 * atmosPi), l * 0.5 + 0.5), 0.0, 1.0);
}

// (sun at azimuth 0).
vec3 atmGenSkyView(vec2 uv, vec3 sunDir, float camAltKm, sampler2D transTex, sampler2D msTex, vec2 res) {
    vec3 rd = atmSkyViewDir(uv);
    float r = atmosRg + max(camAltKm, 0.003);
    vec3 ro = vec3(0.0, r, 0.0);

    float tEnd = atmRaySphere(ro, rd, atmosRt);
    float tG = atmRaySphere(ro, rd, atmosRg);
    if (tG > 0.0) tEnd = min(tEnd, tG);
    if (tEnd <= 0.0) tEnd = 1.0;

    const int STEPS = 32;
    float seg = tEnd / float(STEPS);
    float mu = dot(rd, sunDir);
    float pr = atmPhaseR(mu);
    float pm = atmPhaseM(mu, mix(atmosMieG, atmosRainG, rainStrength));

    vec3 tr = vec3(1.0);
    vec3 L = vec3(0.0);
    for (int s = 0; s < STEPS; s++) {
        vec3 p = ro + rd * (float(s) + 0.5) * seg;
        float rp = length(p);
        float h = rp - atmosRg;
        vec3 rayS; float mieS; vec3 ext;
        atmMedium(h, rayS, mieS, ext);
        vec3 sampleTr = exp(-ext * seg);

        float muSun = dot(normalize(p), sunDir);
        vec3 sunTr = atmFetchTrans(transTex, res, rp, muSun);
        float shadow = (atmRaySphere(p, sunDir, atmosRg) > 0.0) ? 0.0 : 1.0;

        vec3 scatSun = (rayS * pr + vec3(mieS) * pm) * sunTr * shadow;
        vec3 ms = atmFetchMS(msTex, res, rp, muSun) * (rayS + vec3(mieS));

        vec3 sInt = scatSun + ms;
        vec3 integ = (sInt - sInt * sampleTr) / max(ext, vec3(1e-6));
        L += tr * integ;
        tr *= sampleTr;
    }
    return L * atmosSkyBrightness;
}

float atmOvercastLum(float sunElevY) {
    float day = smoothstep(-0.10, 0.18, sunElevY);
    float lum = 0.10 + 2.30 * pow(max(sunElevY, 0.0), 0.62);
    return (lum * day + atmosOvercastNight) * atmosOvercastGain;
}

vec3 atmSky(sampler2D skyViewTex, vec2 res, vec3 rd, vec3 sunDir) {
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 sunAz = normalize(vec3(sunDir.x, 0.0, sunDir.z));
    if (length(vec3(sunDir.x, 0.0, sunDir.z)) < 1e-3) sunAz = vec3(1.0, 0.0, 0.0);
    vec3 right = normalize(cross(up, sunAz));
    vec3 local = vec3(dot(rd, sunAz), rd.y, dot(rd, right));
    vec2 uv = atmSkyViewUv(local);
    vec3 sky = texture2D(skyViewTex, atmLutCoord(uv, atmosSkyOrg, atmosSkySize, res)).rgb;

    // At and below the horizon the LUT has no data
    vec3 horizonCol = texture2D(skyViewTex,
        atmLutCoord(atmSkyViewUv(vec3(local.x, 0.0, local.z)), atmosSkyOrg, atmosSkySize, res)).rgb;
    float below = smoothstep(0.04, -0.0, rd.y);
    vec3 col = mix(sky, horizonCol, below);

    float oa = smoothstep(0.0, 0.55, rainStrength);
    if (oa > 0.001) {
        float ref = atmOvercastLum(sunDir.y);

        float cosZ = clamp(rd.y, 0.0, 1.0);
        float cie  = (1.0 + 2.0 * cosZ) / 3.0;
        vec3 oc = atmosOvercastTint * (ref * cie);

        col = mix(col, oc, oa * atmosOvercastBlend);
    }

    return col;
}

vec3 atmMoonSky(vec3 rd, vec3 moonDir) {
    float up = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 tint = vec3(0.05, 0.09, 0.20);
    float glow = atmPhaseM(dot(rd, moonDir), 0.6) * 0.5;
    float moonUp = clamp(moonDir.y * 2.0, 0.0, 1.0);
    return (tint * up + vec3(0.25, 0.30, 0.45) * glow) * moonUp;
}


vec3 atmSkyFinish(vec3 sky, vec3 rd, vec3 sunDir, vec3 moonDir) {
    float night = smoothstep(0.02, -0.10, sunDir.y);
    sky += atmMoonSky(rd, moonDir) * night * (1.0 - rainStrength * 0.95);
    float luma = dot(sky, vec3(0.2126, 0.7152, 0.0722));
    sky = mix(sky, vec3(luma), vec3(1.0 - 1.12));   // 12% saturation, matches luminance(sky, 1.12) in skybasic.fsh
    return sky;
}

vec3 atmSunColor(sampler2D transTex, vec2 res, vec3 sunDir) {
    float below = smoothstep(-0.06, 0.02, sunDir.y);
    vec3 tr = atmFetchTrans(transTex, res, atmosRg + 0.0005, clamp(sunDir.y, -1.0, 1.0));
    return tr * atmosSunBrightness * below * (1.0 - rainStrength * 0.97);
}

vec3 atmSkyAmbient(sampler2D skyViewTex, vec2 res, vec3 sunDir) {
    vec3 acc = vec3(0.0);
    atmWantBand = false;
    acc += atmSky(skyViewTex, res, vec3(0.0, 1.0, 0.0), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3( 0.6, 0.4,  0.0)), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3(-0.6, 0.4,  0.0)), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3( 0.0, 0.4,  0.6)), sunDir);
    atmWantBand = true;
    return acc * 0.25;
}

// aerial perspective
vec3 atmAerial(sampler2D skyViewTex, sampler2D transTex, vec2 res,
               vec3 rd, float distBlocks, vec3 sunDir, out float outTr) {
    outTr = exp(-distBlocks * atmosFogDensity);
    float fogAmt = 1.0 - outTr;
    vec3 rdHaze = normalize(vec3(rd.x, max(rd.y, 0.03) * 0.35, rd.z));
    vec3 sky = atmSky(skyViewTex, res, rdHaze, sunDir);
    float mu = dot(rd, sunDir);
    sky += atmSunColor(transTex, res, sunDir) * atmPhaseM(mu, mix(atmosMieG * 0.6, atmosRainG, rainStrength)) * 0.02 * fogAmt;
    return sky * fogAmt;
}

// Sunrise/sunset tint, WIP, coloring of the sky at these times needs work.
// Currently 'realistic' but that's boring, these numbers are a terrible temp fix //
#define atmosSunsetSkyTint 0.3   // strength on sky/clouds
#define atmosSunsetSkyTop 1.0    // how far up the tint reaches
#define atmosSunsetPastel 0.38    // 0 = saturated 1 = near white
vec3 atmSunsetTint(vec3 col, vec3 rd, vec3 sunDir, float clearness) {
    float sunsetT = exp(-pow(sunDir.y / 0.20, 2.0));
    if (sunsetT < 0.001) return col;
    float towardSun = max(dot(normalize(vec3(rd.x, 0.0, rd.z)),
                              normalize(vec3(sunDir.x, 0.0, sunDir.z))), 0.0);
    vec3 roseCol   = mix(vec3(1.70, 1.12, 0.62), vec3(1.0), atmosSunsetPastel);
    vec3 violetCol = mix(vec3(1.32, 1.04, 0.82), vec3(1.0), atmosSunsetPastel);
    vec3 tintCol = mix(violetCol, roseCol, pow(towardSun, 0.6));
    float skyReach  = smoothstep(atmosSunsetSkyTop, -0.05, rd.y);
    float cL        = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float cloudEmph = mix(0.85, 1.2, smoothstep(0.25, 0.8, cL));
    float amt = sunsetT * skyReach * atmosSunsetSkyTint * cloudEmph * clearness;
    vec3 target = tintCol * mix(cL, 1.0, 0.18);
    return mix(col, target, clamp(amt, 0.0, 0.92));
}

// aerial perspective //
#define atmosApDensity 0.040
#define atmosApHeight 90.0    // scale of density by height (in blocks), density halves about every 62 blocks up
#define atmosApBaseY 63.0    // altitude where density is full (currently set to sea level)
#define atmosApSourceExposure 1.0
#define atmosApLift 0.12  // how far above the horizon the fog samples

vec3 atmAerialPBR(vec3 surfaceColor, sampler2D skyViewTex, vec2 res,
                  vec3 rd, float distBlocks, vec3 sunDir, float clearness,
                  float camY, float fragY) {
    float rain = 1.0 - clearness;

    float apH = atmosApHeight * mix(1.0, 0.45, rain);
    float avgY = 0.5 * (camY + fragY);
    float heightFall = exp(-max(avgY - atmosApBaseY, 0.0) / apH);

    float aero = mix(1.0e-3, 4.0e-3, rain);
    vec3 betaExt = mix(atmosRayS, vec3(0.010), rain * 0.9) + vec3(aero);
    float nearGuard = smoothstep(0.0, 80.0, distBlocks);
    nearGuard *= nearGuard;
    vec3 tr = exp(-betaExt * (distBlocks * atmosApDensity * heightFall * nearGuard));
         tr = max(tr, vec3(0.30));

    float lift = atmosApLift * (1.0 - rain * 0.92);
    vec3 rdLift = normalize(vec3(rd.x, max(rd.y, 0.0) * (1.0 - rain * 0.8) + lift, rd.z));

    atmWantBand = false;
    vec3 skyC = atmSky(skyViewTex, res, rdLift, sunDir) * atmosApSourceExposure;
    atmWantBand = true;

    float apNight = 1.0 - smoothstep(-0.10, 0.06, sunDir.y);
    skyC *= mix(1 - rainStrength * 0.7, 1, apNight);

    skyC = atmSunsetTint(skyC, rd, sunDir, clearness * clearness);

    return surfaceColor * tr + skyC * (1.0 - tr);
}