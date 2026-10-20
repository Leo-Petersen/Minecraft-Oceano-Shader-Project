#include "/lib/settings.glsl"

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
	
	texcoord = gl_MultiTexCoord0.st;
	glcolor = gl_Color;
}
