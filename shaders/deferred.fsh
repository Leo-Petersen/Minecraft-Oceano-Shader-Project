#version 130

#include "/lib/voxel_settings.glsl"
#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform sampler2D colortex0; // .rgb = color
uniform sampler2D colortex1; // .stp = VIEWNormal
uniform sampler2D colortex2; // .s = torchLightMap, .t = skyLightMap, .p = material
uniform sampler2D colortex3;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex13;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform sampler2D noisetex;
uniform sampler2D specular;

uniform sampler3D floodfillSampler;
uniform sampler3D floodfillSamplerCopy;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float near, far;
uniform float nightVision;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float viewHeight, viewWidth;
uniform float aspectRatio;
uniform float wetness;
uniform float blindness;
uniform float PI;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform ivec2 eyeBrightnessSmooth;

varying vec2 texcoord;
varying vec2 lmcoord;

varying vec3 upVec;
varying vec3 Normal;


#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/lighting.glsl"
#include "/lib/brdf.glsl"
#include "/lib/raytrace.glsl"
#include "/lib/handlight.glsl"

const vec3 voxelVolumeSize = vec3(VOXEL_VOLUME_SIZE, VOXEL_VOLUME_SIZE * 0.5, VOXEL_VOLUME_SIZE);

vec3 worldToVoxelUV(vec3 worldPos) {
    vec3 voxelPos = worldPos + fract(cameraPosition) + voxelVolumeSize * 0.5;
    return voxelPos / voxelVolumeSize;
}

float undergroundFix = clamp(mix(max(lmcoord.t - 2.0 / 16.0, 0.0) * 1.14285714286, 1.0, clamp((eyeBrightnessSmooth.y / 255.0 - 2.0 / 16.0) * 4.0, 0.0, 1.0)), 0.0, 1.0);

float transparencyFactor =  0.5 * (time[0]) +
                            0.9 * (time[1]) +
                            0.9 * (time[2]) +
                            0.9 * (time[3]) +
                            0.5 * (time[4]) +
                            0.3 * (time[5]);

float shadowFactor =  0.55 * (time[0]) +
                      1.0 * (time[1]) +
                      1.0 * (time[2]) +
                      1.0 * (time[3]) +
                      0.55 * (time[4]) +
                      0.4 * (time[5]);

float torchFactor =   1.00 * (time[0]) +
                      0.33 * (time[1]) +
                      0.33 * (time[2]) +
                      0.33 * (time[3]) +
                      1.00 * (time[4]) +
                      1.00 * (time[5]);

// Fixes bounce light being too strong at sunrise/sunset
float bounceDesaturation = 0.9 * (time[0]) +
                           0.0 * (time[1]) +
                           0.0 * (time[2]) +
                           0.0 * (time[3]) +
                           0.9 * (time[4]) +
                           0.7 * (time[5]);

