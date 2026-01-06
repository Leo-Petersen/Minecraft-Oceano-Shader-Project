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
    float roughness  = pow(1.0 - perceptualSmoothness/rainTerm, 1.8);

    // preset roughness value if no PBR textures are being used
    if (perceptualSmoothness == 0 && metalness == 0) {
          roughness  = 0.6;
    }
    if (perceptualSmoothness == 1 && metalness == 1) {
          return vec3(0.0);
    }

    roughness = clamp(roughness, 0.01, 0.99); //fixes black dots given by zero values
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



#ifdef PBRReflection
vec3 fresnelSchlickRoughness(float NdotV, vec3 F0, float roughness) {
    float smoothness = 1.0 - roughness;
    return F0 + (max(vec3(smoothness), F0) - F0) * pow(clamp(1.0 - NdotV, 0.0, 1.0), 5.0);
}

// Environment BRDF approximation (split-sum approximation without LUT)
// This approximates the specular IBL integration
vec2 envBRDFApprox(float NdotV, float roughness) {
    // Polynomial approximation of the BRDF integration
    // Based on Karis' approximation from "Real Shading in Unreal Engine 4"
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    return vec2(-1.04, 1.04) * a004 + r.zw;
}

// Compute reflection weight based on material properties
// Returns: x = reflection strength, y = fresnel factor, z = roughness-adjusted blend
vec3 computeReflectionWeight(vec3 viewDir, vec3 normal, vec2 specularMap, vec3 albedo) {
    float perceptualSmoothness = specularMap.r;
    float metalness = specularMap.g;
    
    // Skip if no PBR data or special marker
    if (perceptualSmoothness == 0.0 && metalness == 0.0) {
        return vec3(0.0);
    }
    if (perceptualSmoothness == 1.0 && metalness == 1.0) {
        return vec3(0.0);
    }
    
    float roughness = pow(1.0 - perceptualSmoothness, 1.8);
    roughness = clamp(roughness, 0.01, 0.99);
    
    float NdotV = max(dot(normal, -viewDir), 0.001);
    
    // Base reflectance (F0)
    vec3 F0 = mix(vec3(0.04), albedo, metalness);
    
    // Fresnel with roughness consideration
    vec3 F = fresnelSchlickRoughness(NdotV, F0, roughness);
    
    // Environment BRDF approximation
    vec2 envBRDF = envBRDFApprox(NdotV, roughness);
    
    // Final reflection weight
    vec3 reflectionStrength = F * envBRDF.x + envBRDF.y;
    
    // Reduce reflection visibility for very rough surfaces
    float roughnessAttenuation = 1.0 - roughness * roughness * 0.7;
    
    // Average for scalar weight, preserve fresnel info
    float avgReflection = (reflectionStrength.r + reflectionStrength.g + reflectionStrength.b) / 3.0;
    
    return vec3(avgReflection * roughnessAttenuation, F.r, roughness);
}

// Blend reflection color with surface using PBR principles
vec3 applyPBRReflection(vec3 baseColor, vec3 reflectionColor, vec2 specularMap, vec3 viewDir, vec3 normal) {
    float perceptualSmoothness = specularMap.r;
    float metalness = specularMap.g;
    
    // Skip non-reflective surfaces
    if (perceptualSmoothness <= 0.01 && metalness <= 0.01) {
        return baseColor;
    }
    
    float roughness = pow(1.0 - perceptualSmoothness, 1.8);
    roughness = clamp(roughness, 0.01, 0.99);
    
    float NdotV = max(dot(normal, -viewDir), 0.001);
    
    // F0 for metals uses albedo, dielectrics use 0.04
    vec3 F0 = mix(vec3(0.04), baseColor, metalness);
    
    // Fresnel reflection
    vec3 F = fresnelSchlickRoughness(NdotV, F0, roughness);
    
    // For metals, reflection is tinted by the surface color
    vec3 tintedReflection = mix(reflectionColor, reflectionColor * baseColor, metalness);
    
    // Energy conservation: reduce diffuse where specular dominates
    vec3 kD = (1.0 - F) * (1.0 - metalness);
    
    // Roughness attenuates reflection visibility (rough surfaces scatter light)
    float roughnessAttenuation = 1.0 - roughness * roughness * 0.5;
    
    // Combine diffuse and specular
    vec3 diffuse = kD * baseColor;
    vec3 specular = F * tintedReflection * roughnessAttenuation;
    
    return diffuse + specular;
}
#endif

////Diffuse////
float calculateDiffuse(vec3 lightDir, vec3 viewDir, vec3 normal, float roughness, float material) {
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