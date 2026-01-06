#version 120
#include "/lib/settings.glsl"

varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;
varying vec3 viewVector;
varying vec3 viewNormal;
varying vec4 glcolor;
varying vec4 vtexcoordam;

varying mat3 tbnMatrix;

attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
    viewNormal = normalize(gl_NormalMatrix*gl_Normal);
	gl_Position = ftransform();
	#ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = mat3(tangent.x, binormal.x, viewNormal.x,
					 tangent.y, binormal.y, viewNormal.y,
					 tangent.z, binormal.z, viewNormal.z);
					 
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2;
	vtexcoordam.st  = min(texcoord.xy ,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
    dist = length(gl_ModelViewMatrix * gl_Vertex);
    viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;

	texcoord = gl_MultiTexCoord0.st;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}