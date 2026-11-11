


uniform sampler2D colortex15;   // sky-view LUT

uniform float viewWidth, viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float rainStrength;

uniform vec3 sunPosition;
uniform vec3 moonPosition;


#include "/lib/time.glsl"
#include "/lib/settings.glsl"
#include "/lib/atmosphereLUT.glsl"

vec3 getSkyDir() {
    vec2 ndc = gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0;
    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
    viewPos /= viewPos.w;
    return normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);
}

void main() {
    vec3 rd  = getSkyDir();
    vec2 res = vec2(viewWidth, viewHeight);

    vec3 sunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 moonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);

    vec3 sky = atmSky(colortex15, res, rd, sunDir);
    sky = atmSkyFinish(sky, rd, sunDir, moonDir);

    sky = max(sky, vec3(0.0));

/* DRAWBUFFERS:9 */
    gl_FragData[0] = vec4(sky, 1.0);
}
