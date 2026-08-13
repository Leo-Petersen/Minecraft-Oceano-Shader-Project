#version 430 compatibility

#include "/lib/settings.glsl"

varying vec2 lmcoord;
varying vec3 viewNormal;
varying vec3 blockNormal;

void main() {
    gl_Position = ftransform();

    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    blockNormal = gl_Normal;
}
