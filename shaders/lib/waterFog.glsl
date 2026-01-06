
#ifdef volumetricFog
vec4 ShadowSpaceWater(vec3 worldPos) {
    vec4 World = vec4(worldPos, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}
#endif


// Absorption coefficients (per meter)
const vec3 waterAbsorptionCoeff = vec3(AbsorptionCoeffR, AbsorptionCoeffG, AbsorptionCoeffB)/255; // R, G, B

// Scattering coefficient (per meter) - Rayleigh + Mie for water
const vec3 waterScatteringCoeff = vec3(0.0045, 0.0060, 0.0080);

#define waterExtinctionCoeff (waterAbsorptionCoeff + waterScatteringCoeff)
#define waterSSA (waterScatteringCoeff / waterExtinctionCoeff)

float phaseHG(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(denom, 1.5));
}

float phaseWater(float cosTheta) {
    float forwardPhase = phaseHG(cosTheta, 0.9);
    float backPhase = phaseHG(cosTheta, -0.3);
    return mix(forwardPhase, backPhase, 0.1);
}

float phaseRayleigh(float cosTheta) {
    return (3.0 / (16.0 * 3.14159265)) * (1.0 + cosTheta * cosTheta);
}

vec3 multiScatteringApprox(vec3 extinction, vec3 scattering, float depth) {
    vec3 ssAlbedo = scattering / extinction;
    vec3 multiScatFactor = ssAlbedo * ssAlbedo;
    vec3 effectiveExtinction = extinction * (1.0 - multiScatFactor * 0.5);
    vec3 transmittance = exp(-effectiveExtinction * depth);
    vec3 inScatter = (1.0 - transmittance) * ssAlbedo * (1.0 + multiScatFactor);
    return inScatter;
}

vec3 waterTransmittance(float depth) {
    return exp(-waterExtinctionCoeff * depth);
}

vec3 getInScatteredLight(vec3 lightColor, float distToSurface, float cosTheta, float shadowFactor) {
    vec3 transmittanceToSurface = exp(-waterExtinctionCoeff * distToSurface);
    float phase = phaseWater(cosTheta);
    vec3 singleScatter = lightColor * transmittanceToSurface * waterScatteringCoeff * phase * shadowFactor;
    vec3 multiScatter = multiScatteringApprox(waterExtinctionCoeff, waterScatteringCoeff, distToSurface);
    multiScatter *= lightColor * shadowFactor * 0.3;
    return singleScatter + multiScatter;
}


vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2, float iswater, float lightMap) {
    
    float depth = distance(fragpos, fragpos2);
    depth = clamp(depth, 0.0, 20.0);
    
    vec3 transmittance = waterTransmittance(depth);
    float fogDensity = 1.0 - dot(transmittance, vec3(0.333));
    
    float adaptiveFactor = 1.0 + (1.0 - lightMap) * 0.3;
    fogDensity = clamp(fogDensity * adaptiveFactor, 0.0, 1.0);
    
    vec3 shallowWaterColor = vec3(shallowwaterR, shallowwaterG, shallowwaterB)/255;
    vec3 deepWaterColor = vec3(deepwaterR, deepwaterG, deepwaterB)/255;
    
    float depthBlend = 1.0 - exp(-depth * 0.15);
    vec3 baseWaterColor = mix(shallowWaterColor, deepWaterColor, depthBlend);
    
    vec3 rainyWaterColor = mix(baseWaterColor, vec3(0.15, 0.22, 0.28), rainStrength * 0.6);
    baseWaterColor = mix(baseWaterColor, rainyWaterColor, rainStrength);
    
    float fogStr = 0.5 * time[0] + 1.0 * time[1] + 1.0 * time[2] + 
                   1.0 * time[3] + 0.5 * time[4] + 0.4 * time[5];
    fogStr *= lightMap;
    
    #ifdef volumetricFog
    #ifdef volumetricLight
    
    vec3 volumetricScatter = vec3(0.0);
    float endRay = 0.0;
    
    if (depth > 0.1) {
        float startRay = 0.0;
        endRay = min(depth, 16.0);
        
        vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        vec3 rayDir = normalize(fragpos2 - fragpos);
        float cosTheta = dot(rayDir, lightDir);
        float viewAngleBoost = max(0.0, cosTheta) * 0.5 + 0.5;
        
        #ifdef TAA
        float sampleReduction = 0.25;
        #else
        float sampleReduction = 1.0;
        #endif
        
        float increment = endRay / (volumetricFogQuality * sampleReduction);
        
        #ifdef TAA
        float frameOffset = fract(frameTimeCounter * 6.283185307);
        dither64 = fract(dither64 + frameOffset);
        #endif
        
        startRay = dither64 * increment;
        
        vec3 startWorldPos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
        vec3 worldStep = mat3(gbufferModelViewInverse) * (rayDir * increment);
        vec3 currentWorldPos = startWorldPos + worldStep * (startRay / increment);
        vec3 waterSurfaceWorldPos = mat3(gbufferModelViewInverse) * fragpos2 + gbufferModelViewInverse[3].xyz;
        
        vec3 accumulatedScatter = vec3(0.0);
        vec3 accumulatedTransmittance = vec3(1.0);
        
        for (float dist = startRay; dist < endRay; dist += increment) {
            vec4 shadowCoord = ShadowSpaceWater(currentWorldPos);
            shadowCoord.xy *= distort(shadowCoord.xy);
            shadowCoord.z /= 6.0;
            vec3 sampleCoords = shadowCoord.xyz * 0.5 + 0.5;
            sampleCoords.z -= 0.0005;
            
            float shadowSample = shadowStep(shadowtex1, sampleCoords);
            
            float distToSurface = (waterSurfaceWorldPos.y - currentWorldPos.y) / lightDir.y;
            
            vec3 causticSamplePos = currentWorldPos + lightDir * distToSurface;
            causticSamplePos.y = waterSurfaceWorldPos.y;
            vec3 causticValue = waterCaustics(causticSamplePos, 1.0);
            float causticIntensity = pow(causticValue.x, 1.5) * 2.0;
            
            float depthFalloff = exp(-dist * 0.08);
            causticIntensity *= depthFalloff;
            float distToSurfaceClamped = max(0.0, distToSurface);
            
            vec3 surfaceToSample = exp(-waterExtinctionCoeff * distToSurfaceClamped);
            float phase = phaseWater(cosTheta);
            vec3 multiScatBoost = 1.0 + waterSSA * 0.5;
            
            float scatterStrength = 0.08;
            vec3 inScatter = sunCol * surfaceToSample * phase * shadowSample;
            inScatter *= (1.0 + causticIntensity * 2.0) * scatterStrength;
            
            vec3 sampleTransmittance = exp(-waterExtinctionCoeff * dist);
            accumulatedScatter += inScatter * accumulatedTransmittance * increment;
            accumulatedTransmittance *= exp(-waterExtinctionCoeff * increment);
            
            currentWorldPos += worldStep;
        }
        
        volumetricScatter = accumulatedScatter * fogStr * transitionFade * viewAngleBoost;
        volumetricScatter *= (1.0 - rainStrength * 0.7);
        
        float avgDepth = endRay * 0.5;
        vec3 shallowShaftColor = sunCol * vec3(0.6, 0.75, 0.85);
        vec3 deepShaftColor = sunCol * vec3(0.3, 0.55, 0.9);
        vec3 underwaterSunColor = mix(shallowShaftColor, deepShaftColor, clamp(avgDepth / 10.0, 0.0, 1.0));
        volumetricScatter *= underwaterSunColor;
    }
    
    baseWaterColor += volumetricScatter;
    
    #endif
    #endif
    
    vec3 ambientMultiScatter = multiScatteringApprox(waterExtinctionCoeff, waterScatteringCoeff, depth);
    ambientMultiScatter *= sunCol * fogStr * 0.15 * (1.0 - rainStrength * 0.5);
    baseWaterColor += ambientMultiScatter;
    
    vec3 worldPos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
    float turbidity = texture2D(noisetex, worldPos.xz * 0.1 + frameTimeCounter * 0.01).r;
    turbidity = turbidity * 0.1 + 0.95;
    baseWaterColor *= turbidity;
    
    vec3 extinctedColor = color * transmittance;
    vec3 finalColor = mix(extinctedColor, baseWaterColor * fogStr, fogDensity);
    
    return finalColor;
}


