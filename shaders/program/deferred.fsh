
#include "/lib/voxel_settings.glsl"
#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

// for Material Reflections
// colortex4: .rgb = reflection environment, .a = packed albedo
#ifdef materialReflections
/*
const int colortex4Format = RGBA32F;
*/
#endif

uniform sampler2D colortex0; // .rgb = color
uniform sampler2D colortex1; // .stp = VIEWNormal
uniform sampler2D colortex2; // .s = torchLightMap, .t = skyLightMap, .p = material
uniform sampler2D colortex9;
uniform sampler2D colortex13;
uniform sampler2D colortex14;  // transmittance + multiscatter LUT
uniform sampler2D colortex15;  // sky-view LUT

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

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

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
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform ivec2 eyeBrightnessSmooth;

varying vec2 texcoord;
varying vec2 lmcoord;

varying vec3 upVec;
varying vec3 Normal;

#define atmosphereSun

vec3 atmSunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec3 atmSunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);

#include "/lib/time.glsl"
#include "/lib/atmosphereLUT.glsl"
vec3 atmSun = atmSunColor(colortex14, vec2(viewWidth, viewHeight), atmSunTrue);
vec3 atmAmb = atmSkyAmbient(colortex15, vec2(viewWidth, viewHeight), atmSunTrue);
#include "/lib/lightCol.glsl"
#include "/lib/lighting.glsl"
#include "/lib/brdf.glsl"
#include "/lib/handlight.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/caustics.glsl"
#include "/lib/dh.glsl"

const vec3 voxelVolumeSize = vec3(voxelVolumeRes, voxelVolumeRes * 0.5, voxelVolumeRes);

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

float shadowFactor =  0.75 * (time[0]) +
                      0.90 * (time[1]) +
                      0.90 * (time[2]) +
                      0.90 * (time[3]) +
                      0.75 * (time[4]) +
                      0.25 * (time[5]);

#if defined NETHER || defined END
    float torchFactor = 1.0;   // no daylight
#else
    float torchFactor = mix(1.0, 0.33, smoothstep(-0.05, 0.12, atmSunTrue.y));
#endif

float causticTimeFactor =  0.6 * (time[0]) +
                           1.0 * (time[1]) +
                           1.0 * (time[2]) +
                           1.0 * (time[3]) +
                           0.6 * (time[4]) +
                           0.7 * (time[5]);

