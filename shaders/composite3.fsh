#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex6;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex13;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;

/*
const float 	wetnessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]
const float 	drynessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]

const int colortex6Format = R11F_G11F_B10F;
const int colortex8Format = R11F_G11F_B10F;
*/

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform ivec2 eyeBrightnessSmooth;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float blindness;
uniform float darknessFactor;
uniform float wetness;
uniform float frameCounter;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 shadowLightPosition;

varying float dist;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 viewVector;
varying vec3 upVec;

#include "/lib/encode.glsl"

vec3 viewNormal = normalize(decodeNormal(texture2D(colortex1, texcoord).st));
float rainMask = 1;
vec2 specularMap = texture2D(colortex1, texcoord).ba;
vec3 waterNormal = normalize(texture2D(colortex5, texcoord).stp * 2.0f - 1.0f);

float Depth = texture2D(depthtex0, texcoord).r;
float Depth1 = texture2D(depthtex1, texcoord).r;
float undergroundFix = clamp(mix(max(lmcoord.t-2.0/16.0,0.0)*1.14285714286,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)), 0.0, 1.0);

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/raytrace.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/puddles.glsl"
#include "/lib/cloudFog.glsl"
#include "/lib/caveFog.glsl"

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

void main() {
	
	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	// .st = lightMap, .p = material
	vec4 colortex2Data = texture2D(colortex2, texcoord);
	float material = colortex2Data.p;
	float surfaceHeight = texture2D(colortex13, texcoord).g; // Height for puddle masking
	
	float iswater = float(material > 0.08 && material < 0.10);
	float isglass = float(material > 0.10 && material < 0.14 || material > 0.14 && material < 0.16)*undergroundFix;
	vec2 lightMap = colortex2Data.st;

	vec3 reflectedSun = texture2D(colortex6, texcoord).rgb;

	vec3 color = texture2D(colortex0, texcoord).rgb;
	float ShadowAccum = texture2D(colortex4, texcoord).a;
	float packedWaveLight = texture2D(colortex3, texcoord).a;
	float waterSSS = max(0.0, (0.5 - packedWaveLight) * 2.0);   
	float frontGlow = max(0.0, (packedWaveLight - 0.5) * 2.0);  
	vec3 reflectedskyBoxCol = texture2D(colortex8, texcoord).rgb;
	vec3 skyBoxCol = texture2D(colortex9, texcoord).rgb;

	//// Compute cloud fog ////
	#ifdef volumetricCloudFog
	vec4 cloudFog = vec4(0.0, 0.0, 0.0, 1.0);
	if (isEyeInWater < 0.5){
		cloudFog = getVolumetricCloudFog(cameraPosition, cloudFogCol);
	}
	#endif

	// Water Refraction and Reflection //
	if (iswater == 1.0){
		vec3 viewDir = normalize(viewPos.xyz);
		float normalDotEye = dot(waterNormal, -viewDir);

		float fogDepth2 = pow(length(worldPos.xz) / 18, 1.0);
			  fogDepth2 = clamp(1/exp(1.2 * fogDepth2), 0.0, 1.0);

		float eta;
		if (isEyeInWater > 0.5) {
			eta = 1.333 / 1.0;  // Underwater looking out
		} else if (isglass == 1.0) {
			eta = 1.0 / 1.0;    // Glass (Should be 1.5, off for now, broken)
		} else {
			eta = 1.0 / 1.333;  // Water
		}
			
		vec3 refractDir = refract(viewDir, waterNormal, eta);
		
		float waterDepth = getDepth(Depth);
		float underwaterDepth = getDepth(Depth1);
		float depthDifference = max(underwaterDepth - waterDepth, 0.0);
		
		vec2 refractOffset = (refractDir.xy - viewDir.xy);
		float offsetScale = clamp(depthDifference * 0.25, 0.0, 0.15);
		refractOffset *= offsetScale;

		// Chromatic aberration
		float chromaMaterial = 0.02;
		//if (isglass == 1.0) chromaMaterial = 0.0; //off for now, broken
		float chromaStrength = chromaMaterial * clamp(depthDifference * 0.1, 0.0, 1.0);
		vec2 chromaOffset = waterNormal.xy * chromaStrength;

		// GHOSTING FIX //
		vec2 testCoord = clamp(texcoord + refractOffset, vec2(0.001), vec2(0.999));
		float destFade = 1.0;
		if (iswater == 1.0) {
			float waterSurfaceAtRefract = texture2D(depthtex0, testCoord).r;
			float terrainAtRefract = texture2D(depthtex1, testCoord).r;
			float waterColumnRaw = terrainAtRefract - waterSurfaceAtRefract;
			destFade = smoothstep(0.0, 0.025, waterColumnRaw);
		 } //else if (isglass == 1.0) {
		// 	float destMaterial = texture2D(colortex2, testCoord).p;
		// 	float isGlassAtDest = float(destMaterial > 0.10 && destMaterial < 0.12);
			
		// 	float destTerrainDepth = texture2D(depthtex1, testCoord).r;
		// 	float behindGlass = smoothstep(Depth - 0.0001, Depth + 0.0001, destTerrainDepth);
			
		// 	destFade = isGlassAtDest * behindGlass;
		// }

		refractOffset *= destFade;
		chromaStrength *= destFade;
		chromaOffset *= destFade;

		vec2 refractCoord = clamp(texcoord + refractOffset, vec2(0.001), vec2(0.999));

		vec3 refractedColor;
		if (isEyeInWater < 0.5) {
			refractedColor.r = texture2D(colortex0, refractCoord + chromaOffset).r;
			refractedColor.g = texture2D(colortex0, refractCoord).g;
			refractedColor.b = texture2D(colortex0, refractCoord - chromaOffset).b;
		} else {
			refractedColor = color.rgb;
		}
				
		// Apply water absorption tint based on depth
		vec3 waterAbsorption = vec3(0.6, 0.85, 0.9);
		float absorptionFactor = exp(-depthDifference * 0.08);
		refractedColor *= mix(waterAbsorption, vec3(1.0), absorptionFactor);
		

		vec4 waterreflection = raytrace(reflectedskyBoxCol*lightMap.t, viewPos.xyz, waterNormal, 6);
		
		float fresnel = pow(1.0 - normalDotEye, 5.0);
		fresnel = mix(0.02, 1.0, fresnel); // F0 for water ~0.02
		
		vec3 reflectionCol = mix(reflectedskyBoxCol*lightMap.t, waterreflection.rgb, waterreflection.a);

		if (isEyeInWater < 0.5){
			color.rgb = mix(refractedColor, reflectionCol, fresnel);
			color.rgb += reflectedSun;
			color.rgb += (vec3(shallowwaterR, shallowwaterG, shallowwaterB)/255) * waterSSS * 0.6; 
			color.rgb += (vec3(deepwaterR, deepwaterG, deepwaterB)/255) * frontGlow * 0.4;           
		} else {
			//color.rgb = mix(refractedColor, reflectionCol, fresnel * 0.3);
			color.rgb += (vec3(shallowwaterR, shallowwaterG, shallowwaterB)/255) * waterSSS * 0.5 * fogDepth2; 
			color.rgb += (vec3(deepwaterR, deepwaterG, deepwaterB)/255) * frontGlow * 0.3 * fogDepth2;            
		}
	}

	// Glass Reflections //
	if (isglass == 1.0) {
		float perceptualSmoothness = specularMap.r;
		
		// Default smoothness if no texture data
		if (perceptualSmoothness == 0.0) {
			perceptualSmoothness = 0.95;
		}
		
		float roughness = 1.0 - perceptualSmoothness;
		
		vec3 viewDir = normalize(viewPos.xyz);
		float NdotV = max(dot(viewNormal, -viewDir), 0.001);
		
		// Glass F0 ~0.04
		float fresnel = 0.04 + (1.0 - 0.04) * pow(1.0 - NdotV, 5.0);
		fresnel *= (1.0 - roughness * 0.5); 
		
		// Calculate reflection 
		vec4 glassreflection = raytrace(reflectedskyBoxCol*lightMap.t, viewPos.xyz, viewNormal, 4);
		vec3 reflectionCol = mix(reflectedskyBoxCol*lightMap.t, glassreflection.rgb, glassreflection.a);

		color.rgb = mix(color.rgb, reflectionCol, fresnel * 0.7);
		
		// Sun specular
		color.rgb += reflectedSun;
	}

	#ifdef rainReflection
		float iswet = wetness;
		float isParticle = float(material == 0);
		  #ifdef alwaysPuddles
	      iswet = 1.0;
		  #endif
		if (iswet > 0 && iswater != 1.0 && isglass != 1.0 && isParticle != 1.0 && Depth > 0.56) {
			color.rgb = puddles(color.rgb, worldPos, reflectedskyBoxCol, viewPos.xyz, lightMap, iswet, surfaceHeight);
		}
	#endif
	

	//// PBR Reflections (opaque surfaces) ////
	#ifdef materialReflections
	if (iswater < 0.5 && isglass < 0.5 && Depth < 1.0) {
		float perceptualSmoothness = specularMap.r;
		float metalness = specularMap.g;
		
		// Only reflect if there's PBR data worth reflecting
		if (perceptualSmoothness > 0.1) {
			float roughness = 1.0 - perceptualSmoothness;
			
			vec3 viewDir = normalize(viewPos.xyz);
			float NdotV = max(dot(viewNormal, -viewDir), 0.001);
			
			vec3 F0;
			float f0Raw = specularMap.g * 255.0;

			if (f0Raw >= 229.5) {
				F0 = color.rgb; // Metal
			} else if (f0Raw > 0.5) {
				// Dielectric, cap f0 to realistic range (max ~0.17 = diamond)
				F0 = vec3(min(specularMap.g, 0.17));
			} else {
				F0 = vec3(0.04); // Default dielectric
			}
			float metalness = float(f0Raw >= 229.5);
			
			// Fresnel with roughness consideration
			vec3 fresnel = F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - NdotV, 5.0);
			
			// Reduce reflection on rough surfaces
			float reflectionFade = (metalness > 0.5) ? 1.0 : max(perceptualSmoothness - 0.5, 0.0) / 0.5;
			fresnel *= reflectionFade;
			//fresnel *= 1.0 - roughness * roughness * 0.7;

			// SSR with sky fallback
			vec4 pbrReflection = raytrace(reflectedskyBoxCol * lightMap.t, viewPos.xyz, viewNormal, 4);
			vec3 reflectionCol = mix(reflectedskyBoxCol * lightMap.t, pbrReflection.rgb, pbrReflection.a);
			
			// Metals tint their reflection by their albedo
			reflectionCol = mix(reflectionCol, reflectionCol * color.rgb, metalness);
			
			// Blend, metals replace diffuse, dielectrics add subtly
			color.rgb += reflectionCol * fresnel;
		}
	}
	#endif

	//// Atmosphere Fog ////
	#ifdef atmosphereFog
	if (Depth < 1.0 && isEyeInWater < 0.9) {
		vec3 viewDir = normalize(viewPos.xyz);
		float sunAngleCosine = 1.0 - clamp(dot(viewDir, shadowLightPosition * 0.01), 0.0, 1.0);
		sunAngleCosine = pow(sunAngleCosine, 2.0) * (3.0 - 2.0 * sunAngleCosine);
		sunAngleCosine = 1.0 / sunAngleCosine - 1.0;
		sunAngleCosine = 1.0 - exp(-sunAngleCosine / 12.0);
		sunAngleCosine = clamp(sunAngleCosine, 0.01, 2.0) * (1.0 - rainStrength * 0.999);
		
		// Normal atmospheric fog
		float normalFogDist = pow(length(worldPos.xz) / 140.0, 2.2);
		float normalFogDepth = clamp(1.0 - exp(-0.1 * normalFogDist), 0.0, 0.35);
		vec3 normalFog = mix(color.rgb, atmoColor*2, normalFogDepth * pow(sunAngleCosine, 0.2));
		
		// Rain fog 
		float rainFogDist = pow(length(worldPos.xz) / 60.0, 1.2);
		float rainFogDepth = clamp(1.0 - exp(-0.15 * rainFogDist), 0.0, 0.4);
		vec3 rainFogColor = cloudFogCol * 0.4;
		vec3 rainFog = mix(color.rgb, rainFogColor, rainFogDepth);
		
		// Blend between normal and rain fog
		color.rgb = mix(normalFog, rainFog, rainStrength);
	}
	#endif


	//// Cave Fog ////
	#ifdef caveFog
	if (Depth < 1.0 && isEyeInWater < 0.9) {
		float heldLight = max(float(heldBlockLightValue), float(heldBlockLightValue2));
		color.rgb = applyCaveFog(color.rgb, worldPos, colortex2Data.t, heldLight, 0.025*(1 - undergroundFix), colortex2Data.s);
	}
	#endif

	//// Border Fog ////
	#ifdef BorderFog
	float effects = blindness + darknessFactor;
	float borderFog = clamp(pow(length(worldPos.xz) / far, 14.0) * 0.7, 0.0, 1.0);
	if (Depth < 1.0 && isEyeInWater < 0.9) {
		color.rgb = mix(color.rgb, skyBoxCol * (1.0 - effects * 0.95), borderFog);
	}
	#endif

	//// Volumetric Cloud Fog (applied over everything including reflections) ////
	#ifdef volumetricCloudFog
	if (isEyeInWater < 0.5){
		float fogVisibility = (Depth >= 1.0) ? 1.0 : smoothstep(0.1, 0.5, colortex2Data.t);
		color.rgb = color.rgb * mix(1.0, cloudFog.a, fogVisibility) + cloudFog.rgb * fogVisibility;
	}
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor

}
