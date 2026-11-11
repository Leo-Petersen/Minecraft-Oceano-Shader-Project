
#ifdef volumetricLight
vec4 ShadowSpaceWater(vec3 worldPos) {
    vec4 World = vec4(worldPos, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}
#endif


#include "/lib/waterMedium.glsl"

float phaseHG(float cosTheta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cosTheta;
    return (1.0 - g2) / (4.0 * PI * pow(denom, 1.5));
}

float phaseWater(float cosTheta) {
    float forwardPhase = phaseHG(cosTheta, 0.9);
    float backPhase = phaseHG(cosTheta, -0.3);
    return mix(forwardPhase, backPhase, 0.1);
}

vec3 multiScatteringApprox(vec3 extinction, vec3 scattering, float depth) {
    vec3 ssAlbedo = scattering / extinction;
    vec3 multiScatFactor = ssAlbedo * ssAlbedo;
    vec3 effectiveExtinction = extinction * (1.0 - multiScatFactor * 0.5);
    vec3 transmittance = exp(-effectiveExtinction * depth);
    vec3 inScatter = (1.0 - transmittance) * ssAlbedo * (1.0 + multiScatFactor);
    return inScatter;
}

//// Shared water model ////
// Seen from above or from below, water is the same thing
vec3 waterBodyColor(float depth) {
    vec3 shallowWaterColor = vec3(shallowwaterR, shallowwaterG, shallowwaterB) / 255.0;
    vec3 deepWaterColor    = vec3(deepwaterR, deepwaterG, deepwaterB) / 255.0;
    return mix(shallowWaterColor, deepWaterColor, 1.0 - exp(-depth * 0.15));
}


// Ambient light in the water body
vec3 waterAmbientScatter(float path) {
    return multiScatteringApprox(waterPureExtinction, waterScatteringCoeff, path) * 0.15;
}

float waterShaftLight() {
    return transitionFade * rainDirect;
}


//// Looking into water from above ////
vec3 getWaterDepthFog(vec3 color, vec3 fragpos, vec3 fragpos2, float iswater, float lightMap, float skyAccess) {

    float path = min(distance(fragpos, fragpos2), 64.0);
    vec3  transmittance = waterTransmittancePath(path);

    // how much light actually reaches this water
    float skyVisibility = smoothstep(0.02, 0.30, skyAccess);

    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);   // world space, used below too
    vec3 light = waterSceneLight(lightDir.y) * lightMap * depthFogStr;
    vec3 waterLight = (waterBodyColor(path) + waterAmbientScatter(path)) * light;

    #ifdef volumetricLight
        float shaftLight = waterShaftLight();
        if (path > 0.1 && shaftLight > 0.0) {
            float startRay = 0.0;
            float endRay = min(path, 16.0);

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
            float surfaceY = startWorldPos.y;
            vec3  waterLightDir = waterRefractedLightDir(lightDir);
            float invWaterLightY = 1.0 / waterLightDir.y;
            float invLightY      = 1.0 / max(lightDir.y, 0.05);

            float phase = phaseWater(cosTheta);
            vec3 stepTransmittance = exp(-waterExtinctionCoeff * increment);
            vec3 scatterBase = sunCol * phase * 0.08;

            vec3 accumulatedScatter = vec3(0.0);
            vec3 accumulatedTransmittance = vec3(1.0);

            vec4 shadowCoordRay  = ShadowSpaceWater(currentWorldPos);
            vec4 shadowCoordStep = shadowProjection * (shadowModelView * vec4(worldStep, 0.0));

            for (float dist = startRay; dist < endRay; dist += increment) {
                vec4 shadowCoord = shadowCoordRay;
                shadowCoordRay += shadowCoordStep;
                shadowCoord.xy *= distort(shadowCoord.xy);
                shadowCoord.z /= 6.0;
                vec3 sampleCoords = shadowCoord.xyz * 0.5 + 0.5;
                sampleCoords.z -= 0.0005;

                float shadowSample = shadowStep(shadowtex1, sampleCoords);

                // Light lost on the way down uses the refracted path length
                float depthHere = max(0.0, surfaceY - currentWorldPos.y);
                float distToSurface = depthHere * invWaterLightY;

                vec3 causticSamplePos = currentWorldPos + lightDir * (depthHere * invLightY);
                causticSamplePos.y = surfaceY;
                vec3 causticValue = waterCaustics(causticSamplePos, 1.0);
                float causticIntensity = pow(causticValue.x, 1.5) * 8.0;
                causticIntensity *= exp(-dist * 0.08);

                vec3 surfaceToSample = waterTransmittancePath(distToSurface);

                vec3 inScatter = scatterBase * surfaceToSample * shadowSample;
                inScatter *= (1.0 + causticIntensity * 2.0);

                accumulatedScatter += inScatter * accumulatedTransmittance * increment;
                accumulatedTransmittance *= stepTransmittance;

                currentWorldPos += worldStep;
            }

            vec3 shaftTint = mix(vec3(shallowwaterR, shallowwaterG, shallowwaterB),
                                 vec3(deepwaterR, deepwaterG, deepwaterB),
                                 clamp(endRay * 0.05, 0.0, 1.0)) / 255.0;
            waterLight += accumulatedScatter * shaftTint * 5.0 * shaftLight * viewAngleBoost * lightMap * depthFogStr;
        }
    #endif

    vec3 worldPos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
    float turbidity = texture2D(noisetex, worldPos.xz * 0.1 + frameTimeCounter * 0.01).r;
    waterLight *= turbidity * 0.1 + 0.95;

    vec3 caveWaterColor = vec3(deepwaterR, deepwaterG, deepwaterB) / 255.0 * 0.04;
    waterLight = mix(caveWaterColor, waterLight, skyVisibility);

    return color * transmittance + waterLight * (1.0 - transmittance);
}


