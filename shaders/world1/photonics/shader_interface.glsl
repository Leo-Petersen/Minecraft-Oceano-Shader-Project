#include "/lib/settings.glsl"

uniform sampler2D colortex1;   // encoded normals
uniform sampler2D colortex14;  // unlit albedo
uniform sampler2D colortex15;  // flat geometric normals

uniform float timeAngle;
uniform int frameCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;

// Octahedral normal decoding
vec3 ph_decodeNormal(vec2 f) {
    f = f * 2.0 - 1.0;
    vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

// Sun/moon direction calculation
vec3 ph_calcSunDir() {
    const vec2 sunRotData = vec2(
        cos(sunPathRotation * 0.01745329251994),
       -sin(sunPathRotation * 0.01745329251994)
    );
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
    vec3 sunDir = normalize(vec3(-sin(ang), cos(ang) * sunRotData));
    // Return sun during day, moon during night
    float dayFactor = (timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0;
    return sunDir * dayFactor;
}

// Sun direction in world space
vec3 sun_direction = ph_calcSunDir();

// Indirect light color
vec3 indirect_light_color = vec3(0.3, 0.4, 0.6) * clamp(ph_calcSunDir().y * 10.0 + 0.5, 0.0, 1.0);

// TAA jitter
vec2 get_taa_jitter() {
    #ifdef TAA
    const vec2 jitterOffsets[8] = vec2[8](
        vec2( 0.5,      -0.333333),
        vec2(-0.25,      0.333333),
        vec2( 0.75,      0.111111),
        vec2( 0.125,    -0.777778),
        vec2(-0.375,     0.555556),
        vec2( 0.625,    -0.111111),
        vec2(-0.125,     0.777778),
        vec2( 0.875,    -0.555556)
    );
    return jitterOffsets[frameCounter & 7] / vec2(viewWidth, viewHeight);
    #else
    return vec2(0.0);
    #endif
}

// Reconstruct world position from depth buffer
vec3 load_world_position() {
    vec2 texCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
    vec3 ndc = vec3(texCoord, depth) * 2.0 - 1.0;

    #ifdef TAA
    ndc.xy -= get_taa_jitter();
    #endif

    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
    viewPos.xyz /= viewPos.w;
    vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
    return playerPos + cameraPosition;
}

// Load surface data from render targets
void load_fragment_variables(
    out vec3 albedo,
    out vec3 world_pos,
    out vec3 geometry_normal,
    out vec3 texture_normal
) {
    vec2 texCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

    // Unlit albedo from colortex14
    albedo = texelFetch(colortex14, ivec2(gl_FragCoord.xy), 0).rgb;

    // Texture normal from colortex1 (octahedral encoded)
    vec2 encodedNormal = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0).xy;
    vec3 viewNormalMapped = ph_decodeNormal(encodedNormal);
    texture_normal = normalize((gbufferModelViewInverse * vec4(viewNormalMapped, 0.0)).xyz);

    // Flat geometric normal from colortex15 (stored as 0.5*n+0.5)
    vec3 flatViewNormal = 2.0 * texelFetch(colortex15, ivec2(gl_FragCoord.xy), 0).xyz - 1.0;
    geometry_normal = normalize((gbufferModelViewInverse * vec4(flatViewNormal, 0.0)).xyz);

    // World position nudged outside the block surface
    world_pos = load_world_position() - 0.01 * geometry_normal;
}

// Whether this fragment is world geometry (not sky)
bool is_in_world() {
    return texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x <= 0.99999;
}
