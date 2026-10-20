#ifndef lightningFlashIncluded
#define lightningFlashIncluded

// Lightning flash: sky, clouds, surfaces, reflections and rain/fog. 
// The lightning flash is a combination of a directional bolt and a whole sky ambient light (with a short afterglow). 

uniform vec4  lightningBoltPosition;
uniform float lightningFlash;
uniform float sunAngle;

const vec3  lnColor        = vec3(0.72, 0.82, 1.0);
const float lnBoltHeight   = 128.0; 
const float lnLocalRadius  = 24.0;

float lnHash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

// Normally in minecraft lightning bolts restrike several times for one 'lightning strike'. BUT with Iris there is no 'restrike' signal/variable,
// so instead just add a flicker per game tick (*thumbs up emoji*).
float lnFlicker() {
    float tick = floor(frameTimeCounter * 20.0);
    float a = lnHash(tick);
    float b = lnHash(tick + 17.31);
    return mix(0.45, 1.0, step(0.35, a)) * (0.85 + 0.15 * b);
}

// Same curve as block light (torchFactor)
float lnAdaptation() {
    #if defined NETHER || defined END
    return 1.0;
    #else
    float sunY = sin(sunAngle * 6.28318531);
    float dayF = mix(1.0, 0.33, smoothstep(-0.05, 0.12, sunY));
    return mix(dayF, 1.0, rainStrength * 0.3);
    #endif
}

// flash intensity
float lnIntensity() {
    #ifndef lightningFlashFx
    return 0.0;
    #else
    if (lightningFlash < 0.002) return 0.0;
    return lightningFlash * lnFlicker() * lnAdaptation() * lightningFlashStrength;
    #endif
}

// Light reaching the sky, plus a glow around the bolt's direction
vec3 lightningSky(vec3 worldDir) {
    float I = lnIntensity();
    if (I <= 0.0) return vec3(0.0);

    vec3 boltDir = normalize(lightningBoltPosition.xyz + vec3(0.0, 0.5 * lnBoltHeight, 0.0) + 1e-4);
    float toward = max(dot(worldDir, boltDir), 0.0);
    // make sure the sky doesn't outshine the lit terrain
    float glow   = pow(toward, 6.0) * 0.8 + pow(toward, 40.0) * 1.25;
    float horizon = 0.6 + 0.4 * (1.0 - clamp(worldDir.y, 0.0, 1.0));
    // the directional glow needs a bolt position
    glow *= lightningBoltPosition.w;

    return lnColor * I * (0.35 * horizon + glow);
}

// Diffuse light on an opaque surface for the lightning flash.
vec3 lightningSurfaceLight(vec3 worldPos, vec3 worldNormal, float skyLight) {
    float I = lnIntensity();
    if (I <= 0.0) return vec3(0.0);

    float skyAccess = clamp((skyLight - 1.0 / 32.0) * 16.0 / 15.0, 0.0, 1.0);
    skyAccess *= skyAccess * skyAccess;
    if (skyAccess <= 0.0) return vec3(0.0);

    // sky flash
    float ambient = 0.6 * (0.55 + 0.45 * worldNormal.y);

    // local light from the bolt
    vec3  b = lightningBoltPosition.xyz;
    vec3  p = vec3(b.x, clamp(worldPos.y, b.y, b.y + lnBoltHeight), b.z);
    vec3  toBolt = p - worldPos;
    float d  = length(toBolt);
    float NdotL = max(dot(worldNormal, toBolt / max(d, 1e-3)), 0.0);
    float falloff = 1.0 / (1.0 + (d * d) / (lnLocalRadius * lnLocalRadius));
    float local = 5.0 * NdotL * falloff * lightningBoltPosition.w;

    return lnColor * I * skyAccess * (ambient + local);
}

// flash scattered by rain and fog
vec3 lightningAirLight(float dist) {
    float I = lnIntensity();
    if (I <= 0.0) return vec3(0.0);
    float density = 0.0015 + 0.006 * rainStrength;
    return lnColor * I * 0.35 * (1.0 - exp(-dist * density));
}

#endif
