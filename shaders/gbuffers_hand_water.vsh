#version 130
#include "/lib/settings.glsl"

varying float material;
varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 viewNormal;
varying vec3 viewVector;
varying vec3 wpos;
varying vec3 lightVector;

varying vec4 glcolor;
varying vec4 position;

varying mat3 tbnMatrix;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

uniform float frameTimeCounter;
uniform int worldTime;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

#define transMAD(mat, v) (mat3(mat) * (v) + (mat)[3].xyz)
#define diagonal4(mat) vec4((mat)[0].x, (mat)[1].y, (mat)[2].zw)
#define projMAD4(mat, v) (diagonal4(mat) * (v.xyzz) + (mat)[3].xyzw)

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {

	gl_Position = ftransform();
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = sunPosition;
	}

	else {
		lightVector = -sunPosition;
	}

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	glcolor = gl_Color;

    viewNormal = normalize(gl_NormalMatrix*gl_Normal);
	
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    vec3 binormal = normalize(cross(tangent, viewNormal));

    tbnMatrix = transpose(mat3(tangent, binormal, viewNormal));

	dist = length(gl_ModelViewMatrix * gl_Vertex);
	viewVector = ( gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = (tbnMatrix * viewVector);
	position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	vec3 viewpos = transMAD(gl_ModelViewMatrix, gl_Vertex.rgb);
		 viewpos = transMAD(gbufferModelViewInverse, viewpos);

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;

	viewpos = transMAD(gbufferModelView, viewpos);
	gl_Position = projMAD4(gl_ProjectionMatrix, viewpos);
	
    #ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif

	material = 0.15;

}
