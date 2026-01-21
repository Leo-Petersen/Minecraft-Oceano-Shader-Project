
const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = true;

// NOTE: shadowcolor still uses sampler2D (to get actual color values)
float Depth = texture2D(depthtex0, texcoord).r;
vec3 viewNormal = normalize(decodeNormal(texture2D(colortex1, texcoord).xy));

float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define bayer4(a)   (bayer2(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer8(a)   (bayer4(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer16(a)  (bayer8(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer32(a)  (bayer16(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer64(a)  (bayer32(0.5 * (a)) * 0.25 + bayer2(a))
float dither64 = bayer64(gl_FragCoord.xy);

vec4 ShadowSpace() {
    vec3 ClipSpace = vec3(texcoord, Depth) * 2.0 - 1.0;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

float distort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

float getShadowBias(vec3 SampleCoords) {
    float dist = length(SampleCoords.xy - 0.5);
    float distFactor = smoothstep(0.0, 0.5, dist);
    
    float NdotL = max(dot(viewNormal, normalize(shadowLightPosition)), 0.0);
    float slopeBias = 0.0004 * (1.0 - NdotL) * distFactor;
    float baseBias = 0.0001 + dist * 0.0005;
    
    return baseBias + slopeBias;
}

vec3 TransparentShadowHardware(vec3 SampleCoords, float transparencyFactor) {
    float bias = getShadowBias(SampleCoords);
    vec3 biasedCoords = vec3(SampleCoords.xy, SampleCoords.z - bias);
    
    // Hardware PCF shadow sampling
    float shadowTransparent = shadow2D(shadowtex0, biasedCoords).r; // all blockers
    float shadowOpaque = shadow2D(shadowtex1, biasedCoords).r;      // opaque only
    
    if (shadowTransparent > 0.99) {
        return sunlightCol;
    }
    
    if (shadowOpaque < 0.01) {
        return vec3(0.0);
    }
    

    if (shadowOpaque > shadowTransparent + 0.01) {
        vec4 shadowCol = texture2D(shadowcolor0, SampleCoords.xy);
        vec3 transmittedColor = shadowCol.rgb * (1.0 - shadowCol.a);
        
        return mix(transmittedColor * transparencyFactor, sunlightCol, shadowTransparent) * shadowOpaque;
    }
    
    return sunlightCol * shadowOpaque;
}

// Legacy function
vec3 TransparentShadow(in vec3 SampleCoords, float transparencyFactor) {
    return TransparentShadowHardware(SampleCoords, transparencyFactor);
}

float getViewDistance() {
    vec3 ClipSpace = vec3(texcoord, Depth) * 2.0 - 1.0;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    return length(View);
}

#ifdef PCSS_ENABLED
float PCSSBlockerSearch(vec3 shadowCoord, mat2 Rotation, vec3 Rotationvec3) {
    float blockerSum = 0.0;
    float numBlockers = 0.0;
    float viewDistance = getViewDistance();
    float distanceScale = clamp(viewDistance / 256.0, 0.1, 4.0);
    float searchSize = (0.003 * filterStr * (1.0 + rainStrength)) / distanceScale;
    
    float ditherOffset = dither64;
    
    for (int i = 0; i < 3; i++) {
        int index = int(64.0 * fract(sin(dot(floor(Rotationvec3) + vec3(i), vec3(12.9898, 78.233, 45.164))) * 43758.5453)) % 64;
        vec2 offset = poissonDisk64[index] * searchSize * Rotation;
        offset *= 0.75 + ditherOffset * 0.5;
        
        float shadowMapDepth = texture2D(shadowtex0Raw, shadowCoord.xy + offset).x;
        
        if (shadowMapDepth < shadowCoord.z - 0.001) {
            blockerSum += shadowMapDepth;
            numBlockers += 1.0;
        }
    }
    
    return (numBlockers > 0.0) ? blockerSum / numBlockers : -1.0;
}

float PCSSPenumbraSize(float receiverDepth, float blockerDepth) {
    if (blockerDepth < 0.0) return 0.006 * filterStr;
    
    float penumbra = (receiverDepth - blockerDepth) / max(blockerDepth, 0.001);
    
    float slope = 12.0; 
    penumbra = 1.0 - exp(-slope * penumbra);
    penumbra = smoothstep(0.0, 1.0, penumbra);
    
    float lightWidth = 0.06;
    
    return clamp(penumbra * lightWidth * filterStr, 
                0.002 * filterStr, 
                0.03 * filterStr * (1.0 + rainStrength)); 
}

vec3 PCSSFiltering(vec3 shadowCoord, float penumbraSize, float transparencyFactor, mat2 Rotation, vec3 Rotationvec3) {
    vec3 shadowSum = vec3(0.0);
    float filterSize = penumbraSize * (1.0 + rainStrength * 2.0);

    int sampleCount = max(lightingQuality / 2, 2);
    
    for (int i = 0; i < sampleCount; i++) {
        int index = int(64.0 * fract(sin(dot(floor(Rotationvec3) + vec3(i), vec3(12.9898, 78.233, 45.164))) * 43758.5453)) % 64;
        vec2 offset = poissonDisk64[index] * filterSize * Rotation;
        shadowSum += TransparentShadowHardware(vec3(shadowCoord.xy + offset, shadowCoord.z), transparencyFactor);
    }
    
    return shadowSum / float(sampleCount);
}
#endif



float cloudNoise(float noise, vec3 worldPos) {
    return texture2D(noisetex, 0.000017 * (vec2(noise) + frameTimeCounter * 3.0 + (worldPos.xz + cameraPosition.xz))).r;
}

float fakeCloudShadow(vec3 worldPos) {
    float shadow = cloudNoise(0.0, worldPos) + cloudNoise(10000.0, worldPos);
    return clamp(pow(shadow, 2.0 * (1.0 - time[5] * 0.5)), 0.0, 1.0);
}

////Bounce Light////
#ifdef BounceLight
    vec3 backLight(vec3 bounceColor) {
        bounceColor *= 2.0;
        sunlightCol *= 2.0;
        float upVector = -dot(upVec, viewNormal);
        
        vec3 backLight = (sunlightCol + bounceColor) * (upVector + 7.0);
        return (backLight + sunlightCol);
    }
#else
    vec3 backLight(vec3 bounceColor) {
        return vec3(8.0);
    }
#endif

////AmbientOcclusion////
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

float IGN(vec2 coord) {
    return fract(52.9829189 * fract(dot(coord, vec2(0.06711056, 0.00583715))));
}

float ambientOcclusion(sampler2D depthTexture) {
    float ambientOcclusion = 0.0;

    int aoSamples = aoQuality + 1;
    float initialRadius = aoRadius / exp2(0.14 * aoQuality);
    float depth = ld(texture2D(depthTexture, texcoord.xy).r);
    const float piAngle = 0.0174603175;

    #ifdef TAA
    float ditherValue = fract(IGN(gl_FragCoord.xy) + float(int(frameCounter) % 8) * 0.125);
    #else
    float ditherValue = dither64;
    #endif

    float rotation = 360.0 / aoSamples * fract(ditherValue);

    float sampleRadius = initialRadius * (0.5 + ditherValue * 0.5);
    vec2 scale = vec2(1.0 / aspectRatio, 1.0) * gbufferProjection[1][1] / (2.74747742 * max(far * depth, 6.0));

    for (int j = 0; j < aoSamples; j++) {
        vec2 offset = vec2(cos(rotation * piAngle), sin(rotation * piAngle)) * sampleRadius * scale;
        float sampleDepth1 = ld(texture2D(depthTexture, texcoord.xy + offset).r);
        float sampleDepth2 = ld(texture2D(depthTexture, texcoord.xy - offset).r);

        float sampleOffset1 = far * (depth - sampleDepth1) / sampleRadius;
        float sampleOffset2 = far * (depth - sampleDepth2) / sampleRadius;

        float angle = clamp(0.5 - sampleOffset1, 0.0, 1.0) + clamp(0.5 - sampleOffset2, 0.0, 1.0);
        float distance = clamp(0.0625 * sampleOffset1, 0.0, 1.0) + clamp(0.0625 * sampleOffset2, 0.0, 1.0);

        ambientOcclusion += clamp(angle + distance, 0.0, 1.0);
        rotation += 180.0 / aoSamples;
    }

    ambientOcclusion /= float(aoSamples);
    return pow(ambientOcclusion, 0.25 * aoQuality + 1.5);
}

////SSS////
vec3 SSS(float material, float Diffuse, vec3 color, vec3 sunlightCol, 
                                  float sunAngleCosine, vec3 ShadowAccum, float lightStrength, 
                                  float lightMapT, float rainStrength, float strength) {
        
    float backlight = max(0.0, -Diffuse * 0.6 + 0.4);
          backlight = pow(backlight, 4.0);
    
    vec3 sssColor = sqrt(color) * sunlightCol; 
    float sssStrength = 30.0 * backlight * pow(sunAngleCosine, 0.3) * strength;
    
    vec3 SSS = sssColor * sssStrength * ShadowAccum * lightStrength * clamp(lightMapT, 0.3, 1.0);
    
    return SSS;
}
