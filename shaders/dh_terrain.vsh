#version 430 compatibility

#include "/lib/settings.glsl"

uniform mat4  gbufferModelViewInverse;
uniform vec3  cameraPosition;

varying float material;
varying float dist;
varying vec2  lmcoord;
varying vec2  texcoord;
varying vec3  viewNormal;
varying vec3  worldpos;
varying vec4  glcolor;
flat out int  dhMat;

uniform mat4  dhProjection;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
    gl_Position = dhProjection * gl_ModelViewMatrix * gl_Vertex;

    vec4 wp = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    worldpos = wp.xyz + cameraPosition;

    #ifdef TAA
    gl_Position.xy = taaJitter(gl_Position.xy, gl_Position.w);
    #endif

    texcoord   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord    = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);

    dist = length((gl_ModelViewMatrix * gl_Vertex).xyz);

    dhMat    = 0;
    material = 1.0;
    #ifdef DH_BLOCK_LEAVES
    if (dhMaterialId == DH_BLOCK_LEAVES) { material = 0.01; dhMat = DH_BLOCK_LEAVES; }
    #endif
    #ifdef DH_BLOCK_GRASS
    if (dhMaterialId == DH_BLOCK_GRASS)  { material = 0.03; dhMat = DH_BLOCK_GRASS;  }
    #endif
    #ifdef DH_BLOCK_ILLUMINATED
    if (dhMaterialId == DH_BLOCK_ILLUMINATED) dhMat = DH_BLOCK_ILLUMINATED;
    #endif

    float baseAo = 0.5;
    #ifdef AO
    baseAo = 1.0;
    #endif
    glcolor = gl_Color;
    glcolor.a   = clamp(sqrt(glcolor.a), baseAo, 1.0);
    glcolor.rgb *= glcolor.a;
}
