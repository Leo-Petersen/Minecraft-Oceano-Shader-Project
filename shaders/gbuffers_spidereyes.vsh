#version 120
#include "/lib/settings.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
	gl_Position = ftransform();
	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif
	 
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}