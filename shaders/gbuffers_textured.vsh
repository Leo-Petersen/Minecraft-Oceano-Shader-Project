#version 120
#include "/lib/settings.glsl"

uniform mat4 gbufferModelViewInverse;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
	vec3 position = mat3(gbufferModelViewInverse) * (gl_ModelViewMatrix * gl_Vertex).xyz + gbufferModelViewInverse[3].xyz;
    viewNormal = normalize(gl_NormalMatrix*gl_Normal);

	gl_Position = ftransform();
	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	gl_FogFragCoord = length(position.xyz);
}