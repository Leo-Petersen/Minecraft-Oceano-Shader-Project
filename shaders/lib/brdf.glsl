#ifdef CookTorranceGGXBRDF

//// Area Light NdotH^2 ////
float GetNoHSquared(float radiusTan, float NoL, float NoV, float VoL) {
    float radiusCos = 1.0 / sqrt(1.0 + radiusTan * radiusTan);
    float RoL = 2.0 * NoL * NoV - VoL;
    if (RoL >= radiusCos) return 1.0;

    float rOverLengthT = radiusCos * radiusTan / sqrt(1.0 - RoL * RoL);
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);
    float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL, 0.0, 1.0));

    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr +
                   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr;
    VoTr = cosTheta * VoTr + sinTheta * VoBr;

    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return clamp(NoH * NoH / HoH, 0.0, 1.0);
}

float GGXDistribution(float NoHsqr, float alpha) {
    float alpha2 = alpha * alpha;
    float denom  = NoHsqr * (alpha2 - 1.0) + 1.0;
    return alpha2 / (3.14159265 * denom * denom);
}

// Denominator (4·NdotL·NdotV) is baked into the 0.5/ form
float SchlickGGX(float NoL, float NoV, float alpha) {
    float k = alpha * 0.5;
    float smithL = 0.5 / (NoL * (1.0 - k) + k);
    float smithV = 0.5 / (NoV * (1.0 - k) + k);
    return smithL * smithV;
}

vec3 SphericalGaussianFresnel(float HoL, vec3 baseReflectance) {
    float fresnel = exp2(((-5.55473 * HoL) - 6.98316) * HoL);
    return fresnel * (1.0 - baseReflectance) + baseReflectance;
}

// Returns SPECULAR ONLY — no diffuse component.
// Albedo is needed only for metallic F0 calculation.
vec3 cookTorranceGGXBRDF(vec3 albedo, vec2 specularMap, float skyMap, vec3 sunCol)
{
    vec3 ClipSpace = vec3(texcoord, Depth) * 2.0 - 1.0;
    vec4 ViewW     = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View      = ViewW.xyz / ViewW.w;
    vec3 eyeNormal = normalize(-View);
    vec3 sunNormal = normalize(shadowLightPosition);
    vec3 halfDir   = normalize(sunNormal + eyeNormal);

    float NoL = clamp(dot(viewNormal, sunNormal), 0.0, 1.0);
    float NoV = clamp(dot(viewNormal, eyeNormal), -1.0, 1.0);
    float HoL = clamp(dot(halfDir, sunNormal), 0.0, 1.0);
    float VoL = dot(eyeNormal, sunNormal);

    if (NoL <= 0.0) return vec3(0.0);

    float perceptualSmoothness = specularMap.r;
    float metalness            = specularMap.g;

    // No PBR data, skip
    if (perceptualSmoothness == 0 && metalness == 0) return vec3(0.0);
    if (perceptualSmoothness == 1 && metalness == 1) return vec3(0.0);

    float rainTerm = (1.0 - wetness * 0.9 * clamp(pow(skyMap, 50), 0.0, 1.0));
    float wetSmoothness = clamp(perceptualSmoothness / rainTerm, 0.0, 1.0);

    float roughness = max(1.0 - wetSmoothness, 0.025);
    float alpha = roughness * roughness;

    // Area light
    float sunRadius = 0.05;
    float NoHsqr = GetNoHSquared(sunRadius, NoL, NoV, VoL);
    if (NoV < 0.0) {
        float NoH = max(dot(viewNormal, halfDir), 0.0);
        NoHsqr = NoH * NoH;
    }
    NoV = max(NoV, 0.0);

    vec3  F0 = mix(vec3(0.04), albedo, metalness);
    vec3  F  = SphericalGaussianFresnel(HoL, F0);
    float D  = GGXDistribution(NoHsqr, alpha);
    float G  = SchlickGGX(NoL, NoV, alpha);

    // Tone mapping, compresses metal peaks, preserves dielectric
    float Fl = max(length(F), 0.001);
    vec3  Fn = F / Fl;
    float specScalar = D * Fl * G;
    vec3 specular = specScalar / (1.0 + 0.0078125 * specScalar) * Fn * NoL * sunCol;

    specular *= (1.0 - rainStrength * 0.8);

    return specular;
}
#else
vec3 cookTorranceGGXBRDF(vec3 albedo, vec2 specularMap, float skyMap, vec3 sunCol) {
    return vec3(0.0);
}
#endif

////Diffuse////
float calculateDiffuse(vec3 lightDir, vec3 viewDir, vec3 normal, float roughness) {
    float NdotL = max(dot(normal, lightDir), 0.0);

    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float LdotH = max(dot(lightDir, halfDir), 0.0);

    // Burley diffuse
    float f90 = 0.5 + 2.0 * roughness * LdotH * LdotH;
    float lightScatter = 1.0 + (f90 - 1.0) * pow(1.0 - NdotL, 5.0);
    float viewScatter = 1.0 + (f90 - 1.0) * pow(1.0 - NdotV, 5.0);

    return (lightScatter * viewScatter * NdotL) / 3.14159265;
}