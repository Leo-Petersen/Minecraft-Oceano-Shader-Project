#version 120

#include "/lib/settings.glsl"

/*
const int colortex0Format = R11F_G11F_B10F;
*/

uniform sampler2D noisetex;
uniform sampler2D depthtex2;
uniform sampler2D colortex11;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float eyeAltitude;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float centerDepthSmooth;

uniform sampler2D colortex0; //.rgb = color
uniform sampler2D depthtex0;

varying vec2 texcoord;
varying vec2 lmcoord;

float Depth = texture2D(depthtex0, texcoord).r;

#ifdef Saturation
vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	//color = color + (color-luma)*strength*0.1;
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}
#else

vec3 luminance(vec3 color, float strength) {
	return color;
}
#endif

#ifdef DOF
#include "/lib/DOF.glsl"
#endif

#include "/lib/toneMap.glsl"

void main() {

	
	vec3 color = texture2D(colortex0, texcoord).rgb;
	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	#ifdef DOF
		 color = getDOF(color);
	#endif

	#if ToneMap == 0 //Default MC Tonemap//
	    //nothing, its minecraft

	#elif ToneMap == 1 //ACES//
		color = ACES(color);
		color = luminance(color, saturation);

	#elif ToneMap == 3 //Oceano (wip)//
 		color = pow(color, vec3(1/1.45));
		color = ACES(color);
		color = luminance(color, saturation);

	#elif ToneMap == 2 //Filmic_Hejl2015//
		//color = vec3(1.0) - exp(-color * 1.4);
 		//color = pow(color, vec3(1.1));
		color = ToneMapFilmic_Hejl2015(color, 10.0); //(color.rgb input, float whitepoint)
		color = luminance(color, saturation);
	
	#elif ToneMap == 4 //AgX//
		//color *= 2;  // Exposure adjustment
		color = agxCdl(color, vec3(1.0), vec3(0.0), vec3(1.6), 1.2);
		color = vec3(1.0) - exp(-color * 4.0);
		//color = luminance(color, saturation);
	#endif

	// //Duiker//
	// if (ToneMap == 4) {
	//     color = vec3(1.0) - exp(-color * 0.07);
 	// 	color = pow(color, vec3(1.0));
	// 	color = Duiker(color);
	// 	color = luminance(color, saturation);
	// }

	
	//Colour Temperature
	#ifdef colorTemp
    	color *= colorTemperatureToRGB(colorTemperature);
	#endif

	#ifdef FilmGrain
		vec3 noise = (texture2D(noisetex,texcoord*vec2(aspectRatio,1.0)+4.0*frameTimeCounter).rgb*2.0-1.0)*0.013*filmGrain*(1+blindness*5)*(1+darknessFactor*5+darknessLightFactor);
			 color += noise;
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}