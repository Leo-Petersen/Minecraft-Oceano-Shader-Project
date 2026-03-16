#ifdef CookTorranceGGXBRDF
float D_GGX(float alpha, float NdotH)
{
    float alpha2 = alpha * alpha;
    float denom  = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
    return alpha2 / (3.14159265 * denom * denom);
}

float G1(float alpha, float ndotx) {
    float alpha2 = alpha * alpha;
    float ndotx2 = ndotx * ndotx;
    return 2.0 * ndotx / (ndotx + sqrt(alpha2 + (1.0 - alpha2) * ndotx2));
}

float G_SmithGGXUncorrelated(float alpha, float NdotV, float NdotL)
{
    return G1(alpha, NdotV) * G1(alpha, NdotL);
}

vec3 SphericalGaussianFresnel(float HoL, vec3 baseReflectance){
    float fresnel = exp2(((-5.55473 * HoL) - 6.98316) * HoL);
    return fresnel * (1.0 - baseReflectance) + baseReflectance;
}

vec3 cookTorranceGGXBRDF(vec3 color, vec2 specularMap, float skyMap, vec3 sunCol) 
{
    vec3 ClipSpace = vec3(texcoord, Depth) * 2.0 - 1.0;
    vec4 ViewW     = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View      = ViewW.xyz / ViewW.w;
    vec3 eyeNormal = normalize(-View);
    vec3 sunNormal = normalize(shadowLightPosition);
    vec3 halfDir = normalize(sunNormal + eyeNormal);

    float cosTheta = max(0.0, dot(viewNormal, sunNormal)); // N·L
    float NdotV    = max(dot(viewNormal, eyeNormal), 0.0); // N·V
    float NdotH  = max(dot(viewNormal, halfDir), 0.0);
    float HdotV = max(dot(halfDir, eyeNormal), 0.0);
    float HdotL = max(dot(halfDir, sunNormal), 0.0);

    if (cosTheta <= 0.0) {
        return vec3(0.0);
    }
    
    float perceptualSmoothness = specularMap.r;
    float metalness            = specularMap.g;

    float rainTerm = (1.0 - wetness * 0.9 * clamp(pow(skyMap, 50), 0.0, 1.0)); // decreases 'smoothness' whilst raining, Psuedo values
    float wetSmoothness = clamp(perceptualSmoothness / rainTerm, 0.0, 1.0);
    float roughness = pow(1.0 - wetSmoothness, 1.8);

    // preset roughness value if no PBR textures are being used
    if (perceptualSmoothness == 0 && metalness == 0) {
          roughness  = 0.6;
    }
    if (perceptualSmoothness == 1 && metalness == 1) {
          return vec3(0.0);
    }

    roughness = clamp(roughness, 0.045, 0.99); //fixes black dots given by zero values
    float alpha = roughness * roughness;

    vec3  F0    = mix(vec3(0.04), color, metalness);
    vec3  F     = SphericalGaussianFresnel(HdotL, F0);
    float D     = D_GGX(alpha, NdotH);
    float G     = G_SmithGGXUncorrelated(alpha, NdotV, cosTheta);

    float denom = NdotV * cosTheta + 1e-5;
    vec3 specular = D * F * G * sunCol / denom;

    //// Diffuse component ////
    vec3 kS = F; // Specular reflection coefficient
    vec3 kD = vec3(1.0) - kS; // Diffuse reflection coefficient
    kD *= 1.0 - metalness; // Metals don't have a diffuse reflection
    
    // Lambert diffuse
    vec3 diffuse = kD * color / 3.14159265;
    
    vec3 finalBRDF = (diffuse + specular) * cosTheta;
         finalBRDF *= (1.0 - rainStrength * 0.8);
    
    // Boost metallic surfaces intensity
    if (metalness > 0.5) {
        finalBRDF *= mix(1.0, 1.3, metalness); 
    }

    return finalBRDF;
}
#else
vec3 cookTorranceGGXBRDF(vec3 color, vec2 specularMap, float skyMap, vec3 sunCol) {
    return vec3(0.0);
}
#endif

////Diffuse////
float calculateDiffuse(vec3 lightDir, vec3 viewDir, vec3 normal, float roughness) {
    float NdotL = max(dot(normal, lightDir), 0.0);
    
    // if (roughness <= 0.01) { 
    //     return NdotL;
    // }
    
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float LdotH = max(dot(lightDir, halfDir), 0.0);
    
    // Burley diffuse
    float f90 = 0.5 + 2.0 * roughness * LdotH * LdotH;
    float lightScatter = 1.0 + (f90 - 1.0) * pow(1.0 - NdotL, 5.0);
    float viewScatter = 1.0 + (f90 - 1.0) * pow(1.0 - NdotV, 5.0);
    
    return (lightScatter * viewScatter * NdotL) / 3.14159265;
}