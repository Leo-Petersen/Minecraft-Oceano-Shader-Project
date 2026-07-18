#ifndef ATMOSPHERE_LUT_GLSL
#define ATMOSPHERE_LUT_GLSL

#define ATM_PI 3.14159265

#ifndef ATMOS_SKY_BRIGHTNESS
#define ATMOS_SKY_BRIGHTNESS 20.0   // overall sky radiance
#endif
#ifndef ATMOS_SUN_BRIGHTNESS
#define ATMOS_SUN_BRIGHTNESS 22.0   // direct sunlight strength
#endif
#ifndef ATMOS_FOG_DENSITY
#define ATMOS_FOG_DENSITY 0.0011    // aerial perspective density (per block)
#endif

// LUT Dimensions //
const vec2 ATM_TRANS_SIZE = vec2(256.0, 64.0);
const vec2 ATM_MS_SIZE    = vec2(32.0, 32.0);
const vec2 ATM_SKY_SIZE   = vec2(192.0, 108.0);

const vec2 ATM_TRANS_ORG = vec2(0.0, 0.0);  // colortex14 (top-left)
const vec2 ATM_MS_ORG    = vec2(0.0, 64.0); // colortex14 (just below transmittance)
const vec2 ATM_SKY_ORG   = vec2(0.0, 0.0);  // colortex15 (top-left)

// medium //
const float ATM_Rg = 6360.0;    // ground radius (in km)
const float ATM_Rt = 6460.0;    // top of atmosphere (in km)

const vec3  ATM_RayS = vec3(5.802e-3, 13.558e-3, 33.10e-3);
const float ATM_MieS = 3.996e-3;
const float ATM_MieE = 4.440e-3;
const vec3  ATM_OzoA = vec3(0.650e-3, 1.881e-3, 0.085e-3);
const float ATM_Hr = 8.0;
const float ATM_Hm = 1.2;
const float ATM_mieG = 0.80;

