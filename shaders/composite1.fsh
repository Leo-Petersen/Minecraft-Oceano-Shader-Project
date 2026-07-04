#version 130
#extension GL_ARB_shader_texture_lod : enable

varying vec2 texcoord;
varying vec2 lmcoord;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float blindness;
uniform float darknessFactor;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform vec3 skyColor;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex9;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

/*
const int colortex12Format = RGBA16F;
const bool colortex12Clear = false;
const int colortex11Format = RGBA16F;
const bool colortex11Clear = false;
*/

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/clouds.glsl"

float undergroundFix = clamp(mix(max(lmcoord.t-2.0/16.0,0.0)*1.14285714286,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)), 0.0, 1.0);

void main(){
	vec3 color = texture2DLod(colortex0,texcoord.xy,0).rgb;
	vec2 lightMap = texture2D(colortex2, texcoord).st;
	float Depth = texture2D(depthtex0, texcoord).r;
	float material = texture2D(colortex2, texcoord).p;
	float iswater = float(material > 0.08 && material < 0.10);
	vec3 skyBoxCol = texture2D(colortex9, texcoord).rgb;

	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	float blindnessFog = clamp(pow(length(worldPos.xz) / 1*blindness, 0.3) * 0.5, 0.0, 1.0);
	if (blindness > 0.0) color.rgb = mix(color*(1-blindness*0.5), color*0.04, blindnessFog);

	float darknessFog = clamp(pow(length(worldPos.xz) / 8*darknessFactor, 1.0) * 0.5, 0.0, 1.0);
	if (darknessFactor > 0.0) color = mix(color, color*0.04, darknessFog);

	float effects = blindness+darknessFactor;
	// float borderFog = clamp(pow(length(worldPos.xz) / far, 14.0)*0.7, 0.0, 1.0);
	if (Depth < 1.0) {
		// #ifdef BorderFog
		// if (iswater < 1.0) {
		// 	if (isEyeInWater < 0.9) color.rgb = mix(color.rgb, skyBoxCol*(1-effects*0.95), borderFog);
		// }
		// #endif
	} else {
		if (isEyeInWater < 0.9) color.rgb = skyBoxCol*(1-effects*0.95);
	}

	//// Half-res volumetric cloud corner ////
	// Only the bottom-left CLOUDS_QUALITY rectangle marches. It packs the whole
	// sky's clouds at reduced resolution; composite3 reads and upscales it.
	// The rectangle is contiguous, so warps outside it skip the march entirely.
	vec4 cloudLowRes = vec4(0.0, 0.0, 0.0, 1.0);
	#ifdef VolumetricClouds
	{
		vec2 cornerSize = vec2(viewWidth, viewHeight) * CLOUDS_QUALITY;
		if (gl_FragCoord.x < cornerSize.x && gl_FragCoord.y < cornerSize.y) {
			// Jitter the sampled direction by this frame's sub-cell offset.
			// composite3 compensates for the same offset when it reconstructs,
			// so the eight-frame pattern rebuilds full resolution.
			vec2 dirUV = (floor(gl_FragCoord.xy) + 0.5 + vcOffset8(frameCounter)) / cornerSize;
			dirUV = clamp(dirUV, 0.0, 1.0);

			vec4 dClip = vec4(dirUV, 1.0, 1.0) * 2.0 - 1.0;   // far plane direction
			vec4 dView = gbufferProjectionInverse * dClip; dView /= dView.w;
			vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * dView.xyz);

			float dith = vcBayer8(gl_FragCoord.xy);
			#ifdef TAA
				dith = fract(dith + float(frameCounter & 15) * 0.0625);
			#endif
			cloudLowRes = computeVolumetricClouds(worldDir, 1e9, dith, VC_STEPS);
		}
	}
	#endif

/* RENDERTARGETS: 0,12 */
	gl_FragData[0] = vec4(color,1.0);
	gl_FragData[1] = cloudLowRes;

}
