#version 120
#include "/lib/settings.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
    viewNormal = normalize(gl_NormalMatrix*gl_Normal);
	gl_Position = ftransform();
	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif
	
	texcoord = gl_MultiTexCoord0.st;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}