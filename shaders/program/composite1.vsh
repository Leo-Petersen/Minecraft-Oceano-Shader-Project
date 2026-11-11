
varying vec2 texcoord;

uniform mat4 gbufferModelViewInverse;

#include "/lib/settings.glsl"
#include "/lib/atmFrame.glsl"

void main(){
	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0.xy;	

	computeAtmFrame(true);
}
