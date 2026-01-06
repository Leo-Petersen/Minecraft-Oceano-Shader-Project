const float stepSize = 1.0;        // Size of one step for ray tracing algorithm
const float refinementMultiplier = 0.5; // Refinement multiplier
const float incrementFactor = 1.5;  // Increment factor at each step
const int maxRefinements = 3;       // Maximum number of refinements
const int numSamples = 15;          // Number of samples

vec3 normalizedVec3(vec4 pos) {
    return pos.xyz / pos.w;
}

vec4 normalizedVec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float computeDistance(vec2 coord) {
    return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
}

vec4 raytrace(vec3 skyColor, vec3 fragmentPos, vec3 normal, float fresnelView) {
    vec4 color = vec4(skyColor, 1.0);

    vec3 reflectionVector = normalize(reflect(normalize(fragmentPos), normalize(normal)));
    vec3 stepVector = stepSize * reflectionVector;
    vec3 oldPosition = fragmentPos;
    fragmentPos += stepVector;

    int stepCount = 0;
    float dist = 0.0;
    vec3 start = fragmentPos;

    for (int i = 0; i < numSamples; i++) {
        vec3 position = normalizedVec3(gbufferProjection * normalizedVec4(fragmentPos)) * 0.5 + 0.5;

        if (position.x < -0.05 || position.x > 1.05 || position.y < -0.05 || position.y > 1.05) {
            break;
        }

        vec3 samplePosition = vec3(position.st, texture2D(depthtex1, position.st).r);
        samplePosition = normalizedVec3(gbufferProjectionInverse * normalizedVec4(samplePosition * 2.0 - 1.0));

        dist = abs(dot(start - samplePosition, normal));
        float error = length(fragmentPos - samplePosition);

        float dynamicThreshold = length(stepVector) * pow(length(stepVector), 0.1) * 2.0; 

        if (error < dynamicThreshold && texture2D(colortex2, position.st).g > 0.15) {
            stepCount++;
            if (stepCount >= maxRefinements) {
                color = texture2D(colortex0, position.st);
                color.a = 1.0 - pow(computeDistance(position.st), fresnelView);
                break;
            }
            fragmentPos = oldPosition;
            stepVector *= refinementMultiplier;
        }

        stepVector *= incrementFactor;
        oldPosition = fragmentPos;
        fragmentPos += stepVector;
    }

    return color;
}

