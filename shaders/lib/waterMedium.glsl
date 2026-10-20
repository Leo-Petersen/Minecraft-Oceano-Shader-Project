// Absorption coefficients (per meter)
const vec3 waterAbsorptionCoeff = vec3(AbsorptionCoeffR, AbsorptionCoeffG, AbsorptionCoeffB);

// Scattering coefficient (per meter): Rayleigh + Mie for water
const vec3 waterScatteringCoeff = vec3(0.0045, 0.0060, 0.0080);

#define waterExtinctionCoeff (waterAbsorptionCoeff + waterScatteringCoeff)
#define waterSSA (waterScatteringCoeff / waterExtinctionCoeff)

float underwaterFogDensity(float dist) {
    dist = clamp(dist, 0.0, 64.0);
    float estimatedDepth = max((1.0 - float(eyeBrightnessSmooth.y) / 255.0) * 28.0, 0.5);
    vec3 transmittance = exp(-waterExtinctionCoeff * 0.75 * dist);
    float fogDensity = 1.0 - dot(transmittance, vec3(0.333));
    return clamp(fogDensity * (1.0 + estimatedDepth * 0.025), 0.0, 0.96);
}
