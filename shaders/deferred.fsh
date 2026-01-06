#version 130

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
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;
uniform sampler2D specular;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float near, far;
uniform float nightVision;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float viewHeight, viewWidth;
uniform float aspectRatio;
uniform float wetness;

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
#include "/lib/poissonDisk.glsl"
#include "/lib/lighting.glsl"
#include "/lib/brdf.glsl"
#include "/lib/raytrace.glsl"

vec3 nvec3(vec4 pos) {
    return pos.xyz / pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float undergroundFix = clamp(mix(max(lmcoord.t - 2.0 / 16.0, 0.0) * 1.14285714286, 1.0, clamp((eyeBrightnessSmooth.y / 255.0 - 2.0 / 16.0) * 4.0, 0.0, 1.0)), 0.0, 1.0);

float transparencyFactor =  0.3 * (time[0]) +
                            0.9 * (time[1]) +
                            0.9 * (time[2]) +
                            0.9 * (time[3]) +
                            0.3 * (time[4]) +
                            0.14 * (time[5]);

float shadowFactor =  0.42 * (time[0]) +
                      1.0 * (time[1]) +
                      1.0 * (time[2]) +
                      1.0 * (time[3]) +
                      0.42 * (time[4]) +
                      0.25 * (time[5]);

float torchFactor =   0.50 * (time[0]) +
                      0.33 * (time[1]) +
                      0.33 * (time[2]) +
                      0.33 * (time[3]) +
                      0.50 * (time[4]) +
                      1.00 * (time[5]);

void main() {

    vec3 color = texture2D(colortex0, texcoord).rgb;
    vec3 albedo = color;

    //// Materials ////
    float material = texture2D(colortex2, texcoord).p;
    float isglass = float(material > 0.10 && material < 0.12);
    float parallaxShadow = texture2D(colortex2, texcoord).a;
    float iswater = float(material > 0.08 && material < 0.10);
    float emission = texture2D(colortex13, texcoord).r;
    float textureAO = texture2D(colortex13, texcoord).b;

    //// Setup LightMap ////
    vec2 lightMap = texture2D(colortex2, texcoord).st;
    float rawSkyLight = lightMap.t;
         lightMap.t = clamp(lightMap.t, ((1.0 - nightVision) * min_skyLightMap) + (0.5 * nightVision), 1.0);
         lightMap.t = pow(lightMap.t * (1.0 - darknessLightFactor), 0.5);

    vec4 screenPos = vec4(texcoord, texture2D(depthtex0, texcoord).r, 1.0);
    vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
    viewPos /= viewPos.w;
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

    float distFactor = length(worldPos.xz) / 120.0;
          distFactor = pow(distFactor, 2.2);
          distFactor = 1.0 - exp(-1.2 * distFactor);

    vec3 skyBoxCol = texture2D(colortex9, texcoord.st).rgb;

	vec2 specularMap = texture2D(colortex1, texcoord).ba;
    float roughness = clamp(1.0 - specularMap.r, 0.01, 0.99);
    vec3 reflectedskyBoxCol = texture2D(colortex8, texcoord).rgb;
    
    vec3 normal = normalize(decodeNormal(texture2D(colortex1, texcoord).xy));

    float Diffuse = calculateDiffuse(normalize(shadowLightPosition), normalize(-viewPos.xyz), normal, roughness, material);
          Diffuse = mix(Diffuse, 0.15 + Diffuse * 0.85, distFactor);


    //// SSS ////
    float sunAngleCosine = 1.0 - clamp(dot(normalize(viewPos.rgb), normalize(shadowLightPosition)), 0.0, 1.0);
    sunAngleCosine = pow(sunAngleCosine, 2.0) * (3.0 - 2.0 * sunAngleCosine);
    sunAngleCosine = 1.0 / sunAngleCosine - 1.0;
    sunAngleCosine = 1.0 - exp(-sunAngleCosine / 12.0);
    sunAngleCosine *= undergroundFix;
    sunAngleCosine = clamp(sunAngleCosine, 0.01, 2.0) * (1.0 - rainStrength * 0.999);


    //// Calculate LightMap Colour and Values ////
    float ao = 1.0;
    #ifdef AO
        ao = ambientOcclusion(depthtex1);
    #endif

    float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
    float handlight = clamp((heldLightValue - 1.5 * length(viewPos.xyz)) / 18.0, 0.0, 0.9333);

    lightMap.s *= (1.0 - darknessLightFactor * 0.5);
    float torchTimeBlend = mix(1.0, torchFactor, rawSkyLight);
    float torchmapLight = max(lightMap.s, handlight) * lightMap.t * torchTimeBlend;
    float torchmapCovered = max(lightMap.s, handlight) * (1.0 - lightMap.t);
    lightMap.s = (torchmapLight * pow(ao, 0.24) * 0.5) + torchmapCovered;
    
    float torchIntensity = lightMap.s * lightMap.s;
    torchIntensity *= 3.2;
    
    // color temperature shift: warmer at distance, whiter near source
    vec3 torchColorBase = vec3(torchR, torchG, torchB) / 255.0;
    vec3 torchColorWarm = torchColorBase * vec3(1.0, 0.7, 0.4);
    vec3 torchColor = mix(torchColorWarm, torchColorBase, lightMap.s) * torchIntensity;
    
    float torchmap = clamp(lightMap.s - 1.0 / 32.0, 0.0, 1.0);
    vec3 torchTotal = torchColor * albedo;

    //// Setup Shadow Filter ////
    vec4 shadowCoord = ShadowSpace();
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

    //// Apply Shadow Filter ////
    vec3 ShadowAccum = vec3(0.0);
    float filterSize = 0.0025 * filterStr * (1.0 + rainStrength * 2.0);

    #ifdef BounceColoredLight
        vec3 flux = vec3(0.0);
        float fluxRadius = 0.08;
        float validSamples = 0.0;
    #else
        vec3 flux = vec3(0.4);
    #endif

    #define samples lightingQuality
    for (int i = 0; i < samples; i++) {
        float theta = float(i) * 2.4 + angle;
        float radius = sqrt((float(i) + 0.5) / float(samples));
        vec2 dir = vec2(cos(theta), sin(theta)) * radius;
        
        // shadow sampling
        vec2 shadowOffset = dir * filterSize;
        ShadowAccum += TransparentShadow(vec3(SampleCoords.xy + shadowOffset, SampleCoords.z), transparencyFactor);
        
        // flux sampling
        #ifdef BounceColoredLight
            vec2 fluxCoord = SampleCoords.xy + dir * fluxRadius;
            
            if (fluxCoord.x >= 0.0 && fluxCoord.x <= 1.0 && 
                fluxCoord.y >= 0.0 && fluxCoord.y <= 1.0) {
                vec4 fluxSample = texture2D(shadowcolor0, fluxCoord);
                flux += fluxSample.rgb * (1.0 - fluxSample.a);
                validSamples += 1.0;
            }
        #endif
    }

    ShadowAccum /= float(samples);
    ShadowAccum *= parallaxShadow;
    ShadowAccum = mix(ShadowAccum, vec3(1.0), emission * 0.8);
    vec3 invShadowAccum = clamp(-ShadowAccum*Diffuse + vec3(0.4), vec3(0.0), vec3(1.0));
    #ifdef BounceColoredLight
        if (validSamples > 0.0) {
            flux /= validSamples;
        } else {
            flux = vec3(0.4);
        }
    #endif
    
    flux = max(flux, vec3(0.0001));
	flux *= (1 - rainStrength*0.88);
	flux /= dot(vec3(0.0721, 0.7154, 0.2125), flux); // Fixes grain and bright spots
	if (Depth < 0.56) flux /= dot(vec3(0.0721, 0.7154, 0.2125), flux) + rainStrength*0.5; // improves noise on hands

	vec3 bounceLight = backLight(flux);
		 bounceLight = mix(shadowCol, bounceLight, dot(vec3(0.0721, 0.7154, 0.2125), flux) + 0.5);
		 bounceLight = mix(bounceLight, bounceLight*0.1+ambientShadowColor*18, distFactor);
         bounceLight *= 0.55;
		 
		 float undergroundBlend = smoothstep(0.0, 0.3, rawSkyLight);
		 
		 #ifdef skyLightMap
		 bounceLight = mix(ambientShadowColor, bounceLight, lightMap.t);
		 #endif
		 float bounceAvg = (bounceLight.r+bounceLight.g+bounceLight.b)*0.33;
		
	#ifdef disableRainShadows
	float rainShadowStr = 24.0;
	#else
	float rainShadowStr = 0.5;
	#endif


	////Setup ambient////
	#ifdef shadowMap

			#ifdef fakecloudshadow
				float fakeCloudShadow = mix(1.0, fakeCloudShadow(worldPos), distFactor*(1-rainStrength));
			#else
				float fakeCloudShadow = 1.0;
			#endif

			float ambientStrength = ambientStr*0.1;
			
		#else
			float ambientStrength = 0.2;
			ShadowAccum = vec3(0.5f);
	#endif
	
	////Apply Lighting and ShadowMap////
	#ifdef shadowMap 
        vec3 ambientCol = bounceLight * (1 - rainStrength * rainShadowStr);
		float lightStrength = lightStr * 6 * (1-darknessFactor*0.9) * fakeCloudShadow * transitionFade * pow(ao, 0.06);
		//color *= mix(1.0, 1.2, distFactor);
		//lightStrength *= mix(1.0, 1.2, distFactor);

        if(Depth < 1.0f){
            vec3 finalShadow = sunlightCol * Diffuse * ShadowAccum * lightMap.t * lightStrength * (1 - rainStrength * 0.65);
                
            float ambientShadowFactorFixed = mix(0.5, shadowFactor, undergroundBlend);
            
            // Shadow mask for bounce light
            float shadowLum = dot(ShadowAccum, vec3(0.2126, 0.7152, 0.0722));
            float litAmount = shadowLum * max(Diffuse, 0.0);
            float bounceMask = 1.0 - smoothstep(0.0, 0.25, litAmount);
            bounceMask *= bounceMask*transitionFade;
            
            vec3 baseAmbient = shadowCol * 3.0 * invShadowAccum * (1.0 - rainStrength * 0.2) * undergroundBlend;
            vec3 bounceAmbient = ambientStrength * ambientCol * ambientShadowFactorFixed * (1.0 - rainStrength * 0.14) * bounceMask;
            vec3 finalAmbient = (baseAmbient + bounceAmbient) * 0.25 * pow(ao, 0.2) * textureAO;
                
            // Underground ambient
            vec3 undergroundBaseAmbient = vec3(0.025, 0.028, 0.035) * (1.0 - undergroundBlend) * pow(ao, 0.42) * textureAO * 5;
            finalAmbient += undergroundBaseAmbient;

            //SSS//
            if (material > 0.00 && material < 0.02 || material > 0.02 && material < 0.04) {
                finalShadow += SSS(material, Diffuse, color.rgb, sunlightCol, sunAngleCosine, ShadowAccum, lightStrength, lightMap.t, rainStrength);
            }
            
            color *= (finalShadow + finalAmbient);

            float nightAmount = time[5] + time[0] * 0.6 + time[4] * 0.6;
            float darkness = 1.0 - lightMap.t * lightMap.t; 
            float emissionStrength = mix(darkness, 1.0, nightAmount);
            emissionStrength = max(emissionStrength, 0.15);
            
            float effectiveEmission = emission * emissionStrength;
            vec3 emissiveColor = albedo * effectiveEmission * 2.5;
            color = mix(color, emissiveColor, effectiveEmission);
		}
	#else
	float lightStrength = lightStr;
	vec3 ambientCol = bounceLight * (1 - rainStrength * rainShadowStr);
		 if(Depth < 1.0f){
		 	color *= Diffuse * ShadowAccum * clamp(pow(lightMap.t, 4.0), 0.24, 1.0) * lightStrength * (1 - rainStrength * 0.2) + ambientStrength * ambientCol;
		 }
	#endif

	#ifdef skyLightMap
	color *= lightMap.t;
	#endif

	////Apply LightMap////
	#ifdef torchLightMap
	color += torchTotal * textureAO; // Apply texture AO to torch light
	#endif


	////Fog////
	float atmoDepth = 0.0;
	if (Depth < 1.0 && isEyeInWater < 0.9) {
		  atmoDepth = pow(length(worldPos.xz) / 140, 3.2);
		  atmoDepth = clamp(1.0 - exp(-0.3 * atmoDepth), 0, 1);
		  color.rgb = mix(color.rgb, ((atmoColor)*(1-rainStrength))+(vec3(0.96, 0.96, 1)*5.8*rainStrength*(1-time[5])), atmoDepth*1.0*pow(sunAngleCosine, 0.2));
	}

	if (isEyeInWater == 1.0){
	float fogDepth = length(worldPos.xz) / 100;
		  fogDepth = pow(fogDepth, 1.0);
		  fogDepth = 1.0 - exp(-11.3 * fogDepth);
		  //fogDepth *= 1.0-lightMap.t;
		  
		color.rgb = mix(color.rgb, vec3(0.0, 0.36, 0.51) * 0.05 *  (1 - time[5] * 0.64) * (1 - rainStrength), fogDepth);
	}

    // Lava+Powdered Snow Fog //
	float blockFog = clamp(pow(length(worldPos.xz) / 5, 0.5), 0.0, 1.0);
	if (isEyeInWater == 2) color.rgb = mix(color.rgb, vec3(1.0, 0.15, 0.0), blockFog);
    if (isEyeInWater == 3) color.rgb = mix(color.rgb, vec3(0.5, 0.6, 0.8), blockFog*2);

	//color.rgb = vec3(Diffuse * ShadowAccum);
/* DRAWBUFFERS:04 */
	gl_FragData[0] = vec4(color, 1);
	gl_FragData[1] = vec4(vec3(0.0), Diffuse * ShadowAccum);
}
