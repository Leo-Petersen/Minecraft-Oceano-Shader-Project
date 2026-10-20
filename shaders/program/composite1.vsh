
varying vec2 texcoord;
varying vec2 lmcoord;

uniform mat4 gbufferModelViewInverse;

#include "/lib/settings.glsl"
#include "/lib/atmFrame.glsl"

void main(){
	gl_Position = ftransform();
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	texcoord = gl_MultiTexCoord0.xy;	

	computeAtmFrame(true);
}
