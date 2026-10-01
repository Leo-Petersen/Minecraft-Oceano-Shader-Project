const float stepSize = 1.0;        // Size of one step for ray tracing algorithm
const float refinementMultiplier = 0.5; // Refinement multiplier
const float incrementFactor = 1.5;  // Increment factor at each step
const int maxRefinements = 5;       // Maximum number of refinements
const int numSamples = 25;          // Number of samples

vec3 normalizedVec3(vec4 pos) {
    return pos.xyz / pos.w;
}

vec4 normalizedVec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

vec3 rtViewToScreen(vec3 p) {
    vec4 c = vec4(gbufferProjection[0].x * p.x + gbufferProjection[2].x * p.z + gbufferProjection[3].x,
                  gbufferProjection[1].y * p.y + gbufferProjection[2].y * p.z + gbufferProjection[3].y,
                  gbufferProjection[2].z * p.z + gbufferProjection[3].z,
                  gbufferProjection[2].w * p.z + gbufferProjection[3].w);
    return c.xyz / c.w * 0.5 + 0.5;
}
vec3 rtScreenToView(vec3 s) {
    vec3 n = s * 2.0 - 1.0;
    vec4 v = vec4(gbufferProjectionInverse[0].x * n.x + gbufferProjectionInverse[3].x,
                  gbufferProjectionInverse[1].y * n.y + gbufferProjectionInverse[3].y,
                  gbufferProjectionInverse[2].z * n.z + gbufferProjectionInverse[3].z,
                  gbufferProjectionInverse[2].w * n.z + gbufferProjectionInverse[3].w);
    return v.xyz / v.w;
}

float computeDistance(vec2 coord) {
    return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 2.0;
}

bool sampleSurfaceViewPos(vec2 uv, out vec3 samplePosition, out bool outIsDH) {
    outIsDH = false;
    float vDepth = texture2D(depthtex1, uv).r;
    // <0.56 is the players hand, march past it
    if (vDepth < 1.0 && vDepth >= 0.56) {
        samplePosition = rtScreenToView(vec3(uv, vDepth));
        return true;
    }
    #ifdef DISTANT_HORIZONS
    float dDepth = texture2D(dhDepthTex1, uv).r;
    if (dDepth < 1.0) {
        samplePosition = normalizedVec3(dhProjectionInverse * normalizedVec4(vec3(uv, dDepth) * 2.0 - 1.0));
        outIsDH = true;
        return true;
    }
    #endif
    return false;
}

bool rtIsWater(vec2 uv) {
    float m = texture2D(colortex2, uv).p;
    return m > 0.08 && m < 0.10;
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
        vec3 position = rtViewToScreen(fragmentPos);

        if (position.x < -0.05 || position.x > 1.05 || position.y < -0.05 || position.y > 1.05) {
            break;
        }

        vec3 samplePosition;
        bool sampleIsDH;
        bool hasSurface = sampleSurfaceViewPos(position.st, samplePosition, sampleIsDH);

        if (hasSurface) {
            dist = abs(dot(start - samplePosition, normal));
            float error = length(fragmentPos - samplePosition);

            float dynamicThreshold = length(stepVector) * pow(length(stepVector), 0.1) * 2.0;

            if (error < dynamicThreshold && !rtIsWater(position.st)) {
                stepCount++;
                if (stepCount >= maxRefinements) {
                    color = textureLod(colortex0, position.st, 0.0);
                    color.a = 1.0 - pow(computeDistance(position.st), fresnelView);
                    break;
                }
                fragmentPos = oldPosition;
                stepVector *= refinementMultiplier;
            }
        }

        stepVector *= incrementFactor;
        oldPosition = fragmentPos;
        fragmentPos += stepVector;
    }

    return color;
}

// Overload, same as the raytrace() function above, but also reports the screen-space hit
vec4 raytrace(vec3 skyColor, vec3 fragmentPos, vec3 normal, float fresnelView, out vec2 hitUV, out float hitDepth, out vec3 hitViewPos) {
    vec4 color = vec4(skyColor, 1.0);
    hitUV = vec2(0.5);       // miss defaults
    hitDepth = -1.0;         // -1.0 means "no hit" (falls back to the sky color)
    hitViewPos = vec3(0.0);

    vec3 reflectionVector = normalize(reflect(normalize(fragmentPos), normalize(normal)));
    vec3 stepVector = stepSize * reflectionVector;
    vec3 oldPosition = fragmentPos;
    fragmentPos += stepVector;

    int stepCount = 0;
    float dist = 0.0;
    vec3 start = fragmentPos;

    for (int i = 0; i < numSamples; i++) {
        vec3 position = rtViewToScreen(fragmentPos);

        if (position.x < -0.05 || position.x > 1.05 || position.y < -0.05 || position.y > 1.05) {
            break;
        }

        vec3 samplePosition;
        bool sampleIsDH;
        bool hasSurface = sampleSurfaceViewPos(position.st, samplePosition, sampleIsDH);

        if (hasSurface) {
            dist = abs(dot(start - samplePosition, normal));
            float error = length(fragmentPos - samplePosition);

            float dynamicThreshold = length(stepVector) * pow(length(stepVector), 0.1) * 2.0;

            if (error < dynamicThreshold && !rtIsWater(position.st)) {
                stepCount++;
                if (stepCount >= maxRefinements) {
                    color = textureLod(colortex0, position.st, 0.0);
                    color.a = 1.0 - pow(computeDistance(position.st), fresnelView);
                    hitUV = position.st; 
                    hitDepth = sampleIsDH ? 1.0 : texture2D(depthtex1, position.st).r;
                    hitViewPos = samplePosition;
                    break;
                }
                fragmentPos = oldPosition;
                stepVector *= refinementMultiplier;
            }
        }

        stepVector *= incrementFactor;
        oldPosition = fragmentPos;
        fragmentPos += stepVector;
    }

    return color;
}

//// Puddle Reflections ////
vec4 raytracePuddles(vec3 skyColor, vec3 fragmentPos, vec3 normal, float fresnelView) {
    vec4 color = vec4(skyColor, 1.0);
    
    vec3 reflectionVector = normalize(reflect(normalize(fragmentPos), normalize(normal)));
    vec3 stepVector = stepSize * reflectionVector;
    vec3 oldPosition = fragmentPos;
    fragmentPos += stepVector;
    int stepCount = 0;

    for (int i = 0; i < numSamples; i++) {
        vec3 position = rtViewToScreen(fragmentPos);
        if (any(lessThan(position, vec3(0.0))) || any(greaterThan(position, vec3(1.0)))) {
            break;
        }
        vec3 samplePosition = vec3(position.st, texture2D(depthtex1, position.st).r);
        samplePosition = rtScreenToView(samplePosition);
        float error = abs(fragmentPos.z - samplePosition.z);
        if (error < pow(length(stepVector), 1.35) && texture2D(depthtex1, position.st).r < 1.0) {
            stepCount++;
            if (stepCount >= maxRefinements) {
                color = textureLod(colortex0, position.st, 0.0);
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
