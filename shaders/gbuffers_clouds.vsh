#version 120
#include "/lib/settings.glsl"

#ifdef defaultClouds
    varying vec2 texcoord;
    varying vec4 glcolor;

    #ifdef TAA
    #include "/lib/jitter.glsl"
    #endif
#endif

void main() {
    #ifdef defaultClouds
        gl_Position = ftransform();
        #ifdef TAA
        gl_Position.xy = taaJitter(gl_Position.xy,gl_Position.w);
        #endif
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        glcolor = gl_Color;
    #endif
}