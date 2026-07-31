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
uniform vec3 sunPosition;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex14;  // transmittance + multiscatter LUT
uniform sampler2D colortex15;  // sky-view LUT
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float PI;
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
const int colortex10Format = RGBA16F;
const bool colortex10Clear = false;
*/

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/atmosphereLUT.glsl"
vec3 atmSunDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
vec3 atmSunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);
vec3 atmSun = atmSunColor(colortex14, vec2(viewWidth, viewHeight), atmSunDir);
vec3 atmAmb = atmSkyAmbient(colortex15, vec2(viewWidth, viewHeight), atmSunTrue);
#define atmosphereSun
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

	vec4  cloudLowRes = vec4(0.0, 0.0, 0.0, 1.0);
	float cloudDist   = 1e6;
	#ifdef VolumetricClouds
	{
		const int area = cloudUpscale * cloudUpscale;
		vec2 cornerSize = floor(vec2(viewWidth, viewHeight) / float(cloudUpscale));
		if (gl_FragCoord.x < cornerSize.x && gl_FragCoord.y < cornerSize.y) {
			ivec2 texel = ivec2(gl_FragCoord.xy);
			ivec2 checkerPos = cloudUpscale * texel
			                 + vcCheckerOffset(frameCounter % area);
			vec2  fullUV = (vec2(checkerPos) + 0.5) / vec2(viewWidth, viewHeight);

			// only march samples that will actually be composited!!
			if (texture2D(depthtex0, fullUV).r >= 1.0) {
				vec4 dClip = vec4(fullUV, 1.0, 1.0) * 2.0 - 1.0;
				vec4 dView = gbufferProjectionInverse * dClip; dView /= dView.w;
				vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * dView.xyz);

				float dith = vcBayer8(vec2(checkerPos));
				dith = fract(dith + float(frameCounter / area) * 0.61803399);

				cloudLowRes = computeVolumetricClouds(worldDir, 1e9, dith, cloudSteps, atmSunTrue.y, cloudDist);
			}
		}
	}
	#endif

/* RENDERTARGETS: 0,12,10 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = cloudLowRes;
	gl_FragData[2] = vec4(texelFetch(colortex10, ivec2(gl_FragCoord.xy), 0).rg, cloudDist, 0.0);

}
