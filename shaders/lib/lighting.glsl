const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = true;

float Depth = texture2D(depthtex0, texcoord).r;
vec3 viewNormal = normalize(decodeNormal(texture2D(colortex1, texcoord).xy));

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

    if (shadowOpaque > shadowTransparent + 0.01) {
        vec4 shadowCol = texture2D(shadowcolor0, SampleCoords.xy);
        vec3 transmittedColor = shadowCol.rgb * (1.0 - shadowCol.a);
        
        return mix(transmittedColor * transparencyFactor, sunlightCol, shadowTransparent) * shadowOpaque;
    }
    
    return sunlightCol * shadowOpaque;
}

////Fake Cloud Shadow////
float cloudNoise(float noise, vec3 worldPos) {
    return texture2D(noisetex, 0.000003 * (vec2(noise) + frameTimeCounter * 3.0 + (worldPos.xz + cameraPosition.xz))).r;
}

float fakeCloudShadow(vec3 worldPos, float distFactor) {
    float shadow = cloudNoise(0.0, worldPos) + cloudNoise(10000.0, worldPos);
    return clamp(pow(shadow, 2.0 * (1.0 - time[5] * 0.5) * distFactor), 0.0, 1.0);
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

// depth using projection matrix
float aoGetLinearDepth(float depth) {
    depth = depth * 2.0 - 1.0;
    vec2 zw = depth * gbufferProjectionInverse[2].zw + gbufferProjectionInverse[3].zw;
    return -zw.x / zw.y;
}

// view position reconstruction
vec3 aoGetViewPos(vec3 screenPos) {
    vec4 viewPos = gbufferProjectionInverse * (vec4(screenPos, 1.0) * 2.0 - 1.0);
    return viewPos.xyz / viewPos.w;
}

// normal reconstruction from depth buffer
vec3 aoGetReconstructedNormal(sampler2D depthTexture, float linZ, vec3 viewPos) {
    float pw = 1.0 / viewWidth;
    float ph = 1.0 / viewHeight;

    float eZ = texture2D(depthTexture, texcoord.xy + vec2(pw, 0.0)).r;
    float wZ = texture2D(depthTexture, texcoord.xy - vec2(pw, 0.0)).r;
    float nZ = texture2D(depthTexture, texcoord.xy + vec2(0.0, ph)).r;
    float sZ = texture2D(depthTexture, texcoord.xy - vec2(0.0, ph)).r;

    float eLinZ = aoGetLinearDepth(eZ);
    float wLinZ = aoGetLinearDepth(wZ);
    float nLinZ = aoGetLinearDepth(nZ);
    float sLinZ = aoGetLinearDepth(sZ);

    vec3 hDeriv = vec3(0.0);
    bool useE = abs(eLinZ - linZ) < abs(wLinZ - linZ);
    if (useE) {
        vec3 hScreenPos = vec3(texcoord.xy + vec2(pw, 0.0), eZ);
        vec3 hViewPos = aoGetViewPos(hScreenPos);
        hDeriv = hViewPos - viewPos;
    } else {
        vec3 hScreenPos = vec3(texcoord.xy - vec2(pw, 0.0), wZ);
        vec3 hViewPos = aoGetViewPos(hScreenPos);
        hDeriv = viewPos - hViewPos;
    }

    vec3 vDeriv = vec3(0.0);
    bool useN = abs(nLinZ - linZ) < abs(sLinZ - linZ);
    if (useN) {
        vec3 vScreenPos = vec3(texcoord.xy + vec2(0.0, ph), nZ);
        vec3 vViewPos = aoGetViewPos(vScreenPos);
        vDeriv = vViewPos - viewPos;
    } else {
        vec3 vScreenPos = vec3(texcoord.xy - vec2(0.0, ph), sZ);
        vec3 vViewPos = aoGetViewPos(vScreenPos);
        vDeriv = viewPos - vViewPos;
    }

    return normalize(cross(hDeriv, vDeriv));
}

float ambientOcclusion(sampler2D depthTexture) {
    float ao = 0.0;
    float pointiness = 0.0;

    float z = texture2D(depthTexture, texcoord.xy).r;
    if (z >= 1.0) return 1.0;

    float hand = float(z < 0.56);
    float linZ = aoGetLinearDepth(z);

    // Interleaved Gradient Noise for TAA *the thumbs up emoji*
    float IGN = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    #ifdef TAA
        float temporalOffset = float(frameCounter % 8) / 8.0;
        IGN = fract(IGN + temporalOffset);
    #endif

    float currentStep = 0.2475 * IGN + 0.01;

    float radius = 0.25;
    float uncappedDist = linZ;
    float distanceScale = max(uncappedDist, 2.5);
    float fovScale = gbufferProjection[1][1] / 1.37;
    vec2 scale = radius * aoRadius * 2 * vec2(1.0 / aspectRatio, 1.0) * fovScale / distanceScale;
    float differenceScale = uncappedDist / distanceScale;

    vec2 baseOffset = vec2(cos(IGN * 6.28), sin(IGN * 6.28));

    vec3 viewPos = aoGetViewPos(vec3(texcoord.xy, z));
    vec3 normal = aoGetReconstructedNormal(depthTexture, linZ, viewPos);
    float angleThreshold = 0.15 + linZ * 0.01;
    
    for (int i = 0; i < aoQuality; i++) {
        vec2 offset = baseOffset * currentStep * scale;
        float visibility = 0.0;

        for (int j = 0; j < 2; j++) {
            vec2 sampleCoord = texcoord + offset;
            float sampleZ = texture2D(depthTexture, sampleCoord).r;
            vec3 sampleViewPos = aoGetViewPos(vec3(sampleCoord, sampleZ));
            vec3 difference = (sampleViewPos.xyz - viewPos.xyz) / (radius * currentStep * differenceScale);
            float attenuation = clamp(1.0 + 0.5 / currentStep - 0.25 * length(difference), 0.0, 1.0);

            if (hand > 0.5) {
                visibility += clamp(0.5 - difference.z * 4096.0, 0.0, 1.0);
            } else {
                float angle = dot(normal, normalize(difference)) * (1.0 + angleThreshold);
                visibility += 0.5 - max(angle - angleThreshold, 0.0) * attenuation;
                pointiness += max(-angle - angleThreshold, 0.0);
            }

            offset = -offset;
        }

        ao += clamp(visibility, 0.0, 1.0);

        currentStep += 0.2475;
        baseOffset = vec2(baseOffset.x - baseOffset.y, baseOffset.x + baseOffset.y) * 0.7071;
    }

    ao *= 1.0 / float(aoQuality);
    pointiness *= 1.0 / float(aoQuality);

    ao = mix(ao, 1.0, pointiness);

    return ao;
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
    float IGN,
    float distFactor
) {
    if (sssAmount < 0.01) return vec3(0.0);

    vec4 rawShadowPos = shadowProjection * shadowModelView * vec4(worldPos, 1.0);

    float distb = length(rawShadowPos.xy);
    float distortFactor = (1.0 - shadowDistortion) + distb * shadowDistortion;

    vec3 shadowPos;
    shadowPos.xy = rawShadowPos.xy / distortFactor;
    shadowPos.z  = rawShadowPos.z / 6.0;
    shadowPos    = shadowPos * 0.5 + 0.5;

    // Reject geometry outside the shadow frustum,
    // fixes foliage beyond the shadow render dist getting the max possible term / being fully lit by sunlight
    float edgeXY = max(abs(shadowPos.x * 2.0 - 1.0), abs(shadowPos.y * 2.0 - 1.0));
    float edgeZ  = abs(shadowPos.z * 2.0 - 1.0);
    float sssValid = (1.0 - smoothstep(0.70, 0.95, edgeXY))
                   * (1.0 - smoothstep(0.85, 0.99, edgeZ));

    if (sssValid < 0.001) return vec3(0.0);

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
             samplePos.xy = clamp(samplePos.xy, 0.0, 1.0);

        sssOcclusion += shadow2D(shadowtex0, samplePos).r;
    }
    sssOcclusion /= SSS_Quality;
    sssOcclusion *= sssOcclusion;

    // backface factor
    float backface = clamp(1.0 - NdotL * 2.0, 0.0, 1.0);
    float transmission = sssOcclusion * backface;

    if (transmission < 0.01) return vec3(0.0);

    // Forward scattering phase
    float phase = clamp(-VdotL * 0.5 + 0.5, 0.0, 1.0);
          phase = mix(0.35, 1.0, phase);    

    vec3 sssContribution = lightColor * lightColor * phase * sssAmount * transmission * skyLight * 0.62;
    sssContribution *= (1.0 - rainStrength * 0.5);
    sssContribution *= sssValid * (1-distFactor);
    
    return sssContribution;
}