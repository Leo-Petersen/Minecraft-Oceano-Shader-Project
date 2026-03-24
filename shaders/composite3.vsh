#version 130

varying vec2 texcoord;
varying vec4 position;
uniform mat4 gbufferModelViewInverse;
uniform vec3 upPosition;

varying float dist;

varying vec2 lmcoord;

varying vec3 viewVector;
varying vec3 viewNormal;
varying vec3 upVec;

varying mat3 tbnMatrix;

attribute vec4 at_tangent;

void main() {
	gl_Position = ftransform();

	position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	upVec = upPosition * 0.01;

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    viewNormal = normalize(gl_NormalMatrix*gl_Normal);

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, viewNormal));

    tbnMatrix = transpose(mat3(tangent, binormal, viewNormal));

	dist = length(gl_ModelViewMatrix * gl_Vertex);
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);

}