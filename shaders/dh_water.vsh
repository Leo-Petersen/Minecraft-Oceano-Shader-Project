#version 430 compatibility

#include "/lib/settings.glsl"

varying float material;
varying float dist;

varying vec2  lmcoord;
varying vec2  texcoord;

varying vec3  viewNormal;
varying vec3  viewVector;
varying vec3  wpos;

varying vec4  glcolor;
varying vec4  viewPosV;

varying mat3  tbnMatrix;

uniform mat4  dhProjection;
uniform mat4  gbufferModelView, gbufferModelViewInverse;
uniform vec3  cameraPosition;

#ifdef TAA
#include "/lib/jitter.glsl"
#endif

void main() {
    viewPosV    = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = dhProjection * viewPosV;

    #ifdef TAA
    gl_Position.xy = taaJitter(gl_Position.xy, gl_Position.w);
    #endif

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    viewNormal = normalize(gl_NormalMatrix * gl_Normal);

    vec3 tangent  = normalize(gbufferModelView[0].xyz);
    vec3 binormal = normalize(gbufferModelView[2].xyz);
    tbnMatrix = mat3(tangent.x, binormal.x, viewNormal.x,
                     tangent.y, binormal.y, viewNormal.y,
                     tangent.z, binormal.z, viewNormal.z);

    viewVector = tbnMatrix * viewPosV.xyz;

    wpos = (gbufferModelViewInverse * viewPosV).xyz + cameraPosition;

    dist    = length(viewPosV.xyz);
    glcolor = gl_Color;

    material = 0.09;
    #ifdef DH_BLOCK_WATER
    if (dhMaterialId == DH_BLOCK_WATER) material = 0.09;
    #endif
}
