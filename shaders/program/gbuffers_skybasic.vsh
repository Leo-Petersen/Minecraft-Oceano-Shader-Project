#include "/lib/settings.glsl"



#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
	gl_Position = ftransform();
	gl_FogFragCoord = gl_Position.z;

	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif


	


}