#ifdef PBRReflection

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 marchRay(vec3 viewPos, vec3 reflectDir, out float confidence) {
    float step = 0.5;
    vec3 rayPos = viewPos + reflectDir * step;
    
    confidence = 0.0;
    
    for (int i = 0; i < 24; i++) {
        vec4 projPos = gbufferProjection * vec4(rayPos, 1.0);
        projPos.xyz /= projPos.w;
        vec2 screenCoord = projPos.xy * 0.5 + 0.5;
        
        // Out of bounds
        if (screenCoord.x < 0.0 || screenCoord.x > 1.0 || 
            screenCoord.y < 0.0 || screenCoord.y > 1.0) {
            return vec3(-1.0);
        }
        
        float sceneDepth = texture2D(depthtex1, screenCoord).r;
        
        // Hit sky
        if (sceneDepth >= 0.9999) {
            return vec3(-2.0);
        }
        
        vec4 sceneViewPos = gbufferProjectionInverse * vec4(screenCoord * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
        sceneViewPos.xyz /= sceneViewPos.w;
        
        float rayDepth = -rayPos.z;
        float surfaceDepth = -sceneViewPos.z;
        float depthDiff = rayDepth - surfaceDepth;
        
        // Hit surface
        if (depthDiff > 0.0 && depthDiff < step * 2.0) {
            if (texture2D(colortex2, screenCoord).g > 0.1) {
                float depthConfidence = 1.0 - smoothstep(0.0, step * 1.5, depthDiff);
                float edgeFade = 1.0 - pow(max(abs(screenCoord.x - 0.5), abs(screenCoord.y - 0.5)) * 2.0, 3.0);
                confidence = depthConfidence * edgeFade;
                return vec3(screenCoord, 1.0);
            }
        }
        
        step *= 1.2;
        rayPos += reflectDir * step;
    }
    
    return vec3(-1.0);
}

// Main PBR raytrace function //
vec4 raytracePBR(vec3 fallbackColor, vec3 viewPos, vec3 normal, float roughness, vec2 screenUV) {
    vec3 viewDir = normalize(viewPos);
    vec3 reflectDir = reflect(viewDir, normal);
    
    // March the ray
    float confidence;
    vec3 hitResult = marchRay(viewPos, reflectDir, confidence);
    
    // Sky hit
    if (hitResult.x < -1.5) {
        return vec4(fallbackColor, 1.0);
    }
    
    // Miss
    if (hitResult.x < 0.0) {
        return vec4(fallbackColor, 0.0);
    }
    
    // Hit
    vec2 hitCoord = hitResult.xy;
    
    // For smooth surfaces, just returning the hit color
    if (roughness < 0.12) {
        vec3 hitColor = texture2D(colortex0, hitCoord).rgb;
        return vec4(hitColor, confidence);
    }
    
    // Golden angle for spiral
    const float goldenAngle = 2.39996323;
    
    float blurPixels = roughness * roughness * 40.0;
    vec2 blurRadius = vec2(blurPixels / viewWidth, blurPixels / viewHeight);

    const int blurSamples = 4;
    
    float rotation = 0.0;
    #ifdef TAA
        rotation = hash12(screenUV * 1000.0 + frameTimeCounter * 50.0) * 6.28318;
    #endif
    
    vec3 blurredColor = vec3(0.0);
    float totalWeight = 0.0;
    
    blurredColor += texture2D(colortex0, hitCoord).rgb * 0.25;
    totalWeight += 0.25;
    
    for (int i = 0; i < blurSamples; i++) {
        float r = sqrt(float(i + 1) / float(blurSamples)); // Radius [0,1]
        float theta = float(i) * goldenAngle + rotation;
        
        vec2 offset = vec2(cos(theta), sin(theta)) * r * blurRadius;
        vec2 sampleCoord = hitCoord + offset;
        
        // Clamp to screen
        sampleCoord = clamp(sampleCoord, vec2(0.001), vec2(0.999));
        
        // Weight falls off toward edges of disk
        float weight = 1.0 - r * 0.5;
        
        blurredColor += texture2D(colortex0, sampleCoord).rgb * weight;
        totalWeight += weight;
    }
    
    blurredColor /= totalWeight;
    
    return vec4(blurredColor, confidence);
}

vec4 raytracePBR(vec3 fallbackColor, vec3 viewPos, vec3 normal) {
    return raytracePBR(fallbackColor, viewPos, normal, 0.0, vec2(0.5));
}

#endif

vec4 raytracePuddles(vec3 skyColor, vec3 fragmentPos, vec3 normal, float fresnelView) {
    vec4 color = vec4(skyColor, 1.0);
    
    vec3 reflectionVector = normalize(reflect(normalize(fragmentPos), normalize(normal)));
    vec3 stepVector = stepSize * reflectionVector;
    vec3 oldPosition = fragmentPos;
    fragmentPos += stepVector;
    int stepCount = 0;

    for (int i = 0; i < numSamples; i++) {
        vec3 position = normalizedVec3(gbufferProjection * normalizedVec4(fragmentPos)) * 0.5 + 0.5;
        if (any(lessThan(position, vec3(0.0))) || any(greaterThan(position, vec3(1.0)))) {
            break;
        }
        vec3 samplePosition = vec3(position.st, texture2D(depthtex1, position.st).r);
        samplePosition = normalizedVec3(gbufferProjectionInverse * normalizedVec4(samplePosition * 2.0 - 1.0));
        float error = abs(fragmentPos.z - samplePosition.z);
        if (error < pow(length(stepVector), 1.35) && texture2D(colortex2, position.st).g > 0.15) {
            stepCount++;
            if (stepCount >= maxRefinements) {
                color = texture2D(colortex0, position.st);
                color.a = 1.0 - pow(computeDistance(position.st), fresnelView);
                break;
            }
            fragmentPos = oldPosition;
            stepVector *= refinementMultiplier;
        }
        stepVector *= incrementFactor;
        oldPosition = fragmentPos;
        fragmentPos += stepVector;
    }

    return color;
}

