#version 130

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex6;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;  // transmittance + multiscatter LUT
uniform sampler2D colortex15;  // sky-view LUT
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;

/*
const float 	wetnessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]
const float 	drynessHalflife 			= 70.0; //[0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0]

const int colortex6Format = R11F_G11F_B10F;
*/

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform ivec2 eyeBrightnessSmooth;

uniform float frameTime;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float blindness;
uniform vec3 moonPosition;
uniform float darknessFactor;
uniform float wetness;
uniform float PI;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int frameCounter;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;

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

#define atmosphereSun

vec3 atmSunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec3 atmMoonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);
vec3 atmSunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/atmosphereLUT.glsl"
vec3 atmSun = atmSunColor(colortex14, vec2(viewWidth, viewHeight), atmSunDir);
vec3 atmAmb = atmSkyAmbient(colortex15, vec2(viewWidth, viewHeight), atmSunTrue);
#include "/lib/lightCol.glsl"
#include "/lib/raytrace.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/puddles.glsl"
#include "/lib/caveFog.glsl"
#include "/lib/clouds.glsl"

float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

// Bicubic Catmull Rom fetch. This preserves the higher frequencies across repeated
// reprojection so the cloud history stops eroding into a blurry mess while the camera moves
vec4 vcSampleCatmullRom(sampler2D tex, vec2 uv, vec2 texSize) {
	vec2 samplePos = uv * texSize;
	vec2 texPos1 = floor(samplePos - 0.5) + 0.5;
	vec2 f = samplePos - texPos1;

	vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
	vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
	vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
	vec2 w3 = f * f * (-0.5 + 0.5 * f);

	vec2 w12 = w1 + w2;
	vec2 offset12 = w2 / w12;

	vec2 texPos0  = (texPos1 - 1.0) / texSize;
	vec2 texPos3  = (texPos1 + 2.0) / texSize;
	vec2 texPos12 = (texPos1 + offset12) / texSize;

	vec4 r = vec4(0.0);
	r += texture2D(tex, vec2(texPos0.x,  texPos0.y))  * w0.x  * w0.y;
	r += texture2D(tex, vec2(texPos12.x, texPos0.y))  * w12.x * w0.y;
	r += texture2D(tex, vec2(texPos3.x,  texPos0.y))  * w3.x  * w0.y;
	r += texture2D(tex, vec2(texPos0.x,  texPos12.y)) * w0.x  * w12.y;
	r += texture2D(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
	r += texture2D(tex, vec2(texPos3.x,  texPos12.y)) * w3.x  * w12.y;
	r += texture2D(tex, vec2(texPos0.x,  texPos3.y))  * w0.x  * w3.y;
	r += texture2D(tex, vec2(texPos12.x, texPos3.y))  * w12.x * w3.y;
	r += texture2D(tex, vec2(texPos3.x,  texPos3.y))  * w3.x  * w3.y;
	return r;
}

void main() {
	
	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	// .st = lightMap, .p = material
	vec4 colortex2Data = texture2D(colortex2, texcoord);
	float material = colortex2Data.p;
	//float surfaceHeight = texture2D(colortex13, texcoord).g; // Height for puddle masking
	
	float iswater = float(material > 0.08 && material < 0.10);
	float isglass = float(material > 0.10 && material < 0.14 || material > 0.14 && material < 0.16)*undergroundFix;
	vec2 lightMap = colortex2Data.st;
	float reflSkyAccess = clamp((lightMap.t - 2.0/16.0) * 1.14285714286, 0.0, 1.0);

	vec3 reflectedSun = texture2D(colortex6, texcoord).rgb;

	vec3 color = texture2D(colortex0, texcoord).rgb;
	float ShadowAccum = texture2D(colortex4, texcoord).a;
	float packedWaveLight = texture2D(colortex3, texcoord).a;
	float waterSSS = max(0.0, (0.5 - packedWaveLight) * 2.0);   
	float frontGlow = max(0.0, (packedWaveLight - 0.5) * 2.0);  
	// This is subpixel wave slope variance, it translates to reflection roughness,
	// i'm not going to calculate actual reflection roughness, this works
	float waveSlopeVar = length(fwidth(waterNormal));

	// The effective reflection roughness for water
	float reflRough = 0.0;
	// This is done so the sky reflection actually follow the surface, water looks flat otherwise
	vec3 reflNormalSurf = viewNormal;
	if (iswater > 0.5) {
		float viewDist = length(viewPos.xyz);

		// Screen space slope variance
		// It's accurate up close, but eh far away because the stored wave normal is itself undersampled
		reflRough = clamp(waveSlopeVar * waveReflFilter, 0.0, 1.0);
		reflNormalSurf = normalize(mix(viewNormal, waterNormal, 1.0 - reflRough));
	}
	vec3 reflViewDir  = reflect(normalize(viewPos.xyz), reflNormalSurf);
	vec3 reflWorldDir = normalize(mat3(gbufferModelViewInverse) * reflViewDir);

	if (iswater > 0.5) {
		// Subhorizon rays reflect more water, i.e. the bright horizon band. Fold, don't clamp!
		if (reflWorldDir.y < 0.0) reflWorldDir.y *= -0.25;
		reflWorldDir = normalize(reflWorldDir);
	}

	vec3 reflectedskyBoxCol = vec3(0.0);
	if (Depth < 1.0) {
		reflectedskyBoxCol = atmSky(colortex15, vec2(viewWidth, viewHeight), reflWorldDir, atmSunTrue);
		reflectedskyBoxCol = atmSkyFinish(reflectedskyBoxCol, reflWorldDir, atmSunTrue, atmMoonDir);
		reflectedskyBoxCol = atmSunsetTint(reflectedskyBoxCol, reflWorldDir, atmSunDir,
		                                   (1.0 - rainStrength) * (1.0 - rainStrength));
	}

	vec3 skyBoxCol = texture2D(colortex9, texcoord).rgb;

	float vcDither = vcBayer8(gl_FragCoord.xy);
	#ifdef TAA
		vcDither = fract(vcDither + float(frameCounter & 15) * 0.0625);
	#endif

	vec3 reflectedskyClouds = reflectedskyBoxCol;
	#if defined(VolumetricClouds) && defined(cloudReflections)
		if (isEyeInWater < 0.9 && Depth < 1.0 && iswater > 0.5) {
			reflectedskyClouds = vcReflectClouds(reflectedskyBoxCol, reflWorldDir, vcDither, atmSunTrue.y);
		}
	#endif

	//// Border Fog ////
	#ifdef BorderFog
		float effects = blindness + darknessFactor;
		float borderFog = clamp(pow(length(worldPos.xz) / far, 14.0) * 0.7, 0.0, 1.0);
		//borderFog *= (1.0 - rainStrength);
	#endif

	// Water Refraction and Reflection //
	if (iswater == 1.0){
		vec3 viewDir = normalize(viewPos.xyz);
		float normalDotEye = max(dot(waterNormal, -viewDir), 0.0);

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
		
		float fresnel = pow(1.0 - normalDotEye, 5.0);
			  fresnel = mix(0.02, 1.0, fresnel);

		vec4 waterreflection;
		vec2 reflHitUV = vec2(0.5);
		float reflHitDepth = -1.0;
		vec3 reflSky = mix(reflectedskyClouds, skyBoxCol, rainStrength) * reflSkyAccess;

		if (fresnel > 0.05) {
			waterreflection = raytrace(reflSky, viewPos.xyz, reflNormalSurf, 6, reflHitUV, reflHitDepth);
		} else {
			waterreflection = vec4(reflSky, 0.0);
		}

		vec3 reflectionCol = mix(reflSky, waterreflection.rgb, waterreflection.a);
			#ifdef BorderFog
				// Fog the reflection by the distance to what it REFLECTS, not the water surface!!
				float reflBorderFog;
				if (reflHitDepth >= 0.0) {
					// Reflection hit, reconstruct the hit's world position and fog by its distance
					vec4 hClip  = vec4(reflHitUV, reflHitDepth, 1.0) * 2.0 - 1.0;
					vec4 hView  = gbufferProjectionInverse * hClip; hView /= hView.w;
					vec3 hWorld = mat3(gbufferModelViewInverse) * hView.xyz + gbufferModelViewInverse[3].xyz;
					reflBorderFog = clamp(pow(length(hWorld.xz) / far, 14.0) * 0.7, 0.0, 0.5) * (1.0 - rainStrength);
				} else {
					// Miss, reflecting the sky, which is already sky-colored (yay).
					// No border fog here, otherwise open water flattens to gray.
					reflBorderFog = 0.0;
				}
				reflectionCol = mix(reflectionCol, skyBoxCol * (1.0 - effects * 0.95), reflBorderFog);
			#endif

		if (isEyeInWater < 0.5){
			color.rgb = mix(refractedColor, reflectionCol, fresnel);
			color.rgb += reflectedSun * vcReflectTrans * reflSkyAccess;
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
			#ifdef BorderFog
				reflectionCol = mix(reflectionCol, skyBoxCol * (1.0 - effects * 0.95), borderFog);
			#endif

		color.rgb = mix(color.rgb, reflectionCol, fresnel);
		
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
			float distFactor = length(worldPos.xz) / 120.0;
				distFactor = pow(distFactor, 2.2);
				distFactor = exp(-1.2 * distFactor);
			color.rgb = puddles(color.rgb, worldPos, reflectedskyClouds, viewPos.xyz, lightMap, iswet, distFactor, 1);
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
				
				float reflectionFade = (metalness > 0.5) ? 1.0 : smoothstep(0.1, 0.5, perceptualSmoothness);
				fresnel *= reflectionFade;
				//fresnel *= 1.0 - roughness * roughness * 0.7;

				// Roughness-jittered reflection normal for blurry SSR (TAA resolves the noise)
				vec3 reflNormal = viewNormal;
				#ifdef TAA
				float h1 = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
				float h2 = fract(h1 * 3.321 + 0.7123);
				h1 = fract(h1 + float(frameCounter % 8) * 0.125);
				h2 = fract(h2 + float(frameCounter % 8) * 0.125);
				vec3 tangent = normalize(cross(reflNormal, abs(reflNormal.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
				vec3 bitangent = cross(reflNormal, tangent);
				float jitterStrength = roughness * roughness * 0.4;
				reflNormal = normalize(reflNormal
					+ tangent   * (h1 - 0.5) * jitterStrength
					+ bitangent * (h2 - 0.5) * jitterStrength);
				#endif

				// SSR with sky fallback
				vec4 pbrReflection = raytrace(reflectedskyBoxCol * lightMap.t, viewPos.xyz, reflNormal, 4);
				vec3 reflectionCol = mix(reflectedskyBoxCol * lightMap.t, pbrReflection.rgb, pbrReflection.a);
				
				// Metals tint their reflection by their albedo
				reflectionCol = mix(reflectionCol, reflectionCol * color.rgb, metalness);
				
				// Blend, metals replace diffuse, dielectrics add subtly
				color.rgb += reflectionCol * fresnel;
			}
		}
	#endif


	//// Volumetric Clouds ////
	vec4 cloudAccum   = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 cloudDataOut = vec4(1e6, 0.0, 0.0, 0.0);   // .x apparent dist, .y age
	#ifdef VolumetricClouds
	{
		const int UP   = cloudUpscale;
		const int area = cloudUpscale * cloudUpscale;

		ivec2 corner = ivec2(floor(vec2(viewWidth, viewHeight) / float(UP)));
		ivec2 dst = ivec2(gl_FragCoord.xy);
		ivec2 src = clamp(dst / UP, ivec2(0), corner - 1);     // corner low res texel

		vec4  current   = texelFetch(colortex12, src, 0);      // fresh color+transmittancve
		float freshDist = texelFetch(colortex10, src, 0).b;    // fresh apparent dist

		vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);

		// fresh vs last frame's history at this pixel
		vec4  hd0     = texture2D(colortex10, texcoord);
		float closest = min(freshDist, hd0.r);

		// Reproject at the cloud's real distance
		vec3 rp = vcReprojectCloudAt(worldDir, closest, frameTime,
		            gbufferPreviousModelView, gbufferPreviousProjection,
		            previousCameraPosition);
		vec2 prevUV = rp.xy;

		vec4 history     = vcSampleCatmullRom(colortex11, prevUV, vec2(viewWidth, viewHeight));
		vec4 historyData = texture2D(colortex10,  prevUV);

		bool disocclusion = rp.z < 0.5 || any(isnan(history));
		// Velocity gated neighbourhood clamp
		float camVel = length(cameraPosition - previousCameraPosition) / max(frameTime, 1e-4);
		float uvVel = length(prevUV - texcoord) * max(viewWidth, viewHeight);
		float velFactor = uvVel / (uvVel + 2.0);
		if (velFactor > 0.02) {
			vec4 e1 = current;	// centre fresh sample
			vec4 b1 = texelFetch(colortex12, src + ivec2( 0,-1), 0);
			vec4 d1 = texelFetch(colortex12, src + ivec2(-1, 0), 0);
			vec4 f1 = texelFetch(colortex12, src + ivec2( 1, 0), 0);
			vec4 h1 = texelFetch(colortex12, src + ivec2( 0, 1), 0);
			vec4 a1 = texelFetch(colortex12, src + ivec2(-1,-1), 0);
			vec4 c1 = texelFetch(colortex12, src + ivec2( 1,-1), 0);
			vec4 g1 = texelFetch(colortex12, src + ivec2(-1, 1), 0);
			vec4 i1 = texelFetch(colortex12, src + ivec2( 1, 1), 0);
			vec4 lo = min(min(min(b1,d1), min(e1,f1)), h1);
			lo = 0.5 * (lo + min(min(min(lo,a1), min(c1,g1)), i1));
			vec4 hi = max(max(max(b1,d1), max(e1,f1)), h1);
			hi = 0.5 * (hi + max(max(max(hi,a1), max(c1,g1)), i1));
			history = mix(history, clamp(history, lo, hi), velFactor);
		}

		// Checkerboard
		ivec2 off0 = dst - src * UP;
		bool freshHere = (off0 == vcCheckerOffset(frameCounter % area));
		if (!freshHere && !disocclusion) {
			current   = history;
			freshDist = min(freshDist, historyData.x);
		}

		// Age weighted blend
		float age = max(historyData.g, 0.0) * float(!disocclusion);
		float historyWeight = 1.0 - 1.0 / max(age - float(area), 1.0);
			  historyWeight = min(historyWeight, mix(0.97, 0.80, clamp(uvVel / 8.0, 0.0, 1.0)));

		cloudAccum     = max(mix(current, history, historyWeight), 0.0);
		cloudDataOut.r = mix(freshDist, historyData.x, historyWeight);
		cloudDataOut.g = min(age + 1.0, float(cloudAccumLimit));

		if (isEyeInWater < 0.9 && Depth >= 1.0) {
			float ca = clamp((cloudAccum.a - 0.05) / 0.95, 0.0, 1.0);
			color.rgb = color.rgb * ca + cloudAccum.rgb;
		}
	}
	#endif

	//// Atmosphere Fog ////
	#ifdef atmosphereFog
		if (isEyeInWater < 0.9) {
			vec3 rd = normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);

			if (Depth < 1.0) {
				float dist = length(worldPos.xz);	// horizontal distance, blocks
				float dayF = max(smoothstep(-0.12, 0.02, atmSunDir.y), rainStrength * 0.65);

				vec3 fogged = atmAerialPBR(color.rgb, colortex15, vec2(viewWidth, viewHeight),
				                           rd, dist, atmSunDir, 1.0 - rainStrength,
				                           cameraPosition.y, cameraPosition.y + worldPos.y);
				color.rgb = mix(color.rgb, fogged, dayF);
			}

			if (Depth >= 1.0) {
				float c = 1.0 - rainStrength;
                color.rgb = atmSunsetTint(color.rgb, rd, atmSunDir, c * c);
			}
		}
	#endif
	#ifdef caveFog
		if (Depth < 1.0 && isEyeInWater < 0.9) {
			float heldLight = max(float(heldBlockLightValue), float(heldBlockLightValue2));
			color.rgb = CaveFog(color.rgb, worldPos, colortex2Data.t, heldLight, 0.5*(1 - undergroundFix), colortex2Data.s);
		}
	#endif

	//// Border Fog ////
	#ifdef BorderFog
		if (Depth < 1.0 && isEyeInWater < 0.9) {
			color.rgb = mix(color.rgb, skyBoxCol * (1.0 - effects * 0.95), borderFog);
		}
	#endif

#ifdef VolumetricClouds
/* RENDERTARGETS: 0,11,10 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = cloudAccum;
	gl_FragData[2] = cloudDataOut;
#else
/* RENDERTARGETS: 0 */
	gl_FragData[0] = vec4(color, 1.0);
#endif

}
