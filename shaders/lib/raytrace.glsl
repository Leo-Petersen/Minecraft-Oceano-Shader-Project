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

        float hitMaterial = texture2D(colortex2, position.st).p;
        bool hitIsWater = (hitMaterial > 0.08 && hitMaterial < 0.10);

        if (error < dynamicThreshold && texture2D(colortex2, position.st).g > 0.15 && !hitIsWater) {
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

// Overload, same as the raytrace() function above, but also reports the screen-space hit
// This is to accomodate the borderFog on the water surface, which needs to know the hit location and depth for proper blending
vec4 raytrace(vec3 skyColor, vec3 fragmentPos, vec3 normal, float fresnelView, out vec2 hitUV, out float hitDepth) {
    vec4 color = vec4(skyColor, 1.0);
    hitUV = vec2(0.5);   // miss defaults
    hitDepth = -1.0;     // -1.0 means "no hit" (falls back to the sky color)

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

        float hitMaterial = texture2D(colortex2, position.st).p;
        bool hitIsWater = (hitMaterial > 0.08 && hitMaterial < 0.10);

        if (error < dynamicThreshold && texture2D(colortex2, position.st).g > 0.15 && !hitIsWater) {
            stepCount++;
            if (stepCount >= maxRefinements) {
                color = texture2D(colortex0, position.st);
                color.a = 1.0 - pow(computeDistance(position.st), fresnelView);
                hitUV = position.st;                              // capture hit location
                hitDepth = texture2D(depthtex1, position.st).r;  // capture hit depth
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

//// Puddle Reflections ////
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

