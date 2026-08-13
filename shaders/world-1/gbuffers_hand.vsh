#version 130
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
#include "/world-1/lib/jitter.glsl"
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
            mc_Entity.x == 51 ) {
                material = 0.03;
            }

        //metals//
        if (mc_Entity.x == 13020 ) material = 0.05;

        //emissives//
        if (mc_Entity.x == 12070 ||    // ender chest (BSL)
            mc_Entity.x == 12090 ||    // redstone ore (BSL)
            mc_Entity.x == 10 ||       // lava
            mc_Entity.x == 50 ||       // torch
            mc_Entity.x == 51 ||       // fire
            mc_Entity.x == 55 ||       // redstone wire
            mc_Entity.x == 62 ||       // furnace
            mc_Entity.x == 76 ||       // redstone torch
            mc_Entity.x == 89 ||       // glowstone
            mc_Entity.x == 91 ||       // jack o lantern
            mc_Entity.x == 138 ||      // beacon
            mc_Entity.x == 169 ||      // sea lantern
            mc_Entity.x == 198 ||      // end rod
            mc_Entity.x == 213 ||      // magma
            mc_Entity.x == 10050 ||    // lantern
            mc_Entity.x == 10052 ||    // soul fire/torch
            mc_Entity.x == 10124 ||    // redstone lamp
            mc_Entity.x == 10225 ||    // crying obsidian
            mc_Entity.x == 10230 ||    // shroomlight
            mc_Entity.x == 10231 ||    // campfire
            mc_Entity.x == 10232 ||    // candles
            mc_Entity.x == 10233 ||    // amethyst
            mc_Entity.x == 10234 ||    // glow lichen
            mc_Entity.x == 10235 ||    // froglight ochre
            mc_Entity.x == 10236 ||    // froglight verdant
            mc_Entity.x == 10237 ||    // froglight pearlescent
            mc_Entity.x == 10238 ||    // sculk
            mc_Entity.x == 10239 ||    // respawn anchor
            mc_Entity.x == 10242      // cave vines
            ) material = 0.07;

        //glass//
        if (mc_Entity.x == 13000) material = 0.09;
        if (mc_Entity.x == 13010) material = 0.11;
        if (mc_Entity.x == 10) material = 0.13;

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