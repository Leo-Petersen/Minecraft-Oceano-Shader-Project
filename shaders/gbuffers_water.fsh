#version 120

uniform sampler2D lightmap;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D normals;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float aspectRatio;
uniform float screenBrightness;
uniform float nightVision;
uniform float viewWidth;
uniform float viewHeight;
uniform float darknessLightFactor;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform vec3 shadowLightPosition;
uniform vec3 skyColor;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying float material;
varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 viewNormal;
varying vec3 viewVector;
varying vec3 wpos;

varying vec4 glcolor;
varying vec4 position;

varying mat3 tbnMatrix;

#include "/lib/settings.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/skyboxreflected.glsl"
#include "/lib/encode.glsl"
#include "/lib/sharedLighting.glsl"


void main() {
	float iswater = float(material > 0.08 && material < 0.10);
    float isglass = float(material > 0.10 && material < 0.12);
	float isTransparent = 1.0 - iswater; // Everything except water
	
	vec3 fragpos = toNDC(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z));
	
	float rawSkyLight = lmcoord.t;
	float rawTorchLight = lmcoord.s;
	
	float processedSkyLight = processSkyLight(rawSkyLight, nightVision, darknessLightFactor);
	
	float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
	float handlight = clamp((heldLightValue - 1.5 * length(fragpos)) / 18.0, 0.0, 0.9333);
	
	float processedTorchLight = processTorchLight(rawTorchLight, rawSkyLight, processedSkyLight, 
	                                               handlight, darknessLightFactor);

	#ifdef TAA
	float RandomAngle = 0.0;	
	#else
	float RandomAngle = 0.0;	
	#endif

	#ifdef Reflections
	float waterTransparency = 1.0 - iswater;
	#else
	float waterTransparency = 1.0 - iswater * 0.3;
	#endif

	vec4 color = texture2D(colortex0, texcoord) * glcolor;
	vec3 albedo = color.rgb;

	// Water Lighting //
	if (iswater > 0.5) {
		float skylightMap = texture2D(colortex2, texcoord).t;
		skylightMap = clamp(skylightMap, min_skyLightMap, 1.0);
		skylightMap = pow(skylightMap, 0.1);
		
		float transparencyFactor = 0.15 * getTransparencyFactor() * skylightMap;
		
		color *= texture2D(lightmap, lmcoord);
		if (isEyeInWater < 1.0) {
			color.a *= (waterTransparency + 0.6);
			color.rgb *= transparencyFactor;
		} else {
			color.rgb *= transparencyFactor;
		}
	}
	// Transparent Lighting //
	else {
		float NdotL = max(dot(viewNormal, normalize(shadowLightPosition)), 0.0);
		float diffuse = NdotL * 0.7 + 0.3; // Softer falloff
		
		float transparencyFactor = getTransparencyFactor();
		float shadowFactor = getShadowFactor();
		
		float undergroundBlend = smoothstep(0.0, 0.3, rawSkyLight);
		
		vec3 shadowCol = vec3(0.08, 0.12, 0.18);
		vec3 flatAmbient = pow(shadowCol, vec3(0.3)) * undergroundBlend * (1.0 - rainStrength * 0.2);
		vec3 undergroundAmbient = vec3(0.025, 0.028, 0.035) * (1.0 - undergroundBlend) * 5.0;
		vec3 ambient = (flatAmbient * 0.25 + undergroundAmbient);
		
		float lightStrength = lightStr * 4.0 * transparencyFactor * transitionFade;
		vec3 sunLight = sunlightCol * diffuse * processedSkyLight * lightStrength * (1.0 - rainStrength * 0.65);
		
		vec3 torchLight = getTorchLighting(processedTorchLight, albedo);
		
		color.rgb = albedo * (ambient + sunLight * 0.2) + torchLight;
		
		#ifdef skyLightMap
		color.rgb *= processedSkyLight;
		#endif
		
		color.rgb *= transparencyFactor * 3.33;
	}

	// Reflections and normal map for water and glass //
	vec3 glassNormal = viewNormal;
	if (isglass > 0.5) {
		vec4 normalRaw = texture2D(normals, texcoord);
		vec2 normalXY = normalRaw.rg * 2.0 - 1.0;
		vec3 normalData = vec3(normalXY, sqrt(1.0 - dot(normalXY, normalXY)));
		glassNormal = normalize(normalData * tbnMatrix);
	}

	#ifdef Reflections
	#ifdef ParallaxWater
		vec3 posxz = wpos.xyz;
		posxz = getParallaxDisplacement(posxz, iswater);
		vec3 bump = getWaveHeight(posxz.xz - posxz.y, iswater, RandomAngle);
		const float bumpmult = 0.5;
	#else
		vec3 bump = getWaveHeight((wpos.xz - wpos.y), iswater, RandomAngle);
		const float bumpmult = 0.5 * (WaterDepth + 0.5);
	#endif

	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);
	bump = normalize(clamp(bump, vec3(-1.0), vec3(1.0)));

	vec4 normalTangentSpace;
	if (isglass > 0.5) {
		normalTangentSpace = vec4(glassNormal * 0.5 + 0.5, 1.0);
	} else {
		normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	}
	
	// Reflected skybox
	vec3 reflectedVector = reflect(fragpos, normalize(bump * tbnMatrix).xyz) * 300.0;
	if (isglass > 0.5) {
		reflectedVector = reflect(fragpos, glassNormal) * 300.0;
	}
	vec3 skybox = getSkyTextureFromSequence(position.xyz + reflectedVector);
		 skybox += vec3(skyColor * 0.5) * (rainStrength * 0.5);
	     skybox = pow(skybox, vec3(3.2)) * 2.0;
	     skybox = clamp(skybox * (1.0 - rainStrength * 0.6), vec3(0.0), vec3(1.0));
	#endif

	// Water SSS //
	vec3 sunDir = normalize(shadowLightPosition);
	vec2 sunDirHoriz = normalize(sunDir.xz);
	vec2 waveTilt = bump.xy;
	
	float tiltTowardSun = dot(waveTilt, sunDirHoriz);
	float sssMask = smoothstep(0.05, -0.15, tiltTowardSun);
	
	float tiltMagnitude = length(waveTilt);
	sssMask *= smoothstep(0.0, 0.07, tiltMagnitude);
	
	vec3 viewDir = normalize(viewVector);
	float viewFactor = pow(max(dot(viewDir, sunDir), 0.0), 1.5) * 0.5 + 0.5;
	
	float transparencyFactorTime = getTransparencyFactor();
	float sssTime = 0.6 * time[0] + 1.0 * time[1] + 1.0 * time[2] + 
                   1.0 * time[3] + 0.6 * time[4] + 0.5 * time[5];

	float sssIntensity = sssMask * viewFactor * 0.7 * transparencyFactorTime * sssTime;
	sssIntensity *= processedSkyLight;
	sssIntensity *= (1.0 - rainStrength * 0.7);

	float frontGlowMask = smoothstep(-0.05, 0.2, tiltTowardSun);
	frontGlowMask *= smoothstep(0.0, 0.1, tiltMagnitude);

	float frontGlow = frontGlowMask * viewFactor * 0.7 * transparencyFactorTime;
	frontGlow *= processedSkyLight;
	frontGlow *= (1.0 - rainStrength * 0.7);

	float packedWaveLight = 0.5 + (frontGlow * 0.5) - (sssIntensity * 0.5);
	packedWaveLight = clamp(packedWaveLight, 0.0, 1.0);
	
/* DRAWBUFFERS:012583 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodeNormal(isglass > 0.5 ? glassNormal : viewNormal), 1, 1);
	gl_FragData[2] = vec4(lmcoord, material, 1.0f);
	gl_FragData[3] = normalTangentSpace;
	gl_FragData[4] = vec4(skybox, 1.0);
	gl_FragData[5] = vec4(vec3(0.0), packedWaveLight);
}
