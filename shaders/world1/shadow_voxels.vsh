#version 430 compatibility

#include "/lib/settings.glsl"

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying vec3 playerPos;
varying vec3 blockNormal;

void main() {
    blockNormal = gl_Normal;

    // Get player space position from shadow space vertex
    vec4 pos = shadowModelViewInverse * shadowProjectionInverse * ftransform();
    playerPos = pos.xyz;

    gl_Position = shadowProjection * shadowModelView * pos;

    // Apply distortion matching shadow.vsh
    float dist = length(gl_Position.xy);
    float distortFactor = (1.0 - shadowDistortion) + dist * shadowDistortion;
    gl_Position.xy /= distortFactor;
    gl_Position.z *= 0.2;
}
