


varying vec2 texcoord;

uniform mat4 gbufferModelViewInverse;

#include "/lib/settings.glsl"
#include "/lib/atmFrame.glsl"

void main() {


	gl_Position = ftransform();

	texcoord.xy = gl_MultiTexCoord0.st;

	computeAtmFrame(false);
}
