#version 430 compatibility

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D colortex2;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;

uniform float viewWidth, viewHeight, far, frameTimeCounter, rainStrength, nightVision, darknessLightFactor;
uniform vec3 skyColor;
uniform vec3 sunPosition;

varying float material;
varying float dist;
varying vec2  lmcoord;
varying vec2  texcoord;
varying vec3  viewNormal;
varying vec3  wpos;
varying vec4  glcolor;
varying vec4  viewPosV;
varying mat3  tbnMatrix;

vec3 atmSunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);

#include "/lib/settings.glsl"
#include "/lib/encode.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/sharedLighting.glsl"

float Bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float Bayer4(vec2 a)  { return Bayer2(0.5 * a) * 0.25 + Bayer2(a); }
float Bayer8(vec2 a)  { return Bayer4(0.5 * a) * 0.25 + Bayer2(a); }

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

    if (texture2D(depthtex1, uv).r < 1.0) discard;

    float iswater = 1.0;

    float skylightMap = texture2D(colortex2, texcoord).t;
    skylightMap = clamp(skylightMap, min_skyLightMap, 1.0);
    skylightMap = pow(skylightMap, 0.1);

    float transparencyFactor = 0.15 * getTransparencyFactor() * skylightMap;

    #ifdef Reflections
    float waterTransparency = 1.0 - iswater;
    #else
    float waterTransparency = 1.0 - iswater * 0.3;
    #endif

    vec4 color = texture2D(texture, texcoord) * glcolor;
    color *= texture2D(lightmap, lmcoord);
    color.a   *= (waterTransparency + 0.6);
    color.rgb *= transparencyFactor;

    vec3 bump = getWaveHeight((wpos.xz - wpos.y), 1.0, 0, dist);
    const float bumpmult = 0.5 * (WaterDepth + 0.5);
    bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);
    bump = normalize(clamp(bump, vec3(-1.0), vec3(1.0)));
    vec4 normalTangentSpace = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

    float packedWaveLight = 0.5;

    float dither  = Bayer8(gl_FragCoord.xy);
    float minDist = (dither - 0.75) * 16.0 + far;
    if (dist <= minDist) discard;

/* DRAWBUFFERS:01253 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 0.0, 1.0);
    gl_FragData[2] = vec4(lmcoord, material, 1.0);
    gl_FragData[3] = normalTangentSpace;
    gl_FragData[4] = vec4(vec3(0.0), packedWaveLight);
}