
varying vec2 texcoord;
varying vec4 position;
uniform mat4 gbufferModelViewInverse;

varying float dist;


varying vec3 viewVector;
varying vec3 viewNormal;


attribute vec4 at_tangent;

#include "/lib/settings.glsl"
#include "/lib/atmFrame.glsl"

void main() {
	gl_Position = ftransform();

	position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    viewNormal = normalize(gl_NormalMatrix*gl_Normal);

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, viewNormal));

    mat3 tbnMatrix = transpose(mat3(tangent, binormal, viewNormal));

	dist = length(gl_ModelViewMatrix * gl_Vertex);
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);

	computeAtmFrame(true);
}