void atmMedium(float h, out vec3 rayS, out float mieS, out vec3 extinction) {
    float dRay = exp(-h / ATM_Hr);
    float dMie = exp(-h / ATM_Hm);
    float dOzo = max(0.0, 1.0 - abs(h - 25.0) / 15.0);
    rayS = ATM_RayS * dRay;
    mieS = ATM_MieS * dMie;
    extinction = rayS + vec3(ATM_MieE * dMie) + ATM_OzoA * dOzo;
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

float atmPhaseR(float mu) { return 3.0 / (16.0 * ATM_PI) * (1.0 + mu * mu); }
float atmPhaseM(float mu, float g) {
    float g2 = g * g;
    float num = 3.0 * (1.0 - g2) * (1.0 + mu * mu);
    float den = 8.0 * ATM_PI * (2.0 + g2) * pow(max(1.0 + g2 - 2.0 * g * mu, 1e-4), 1.5);
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
    float t = atmRaySphere(ro, rd, ATM_Rt);
    if (t <= 0.0) return vec3(1.0);
    const int STEPS = 40;
    float seg = t / float(STEPS);
    vec3 od = vec3(0.0);
    for (int i = 0; i < STEPS; i++) {
        vec3 p = ro + rd * (float(i) + 0.5) * seg;
        float h = length(p) - ATM_Rg;
        vec3 rayS; float mieS; vec3 ext;
        atmMedium(h, rayS, mieS, ext);
        od += ext * seg;
    }
    return exp(-od);
}

void atmTransUvToRMu(vec2 uv, out float r, out float mu) {
    float H = sqrt(ATM_Rt * ATM_Rt - ATM_Rg * ATM_Rg);
    float rho = H * uv.y;
    r = sqrt(rho * rho + ATM_Rg * ATM_Rg);
    float dMin = ATM_Rt - r;
    float dMax = rho + H;
    float d = dMin + uv.x * (dMax - dMin);
    mu = (d == 0.0) ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = clamp(mu, -1.0, 1.0);
}
vec2 atmTransRMuToUv(float r, float mu) {
    float H = sqrt(ATM_Rt * ATM_Rt - ATM_Rg * ATM_Rg);
    float rho = sqrt(max(r * r - ATM_Rg * ATM_Rg, 0.0));
    float d = -mu * r + sqrt(max(r * r * (mu * mu - 1.0) + ATM_Rt * ATM_Rt, 0.0));
    float dMin = ATM_Rt - r;
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
    return texture2D(tex, atmLutCoord(uv, ATM_TRANS_ORG, ATM_TRANS_SIZE, res)).rgb;
}

// Inline transmittance from point p toward dir
vec3 atmTransmittanceInline(vec3 p, vec3 dir) {
    float t = atmRaySphere(p, dir, ATM_Rt);
    if (t <= 0.0) return vec3(1.0);
    const int N = 12;
    float seg = t / float(N);
    vec3 od = vec3(0.0);
    for (int i = 0; i < N; i++) {
        vec3 s = p + dir * (float(i) + 0.5) * seg;
        float h = length(s) - ATM_Rg;
        vec3 rs; float ms; vec3 ext;
        atmMedium(h, rs, ms, ext);
        od += ext * seg;
    }
    return exp(-od);
}

// Multiple Scatter LUT //
vec3 atmGenMultiScatter(vec2 uv) {
    float cosSun = uv.x * 2.0 - 1.0;
    float r = mix(ATM_Rg + 0.001, ATM_Rt, uv.y);
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
        float phi = 2.0 * ATM_PI * u1;
        vec3 rd = vec3(sinT * cos(phi), cosT, sinT * sin(phi));

        float tEnd = atmRaySphere(ro, rd, ATM_Rt);
        float tG = atmRaySphere(ro, rd, ATM_Rg);
        if (tG > 0.0) tEnd = min(tEnd, tG);
        if (tEnd <= 0.0) continue;
        float seg = tEnd / float(STEPS);

        vec3 tr = vec3(1.0);
        vec3 lum = vec3(0.0);
        vec3 fms = vec3(0.0);
        for (int s = 0; s < STEPS; s++) {
            vec3 p = ro + rd * (float(s) + 0.5) * seg;
            float rp = length(p);
            float h = rp - ATM_Rg;
            vec3 rayS; float mieS; vec3 ext;
            atmMedium(h, rayS, mieS, ext);
            vec3 sampleTr = exp(-ext * seg);
            vec3 scat = rayS + vec3(mieS);

            vec3 sInt = (scat - scat * sampleTr) / max(ext, vec3(1e-6));
            fms += tr * sInt;

            float muSun = dot(normalize(p), sunDir);
            vec3 sunTr = atmTransmittanceInline(p, sunDir);
            float shadow = (atmRaySphere(p, sunDir, ATM_Rg) > 0.0) ? 0.0 : 1.0;
            lum += tr * shadow * sunTr * scat * (1.0 / (4.0 * ATM_PI))
                 * (vec3(1.0) - sampleTr) / max(ext, vec3(1e-6));

            tr *= sampleTr;
        }
        lumTotal += lum * invN;
        fmsTotal += fms * invN;
    }

    return lumTotal / max(vec3(1.0) - fmsTotal, vec3(1e-4));
}

vec3 atmFetchMS(sampler2D tex, vec2 res, float r, float cosSun) {
    vec2 uv = vec2(cosSun * 0.5 + 0.5, clamp((r - ATM_Rg) / (ATM_Rt - ATM_Rg), 0.0, 1.0));
    return texture2D(tex, atmLutCoord(uv, ATM_MS_ORG, ATM_MS_SIZE, res)).rgb;
}

// Skyview LUT //
vec3 atmSkyViewDir(vec2 uv) {
    float az = uv.x * 2.0 * ATM_PI;
    float l = uv.y * 2.0 - 1.0;
    float elev = sign(l) * (l * l) * (ATM_PI * 0.5);
    float ce = cos(elev);
    return vec3(ce * cos(az), sin(elev), ce * sin(az));
}
vec2 atmSkyViewUv(vec3 rd) {
    float elev = asin(clamp(rd.y, -1.0, 1.0));
    float l = sqrt(abs(elev) / (ATM_PI * 0.5)) * sign(elev);
    float az = atan(rd.z, rd.x);
    if (az < 0.0) az += 2.0 * ATM_PI;
    return clamp(vec2(az / (2.0 * ATM_PI), l * 0.5 + 0.5), 0.0, 1.0);
}