void main() {
    // Early out for sky pixels
    if (isSky(texcoord, Depth)) {
        vec3 color = texture2D(colortex0, texcoord).rgb;
        #ifdef materialReflections
        /* DRAWBUFFERS:04 */
        gl_FragData[0] = vec4(color, 1.0);
        gl_FragData[1] = vec4(0.0);
        #else
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(color, 1.0);
        #endif
        return;
    }

    vec3 color = texture2D(colortex0, texcoord).rgb;
    vec3 albedo = color;

    //// Materials ////
    vec4 colortex2Map = texture2D(colortex2, texcoord); // .s = torchLightMap, .t = skyLightMap, .p = material
    vec4 colortex1Map = texture2D(colortex1, texcoord); // .rg = ViewNormal, ba = specular/roughness
    float material = colortex2Map.p;
    float isglass = float(material > 0.10 && material < 0.12);
    // FORMAT: colortex2.a = parallax self shadow (high 4 bits) + sunk depth (low 4 bits, inverted)
    float parallaxPacked    = floor(colortex2Map.a * 255.0 + 0.5);
    float parallaxShadow    = floor(parallaxPacked / 16.0) / 15.0;
    float parallaxSunkDepth = (15.0 - mod(parallaxPacked, 16.0)) / 15.0 * parallaxDepth;
    float iswater = float(material > 0.08 && material < 0.10);
    bool isHand = material > 0.96 && material < 0.98;
    
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

    bool fromDH;
    vec4 viewPos = vec4(reconstructViewPos(texcoord, Depth, fromDH), 1.0);
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
    float NdotL = max(dot(normal, normalize(shadowLightPosition)), 0.0);

    vec3 pomShadowOffset = vec3(0.0);
    vec3 pomDpx = dFdx(worldPos), pomDpy = dFdy(worldPos);   // outside any branch
    #ifdef Parallax
    if (parallaxSunkDepth > 0.0) {
        vec3 gN = cross(pomDpx, pomDpy);                      // geometric face normal, snapped to the block axis
        vec3 aN = abs(gN);
        gN = (aN.x > aN.y && aN.x > aN.z) ? vec3(sign(gN.x), 0.0, 0.0) : ((aN.y > aN.z) ? vec3(0.0, sign(gN.y), 0.0) : vec3(0.0, 0.0, sign(gN.z)));
        vec3 Vw = mat3(gbufferModelViewInverse) * normalize(viewPos.xyz);
        if (dot(gN, Vw) > 0.0) gN = -gN;
        vec3 Lw = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);
        float NdV = max(-dot(gN, Vw), 0.02);
        float NdL = dot(gN, Lw);
        if (NdL > 0.05) pomShadowOffset = Vw * (parallaxSunkDepth / NdV) + Lw * (parallaxSunkDepth / NdL);
    }
    #endif
    vec3 shadowBasePos = worldPos + pomShadowOffset;
    #ifdef PixelLockedShadows
        vec3 snapSrcPos = worldPos;
        #ifdef TAA
        if (!fromDH) {
            const vec2 taaJitterSeq[8] = vec2[8](
                vec2( 0.5,  -0.333333), vec2(-0.25,  0.333333),
                vec2( 0.75,  0.111111), vec2( 0.125, -0.777778),
                vec2(-0.375, 0.555556), vec2( 0.625, -0.111111),
                vec2(-0.125, 0.777778), vec2( 0.875, -0.555556));
            vec2 uvJitter = 0.5 * taaJitterSeq[frameCounter & 7] / vec2(viewWidth, viewHeight);

            bool dhUnused;
            vec3 viewUnjit = reconstructViewPos(texcoord - uvJitter, Depth, dhUnused);
            snapSrcPos = mat3(gbufferModelViewInverse) * viewUnjit + gbufferModelViewInverse[3].xyz;
        }
        #endif
        shadowBasePos = snapShadowPos(snapSrcPos + pomShadowOffset);
    #endif
    vec3 shadowWorldPos = shadowBasePos + worldNormal * 0.04 * (1.0 - NdotL);

    float distNorm = 120.0;
    #ifdef DISTANT_HORIZONS
        distNorm = max(120.0, dhRenderDistance * 0.5);
    #endif
    float clouddistFactor = length(worldPos.xz) / far;
          clouddistFactor = pow(clouddistFactor, 2.2);
          clouddistFactor = 1.0 - exp(-0.24 * clouddistFactor);
    float distFactor = length(worldPos.xz) / distNorm;
          distFactor = pow(distFactor, 2.2);
          distFactor = 1.0 - exp(-1.2 * distFactor);

    vec3 skyBoxCol = texture2D(colortex9, texcoord.st).rgb;

	vec2 specularMap = colortex1Map.ba;
    vec3 openAmbient = vec3(0.0);   // ambient an unoccluded surface gets
    vec3 diffuseLight = vec3(0.0);  // light arriving at the surface

    // LabPBR metals have no diffuse
    float isMetal = 0.0;
    #if defined materialReflections && defined hardcodedMetals
        // material > 0, entities, particles etc
        isMetal = float(specularMap.g * 255.0 > 229.5 && material > 0.0);
    #endif
    float diffuseWeight = mix(1.0, metalDiffuse, isMetal);
    float roughness = clamp(1.0 - specularMap.r, 0.01, 0.99);
    
    float Diffuse = calculateDiffuse(shadowLightPosition * 0.01, normalize(-viewPos.xyz), normal, roughness);

    //// Calculate LightMap Colour and Values ////
    float ao = 1.0;
    #ifdef AO
        ao = ambientOcclusion(depthtex1);
        ao = pow(ao, aoStrength);
    #endif
    #ifdef DISTANT_HORIZONS
        if (fromDH) ao = 1.0;
    #endif
   
    float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
    #if defined NETHER
        float handlight = clamp(((heldLightValue * 1.2) - 1.5 * length(viewPos.xyz)) / 18.0, 0.0, 0.9333);
    #else
        float handlight = clamp(((heldLightValue * 1.2) - 2.0 * length(viewPos.xyz)) / 18.0, 0.0, 0.9333);
    #endif

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
    #if defined NETHER
        lightMap.s = max(pow(lightMap.s, 1.8), handlight);
        float torchIntensity = lightMap.s * lightMap.s * 5.2;
    #elif defined END
        float torchmapLight = max(lightMap.s, handlight) * lightMap.t * torchTimeBlend;
        float torchmapCovered = max(lightMap.s, handlight) * (1.0 - lightMap.t);
        lightMap.s = (torchmapLight * pow(ao, 0.3) * 0.5) + torchmapCovered;

        float torchIntensity = lightMap.s * lightMap.s * 2.2;
    #else
        float torchmapLight = max(lightMap.s, handlight) * lightMap.t * torchTimeBlend;
        float torchmapCovered = max(lightMap.s, handlight) * (1.0 - lightMap.t);
        lightMap.s = (torchmapLight * pow(ao, 0.3) * 0.5) + torchmapCovered;

        float torchIntensity = lightMap.s * lightMap.s * 3.2;
    #endif
    
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
            vec3 voxelLight = pow(lightVolume, vec3(1.0 / floodfillRadius));
            voxelStrength = length(voxelLight);
            
            // Normalize to get just the color
            if (voxelStrength > 0.001) {
                voxelColor = voxelLight / voxelStrength;
            }
            
            // Edge fade
            vec3 edgeDist = min(voxelUV, 1.0 - voxelUV);
            float edgeFade = smoothstep(0.0, 0.1, min(min(edgeDist.x, edgeDist.y), edgeDist.z));
            
            voxelBlend = clamp(voxelStrength * floodfillBrightness, 0.0, 1.0) * edgeFade;
        }
    #else
        defaultTorchColor *= 1.5;
    #endif
    
    // When hand light dominates, use its color; otherwise use voxel/default
    vec3 voxelFallback = torchColorBase;
    vec3 voxelOrDefault = mix(voxelFallback, voxelColor * 2.0, voxelBlend);
    vec3 handColor = (length(handLightColor) > 0.001) ? handLightColor : defaultTorchColor;

    float totalWeight = originalBlockLight + handlight + 0.001;
    vec3 finalBlockLightColor = (voxelOrDefault * originalBlockLight + handColor * handlight) / totalWeight;
    vec3 torchTotal = finalBlockLightColor * torchIntensity * color;

    //// Setup Shadow Filter ////
    vec4 shadowCoord = ShadowSpace(shadowWorldPos);
    shadowCoord.xy *= distort(shadowCoord.xy);
    shadowCoord.z /= 6.0;

    float shadowCoverage = 1.0;
    #ifdef DISTANT_HORIZONS
        float shadowEdge = shadowDistance - 8.0;    // fade a bit before the hard edge
        shadowCoverage = 1.0 - smoothstep(shadowEdge - 12.0, shadowEdge, length(worldPos.xz));
    #endif

    vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;

    // Interleaved gradient noise
    float IGN = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    #ifdef TAA
        float temporalOffset = float(frameCounter % 8) / 8.0;
        IGN = fract(IGN + temporalOffset);
    #endif

    float angle = IGN * 6.28318530718; // full rotation

    #ifdef PixelLockedShadows
        angle = 0.0;
    #endif

    //// Shadow Sampling ////
    vec3 ShadowAccum = vec3(0.0);

    vec3 flux = vec3(0.4);
    float fluxRadius = 0.08;
    float validSamples = 0.0;

    #ifdef BounceLight
        flux = vec3(0.0);
    #endif

    #ifdef shadowMap
    #ifdef DISTANT_HORIZONS
    if (fromDH) {
        float dhSh = 0.0;
        if (Diffuse > 0.001) {
            dhSh = GetDHShadow(viewPos.xyz, normalize(shadowLightPosition), IGN);
            dhSh *= fakeCloudShadow(worldPos, clouddistFactor);
        }
        ShadowAccum = mix(vec3(0.0), sunlightCol*Diffuse*transitionFade*4*mix(1.0, 0.85, distFactor), dhSh);
    } else
    #endif
    {

        float filterSize = 0.0025 * filterStr * (1.0 + rainT * 1.2);

        float sinAngle = sin(angle);
        float cosAngle = cos(angle);

        const float goldenAngle = 2.39996323;
        float goldenCos = cos(goldenAngle);
        float goldenSin = sin(goldenAngle);

        vec2 dir = vec2(cosAngle, sinAngle);

        float shadowBias = getShadowBias(SampleCoords);

        for (int i = 0; i < lightingQuality; i++) {
            float radius = sqrt((float(i) + 0.5) / float(lightingQuality));
            vec2 offset = dir * radius;

            ShadowAccum += TransparentShadowHardware(vec3(SampleCoords.xy + offset * filterSize, SampleCoords.z), transparencyFactor, shadowBias);

            dir = vec2(
                dir.x * goldenCos - dir.y * goldenSin,
                dir.x * goldenSin + dir.y * goldenCos
            );
        }

        ShadowAccum /= float(lightingQuality);
        ShadowAccum *= parallaxShadow;
        #ifdef DISTANT_HORIZONS
        if (shadowCoverage < 0.999) {
            float dhSh = 0.0;
            if (Diffuse > 0.001) {
                dhSh = GetDHShadow(viewPos.xyz, normalize(shadowLightPosition), IGN);
                dhSh *= fakeCloudShadow(worldPos, clouddistFactor);
            }
            //vec3 dhShadowVal = mix(shadowDistColor, sunlightCol * Diffuse * transitionFade * 5.0, dhSh);
            vec3 dhShadowVal = mix(vec3(0.0), sunlightCol * Diffuse * transitionFade * 5.0, dhSh);
            // Blend from map shadow to DH trace
            ShadowAccum = mix(dhShadowVal, ShadowAccum, shadowCoverage);
        } else {
            ShadowAccum = mix(sunlightCol, ShadowAccum, shadowCoverage);
        }
        #else
        ShadowAccum = mix(sunlightCol, ShadowAccum, shadowCoverage);
        #endif
    }
    #else
        ShadowAccum = sunlightCol;
    #endif

    #ifdef shadowMap
        // Held items, unshadowed
        // if (isHand) ShadowAccum = sunlightCol * parallaxShadow;
    #endif

    float shadowLum = dot(ShadowAccum, vec3(0.2126, 0.7152, 0.0722));
    vec3 invShadowAccum = clamp(-ShadowAccum * Diffuse + vec3(0.4), vec3(0.0), vec3(1.0));


    //// Process Flux / Bounce Light ////
    #ifdef shadowMap
        #ifdef BounceLight
            vec3 c = vec3(0.0);
            float ang = fract(sin(dot(SampleCoords.xy, vec2(12.9898, 78.233))) * 43758.5) * 6.2831;
            vec2 d = vec2(cos(ang), sin(ang));
            const float g = 2.39996323;
            for (int i = 0; i < 3; i++) {
                float r = sqrt((float(i) + 0.5) / 3.0) * 0.08;
                c += texture2D(shadowcolor0, SampleCoords.xy + d * r).rgb;
                d = vec2(d.x * cos(g) - d.y * sin(g), d.x * sin(g) + d.y * cos(g));
            }
            flux = c / 3.0;
        #endif
    #endif

    const vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);

    flux  = max(flux, vec3(0.0001));
    #if defined NETHER || defined END
        flux *= (1.0 - rainStrength * 0.88);
    #endif
    flux /= dot(lumaWeights, flux);
    #if defined NETHER || defined END
        if (Depth < 0.56) flux /= dot(lumaWeights, flux) + rainStrength * 0.5;
    #endif

    vec3 bounceLight = backLight(flux);
    bounceLight = mix(shadowCol, bounceLight, dot(lumaWeights, flux) + 0.5);
    bounceLight *= 0.55 * BounceLightStr;

    float bounceLum = dot(bounceLight, lumaWeights);
    #if defined NETHER || defined END
       // bounceLight = mix(bounceLight, vec3(bounceLum), 0.9);
    #else
        bounceLight = mix(bounceLight, vec3(bounceLum), time[5]);

        float bounceNight = smoothstep(-0.08, 0.0, atmSunTrue.y);
        float bounceRain  = 1.0 - rainStrength;
        bounceLight *= bounceNight * bounceRain;
    #endif

    float undergroundBlend = smoothstep(0.0, 1.0, pow(rawSkyLight, 0.5));

    #ifdef skyLightMap
        bounceLight = mix(ambientShadowColor, bounceLight, undergroundBlend);
    #endif

    //// Setup Ambient ////
    #if defined shadowMap && defined END
        float ambientStrength = ambientStr * 0.02;
    #elif defined shadowMap
        float ambientStrength = ambientStr * 0.09;
    #elif defined NETHER
        float ambientStrength = 0.14 * pow(ao, 0.42);
        ShadowAccum = vec3(0.5);
    #else
        float ambientStrength = 0.034 * pow(ao, 0.42);
        ShadowAccum = vec3(0.5);
    #endif

    //// Apply Lighting ////
    #ifdef shadowMap 
        vec3 ambientCol = bounceLight;
        #if defined END
            float lightStrength = lightStr * 8 * (1.0 - darknessFactor * 0.9) * transitionFade * pow(ao, 0.2);
        #else
            float lightStrength = lightStr * 11 * (1.0 - darknessFactor * 0.9) * transitionFade * pow(ao, 0.2);
        #endif

        // Material flags
        float isGrass = float(material > 0.025 && material < 0.04);
        bool isFoliage = (material > 0.005 && material < 0.02);

        if (isGrass == 1) Diffuse = mix(Diffuse, 0.3, distFactor);

        // a single infinite term turns 0 * inf into NaN, which renders black, SSS and specular are skipped instead. (fixes flashing black artifacts at sun/moon transition)
        bool directLit = lightStrength > 0.0;
        vec3 directBeam = directLit ? sunlightCol * Diffuse * ShadowAccum * lightMap.t * lightStrength * max(0.14, rainDirect) : vec3(0.0);
             directBeam *= mix(1.0, 0.9, distFactor); // Reduce direct light on distant terrain to balance with fog and prevent harsh edges

        vec3 finalShadow = directBeam;

        // Bounce mask, restrict bounce light to shadowed areas
        float bounceMask = 1.0 - smoothstep(0.0, 0.25, shadowLum * max(Diffuse, 0.0));
        bounceMask *= bounceMask * transitionFade;

        // Ambient components
        float ambientShadowFactor = mix(0.5, shadowFactor, undergroundBlend);
        vec3 flatAmbient   = pow(shadowCol, vec3(0.3)) * (1.0 - rainStrength * 0.2) * undergroundBlend;
        vec3 shadowAmbient = shadowCol * 3.0 * invShadowAccum * (1.0 - rainStrength * 0.7) * undergroundBlend;
        vec3 baseAmbient   = mix(flatAmbient, shadowAmbient, transitionFade);
        vec3 bounceAmbient = ambientStrength * ambientCol * ambientShadowFactor * bounceMask;

        // Sky/moon ambient
        vec3 nightAmbient = ambientShadowColor * 2.0 * atmNight * undergroundBlend;

        vec3 finalAmbient = (baseAmbient + bounceAmbient + nightAmbient) * 0.25 * pow(ao, 0.42) * textureAO;

        // Distance shadow transition (fade out of fake bouncelighting)
        //float distShadowDiffuse = mix(Diffuse, 1.0, isGrass); //Remove diffuse on grass with distance, not 'correct' but looks like artifacting otherwise
        finalAmbient = mix(finalAmbient, finalAmbient*distAmbient, distFactor * undergroundBlend);

        const float overcastStrength = 0.70;
        vec3 flatRain = rainAmbient * overcastStrength * lightMap.t * pow(ao, 0.42) * textureAO * undergroundBlend;
        finalAmbient = mix(finalAmbient, flatRain, rainScatter);

        // Underground ambient
        finalAmbient += vec3(0.025, 0.028, 0.035) * (1.0 - undergroundBlend) * pow(ao, 0.2) * textureAO * 5.0;

        // Subsurface scattering
        #ifdef shadowMap
            #ifdef SubsurfaceScattering
            if (directLit && sssAmount > 0.01 && iswater < 0.5 && isglass < 0.5 && material > 0.001 && !isHand) {
                vec3 viewDir  = normalize(-viewPos.xyz);
                vec3 lightDir = shadowLightPosition * 0.01;
                float VdotL   = dot(viewDir, lightDir);
                float NdotLs  = dot(normal, lightDir);

                vec3 sssContribution = vec3(0.0);

                #ifdef DISTANT_HORIZONS
                float sssCoverage = fromDH ? 0.0 : shadowCoverage;
                #else
                float sssCoverage = 1.0;
                #endif

                if (sssCoverage > 0.001) {
                    sssContribution = calculateSSS(worldPos, color, sunlightCol, sssAmount,
                                                VdotL, NdotLs, lightMap.t, IGN, distFactor);
                }

                #ifdef DISTANT_HORIZONS
                if (sssCoverage < 0.999) {
                    float skyLevel   = rawSkyLight * 16.0;
                    float canopyMask = clamp((skyLevel - (15.0 - dhSssDepth)) / dhSssDepth, 0.0, 1.0);
                    canopyMask *= canopyMask;

                    vec3 sssDH = vec3(0.0);
                    if (canopyMask > 0.01) {
                        sssDH = calculateSSS_DH(viewPos.xyz, normal, sunlightCol, sssAmount,
                                                lightMap.t, IGN, distFactor) * canopyMask;
                    }
                    sssContribution = mix(sssDH, sssContribution, sssCoverage);
                }
                #endif

                finalShadow += sssContribution * lightStrength * undergroundFix;
            }
            #endif
        #endif
        
        // PBR Specular
        vec3 specularBRDF = vec3(0.0);
        if (directLit) {
            specularBRDF = cookTorranceGGXBRDF(color, specularMap, lightMap.t, sunlightCol);
            specularBRDF *= ShadowAccum * lightMap.t * lightStrength * rainDirect * transitionFade;
        }
        //specularBRDF *= mix(1.0, 0.8, distFactor);

        // Combine lighting
        diffuseLight = finalShadow + finalAmbient;
        color *= diffuseLight * diffuseWeight;

        #ifdef materialReflections
        // same ambient at the shadowed level
        vec3 shadowAmbientOpen = shadowCol * 3.0 * 0.4 * (1.0 - rainStrength * 0.7) * undergroundBlend;
        vec3 ambientOpenDelta  = (transitionFade * (shadowAmbientOpen - shadowAmbient)
                               + ambientStrength * ambientCol * ambientShadowFactor * (transitionFade - bounceMask))
                               * 0.25 * pow(ao, 0.42) * textureAO;
        ambientOpenDelta = mix(ambientOpenDelta, ambientOpenDelta * distAmbient, distFactor * undergroundBlend);
        ambientOpenDelta *= 1.0 - rainScatter;
        openAmbient = (finalAmbient + max(ambientOpenDelta, vec3(0.0))) / max(pow(ao, 0.42) * textureAO, 0.05);
        #endif

        // Add specular on top of lit surface
        color += specularBRDF;

        // Reflected water caustics, light bouncing off water onto surfaces
        #ifdef reflectedCaustics
        {
            vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * (shadowLightPosition * 0.01));
            vec3 reflCaust = reflectedWaterCaustics(
                worldPos, worldNormal, sunDirWorld,
                pow(lightMap.t, 0.5), iswater, shadowLum, causticTimeFactor
            );
            reflCaust *= sunlightCol * transitionFade * rainDirect;
            if (!directLit) reflCaust = vec3(0.0);
            diffuseLight += reflCaust;
            color.rgb += albedo * reflCaust * diffuseWeight;
        }
        #endif

        // Emission
        #ifdef materialEmission
            float emissionStr = mix(0.05, 0.6, torchFactor) + (1.0 - lightMap.t) * 0.5;
            emissionStr = clamp(emissionStr, 0.0, 1.0);
            color += albedo * emission * emissionStr * emissionStrength * 0.075;
        #endif
    #elif defined NETHER
        float lightStrength = lightStr;
        vec3 ambientCol = bounceLight * (1.0 - rainStrength * 0.55);
             diffuseLight = Diffuse * ShadowAccum * clamp(pow(lightMap.t, 4.0), 0.24, 1.0) * lightStrength * (1.0 - rainStrength * 0.2) + ambientStrength * ambientCol;
             color *= diffuseLight * diffuseWeight;
             openAmbient = ambientStrength * ambientCol;
    #else
        float lightStrength = lightStr;
        vec3 ambientCol = bounceLight;
             diffuseLight = Diffuse * ShadowAccum * clamp(pow(lightMap.t, 4.0), 0.24, 1.0) * lightStrength * (1.0 - rainStrength * 0.2) + ambientStrength * ambientCol * pow(shadowFactor, 2.0);
             color *= diffuseLight * diffuseWeight;
             openAmbient = ambientStrength * ambientCol * pow(shadowFactor, 2.0);
    #endif

    #ifdef skyLightMap
        color *= lightMap.t;
        diffuseLight *= lightMap.t;
    #endif

    //// Block Light ////
    #ifdef torchLightMap
        color += torchTotal * textureAO * diffuseWeight;
        diffuseLight += finalBlockLightColor * torchIntensity * textureAO;
    #endif

    //// Material reflection environment ////
    vec3 albedoQ = floor(clamp(albedo, 0.0, 1.0) * 255.0 + 0.5);
    vec3 envMiss = vec3(0.0);
    #if defined materialReflections && defined hardcodedMetals
    if (material > 0.0 && (specularMap.r > 0.0 || specularMap.g > 0.0)) {
        LabMaterial pbr = decodeLabPBR(specularMap, albedoQ / 255.0, rawSkyLight, wetness);
        vec3  Vv   = -normalize(viewPos.xyz);
        float NoVe = max(dot(normal, Vv), 1e-4);
        vec3  envE = specularAlbedo(pbr, NoVe);

        vec3 localRad = min(diffuseLight, vec3(16.0));
        envMiss = localRad;
        #if !defined NETHER && !defined END
        {
            float reflSkyAccess = clamp((rawSkyLight - 2.0 / 16.0) * 1.14285714286, 0.0, 1.0);
            vec3  R      = specularDominantDir(normal, reflect(-Vv, normal), pbr.roughness);
            vec3  RWorld = normalize(mat3(gbufferModelViewInverse) * R);
            vec3  Nw     = normalize(worldNormal);
            float roughBlend = smoothstep(0.1, 0.7, pbr.roughness);
            vec3  envMoonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);

            // Sky
            vec3 skyDir = normalize(vec3(RWorld.x, max(RWorld.y, 0.02), RWorld.z));
            vec3 skyR   = atmSky(colortex15, vec2(viewWidth, viewHeight), skyDir, atmSunTrue);
                 skyR   = atmSkyFinish(skyR, skyDir, atmSunTrue, envMoonDir);
                 skyR   = mix(skyR, skyBoxCol, rainStrength);
            vec3 skyAvg = mix(atmAmb, skyBoxCol, rainStrength);

            skyAvg *= clamp(openAmbient / max(skyAvg, vec3(1e-4)), vec3(0.02), vec3(20.0));

            // ground below the horizon
            vec3 groundRad = reflGroundAlbedo * (sunlightCol * sunlightCol * max(atmSunDir.y, 0.0) / PI
                                                   * lightStr * 11.0 * transitionFade * max(0.14, rainDirect)
                                                   + skyAvg);

            vec3 envSmooth = mix(groundRad, skyR,   smoothstep(-0.08, 0.08, RWorld.y));
            vec3 envRough  = mix(groundRad, skyAvg, clamp(0.5 + 0.5 * Nw.y, 0.0, 1.0));
            vec3 envOpen   = mix(envSmooth, envRough, roughBlend);
                 // specular occlusion from AO
                 envOpen  *= pow(ao, 0.42) * textureAO;

            envMiss = mix(localRad, envOpen, reflSkyAccess * reflSkyAccess);
        }
        #endif
        envMiss = max(envMiss, vec3(0.0));

        color += envMiss * envE * isMetal;
    }
    #endif

    //// Lava + Powdered Snow Fog ////
    float blockFog = clamp(pow(length(worldPos.xz) / 5.0, 0.5), 0.0, 1.0);
    if (isEyeInWater == 2) color.rgb = mix(color.rgb, vec3(1.0, 0.15, 0.0), blockFog);
    if (isEyeInWater == 3) color.rgb = mix(color.rgb, vec3(0.5, 0.6, 0.8), blockFog * 2.0);

#ifdef materialReflections
/* DRAWBUFFERS:04 */
    gl_FragData[0] = vec4(color, 1.0);
    #ifdef hardcodedMetals
    gl_FragData[1] = vec4(envMiss, albedoQ.r * 65536.0 + albedoQ.g * 256.0 + albedoQ.b);
    #else
    gl_FragData[1] = vec4(openAmbient, albedoQ.r * 65536.0 + albedoQ.g * 256.0 + albedoQ.b);
    #endif
#else
/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
#endif
}