vec3 getUnderwaterFog(vec3 color, vec3 viewPos, float lightMapSky) {
    
    float dist = length(viewPos);
    dist = clamp(dist, 0.0, 64.0);
    
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    
    // eyeBrightnessSmooth.y: 255 at surface, decreases with depth
    float skyExposure = float(eyeBrightnessSmooth.y) / 255.0;
    
    float estimatedDepth = (1.0 - skyExposure) * 28.0;
    estimatedDepth = max(estimatedDepth, 0.5);
    
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightAngle = max(0.15, abs(lightDir.y));
    
    float distSurfaceToCamera = estimatedDepth / lightAngle;
    
    vec3 underwaterExtinction = waterExtinctionCoeff * 0.75;
    vec3 transmittance = exp(-underwaterExtinction * dist);
    float fogDensity = 1.0 - dot(transmittance, vec3(0.333));
    
    float depthFactor = 1.0 + estimatedDepth * 0.025;
    fogDensity = clamp(fogDensity * depthFactor, 0.0, 0.96);
    
    
    vec3 shallowWaterColor = vec3(shallowwaterR, shallowwaterG, shallowwaterB)/255;
    vec3 deepWaterColor = vec3(deepwaterR, deepwaterG, deepwaterB)/255;
    vec3 abyssColor = vec3(0.008, 0.025, 0.04);
    
    float depthBlend = 1.0 - exp(-estimatedDepth * 0.09);
    float abyssBlend = 1.0 - exp(-estimatedDepth * 0.04);
    
    vec3 baseWaterColor = mix(shallowWaterColor, deepWaterColor, depthBlend);
    baseWaterColor = mix(baseWaterColor, abyssColor, abyssBlend * 0.45);
    
    vec3 rainyWaterColor = mix(baseWaterColor, vec3(0.11, 0.15, 0.19), rainStrength * 0.55);
    baseWaterColor = mix(baseWaterColor, rainyWaterColor, rainStrength);
    
    float fogStr = 0.55 * time[0] + 1.0 * time[1] + 1.0 * time[2] + 
                   1.0 * time[3] + 0.55 * time[4] + 0.45 * time[5];
    fogStr = max(fogStr, 0.25);
    
    vec3 surfaceToCameraAtten = exp(-underwaterExtinction * distSurfaceToCamera * 0.12);
    float attenuationFactor = dot(surfaceToCameraAtten, vec3(0.33, 0.34, 0.33));
    fogStr *= max(attenuationFactor, 0.3);
    
    #ifdef volumetricFog
    #ifdef volumetricLight
    
    vec3 volumetricScatter = vec3(0.0);
    
    if (dist > 0.1 && fogStr > 0.01) {
        float startRay = 0.0;
        float maxRayDist = 16.0;
        float endRay = min(dist, maxRayDist);
        
        vec3 rayDir = normalize(viewPos);
        vec3 rayDirWorld = normalize(mat3(gbufferModelViewInverse) * rayDir);
        
        float cosTheta = dot(rayDirWorld, lightDir);
        
        float forwardBoost = max(0.0, cosTheta) * 0.5 + 0.5; 
        float backwardVisibility = 0.4; // Minimum visibility of caustic rays when looking away
        float viewAngleBoost = max(forwardBoost, backwardVisibility);
        
        float waterSurfaceY = cameraPosition.y + estimatedDepth;
        
        #ifdef TAA
        float sampleReduction = 0.25;
        #else
        float sampleReduction = 1.0;
        #endif
        
        float increment = endRay / (volumetricFogQuality * sampleReduction);
        
        #ifdef TAA
        float jitter = fract(dither64 + fract(frameTimeCounter * 6.283185307));
        #else
        float jitter = dither64;
        #endif
        
        startRay = jitter * increment;
        
        vec3 currentWorldPos = cameraPosition + rayDirWorld * startRay;
        vec3 worldStep = rayDirWorld * increment;
        
        vec3 accumulatedScatter = vec3(0.0);
        vec3 accumulatedTransmittance = vec3(1.0);
        
        for (float rayDist = startRay; rayDist < endRay; rayDist += increment) {
            float distanceFalloff = exp(-rayDist * 0.04);
            
            vec4 shadowCoord = ShadowSpaceWater(currentWorldPos - cameraPosition);
            shadowCoord.xy *= distort(shadowCoord.xy);
            shadowCoord.z /= 6.0;
            vec3 sampleCoords = shadowCoord.xyz * 0.5 + 0.5;
            sampleCoords.z -= 0.0005;
            
            float shadowSample = shadowStep(shadowtex1, sampleCoords);
            
            float shadowMapEdge = max(abs(sampleCoords.x - 0.5), abs(sampleCoords.y - 0.5)) * 2.0;
            float shadowEdgeFade = 1.0 - smoothstep(0.8, 1.0, shadowMapEdge);
            shadowSample = mix(0.5, shadowSample, shadowEdgeFade);
            
            float sampleDepth = estimatedDepth - rayDist * rayDirWorld.y;
            sampleDepth = max(0.1, sampleDepth);
            
            float distToSurface = sampleDepth / max(0.1, lightDir.y);
            vec3 causticPos = currentWorldPos + lightDir * distToSurface;
            
            vec3 causticValue = waterCaustics(causticPos, 1.0);
            float causticIntensity = pow(causticValue.x, 1.5) * 2.0;
            causticIntensity *= exp(-sampleDepth * 0.04);
            
            vec3 surfaceToSample = exp(-underwaterExtinction * sampleDepth * 0.3);
            
            float phase = phaseWater(cosTheta);

            vec3 multiScatBoost = 1.0 + waterSSA * 0.55;
            
            float scatterStrength = 0.14;
            vec3 inScatter = sunCol * surfaceToSample * phase * shadowSample;
            inScatter *= (1.0 + causticIntensity * 2.0) * scatterStrength;
            inScatter *= multiScatBoost;
            inScatter *= distanceFalloff; 
            inScatter = min(inScatter, vec3(4.0));
            
            accumulatedScatter += inScatter * accumulatedTransmittance * increment;
            accumulatedTransmittance *= exp(-underwaterExtinction * increment);
            
            currentWorldPos += worldStep;
        }
        
        volumetricScatter = accumulatedScatter * fogStr * transitionFade * viewAngleBoost;
        volumetricScatter *= (1.0 - rainStrength * 0.8);
        
        vec3 shallowShaftColor = vec3(0.3, 0.9, 0.95);
        vec3 deepShaftColor = vec3(0.1, 0.55, 0.7);
        float shaftDepthBlend = 1.0 - exp(-estimatedDepth * 0.06);
        vec3 shaftTint = mix(shallowShaftColor, deepShaftColor, shaftDepthBlend);
        volumetricScatter *= shaftTint;
    }
    
    baseWaterColor += volumetricScatter;
    
    #endif
    #endif
    
    vec3 ambientMultiScatter = multiScatteringApprox(underwaterExtinction, waterScatteringCoeff, dist);
    ambientMultiScatter *= sunCol * fogStr * 0.25 * (1.0 - rainStrength * 0.45);
    
    vec3 upwellingLight = vec3(0.02, 0.05, 0.065) * max(lightMapSky, 0.25) * (1.0 - rainStrength * 0.35);
    upwellingLight *= (1.0 - depthBlend * 0.8);
    ambientMultiScatter += upwellingLight;
    
    vec3 ambientSky = vec3(0.025, 0.05, 0.07) * fogStr * (1.0 - depthBlend * 0.6);
    ambientMultiScatter += ambientSky;
    
    baseWaterColor += ambientMultiScatter;
    
    vec2 turbCoord = worldPos.xz + worldPos.y * 0.7;
    float turbidity = texture2D(noisetex, turbCoord * 0.08 + frameTimeCounter * 0.008).r;
    turbidity = turbidity * 0.12 + 0.94;
    baseWaterColor *= turbidity;
    
    vec3 extinctedColor = color * transmittance;
    
    float finalFogStr = max(fogStr, 0.2);
    vec3 finalColor = mix(extinctedColor, baseWaterColor * finalFogStr, fogDensity);
    
    finalColor += baseWaterColor * 0.03 * (1.0 - fogDensity);
    
    return finalColor;
}
