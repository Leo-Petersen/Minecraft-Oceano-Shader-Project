#version 120

uniform sampler2D lightmap;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex11;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float aspectRatio;

uniform int isEyeInWater;

uniform vec3 shadowLightPosition;

varying float material;
varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 viewNormal;
varying vec3 viewVector;
varying vec3 wpos;

varying vec4 glcolor;

varying mat3 tbnMatrix;

#include "/lib/settings.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/time.glsl"
#include "/lib/encode.glsl"

float transparencyFactorTime = 0.25 * (time[0]) +  
					   	       1.0 * (time[1]) +
					   		   1.0 * (time[2]) + 
					   		   1.0 * (time[3]) + 
					   		   0.25 * (time[4]) + 
					   		   0.4 * (time[5]);
void main() {
	float iswater = float(material > 0.08 && material < 0.10);
    float isglass = float(material > 0.10 && material < 0.12);
	float skylightMap = texture2D(colortex2, texcoord).t;
		  skylightMap = clamp(skylightMap, min_skyLightMap, 1.0);
		  skylightMap = pow(skylightMap, 0.1);

	#ifdef Reflections
	float waterTransparency = 1-iswater;
	#else
	float waterTransparency = 1-iswater*0.3;
	#endif

	#ifdef TAA
	float RandomAngle = texture2D(noisetex, texcoord * 20.0f).r * 100.0f;	
		  RandomAngle = fract(RandomAngle + frameTimeCounter * 8.0)*0.05;
	#else
	float RandomAngle = 0.0;	
	#endif

	float transparencyFactor = (0.1*transparencyFactorTime)*(skylightMap);
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
		 //color.a *= 0.8;
		} else {
		 color.rgb *= transparencyFactor*3.0;
		 //color.a *= 0.8;
		}


	#ifdef Reflections
		#ifdef ParallaxWater
			vec3 posxz = wpos.xyz;
				posxz = getParallaxDisplacement(posxz, iswater);

			vec3 bump;
				bump = getWaveHeight(posxz.xz - posxz.y,iswater, RandomAngle);
			const float bumpmult = 0.4 * (WaterDepth - 0.25);
		#else
			vec3 bump;
				bump = getWaveHeight((wpos.xz - wpos.y),iswater, RandomAngle);
			const float bumpmult = 0.4 * (WaterDepth - 0.25);
		#endif		

	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	vec4 normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

	#endif

	vec2 lightMap = vec2(1.0);
		 lightMap.s = clamp(lmcoord.s - 1.0 / 32.0, 0.0, 1.0);
		 lightMap.t = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);

/* DRAWBUFFERS:0125 */
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 1, 1);
	gl_FragData[2] = vec4(lightMap, material, 1.0f);
	#ifdef Reflections
	gl_FragData[3] = normalTangentSpace;
	#endif
}