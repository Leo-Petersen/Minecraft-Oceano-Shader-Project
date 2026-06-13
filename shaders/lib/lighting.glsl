
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

vec3 TransparentShadowHardware(vec3 SampleCoords, float transparencyFactor, float bias) {
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
    
    if (shadowOpaque > 0.99) {
        return sunlightCol * shadowOpaque;
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
    float depth = ld(texture2D(depthTexture, texcoord.xy).r);
    const float piAngle = 0.0174532925;

    #ifdef TAA
    float ditherValue = fract(IGN(gl_FragCoord.xy) + float(int(frameCounter) % 8) * 0.125);
    #else
    float ditherValue = dither64;
    #endif

    float rotation = 360.0 / aoSamples * fract(ditherValue);

    float sampleRadius = aoRadius * (0.5 + ditherValue * 0.5);
    vec2 scale = vec2(1.0 / aspectRatio, 1.0) * gbufferProjection[1][1] / (2.74747742 * max(far * depth, 6.0));

    // Precompute linearization constants for ld()
    float linDepthA = 2.0 * near;
    float linDepthB = far + near;
    float linDepthC = far - near;

    // Precompute the rotation step
    float stepAngle = PI / float(aoSamples);
    float cosStep = cos(stepAngle);
    float sinStep = sin(stepAngle);
    mat2 rotStep = mat2(cosStep, sinStep, -sinStep, cosStep);

    // Initial direction
    float startAngle = rotation * piAngle;
    vec2 dir = vec2(cos(startAngle), sin(startAngle)) * sampleRadius * scale;

    for (int j = 0; j < aoSamples; j++) {
        // Inline linearized depth, using precomputed constants
        float sampleDepth1 = linDepthA / (linDepthB - texture2D(depthTexture, texcoord.xy + dir).r * linDepthC);
        float sampleDepth2 = linDepthA / (linDepthB - texture2D(depthTexture, texcoord.xy - dir).r * linDepthC);

        float sampleOffset1 = far * (depth - sampleDepth1) / sampleRadius;
        float sampleOffset2 = far * (depth - sampleDepth2) / sampleRadius;

        float angle = clamp(0.5 - sampleOffset1, 0.0, 1.0) + clamp(0.5 - sampleOffset2, 0.0, 1.0);
        float distance = clamp(0.0625 * sampleOffset1, 0.0, 1.0) + clamp(0.0625 * sampleOffset2, 0.0, 1.0);

        ambientOcclusion += clamp(angle + distance, 0.0, 1.0);
        dir = rotStep * dir;
    }

    ambientOcclusion /= float(aoSamples);
    return pow(ambientOcclusion, aoStrength);
}

////SSS////
vec3 calculateSSS(
    vec3 worldPos,
    vec3 albedo,
    vec3 lightColor,
    float sssAmount,
    float VdotL,
    float NdotL,
    float skyLight,
    float IGN
) {
    if (sssAmount < 0.01) return vec3(0.0);

    vec4 rawShadowPos = shadowProjection * shadowModelView * vec4(worldPos, 1.0);

    float distb = length(rawShadowPos.xy);
    float distortFactor = (1.0 - shadowDistortion) + distb * shadowDistortion;

    vec3 shadowPos;
    shadowPos.xy = rawShadowPos.xy / distortFactor;
    shadowPos.z  = rawShadowPos.z / 6.0;
    shadowPos    = shadowPos * 0.5 + 0.5;

    // Offset scale, divide XY by distortFactor for consistent world-space radius.
    vec3 offsetScale = vec3(
        0.002 / distortFactor,
        0.002 / distortFactor,
        0.001
    ) * (sssAmount * 0.75 + 0.25);

    // Thickness estimation, golden-ratio spiral with depth probing.
    float gradNoise = fract(IGN + 1.618);
    float sssOcclusion = 0.0;

    for (int i = 0; i < SSS_Quality; i++) {
        gradNoise = fract(gradNoise + 1.618);
        float rot  = gradNoise * 6.283;
        float dist = (float(i) + gradNoise) / 12.0;

        vec2  offset2D = vec2(cos(rot), sin(rot)) * dist;
        float offsetZ  = -(dist * dist + 0.025);

        vec3 samplePos = shadowPos + vec3(offset2D, offsetZ) * offsetScale;

        sssOcclusion += shadow2D(shadowtex0, samplePos).r;
    }
    sssOcclusion /= SSS_Quality;
    sssOcclusion *= sssOcclusion;

    // backface factor
    float backface = clamp(1.0 - NdotL * 2.0, 0.0, 1.0);
    float transmission = sssOcclusion * backface;

    if (transmission < 0.01) return vec3(0.0);

    // Forward scattering phase
    float phase = pow(clamp(-VdotL * 0.5 + 0.5, 0.0, 1.0), 2.0);

    vec3 sssAlbedo = mix(lightColor, sqrt(albedo), 0.2);
    vec3 sssContribution = lightColor * sssAlbedo;

    sssContribution *= phase * sssAmount * transmission * skyLight * 0.8;
    sssContribution *= (1.0 - rainStrength * 0.5);

    return sssContribution;
}