//// Underwater ////
vec3 getUnderwaterFog(vec3 color, vec3 viewPos, float lightMapSky) {
    
    float dist = length(viewPos);
    dist = clamp(dist, 0.0, 64.0);
    
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    
    // eyeBrightnessSmooth.y, 255 at surface, decreases with depth
    float skyExposure = float(eyeBrightnessSmooth.y) / 255.0;
    
    float estimatedDepth = (1.0 - skyExposure) * 28.0;
    estimatedDepth = max(estimatedDepth, 0.5);
    
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float lightAngle = max(0.15, abs(lightDir.y));
    
    float distSurfaceToCamera = estimatedDepth / lightAngle;
    
    vec3 underwaterExtinction = waterPureExtinction * 0.75;
    vec3 transmittance = exp(-underwaterExtinction * dist);
    float fogDensity = underwaterFogDensity(dist);
    
    
    vec3 shallowWaterColor = vec3(shallowwaterR, shallowwaterG, shallowwaterB)/255;
    vec3 deepWaterColor = vec3(deepwaterR, deepwaterG, deepwaterB)/255;
    vec3 abyssColor = vec3(0.008, 0.025, 0.04);
    
    float depthBlend = 1.0 - exp(-estimatedDepth * 0.09);
    float abyssBlend = 1.0 - exp(-estimatedDepth * 0.04);
    
    vec3 baseWaterColor = mix(shallowWaterColor, deepWaterColor, depthBlend);
    baseWaterColor = mix(baseWaterColor, abyssColor, abyssBlend * 0.45);
    
    vec3 rainyWaterColor = mix(baseWaterColor, vec3(0.11, 0.15, 0.19), rainStrength * 0.85);
    baseWaterColor = mix(baseWaterColor, rainyWaterColor * 0.32, rainStrength);
    
    float fogStr = waterDayLight * underFogStr;
    vec3 surfaceToCameraAtten = exp(-underwaterExtinction * distSurfaceToCamera * 0.12);
    float attenuationFactor = dot(surfaceToCameraAtten, vec3(0.33, 0.34, 0.33));
    fogStr *= max(attenuationFactor, 0.3);
    
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
            
            // Pre-compute loop-invariant values
            float phase = phaseWater(cosTheta);
            vec3 multiScatBoost = 1.0 + waterSSA * 0.55;
            vec3 stepTransmittance = exp(-underwaterExtinction * increment);
            vec3 scatterBase = sunCol * phase * 0.14 * multiScatBoost;
            float invLightDirY = 1.0 / max(0.1, lightDir.y);

            vec3 accumulatedScatter = vec3(0.0);
            vec3 accumulatedTransmittance = vec3(1.0);
            
            vec4 shadowCoordRay  = ShadowSpaceWater(currentWorldPos - cameraPosition);
            vec4 shadowCoordStep = shadowProjection * (shadowModelView * vec4(worldStep, 0.0));

            for (float rayDist = startRay; rayDist < endRay; rayDist += increment) {
                float distanceFalloff = exp(-rayDist * 0.04);
                
                vec4 shadowCoord = shadowCoordRay;
                shadowCoordRay += shadowCoordStep;
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
                
                float distToSurface = sampleDepth * invLightDirY;
                vec3 causticPos = currentWorldPos + lightDir * distToSurface;
                
                vec3 causticValue = waterCaustics(causticPos, 1.0);
                float causticIntensity = pow(causticValue.x, 1.5) * 2.0;
                causticIntensity *= exp(-sampleDepth * 0.04);
                
                vec3 surfaceToSample = exp(-underwaterExtinction * sampleDepth * 0.3);
                
                vec3 inScatter = scatterBase * surfaceToSample * shadowSample;
                inScatter *= (1.0 + causticIntensity * 2.0);
                inScatter *= distanceFalloff; 
                inScatter = min(inScatter, vec3(4.0));
                
                accumulatedScatter += inScatter * accumulatedTransmittance * increment;
                accumulatedTransmittance *= stepTransmittance;
                
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
