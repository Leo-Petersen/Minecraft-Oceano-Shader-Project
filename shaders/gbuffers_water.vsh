#version 120
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

	float fy = fract(worldpos.y + 0.001);
	if (fy > 0.02 && mc_Entity.x == 13000) {

		//Vertex Displacement
		//viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.5 + 0.5) * (sin(frameTimeCounter) * 0.5 + 0.5) * 0.05;
		//viewpos.y += (sin((worldpos.x - worldpos.z) + frameTimeCounter * 3.0) * 0.5 + 0.5) * 0.07;

		viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.15 + 0.15) * (sin(frameTimeCounter) * 0.5 + 0.5) * 0.14;
		viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.1 + 0.1) * 0.14;
		viewpos.y += (sin((worldpos.x - worldpos.z) + frameTimeCounter * 3.0) * 0.15 + 0.15) * 0.14;
	}

	viewpos = transMAD(gbufferModelView, viewpos);
	gl_Position = projMAD4(gl_ProjectionMatrix, viewpos);
	
    #ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif

	//water//
	//material = 0.0;
	if (mc_Entity.x == 13000) material = 0.09;
    if (mc_Entity.x == 13010) material = 0.11;
		
	//if (material != 0.09 && material != 0.11) material = 0.0;

}