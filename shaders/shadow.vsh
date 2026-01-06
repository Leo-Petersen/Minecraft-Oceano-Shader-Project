#version 120

#include "/lib/settings.glsl"

varying float iswater;

varying vec2 texcoord;
varying vec4 color;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

vec4 calcShadowDistortion(in vec4 pos) {
    float distortFactor = (1.0 - shadowDistortion) + length(pos.xy) * shadowDistortion;
    pos.xy /= distortFactor;
    return pos;
}

#include "/lib/vertexDisplacement.glsl"

void main() {

    vec4 position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

    #ifdef wavingFoliage
        position.xyz = doVertexDisplacement(position.xyz, position.xyz + cameraPosition);
    #endif
    
    position = shadowProjection * shadowModelView * position;
    position = calcShadowDistortion(position);

    gl_Position = position;
    gl_Position.z /= 6.0;

    if (mc_Entity.x == 13000) {
        iswater = 1.00;
    }

    texcoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}