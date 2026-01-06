#version 400 compatibility

#include "/lib/settings.glsl"

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0; //.rgb = color
uniform sampler2D colortex1; //.st = viewNormal
uniform sampler2D colortex2; //.s = torchLightMap, .t = skyLightMap, .p = material
uniform sampler2D colortex3;
uniform sampler2D colortex5; 
uniform sampler2D colortex8; 
uniform sampler2D colortex9; 
uniform sampler2D texture; 
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform vec2 texelSize;

uniform float far;
uniform float near;
uniform float eyeAltitude;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float nightVision;
uniform float darknessFactor;
uniform float darknessLightFactor;

uniform vec3 skyColor;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

varying vec2 texcoord;
varying vec2 lmcoord;

/*
const bool colortex7Clear = false;
const int colortex7Format = RGBA16F;
const int colortex9Format = R11F_G11F_B10F;
*/

float Depth = texture2D(depthtex0, texcoord).r;
float Depth1 = texture2D(depthtex1, texcoord).r;
vec2 lightMap = texture2D(colortex2, texcoord).st;

vec3 luma(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

#include "/lib/encode.glsl"

float undergroundFix = clamp(mix(max(lmcoord.t-2.0/16.0,0.0)*1.14285714286,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)), 0.0, 1.0);
vec3 viewNormal = normalize(decodeNormal(texture2D(colortex1, texcoord).st));
vec3 waterNormal = normalize(texture2D(colortex5, texcoord).rgb * 2.0f - 1.0f);
float Diffuse = max(0.0, dot(viewNormal, normalize(shadowLightPosition))); 

////#includes////
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/raytrace.glsl"
#include "/lib/waterShadow.glsl"
#include "/lib/caustics.glsl"
#include "/lib/fog.glsl"
#include "/lib/waterFog.glsl"

