#version 400 compatibility
#include "/lib/settings.glsl"

varying vec4 starData; //rgb = star color, a = flag for whether or not this pixel is a star.
varying vec4 gcolor;
varying vec4 position;
varying float stars;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
varying vec2 texcoord;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
	gl_Position = ftransform();
	gl_FogFragCoord = gl_Position.z;

	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif

	gcolor = gl_Color;

	stars = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	starData = vec4(gl_Color.rgb, float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0));
}