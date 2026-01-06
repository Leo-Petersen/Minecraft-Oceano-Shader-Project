#version 120
#include "/lib/settings.glsl"

varying float dist;

varying float material;
varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;
varying vec3 viewVector;
varying vec3 viewNormal;
varying vec4 glcolor;
varying vec4 vtexcoordam;

varying mat3 tbnMatrix;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

#ifdef TAA
//#include "/lib/jitter.glsl"
#endif

void main() {

    //Materials//
        material = 1.0;
        //foliage//
        if (mc_Entity.x == 11050 ||
            mc_Entity.x == 11060 ||
            mc_Entity.x == 11080 ) {
                material = 0.01;
            }

        //grass + fire//
        if (mc_Entity.x == 11000 ||
            mc_Entity.x == 11010 ||
            mc_Entity.x == 11020 ||
            mc_Entity.x == 11030 ||
            mc_Entity.x == 11040 ||
            mc_Entity.x == 12153 ) {
                material = 0.03;
            }

        //metals//
        if (mc_Entity.x == 13020 ) material = 0.05;

        //emissives//
        if (mc_Entity.x == 12000 ||
            mc_Entity.x == 12001 ||
            mc_Entity.x == 12070 ||
            mc_Entity.x == 12090 ||
            mc_Entity.x == 12130 ||
            mc_Entity.x == 12140 ||
            mc_Entity.x == 12150 ||
            mc_Entity.x == 12151 ||
            mc_Entity.x == 12152 ||
            mc_Entity.x == 12153 ) material = 0.07;

        //glass//
        if (mc_Entity.x == 13000) material = 0.09;
        if (mc_Entity.x == 13010) material = 0.11;
        if (mc_Entity.x == 12152) material = 0.13;

    viewNormal = normalize(gl_NormalMatrix*gl_Normal);
	gl_Position = ftransform();
	#ifdef TAA
	//gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
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