void main() {
    // Early out for sky pixels
    if (Depth >= 1.0) {
        vec3 color = texture2D(colortex0, texcoord).rgb;
        /* DRAWBUFFERS:04 */
        gl_FragData[0] = vec4(color, 1.0);
        gl_FragData[1] = vec4(0.0);
        return;
    }

    vec3 color = texture2D(colortex0, texcoord).rgb;
    vec3 albedo = color;

    //// Materials ////
    vec4 colortex2Map = texture2D(colortex2, texcoord); // .s = torchLightMap, .t = skyLightMap, .p = material
    vec4 colortex1Map = texture2D(colortex1, texcoord); // .rg = ViewNormal, ba = specular/roughness
    float material = colortex2Map.p;
    float isglass = float(material > 0.10 && material < 0.12);
    float parallaxShadow = colortex2Map.a;
    float iswater = float(material > 0.08 && material < 0.10);
    
    vec4 extraData = texture2D(colortex13, texcoord);
    float emission = extraData.r;
    float textureAO = extraData.b;
    float sssAmount = extraData.a;

    //// Setup LightMap ////
    vec2 lightMap = colortex2Map.st;
    float rawSkyLight = lightMap.t;
         lightMap.t = clamp(lightMap.t, ((1.0 - nightVision) * min_skyLightMap) + (0.5 * nightVision), 1.0);
         lightMap.t = pow(lightMap.t * (1.0 - darknessLightFactor), 0.5);

    vec3 normal = normalize(decodeNormal(colortex1Map.xy));

    vec4 screenPos = vec4(texcoord, texture2D(depthtex0, texcoord).r, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
    float NdotL = max(dot(normal, normalize(shadowLightPosition)), 0.0);
    vec3 shadowWorldPos = worldPos + worldNormal * 0.04 * (1.0 - NdotL);

    float distFactor = length(worldPos.xz) / 120.0;
          distFactor = pow(distFactor, 2.2);
          distFactor = 1.0 - exp(-1.2 * distFactor);

    vec3 skyBoxCol = texture2D(colortex9, texcoord.st).rgb;

	vec2 specularMap = colortex1Map.ba;
    float roughness = clamp(1.0 - specularMap.r, 0.01, 0.99);
    vec3 reflectedskyBoxCol = texture2D(colortex8, texcoord).rgb;
    
    float Diffuse = calculateDiffuse(shadowLightPosition * 0.01, normalize(-viewPos.xyz), normal, roughness);

    //// Calculate LightMap Colour and Values ////
    float ao = 1.0;
    #ifdef AO
        ao = ambientOcclusion(depthtex1);
    #endif

    float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
    float handlight = clamp(((heldLightValue * 1.2) - 1.5 * length(viewPos.xyz)) / 18.0, 0.0, 0.9333);

    // Colored hand light
    vec3 handLightColor = vec3(0.0);
    if (heldBlockLightValue > 0) {
        vec3 col = getBlocklightColor(heldItemId);
        if (length(col) > 0.001) handLightColor = col;
    }
    if (heldBlockLightValue2 > 0) {
        vec3 col2 = getBlocklightColor(heldItemId2);
        if (length(col2) > 0.001) handLightColor = max(handLightColor, col2);
    }

    lightMap.s *= (1.0 - darknessLightFactor * 0.5);

    float originalBlockLight = lightMap.s;
    float torchTimeBlend = mix(1.0, torchFactor, rawSkyLight);
    float torchmapLight = max(lightMap.s, handlight) * lightMap.t * torchTimeBlend;
    float torchmapCovered = max(lightMap.s, handlight) * (1.0 - lightMap.t);
    lightMap.s = (torchmapLight * pow(ao, 0.24) * 0.5) + torchmapCovered;
    
    // Torch intensity
    float torchIntensity = lightMap.s * lightMap.s * 3.2;
    
    // Default torch color
    vec3 torchColorBase = vec3(torchR, torchG, torchB) / 255.0;
    vec3 torchColorWarm = torchColorBase * vec3(1.0, 0.7, 0.4);
    vec3 defaultTorchColor = mix(torchColorWarm, torchColorBase, lightMap.s);

    //// Voxel Lighting ////
    vec3 voxelColor = vec3(0.0);
    float voxelStrength = 0.0;
    float voxelBlend = 0.0;
    
    #ifdef VoxelLighting
        vec3 samplePos = worldPos + worldNormal * 0.5;
        vec3 voxelUV = worldToVoxelUV(samplePos);
        
        if (all(greaterThan(voxelUV, vec3(0.01))) && all(lessThan(voxelUV, vec3(0.99)))) {
            vec3 lightVolume;
            if ((frameCounter & 1) == 0) {
                lightVolume = texture3D(floodfillSamplerCopy, voxelUV).rgb;
            } else {
                lightVolume = texture3D(floodfillSampler, voxelUV).rgb;
            }
            
            // Convert from compressed to linear
            vec3 voxelLight = pow(lightVolume, vec3(1.0 / FLOODFILL_RADIUS));
            voxelStrength = length(voxelLight);
            
            // Normalize to get just the color
            if (voxelStrength > 0.001) {
                voxelColor = voxelLight / voxelStrength;
            }
            
            // Edge fade
            vec3 edgeDist = min(voxelUV, 1.0 - voxelUV);
            float edgeFade = smoothstep(0.0, 0.1, min(min(edgeDist.x, edgeDist.y), edgeDist.z));
            
            voxelBlend = clamp(voxelStrength * FLOODFILL_BRIGHTNESS, 0.0, 1.0) * edgeFade;
        }
    #endif
    
    // When hand light dominates, use its color; otherwise use voxel/default
    vec3 voxelOrDefault = mix(defaultTorchColor, voxelColor * 2.0, voxelBlend);
    vec3 handColor = (length(handLightColor) > 0.001) ? handLightColor : defaultTorchColor;

    float totalWeight = originalBlockLight + handlight + 0.001;
    vec3 finalBlockLightColor = (voxelOrDefault * originalBlockLight + handColor * handlight) / totalWeight;
    vec3 torchTotal = finalBlockLightColor * torchIntensity * color;

    //// Setup Shadow Filter ////
    vec4 shadowCoord = ShadowSpace(shadowWorldPos);
    shadowCoord.xy *= distort(shadowCoord.xy);
    shadowCoord.z /= 6.0;

    vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;

    // Interleaved gradient noise
    float IGN = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    #ifdef TAA
        float temporalOffset = float(frameCounter % 8) / 8.0;
        IGN = fract(IGN + temporalOffset);
    #endif

    float angle = IGN * 6.28318530718; // full rotation

    //// Shadow Sampling ////
    vec3 ShadowAccum = vec3(0.0);

    #ifdef shadowMap
        float filterSize = 0.0025 * filterStr * (1.0 + rainStrength * 2.0);

        #ifdef BounceColoredLight
            vec3 flux = vec3(0.0);
            float fluxRadius = 0.08;
            float validSamples = 0.0;
        #else
            vec3 flux = vec3(0.4);
        #endif
        
        float sinAngle = sin(angle);
        float cosAngle = cos(angle);

        // Golden angle rotation matrix
        const float goldenAngle = 2.39996323;
        float goldenCos = cos(goldenAngle);
        float goldenSin = sin(goldenAngle);
        
        // Initial direction from IGN noise rotation
        vec2 dir = vec2(cosAngle, sinAngle);

        float shadowBias = getShadowBias(SampleCoords);

        for (int i = 0; i < lightingQuality; i++) {
            float radius = sqrt((float(i) + 0.5) / float(lightingQuality));
            vec2 offset = dir * radius;
            
            ShadowAccum += TransparentShadowHardware(vec3(SampleCoords.xy + offset * filterSize, SampleCoords.z), transparencyFactor, shadowBias);
            
            #ifdef BounceColoredLight
            if ((i & 1) == 0) {
                vec2 fluxCoord = SampleCoords.xy + offset * fluxRadius;
                if (fluxCoord.x >= 0.0 && fluxCoord.x <= 1.0 && 
                    fluxCoord.y >= 0.0 && fluxCoord.y <= 1.0) {
                    vec4 fluxSample = texture2D(shadowcolor0, fluxCoord);
                    flux += fluxSample.rgb * (1.0 - fluxSample.a);
                    validSamples += 1.0;
                }
            }
            #endif
            
            // Rotate direction by golden angle for next sample
            dir = vec2(
                dir.x * goldenCos - dir.y * goldenSin,
                dir.x * goldenSin + dir.y * goldenCos
            );
        }

        //// Process Shadow Results ////
        ShadowAccum /= float(lightingQuality);
        ShadowAccum *= parallaxShadow;
        //ShadowAccum = mix(ShadowAccum, vec3(1.0), emission * 0.8);
    #else
        ShadowAccum = sunlightCol;
        vec3 flux = vec3(0.4);
    #endif

    float shadowLum = dot(ShadowAccum, vec3(0.2126, 0.7152, 0.0722));
    vec3 invShadowAccum = clamp(-ShadowAccum * Diffuse + vec3(0.4), vec3(0.0), vec3(1.0));

    //// Process Flux / Bounce Light ////
    #ifdef shadowMap
        #ifdef BounceColoredLight
            flux = (validSamples > 0.0) ? flux / validSamples : vec3(0.4);
        #endif
    #endif
    
    flux = max(flux, vec3(0.0001));
    flux *= (1.0 - rainStrength * 0.88);
    flux /= dot(vec3(0.2126, 0.7152, 0.0722), flux);
    if (Depth < 0.56) flux /= dot(vec3(0.2126, 0.7152, 0.0722), flux) + rainStrength * 0.5;

    vec3 bounceLight = backLight(flux);
    bounceLight = mix(shadowCol, bounceLight, dot(vec3(0.2126, 0.7152, 0.0722), flux) + 0.5);
    bounceLight *= 0.55;
    float bounceLum = dot(bounceLight, vec3(0.2126, 0.7152, 0.0722));
          bounceLight = mix(bounceLight, vec3(bounceLum), mix(bounceDesaturation, 0.9, rainStrength)); // Fixes bounce light being too strong at sunrise / sunset

    float undergroundBlend = smoothstep(0.0, 1.0, pow(rawSkyLight, 0.5));

    #ifdef skyLightMap
        bounceLight = mix(ambientShadowColor, bounceLight, undergroundBlend);
    #endif

    //// Rain Shadow Strength ////
    // Currently redundant legacy code
    #ifdef disableRainShadows
        float rainShadowStr = 24.0;
    #else
        float rainShadowStr = 0.2;
    #endif

    //// Setup Ambient ////
    #ifdef shadowMap
        #ifdef fakecloudshadow
            float fakeCloudShadow = mix(1.0, fakeCloudShadow(worldPos), distFactor * (1.0 - rainStrength));
        #else
            float fakeCloudShadow = 1.0;
        #endif
        float ambientStrength = ambientStr * 0.1142;
    #else
        float ambientStrength = 0.03;
        ShadowAccum = vec3(0.5);
    #endif
    
    //// Apply Lighting ////
    #ifdef shadowMap 
        vec3 ambientCol = bounceLight * (1.0 - rainStrength * rainShadowStr);
        float lightStrength = lightStr * 11.2 * (1.0 - darknessFactor * 0.9) * fakeCloudShadow * transitionFade * pow(ao, 0.21);

        // Material flags
        float isGrass = float(material > 0.025 && material < 0.04);
        bool isFoliage = (material > 0.005 && material < 0.02);

        // Direct sunlight
        vec3 finalShadow = sunlightCol * Diffuse * ShadowAccum * lightMap.t * lightStrength * (1.0 - rainStrength * 0.65);
        finalShadow *= mix(1.0, 0.8, distFactor); // Reduce direct light on distant terrain to balance with fog and prevent harsh edges

        // Bounce mask, restrict bounce light to shadowed areas
        float bounceMask = 1.0 - smoothstep(0.0, 0.25, shadowLum * max(Diffuse, 0.0));
        bounceMask *= bounceMask * transitionFade;

        // Ambient components
        float ambientShadowFactorFixed = mix(0.5, shadowFactor, undergroundBlend);
        vec3 flatAmbient = pow(shadowCol, vec3(0.3)) * (1.0 - rainStrength * 0.2) * undergroundBlend;
        vec3 shadowAmbient = shadowCol * 3.0 * invShadowAccum * (1.0 - rainStrength * 0.7) * undergroundBlend;
        vec3 baseAmbient = mix(flatAmbient, shadowAmbient, transitionFade);
        vec3 bounceAmbient = ambientStrength * ambientCol * ambientShadowFactorFixed * (1.0 - rainStrength * 0.14) * bounceMask;

        vec3 finalAmbient = (baseAmbient + bounceAmbient) * 0.25 * pow(ao, 0.2) * textureAO;

        // Distance shadow transition (fade out of fake bouncelighting)
        float distShadowDiffuse = mix(Diffuse, 1.0, isGrass); //Remove diffuse on grass with distance, not 'correct' but looks like artifacting otherwise
        float distShadowMask = 1.0 - smoothstep(0.0, 0.1, shadowLum * distShadowDiffuse * transitionFade); //Using the full diffuse at distance makes distain terrain look too harsh, this achieves a good middle ground
        finalAmbient = mix(finalAmbient, mix(finalAmbient, shadowDistColor * 2.5, distShadowMask), distFactor * undergroundBlend);

        // Underground ambient
        finalAmbient += vec3(0.025, 0.028, 0.035) * (1.0 - undergroundBlend) * pow(ao, 0.42) * textureAO * 5.0;

        // Subsurface scattering
        #ifdef shadowMap
            if ((isFoliage || isGrass > 0.0) && sssAmount > 0.01) {
                // View/Light directions
                vec3 viewDir = normalize(-viewPos.xyz);
                vec3 lightDir = shadowLightPosition * 0.01;
                float VdotL = dot(viewDir, lightDir);
                float NdotL = dot(normal, lightDir);

                // SSS parameters
                float sssScale = isFoliage ? 1.5 : 1.0;
                float uniformity = isFoliage ? 0.5 : 1.5;
                
                vec3 sssContribution = calculateSSS(
                    SampleCoords, color, sunlightCol,
                    sssAmount * sssScale,
                    VdotL, NdotL, lightMap.t,
                    distFactor, IGN, uniformity
                );
                finalShadow += sssContribution * lightStrength * undergroundFix * (1.0 - time[5] * 0.2);
            }
        #endif
        
        // PBR Specular
        vec3 specularBRDF = cookTorranceGGXBRDF(color, specularMap, lightMap.t, sunlightCol);
        specularBRDF *= ShadowAccum * lightMap.t * lightStrength * (1.0 - rainStrength * 0.65) * transitionFade;
        //specularBRDF *= mix(1.0, 0.8, distFactor);

        // Combine lighting
        color *= (finalShadow + finalAmbient);

        // Add specular on top of lit surface
        color += specularBRDF;

        // Emission
        #ifdef materialEmission
            float darkness = 1.0 - (lightMap.t + pow(lightMap.s, 1.5));
            float emissionStr = pow(darkness, 3.0);
            color += albedo * emission * emissionStr * emissionStrength;
        #endif
    #else
        float lightStrength = lightStr;
        vec3 ambientCol = bounceLight * (1.0 - rainStrength * rainShadowStr);
             color *= Diffuse * ShadowAccum * clamp(pow(lightMap.t, 4.0), 0.24, 1.0) * lightStrength * (1.0 - rainStrength * 0.2) + ambientStrength * ambientCol;
    #endif

    #ifdef skyLightMap
        color *= lightMap.t;
    #endif

    //// Block Light ////
    #ifdef torchLightMap
        color += torchTotal * textureAO;
    #endif

    //// Eye-in-water Fog ////
    if (isEyeInWater == 1) {
        float fogDepth = 1.0 - exp(-11.3 * length(worldPos.xz) / 100.0);
        color.rgb = mix(color.rgb, vec3(0.0, 0.36, 0.51) * 0.05 * (1.0 - time[5] * 0.64) * (1.0 - rainStrength), fogDepth);
    }

    //// Lava + Powdered Snow Fog ////
    float blockFog = clamp(pow(length(worldPos.xz) / 5.0, 0.5), 0.0, 1.0);
    if (isEyeInWater == 2) color.rgb = mix(color.rgb, vec3(1.0, 0.15, 0.0), blockFog);
    if (isEyeInWater == 3) color.rgb = mix(color.rgb, vec3(0.5, 0.6, 0.8), blockFog * 2.0);

/* DRAWBUFFERS:04 */
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(vec3(0.0), Diffuse * ShadowAccum);
}
