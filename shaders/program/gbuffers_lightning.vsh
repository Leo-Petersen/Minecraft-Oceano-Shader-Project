#include "/lib/settings.glsl"

varying vec4 glcolor;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
	gl_Position = ftransform();
	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif
	
	glcolor = gl_Color;
}