// (sun at azimuth 0).
vec3 atmGenSkyView(vec2 uv, vec3 sunDir, float camAltKm, sampler2D transTex, sampler2D msTex, vec2 res) {
    vec3 rd = atmSkyViewDir(uv);
    float r = ATM_Rg + max(camAltKm, 0.0002);
    vec3 ro = vec3(0.0, r, 0.0);

    float tEnd = atmRaySphere(ro, rd, ATM_Rt);
    float tG = atmRaySphere(ro, rd, ATM_Rg);
    if (tG > 0.0) tEnd = min(tEnd, tG);
    if (tEnd <= 0.0) return vec3(0.0);

    const int STEPS = 32;
    float seg = tEnd / float(STEPS);
    float mu = dot(rd, sunDir);
    float pr = atmPhaseR(mu);
    float pm = atmPhaseM(mu, ATM_mieG);

    vec3 tr = vec3(1.0);
    vec3 L = vec3(0.0);
    for (int s = 0; s < STEPS; s++) {
        vec3 p = ro + rd * (float(s) + 0.5) * seg;
        float rp = length(p);
        float h = rp - ATM_Rg;
        vec3 rayS; float mieS; vec3 ext;
        atmMedium(h, rayS, mieS, ext);
        vec3 sampleTr = exp(-ext * seg);

        float muSun = dot(normalize(p), sunDir);
        vec3 sunTr = atmFetchTrans(transTex, res, rp, muSun);
        float shadow = (atmRaySphere(p, sunDir, ATM_Rg) > 0.0) ? 0.0 : 1.0;

        vec3 scatSun = (rayS * pr + vec3(mieS) * pm) * sunTr * shadow;
        vec3 ms = atmFetchMS(msTex, res, rp, muSun) * (rayS + vec3(mieS));

        vec3 sInt = scatSun + ms;
        vec3 integ = (sInt - sInt * sampleTr) / max(ext, vec3(1e-6));
        L += tr * integ;
        tr *= sampleTr;
    }
    return L * ATMOS_SKY_BRIGHTNESS;
}

vec3 atmSky(sampler2D skyViewTex, vec2 res, vec3 rd, vec3 sunDir) {
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 sunAz = normalize(vec3(sunDir.x, 0.0, sunDir.z));
    if (length(vec3(sunDir.x, 0.0, sunDir.z)) < 1e-3) sunAz = vec3(1.0, 0.0, 0.0);
    vec3 right = normalize(cross(up, sunAz));
    vec3 local = vec3(dot(rd, sunAz), rd.y, dot(rd, right));
    vec2 uv = atmSkyViewUv(local);
    vec3 sky = texture2D(skyViewTex, atmLutCoord(uv, ATM_SKY_ORG, ATM_SKY_SIZE, res)).rgb;

    // At and below the horizon the LUT has no data
    vec3 horizonCol = texture2D(skyViewTex,
        atmLutCoord(atmSkyViewUv(vec3(local.x, 0.0, local.z)), ATM_SKY_ORG, ATM_SKY_SIZE, res)).rgb;
    float below = smoothstep(0.04, -0.0, rd.y);
    return mix(sky, horizonCol, below);
}

vec3 atmSunColor(sampler2D transTex, vec2 res, vec3 sunDir) {
    float below = smoothstep(-0.06, 0.02, sunDir.y);
    vec3 tr = atmFetchTrans(transTex, res, ATM_Rg + 0.0005, clamp(sunDir.y, -1.0, 1.0));
    return tr * ATMOS_SUN_BRIGHTNESS * below;
}

vec3 atmSkyAmbient(sampler2D skyViewTex, vec2 res, vec3 sunDir) {
    vec3 acc = vec3(0.0);
    acc += atmSky(skyViewTex, res, vec3(0.0, 1.0, 0.0), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3( 0.6, 0.4,  0.0)), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3(-0.6, 0.4,  0.0)), sunDir);
    acc += atmSky(skyViewTex, res, normalize(vec3( 0.0, 0.4,  0.6)), sunDir);
    return acc * 0.25;
}

