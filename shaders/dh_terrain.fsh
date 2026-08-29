#version 430 compatibility

#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform float far;
uniform mat4  gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying float material;
varying float dist;
varying vec2  lmcoord;
varying vec2  texcoord;
varying vec3  worldpos;
varying vec3  viewNormal;
varying vec4  glcolor;
flat in  int  dhMat;

float GetBlueNoise3D(vec3 pos, vec3 worldNormal) {
    pos = (floor(pos + 0.01) + 0.5) / 512.0;
    vec3 noise3D = vec3(
        texture2D(noisetex, pos.yz).b,
        texture2D(noisetex, pos.xz).b,
        texture2D(noisetex, pos.xy).b
    );
    float noise = noise3D.x * abs(worldNormal.x)
                + noise3D.y * abs(worldNormal.y)
                + noise3D.z * abs(worldNormal.z);
    return noise - 0.5;
}

float Bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float Bayer4(vec2 a)  { return Bayer2(0.5 * a) * 0.25 + Bayer2(a); }
float Bayer8(vec2 a)  { return Bayer4(0.5 * a) * 0.25 + Bayer2(a); }

void main() {

    // float dither = Bayer8(gl_FragCoord.xy);
    // float minDist = (dither - 0.75) * 16.0 + far;
    // if (dist <= minDist) discard;

    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.1) discard;

    #ifdef whiteWorld
    albedo.rgb = vec3(1.0);
    #endif

    vec2 lm = clamp(lmcoord - 1.0 / 32.0, 0.0, 1.0);

    // SSS is disabled on DH terrain
    float labSSS = 0.0;

    float emission = 0.0;
    #ifdef DH_BLOCK_ILLUMINATED
    if (dhMat == DH_BLOCK_ILLUMINATED) emission = 1.0;
    #endif

    vec3 worldNormal = mat3(gbufferModelViewInverse) * viewNormal;
    float albedoLuma = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    float noiseAmount = (1.0 - albedoLuma * albedoLuma) * 0.3;
    float n = GetBlueNoise3D(worldpos * 5.0, worldNormal);
    albedo.rgb = clamp(albedo.rgb + n * noiseAmount, vec3(0.0), vec3(1.0));

#ifdef PHOTONICS_ENABLED
/* RENDERTARGETS: 0,1,2,8,13,14,15 */
#else
/* RENDERTARGETS: 0,1,2,8,13 */
#endif
    gl_FragData[0] = albedo;                                     
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 0.0, 0.0);   
    gl_FragData[2] = vec4(lm, material, 1.0);   
    gl_FragData[4] = vec4(emission, 1.0, 1.0, labSSS);
#ifdef PHOTONICS_ENABLED
    gl_FragData[5] = vec4(albedo.rgb, 1.0);
    gl_FragData[6] = vec4(0.5 * viewNormal + 0.5, 1.0);
#endif
}
