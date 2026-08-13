#version 400 compatibility

varying vec2 texcoord;
varying vec2 lmcoord;

varying vec3 viewVector;
varying vec3 viewNormal;

varying mat3 tbnMatrix;

attribute vec4 at_tangent;

void main() {
	gl_Position = ftransform();
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	viewNormal = normalize(gl_NormalMatrix*gl_Normal);

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, viewNormal));

    tbnMatrix = transpose(mat3(tangent, binormal, viewNormal));

	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);
}