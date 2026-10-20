uniform sampler2D colortex14;
uniform sampler2D colortex15;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;

#include "/lib/atmosphereLUT.glsl"

varying vec3 atmSunFrame;
varying vec3 atmAmbFrame;

void computeAtmFrame(bool sunFromShadowLight) {
    vec3 sunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 sunDir  = sunFromShadowLight ? normalize(mat3(gbufferModelViewInverse) * shadowLightPosition) : sunTrue;
    vec2 res = vec2(viewWidth, viewHeight);
    atmSunFrame = atmSunColor(colortex14, res, sunDir);
    atmAmbFrame = atmSkyAmbient(colortex15, res, sunTrue);
}
