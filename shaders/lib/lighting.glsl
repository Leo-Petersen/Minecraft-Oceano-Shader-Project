
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

vec4 ShadowSpace(vec3 worldPos) {
    vec4 ShadowSpace = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    return ShadowSpace;
}

float distort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

float getShadowBias(vec3 SampleCoords) {
    float dist = length(SampleCoords.xy - 0.5);
    float distFactor = smoothstep(0.0, 0.5, dist);
    
    float NdotL = max(dot(viewNormal, shadowLightPosition*0.01), 0.0);
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

////Fake Cloud Shadow////
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
        vec3 scaledBounce = bounceColor * 2.0;
        vec3 scaledSunlight = sunlightCol * 2.0;
        float upVector = -dot(upVec, viewNormal);
        vec3 backLight = (scaledSunlight + scaledBounce) * (upVector + 7.0);
        return (backLight + scaledSunlight);
    }
#else
    vec3 backLight(vec3 bounceColor) {
        return vec3(20.0);
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
    const float piAngle = 0.0174532925;

    #ifdef TAA
    float ditherValue = fract(IGN(gl_FragCoord.xy) + float(int(frameCounter) % 8) * 0.125);
    #else
    float ditherValue = dither64;
    #endif

    float rotation = 360.0 / aoSamples * fract(ditherValue);

    float sampleRadius = initialRadius * (0.5 + ditherValue * 0.5);
    vec2 scale = vec2(1.0 / aspectRatio, 1.0) * gbufferProjection[1][1] / (2.74747742 * max(far * depth, 6.0));

    // Compute the rotation step angle
    float stepAngle = PI / float(aoSamples);
    float cosStep = cos(stepAngle);
    float sinStep = sin(stepAngle);
    mat2 rotStep = mat2(cosStep, sinStep, -sinStep, cosStep);

    // Compute initial direction
    float startAngle = rotation * piAngle;
    vec2 dir = vec2(cos(startAngle), sin(startAngle)) * sampleRadius * scale;

    for (int j = 0; j < aoSamples; j++) {
        float sampleDepth1 = ld(texture2D(depthTexture, texcoord.xy + dir).r);
        float sampleDepth2 = ld(texture2D(depthTexture, texcoord.xy - dir).r);

        float sampleOffset1 = far * (depth - sampleDepth1) / sampleRadius;
        float sampleOffset2 = far * (depth - sampleDepth2) / sampleRadius;

        float angle = clamp(0.5 - sampleOffset1, 0.0, 1.0) + clamp(0.5 - sampleOffset2, 0.0, 1.0);
        float distance = clamp(0.0625 * sampleOffset1, 0.0, 1.0) + clamp(0.0625 * sampleOffset2, 0.0, 1.0);

        ambientOcclusion += clamp(angle + distance, 0.0, 1.0);
        dir = rotStep * dir;
    }

    ambientOcclusion /= float(aoSamples);
    return pow(ambientOcclusion, 0.25 * aoQuality + 1.5);
}

////SSS////
vec3 calculateSSS(
    vec3 shadowCoord,
    vec3 albedo,
    vec3 lightColor,
    float sssAmount,
    float VdotL,
    float NdotL,
    float skyLight,
    float distFactor,
    float IGN,
    float uniformity
) {
    if (sssAmount < 0.01) return vec3(0.0);
    
    // Backlit detection
    float backlit = max(0.0, -NdotL);
    backlit = mix(backlit, 0.5, uniformity);
    
    // Sample shadow for occlusion
    const float sssRadius = 0.002;
    float screenNoise = fract(IGN + (texcoord.x + texcoord.y) * 64.0);
    vec2 offset = vec2(cos(screenNoise * 6.28318), sin(screenNoise * 6.28318)) * sssRadius;
    
    float sssShadow = shadow2D(shadowtex1, vec3(shadowCoord.xy, shadowCoord.z - 0.00007)).r;
    sssShadow += shadow2D(shadowtex1, vec3(shadowCoord.xy + offset, shadowCoord.z)).r;
    sssShadow *= 0.5;

    vec3 sssColor = texture2D(shadowcolor0, shadowCoord.xy).rgb;
    sssColor = mix(vec3(1.0), sssColor, 0.5);

    // SSS needs light to transmit through, backfacing AND in light path
    float transmission = sssShadow * backlit;
    
    // Kill SSS on front lit surfaces
    float frontlit = max(0.0, NdotL);
    transmission *= 1.0 - frontlit * 0.9;
    
    if (transmission < 0.01) return vec3(0.0);
    
    // Forward scattering phase
    float phase = pow(max(0.0, -VdotL) * 0.5 + 0.5, 2.0);
    
    float lightLum = dot(lightColor, vec3(0.2126, 0.7152, 0.0722));
    vec3 sssAlbedo = mix(vec3(lightLum), sqrt(albedo), clamp(lightLum * 2.0, 0.0, 1.0));
    vec3 sssContribution = lightColor * sssAlbedo * sssColor;
    
    sssContribution *= phase * sssAmount * transmission * skyLight;
    sssContribution *= (1.0 - rainStrength * 0.5);
    sssContribution *= mix(1.0, 0.5, distFactor);
    //sssContribution *= 2.0;
    
    return sssContribution;
}
