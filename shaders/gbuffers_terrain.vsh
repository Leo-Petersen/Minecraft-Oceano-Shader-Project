#version 120

#include "/lib/settings.glsl"

varying float material;
varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;

varying vec3 viewNormal;
varying vec3 viewVector;
varying vec3 worldpos;

varying mat3 tbnMatrix;

varying vec4 glcolor;
varying vec4 vtexcoordam;
varying vec4 position;

uniform vec3 cameraPosition;
uniform vec3 sunVec;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform float rainStrength;

uniform float frameTimeCounter;

attribute vec4 mc_midTexCoord;
attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;

#ifdef wavingFoliage
#include "/lib/vertexDisplacement.glsl"
#endif
#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {

	vec3 viewpos = mat3(gbufferModelViewInverse) * (gl_ModelViewMatrix * gl_Vertex).xyz + gbufferModelViewInverse[3].xyz;
    vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		 worldpos = position.xyz + cameraPosition;
        
    #ifdef wavingFoliage
	vec3 worldpos = viewpos.xyz + cameraPosition;
		viewpos = doVertexDisplacement(viewpos, worldpos);
        //lava//
        float fy = fract(worldpos.y + 0.01);
        if (fy > 0.02 && mc_Entity.x == 10) {

            //Vertex Displacement
            //viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.5 + 0.5) * (sin(frameTimeCounter) * 0.5 + 0.5) * 0.05;
            //viewpos.y += (sin((worldpos.x - worldpos.z) + frameTimeCounter * 3.0) * 0.5 + 0.5) * 0.07;

            viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.15 + 0.15) * (sin(frameTimeCounter) * 0.5 + 0.5) * 0.05;
            viewpos.y += (cos((worldpos.x + worldpos.z) + frameTimeCounter * 2.0) * 0.1 + 0.1) * 0.05;
            viewpos.y += (sin((worldpos.x - worldpos.z) + frameTimeCounter * 3.0) * 0.15 + 0.15) * 0.07;
        }
        
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(viewpos, 1.0);
    #ifdef TAA
	gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
	#endif
    
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	viewNormal = normalize(gl_NormalMatrix*gl_Normal);
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = mat3(tangent.x, binormal.x, viewNormal.x,
					 tangent.y, binormal.y, viewNormal.y,
					 tangent.z, binormal.z, viewNormal.z);
    vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2;
	vtexcoordam.st  = min(texcoord.xy ,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
    dist = length(gl_ModelViewMatrix * gl_Vertex);
    viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
    
    float baseAo = 0.5;
    #ifdef AO
    baseAo = 1.0;
    #endif
    
    //Materials//
        material = 1.0;
        //foliage//
        if (mc_Entity.x == 11050 ||
            mc_Entity.x == 11060 ||
            mc_Entity.x == 11080 ) {
                material = 0.01;
                baseAo = 0.9;
            }

        //grass + fire//
        if (mc_Entity.x == 11000 ||
            mc_Entity.x == 11010 ||
            mc_Entity.x == 11020 ||
            mc_Entity.x == 11030 ||
            mc_Entity.x == 11040 ||
            mc_Entity.x == 51 ) {
                material = 0.03;
                baseAo = 0.9;
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
        if (mc_Entity.x == 13031) material = 0.13;
        if (mc_Entity.x == 13050) material = 0.19;

    glcolor = gl_Color;

    glcolor.a = clamp(sqrt(glcolor.a), baseAo, 1.0);
	glcolor.rgb *= glcolor.a;
}