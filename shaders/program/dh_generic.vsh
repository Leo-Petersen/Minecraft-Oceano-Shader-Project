#include "/lib/settings.glsl"

uniform mat4  gbufferModelViewInverse;
uniform vec3  cameraPosition;
uniform mat4  dhProjection;

varying vec3  viewNormal;
varying vec3  worldpos;
varying vec4  glcolor;

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

    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    glcolor    = gl_Color;
}
