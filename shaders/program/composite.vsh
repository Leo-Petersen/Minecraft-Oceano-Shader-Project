
varying vec2 texcoord;

varying vec3 viewVector;
varying vec3 viewNormal;


attribute vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;

#include "/lib/settings.glsl"
#include "/lib/atmFrame.glsl"

void main() {
	gl_Position = ftransform();
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	viewNormal = normalize(gl_NormalMatrix*gl_Normal);

	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, viewNormal));

    mat3 tbnMatrix = transpose(mat3(tangent, binormal, viewNormal));

	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);

	computeAtmFrame(false);
}