// aerial perspective
vec3 atmAerial(sampler2D skyViewTex, sampler2D transTex, vec2 res,
               vec3 rd, float distBlocks, vec3 sunDir, out float outTr) {
    outTr = exp(-distBlocks * ATMOS_FOG_DENSITY);
    float fogAmt = 1.0 - outTr;
    vec3 rdHaze = normalize(vec3(rd.x, max(rd.y, 0.03) * 0.35, rd.z));
    vec3 sky = atmSky(skyViewTex, res, rdHaze, sunDir);
    float mu = dot(rd, sunDir);
    sky += atmSunColor(transTex, res, sunDir) * atmPhaseM(mu, ATM_mieG * 0.6) * 0.02 * fogAmt;
    return sky * fogAmt;
}

// Sunrise/sunset tint, WIP, coloring of the sky at these times needs work.
// Currently 'realistic' but that's boring, these numbers are a terrible temp fix //
#ifndef ATMOS_SUNSET_SKY_TINT
#define ATMOS_SUNSET_SKY_TINT 0.3   // strength on sky/clouds
#endif
#ifndef ATMOS_SUNSET_SKY_TOP
#define ATMOS_SUNSET_SKY_TOP 1.0    // how far up the tint reaches
#endif
#ifndef ATMOS_SUNSET_PASTEL
#define ATMOS_SUNSET_PASTEL 0.38    // 0 = saturated 1 = near white
#endif
vec3 atmSunsetTint(vec3 col, vec3 rd, vec3 sunDir, float clearness) {
    float sunsetT = exp(-pow(sunDir.y / 0.20, 2.0));
    if (sunsetT < 0.001) return col;
    float towardSun = max(dot(normalize(vec3(rd.x, 0.0, rd.z)),
                              normalize(vec3(sunDir.x, 0.0, sunDir.z))), 0.0);
    vec3 roseCol   = mix(vec3(1.70, 1.12, 0.62), vec3(1.0), ATMOS_SUNSET_PASTEL);
    vec3 violetCol = mix(vec3(1.32, 1.04, 0.82), vec3(1.0), ATMOS_SUNSET_PASTEL);
    vec3 tintCol = mix(violetCol, roseCol, pow(towardSun, 0.6));
    float skyReach  = smoothstep(ATMOS_SUNSET_SKY_TOP, -0.05, rd.y);
    float cL        = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float cloudEmph = mix(0.85, 1.2, smoothstep(0.25, 0.8, cL));
    float amt = sunsetT * skyReach * ATMOS_SUNSET_SKY_TINT * cloudEmph * clearness;
    vec3 target = tintCol * mix(cL, 1.0, 0.18);
    return mix(col, target, clamp(amt, 0.0, 0.92));
}

// aerial perspective //
#ifndef ATMOS_AP_DENSITY
#define ATMOS_AP_DENSITY 0.040
#endif
#ifndef ATMOS_AP_HEIGHT
#define ATMOS_AP_HEIGHT 90.0    // scale height in blocks, density halves about every 62 blocks up
#endif
#ifndef ATMOS_AP_BASE_Y
#define ATMOS_AP_BASE_Y 63.0    // altitude where density is full (set to sea level)
#endif
#ifndef ATMOS_AP_SOURCE_EXPOSURE
#define ATMOS_AP_SOURCE_EXPOSURE 1.0
#endif
#ifndef ATMOS_AP_LIFT
#define ATMOS_AP_LIFT 0.12  // how 'far above the horizon' the fog samples
#endif

vec3 atmAerialPBR(vec3 surfaceColor, sampler2D skyViewTex, vec2 res,
                  vec3 rd, float distBlocks, vec3 sunDir, float clearness,
                  float camY, float fragY) {
    float avgY = 0.5 * (camY + fragY);
    float heightFall = exp(-max(avgY - ATMOS_AP_BASE_Y, 0.0) / ATMOS_AP_HEIGHT);

    float aero = mix(1.0e-3, 6.0e-3, 1.0 - clearness);
    vec3 betaExt = ATM_RayS + vec3(aero);
    vec3 tr = exp(-betaExt * (distBlocks * ATMOS_AP_DENSITY * heightFall));

    vec3 rdLift = normalize(vec3(rd.x, max(rd.y, 0.0) + ATMOS_AP_LIFT, rd.z));
    vec3 skyC = atmSky(skyViewTex, res, rdLift, sunDir) * ATMOS_AP_SOURCE_EXPOSURE;

    skyC = atmSunsetTint(skyC, rd, sunDir, clearness);

    return surfaceColor * tr + skyC * (1.0 - tr);
}

#endif
