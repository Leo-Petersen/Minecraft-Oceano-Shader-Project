#version 120
#extension GL_ARB_shader_texture_lod : enable

varying vec2 texcoord;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

#include "/lib/settings.glsl"

//TAA//
#ifdef TAA
float Depth = texture2D(depthtex0, texcoord).r;
#include "/lib/taa.glsl"
#else

void main(){
	vec3 color = texture2DLod(colortex0,texcoord.xy,0).rgb;

/*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
	
}
#endif
