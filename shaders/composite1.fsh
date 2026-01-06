#version 120
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

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"

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
	float borderFog = clamp(pow(length(worldPos.xz) / far, 14.0)*0.7, 0.0, 1.0);
	if (Depth < 1.0) {
		#ifdef BorderFog
		if (iswater < 1.0) {
			if (isEyeInWater < 0.9) color.rgb = mix(color.rgb, skyBoxCol*(1-effects*0.95), borderFog);
		}
		#endif
	} else {
		if (isEyeInWater < 0.9) color.rgb = skyBoxCol*(1-effects*0.95);
	}

/*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
	
}
