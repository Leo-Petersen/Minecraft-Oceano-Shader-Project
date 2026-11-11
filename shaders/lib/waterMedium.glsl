#ifndef waterMediumIncluded
#define waterMediumIncluded

// One water medium, used for all the water effects!!! This fixes a lot of problems with the old system
// Absorption coefficients (per block)
const vec3 waterAbsorptionCoeff = vec3(AbsorptionCoeffR, AbsorptionCoeffG, AbsorptionCoeffB);

// Scattering by the water itself (per block), Rayleigh-like but bluer
const vec3 waterScatteringCoeff = vec3(0.0045, 0.0060, 0.0080);

// Scattering by suspended particles
const vec3 waterParticleCoeff = vec3(waterTurbidity);

// Total extinction
#define waterExtinctionCoeff (waterAbsorptionCoeff + waterScatteringCoeff + waterParticleCoeff)

// Pure water only
#define waterPureExtinction (waterAbsorptionCoeff + waterScatteringCoeff)
#define waterSSA (waterScatteringCoeff / waterPureExtinction)

vec3 waterRefractedLightDir(vec3 lightDirWorld) {
    float sinI = sqrt(max(1.0 - lightDirWorld.y * lightDirWorld.y, 0.0));
    float sinT = sinI / 1.333;
    float cosT = sqrt(1.0 - sinT * sinT);
    vec2  horiz = (sinI > 1e-4) ? lightDirWorld.xz / sinI : vec2(0.0);
    return vec3(horiz.x * sinT, cosT, horiz.y * sinT);
}

// Amount of light that survives a path of the given length through water
vec3 waterTransmittancePath(float pathLength) {
    return exp(-waterExtinctionCoeff * pathLength);
}

// How much the underwater view is fogged at a distance
float underwaterFogDensity(float dist) {
    dist = clamp(dist, 0.0, 64.0);
    float estimatedDepth = max((1.0 - float(eyeBrightnessSmooth.y) / 255.0) * 28.0, 0.5);
    vec3 transmittance = exp(-waterPureExtinction * 0.75 * dist);
    float fogDensity = 1.0 - dot(transmittance, vec3(0.333));
    return clamp(fogDensity * (1.0 + estimatedDepth * 0.025), 0.0, 0.96);
}

#endif
