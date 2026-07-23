#version 130

#include "/lib/settings.glsl"

/*
const int colortex0Format = R11F_G11F_B10F;
#ifdef PHOTONICS_ENABLED
const int colortex12Format = RGBA16F;   // Photonics: indirect GI
#endif
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

#ifdef tonemapSaturation
vec3 luminance(vec3 color, float str) {
    const vec3 lw = vec3(0.2126, 0.7152, 0.0722);
    float luma = dot(color, lw);
    return luma + str * (color - luma);
}
#else
vec3 luminance(vec3 color, float str) {
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
		color *= exposure;
		color = luminance(color, saturation);

		//The following fixes colors being crushed due to not adgusting out of the srgb pipeline
		float shoulder = 0.5;
		vec3 over = max(color - shoulder, 0.0);
		float range = 1.0 - shoulder;
		color = min(color, shoulder) + range * (1.0 - exp(-over / range));

	#elif ToneMap == 1 //ACES//
		color = ACES(color * 0.85 * exposure); // Exposure adjustment (the way lighting is done leaves the scene overexposed, adjusting this looks better than adjusting the lighting itself)
		//color = ACES(color);
		color = luminance(color, saturation);

	#elif ToneMap == 2 //Filmic_Hejl2015//
		//color = vec3(1.0) - exp(-color * 1.4);
 		//color = pow(color, vec3(1.1));
		color = ToneMapFilmic_Hejl2015(color * exposure, 10.0); //(color.rgb input, float whitepoint)
		color = luminance(color, saturation);

	#elif ToneMap == 3 //Oceano (wip)//
 		color = pow(color, vec3(1/1.0));
		color = ACES(color * exposure);
		color = luminance(color, saturation);

	#elif ToneMap == 4 //AgX//
		//color *= 2;  // Exposure adjustment
		color = agxCdl(color * exposure, vec3(1.0), vec3(0.0), vec3(1.75), 1.2);
		color = vec3(1.0) - exp(-color * 3.0);
		//color = luminance(color, saturation);
	#endif

	// //Duiker//
	// if (ToneMap == 4) {
	//     color = vec3(1.0) - exp(-color * 0.07);
 	// 	color = pow(color, vec3(1.0));
	// 	color = Duiker(color);
	// 	color = luminance(color, saturation);
	// }

    #ifdef PURKINJE_SHIFT
        float sceneLum = dot(color, vec3(0.2126, 0.7152, 0.0722));
        float adaptationLum = sceneLum * 0.5 + 0.01; // Rough estimate
        
        color = applyPurkinjeShift(color, adaptationLum);
    #endif

	//Colour Temperature
	#ifdef colorTemp
    	color *= colorTemperatureToRGB(colorTemperature);
	#endif

	#ifdef FilmGrain
		vec3 noise = (texture2D(noisetex,texcoord*vec2(aspectRatio,1.0)+4.0*frameTimeCounter).rgb*2.0-1.0)*0.013*filmGrain*(1+blindness*5)*(1+darknessFactor*5+darknessLightFactor);
			 color += noise;
	#endif
	
	// TPDF dither, breaks up quantization in smooth dark gradients
    vec2 dseed = gl_FragCoord.xy + frameTimeCounter * 17.0;
    float r1 = fract(sin(dot(dseed, vec2(12.9898, 78.233))) * 43758.5453);
    float r2 = fract(sin(dot(dseed + 1.7, vec2(12.9898, 78.233))) * 43758.5453);
    color.rgb += (r1 + r2 - 1.0) / 255.0;

/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}