void main() {
	////Setup world spaces////
	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	////Materials////
	float material = texture2D(colortex2, texcoord).p;
	float iswater = float(material > 0.08 && material < 0.10);
	float isglass = float(material > 0.10 && material < 0.12);

	////WaterShadow////
	float ShadowVisibility = 1.0;
	if (iswater == 1.0 || isglass == 1.0){
		  ShadowVisibility = GetShadow().r*transitionFade;
	}

	////Calculate sun////
    vec3 reflectedVector = reflect(normalize(viewPos.xyz), waterNormal) * 300.0;

    float sunDist = 1.0/distance(normalize(viewPos.xyz), normalize(shadowLightPosition));
    float sunDistReflected = 1.0/distance(normalize(reflectedVector.xyz), normalize(shadowLightPosition));

	float normalDotEye = dot(waterNormal, -normalize(viewPos.xyz));
	float fresnel = pow(1.0 - normalDotEye, 3.0);

	//Atmo time factor/
	float atmoStr = 0.06 * (time[0]) +  
					0.0 * (time[1]) +
					0.0 * (time[2]) + 
					0.0 * (time[3]) + 
					0.06 * (time[4]) + 
					0.3 * (time[5]);

	float altitudeAtmoStr = 0.0 * (time[0]) +  
							0.8 * (time[1]) +
							1.0 * (time[2]) + 
							0.8 * (time[3]) + 
							0.0 * (time[4]) + 
							0.8 * (time[5]);
	//Main sun//
    vec3 mainSun = pow(sunDist*0.02, 5.2) * sunCol;
		 mainSun = 1.0 - exp( -mainSun );
		 mainSun *= (1- rainStrength);
		 mainSun *= 64.0;
	//Sun Glare//
    vec3 sunGlare = pow(sunDist*0.07, 1.8) * sunCol;
		 sunGlare = 1.0 - exp( -sunGlare ); 
		 sunGlare *= 2.0;
	//Screen Glare//
	#ifdef screenSunGlare
    vec3 screensunGlare = pow(sunDist*0.04, 2.2) * sunCol;
		 screensunGlare = 1.0 - exp( -screensunGlare );
		 screensunGlare *= (1-rainStrength);
	#endif
	//Atmosphere Glare//
    vec3 atmoGlare = pow(sunDist*2.2, 0.1) * sunCol;
		 atmoGlare = 1.0 - exp( -atmoGlare );
		 atmoGlare *= (1-rainStrength);
		 //atmoGlare *= 5.0*(1.0-time[5]*0.8);

	//Reflected sun//
    //vec3 reflectSun = pow(sunDistReflected*0.12, 5.2) * sunCol;
		 //reflectSun = 1.0 - exp( -reflectSun );
		 //reflectSun *= 4.0*ShadowVisibility*(1-(time[5]*0.9))*(1-rainStrength*0.94)*transitionFade;
		vec3 lightDir = normalize(shadowLightPosition);
		vec3 viewDir = normalize(-viewPos.xyz);
		vec3 halfVec = normalize(lightDir + viewDir);
		
		float NdotH = max(dot(waterNormal, halfVec), 0.0);
		
		// Very sharp specular for sparkle effect
		float sparkle = pow(NdotH, 256.0) * 3.0;
		sparkle *= lightMap.t; // Only in sunlight
		sparkle *= (1.0 - rainStrength*0.94) * 2 * transitionFade * ShadowVisibility; // Reduce in rain
		vec3 reflectSun = sunCol * sparkle;

		float packedWaveLight = texture2D(colortex3, texcoord).a;
		float waterSSS = max(0.0, (0.5 - packedWaveLight) * 2.0);
		float frontGlow = max(0.0, (packedWaveLight - 0.5) * 2.0);

		// Apply shadows
		waterSSS *= ShadowVisibility;
		frontGlow *= ShadowVisibility;

		// Repack
		float repackedWaveLight = 0.5 + (frontGlow * 0.5) - (waterSSS * 0.5);
		repackedWaveLight = clamp(repackedWaveLight, 0.0, 1.0);

	//Reflected Atmosphere//
    vec3 ReflectAtmoGlare = pow(sunDistReflected*2.2, 0.1) * sunCol;
		 ReflectAtmoGlare = 1.0 - exp( -ReflectAtmoGlare );
		 ReflectAtmoGlare *= (1-rainStrength*0.9)*transitionFade*atmoStr*1.5*fresnel;

	float sunStr = sunStrength;
	if (ToneMap == 0) {
		sunStr *= 0.4;
	}

	vec4 tpos = gbufferProjection * vec4(shadowLightPosition, 1.0);
		 tpos.xyz /= tpos.w;
	vec2 lightPos = tpos.xy / tpos.z * 0.5;


	//Final sky and sun colour//
	sunStr *= 0.05;
	vec3 reflectedskyBoxCol = texture2D(colortex8, texcoord.st).rgb+ReflectAtmoGlare;
	#ifdef screenSunGlare
	float visibleSun = float(texture2D(depthtex1, lightPos + 0.5).r >= 1.0);
	vec3 finalGlare = (screensunGlare) * sunStr * (1.0 - ((time2[1].y)*rainStrength))* transitionFade * (1.0-isEyeInWater) * visibleSun * transitionFade;
	#else
	vec3 finalGlare = vec3(0.0);
	#endif

	vec3 finalSun = (mainSun + sunGlare + atmoGlare*atmoStr*transitionFade) * (1.0 - ((time2[1].y)*rainStrength)) * (1.0-isEyeInWater) * sunStr * transitionFade;

	
	////Colours////
	vec4 color = texture2D(colortex0, texcoord.st)+vec4(finalGlare, 0.0);
	vec3 skyBoxCol = texture2D(colortex9, texcoord.st).rgb+finalSun+finalGlare;

	////Reflections////
	vec3 fragpos2 = vec3(0.0);
	if (iswater == 1.0){
	    fragpos2 = vec3(texcoord.st, texture2D(depthtex1, texcoord.st).r);
	#ifdef Reflections
		fragpos2 = normalizedVec3(gbufferProjectionInverse * normalizedVec4(fragpos2 * 2.0 - 1.0));
	#endif
	}

    float glare = pow(sunDist*0.07, 2.0);
		  glare = 1.0 - exp( -glare );
		  glare *= 150.0 * (1.0 - time2[1].y);
		  glare = clamp(glare, 0.0, 2.0);

	float sunAngleCosine = 1.0 - clamp(dot(normalize(viewPos.rgb), normalize(shadowLightPosition)), 0.0, 1.0);
		  sunAngleCosine = pow(sunAngleCosine, 2.0)*(3.0 - 2.0 * sunAngleCosine);
		  sunAngleCosine = 1.0 / sunAngleCosine - 1.0;
		  sunAngleCosine = 1.0 - exp( -sunAngleCosine);
		  //sunAngleCosine = sunAngleCosine+(1*altitudeAtmoStr);
		  //sunAngleCosine /= sunAngleCosine * 0.02 + 1.0;


	///Caustics///
	#ifdef Caustics
	float WaterShadowVisibility = 1.0;
	if (iswater == 1.0 || isEyeInWater > 0.9){

		  WaterShadowVisibility = GetCausticsShadow().r*transitionFade*Diffuse;

		vec3 fragpos3 = vec3(texcoord.st, Depth1);
			fragpos3 = normalizedVec3(gbufferProjectionInverse * normalizedVec4(fragpos3 * 2.0 - 1.0));
		vec3 worldPosWater = mat3(gbufferModelViewInverse) * fragpos3.xyz + gbufferModelViewInverse[3].xyz;
		vec3 caustics = waterCaustics(worldPosWater, WaterShadowVisibility);
		color.rgb *= caustics;
	}
	#endif

	///Lightmap///
	float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
	float handlight = clamp((heldLightValue - 1.5 * length(viewPos.xyz)) / 15.0, 0.0, 0.9333);
	// float torchtimeFactor = 1.0 * (time[0]) +  
	// 				   	    0.8*(1+rainStrength*0.15) * (time[1]) +
	// 				   		0.8*(1+rainStrength*0.15) * (time[2]) + 
	// 				   		0.8*(1+rainStrength*0.15) * (time[3]) + 
	// 				   		1.0 * (time[4]) + 
	// 				   		1.0 * (time[5]);

	lightMap.t = clamp(lightMap.t, ((1-nightVision)*min_skyLightMap)+(0.5*nightVision), 1.0);
	lightMap.t = pow(lightMap.t*(1-darknessLightFactor), 0.65);
	lightMap.s *= (1-darknessLightFactor*0.5);
	float torchmapLight = max(lightMap.s, handlight) * lightMap.t;
	float torchmapCovered = max(lightMap.s, handlight) * (1-lightMap.t);
		  lightMap.s = (torchmapLight) + torchmapCovered;

	float adjustedTorchMap = lightMap.s * 0.7 + pow(lightMap.s, 4.2) * 2.0;
	vec3 torchColor = vec3(255, 140, 80)/255 * adjustedTorchMap;
	float torchmap = clamp(adjustedTorchMap - 1.0 / 32.0, 0.0, 1.0);
	vec3 torchTotal = mix(vec3(0.0), pow(torchColor, vec3(1.5)), color.rgb)*0.3;
		 //torchTotal = vec3(1.0) - exp(-torchTotal * 1.0);

	////GlassLighting////
	if (isglass == 1.0) {
		color.rgb *= clamp(1 + ShadowVisibility, 1.0, 1.2);
		color.rgb *= lightMap.t;
		color.rgb += torchTotal;
	}

	////Fog////
	if (iswater == 1.0){
		color.rgb = getWaterDepthFog(color.rgb, viewPos.xyz, fragpos2, iswater, lightMap.t);
	}

	float atmoDepth = 0.0;
	if (Depth < 1.0 && isglass > 0.9 && isEyeInWater < 0.9) {
		  atmoDepth = pow(length(worldPos.xz) / 140, 2.2);
		  atmoDepth = 1.0 - exp(-0.4 * atmoDepth);
		  color.rgb = mix(color.rgb, (atmoColor*(1-rainStrength))+(vec3(0.48, 0.48, 0.56)*rainStrength*(1-time[5])), atmoDepth*0.5);
	}
	
	if(rainStrength > 0 && iswater == 1) {
		  atmoDepth = pow(length(worldPos.xz) / 140, 2.2);
		  atmoDepth = 1.0 - exp(-0.4 * atmoDepth);
		  color.rgb = mix(color.rgb, (vec3(0.96, 0.96, 1)*0.8*rainStrength*(1-time[5])), atmoDepth*0.8);
	}

	//fogColor = pow(fogColor, vec3(0.7))*1.5;

	#ifdef Fog
	if (Depth < 1.0){
		color.rgb = getFog(color.rgb, cameraPosition, worldPos, pow(fogColor, vec3(0.7))*1.5, iswater, glare, sunCol, transitionFade, skyColor, sunAngleCosine);
	}
	#endif

	if (isEyeInWater == 1.0){
		color.rgb = getUnderwaterFog(color.rgb, viewPos.xyz, lightMap.t);
	}

/* DRAWBUFFERS:06893 */
	gl_FragData[0] = vec4(color); //colortex0
	gl_FragData[1] = vec4(reflectSun, 0.0); //colortex6
	gl_FragData[2] = vec4(reflectedskyBoxCol, 0.0); //colortex8
	gl_FragData[3] = vec4(skyBoxCol, 1.0); //colortex9
	gl_FragData[4] = vec4(vec3(0.0), repackedWaveLight);
}