#version 120

uniform sampler2D lightmap;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float aspectRatio;
uniform float screenBrightness;
uniform float nightVision;
uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;

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
#include "/lib/skyboxreflected.glsl"
#include "/lib/encode.glsl"

float transparencyFactorTime = 0.3 * (time[0]) +  
					   	       1.0 * (time[1]) +
					   		   1.0 * (time[2]) + 
					   		   1.0 * (time[3]) + 
					   		   0.3 * (time[4]) + 
					   		   0.3 * (time[5]);

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	//color = color + (color-luma)*strength*0.1;
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

void main() {
	float iswater = float(material > 0.08 && material < 0.10);
    float isglass = float(material > 0.10 && material < 0.12);
	float skylightMap = texture2D(colortex2, texcoord).t;
		  skylightMap = clamp(skylightMap, min_skyLightMap, 1.0);
		  skylightMap = pow(skylightMap, 0.1);
 	vec3 fragpos = toNDC(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z));

	#ifdef Reflections
	float waterTransparency = 1-iswater;
	#else
	float waterTransparency = 1-iswater*0.3;
	#endif

	#ifdef TAA
	//float RandomAngle = texture2D(noisetex, texcoord * 20.0f).r * 100.0f;	
		  //RandomAngle = fract(RandomAngle + frameTimeCounter * 8.0)*0.05;
	float RandomAngle = 0.0;	
	#else
	float RandomAngle = 0.0;	
	#endif

	float transparencyFactor = 0.15*transparencyFactorTime*skylightMap;
	vec4 color = texture2D(colortex0, texcoord) * glcolor;
		 color *= texture2D(lightmap, lmcoord);

		//water//
		if (iswater == 1.0){
			if (isEyeInWater < 1.0) {
		  		color.a *= (waterTransparency+0.6);
		  		color.rgb *= transparencyFactor;
			} else {
				//color.a *= (waterTransparency+0.5);
		  		color.rgb *= transparencyFactor;
			}
		//glass//
		} else if (isglass == 1.0){
		 color.rgb *= transparencyFactor*3.33;
		// color.a *= 1.2;
		} else {
		 color.rgb *= transparencyFactor*3.0;
		 //color.a *= 0.8;
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
		// Glass gets smooth flat normal
		normalTangentSpace = vec4(viewNormal * 0.5 + 0.5, 1.0);
	} else {
		// Water gets wavy normal
		normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	}
	// Reflected skybox
	vec3 reflectedVector = reflect(fragpos, normalize(bump * tbnMatrix).xyz) * 300.0;
	if (isglass > 0.5) {
		reflectedVector = reflect(fragpos, viewNormal) * 300.0;
	}
	vec3 skybox = getSkyTextureFromSequence(position.xyz+reflectedVector);
		 skybox += vec3(skyColor*0.5) * (rainStrength * 0.5);
	     skybox = pow(skybox, vec3(3.2))*2;
	     //skybox = luminance(skybox, 1.15);
	     skybox = clamp(skybox*(1-rainStrength*0.6), vec3(0.0), vec3(1.0));

	#endif

	// SSS for water waves //
	//#ifdef WaterSSS
	
		vec3 sunDir = normalize(shadowLightPosition);
		vec2 sunDirHoriz = normalize(sunDir.xz);
		vec2 waveTilt = bump.xy;
		
		float tiltTowardSun = dot(waveTilt, sunDirHoriz);
		float sssMask = smoothstep(0.05, -0.15, tiltTowardSun);
		
		float tiltMagnitude = length(waveTilt);
		sssMask *= smoothstep(0.0, 0.07, tiltMagnitude);
		
		vec3 viewDir = normalize(viewVector);
		float viewFactor = pow(max(dot(viewDir, sunDir), 0.0), 1.5) * 0.5 + 0.5;
		
		float sssIntensity = sssMask * viewFactor * 0.7 * transparencyFactorTime;
		sssIntensity *= skylightMap;
		sssIntensity *= (1.0 - rainStrength * 0.7);

		float frontGlowMask = smoothstep(-0.05, 0.2, tiltTowardSun);
		frontGlowMask *= smoothstep(0.0, 0.1, tiltMagnitude);

		float frontGlow = frontGlowMask * viewFactor * 0.7 * transparencyFactorTime;
		frontGlow *= skylightMap;
		frontGlow *= (1.0 - rainStrength * 0.7);

		float packedWaveLight = 0.5 + (frontGlow * 0.5) - (sssIntensity * 0.5);
			  packedWaveLight = clamp(packedWaveLight, 0.0, 1.0);
	//#endif
	
/* DRAWBUFFERS:012583 */
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 1, 1);
	gl_FragData[2] = vec4(lmcoord, material, 1.0f);
	gl_FragData[3] = normalTangentSpace;
	gl_FragData[4] = vec4(skybox, 1.0);
	gl_FragData[5] = vec4(vec3(0.0), packedWaveLight);
}