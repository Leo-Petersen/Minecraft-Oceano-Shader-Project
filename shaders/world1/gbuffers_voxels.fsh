#version 430 compatibility

#include "/lib/settings.glsl"
#include "/world1/lib/encode.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;

uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

#include "/photonics/photonics.glsl"

varying vec2 lmcoord;
varying vec3 viewNormal;
varying vec3 blockNormal;

void main() {
    // Screen position from fragment coordinates
    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);

    // Screen to view space (no TAA jitter for voxels)
    vec4 viewPosH = gbufferProjectionInverse * vec4(screenPos * 2.0 - 1.0, 1.0);
    vec3 viewPos = viewPosH.xyz / viewPosH.w;

    // View to player space
    vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    // Set up ray in RT coordinate space
    vec3 rtPos = playerPos + rt_camera_position;

    RayJob ray = RayJob(
        rtPos - 0.001 * blockNormal,                              // origin
        normalize(playerPos - gbufferModelViewInverse[3].xyz),     // direction
        vec3(0), vec3(0), vec3(0), false                           // result defaults
    );

    // Constrain ray to this block
    ray_constraint = ivec3(ray.origin);
    trace_ray(ray);

    // Discard if ray missed (transparent voxel corner)
    if (!ray.result_hit) discard;
    if (ray.result_normal == vec3(0.0)) ray.result_normal = blockNormal;

    // Update position with hit result
    playerPos = ray.result_position - rt_camera_position;
    viewPos = (gbufferModelView * vec4(playerPos, 1.0)).xyz;
    vec4 ndcPos = gbufferProjection * vec4(viewPos, 1.0);
    screenPos = ndcPos.xyz / ndcPos.w * 0.5 + 0.5;
    gl_FragDepth = screenPos.z;

    // Results
    vec3 normal = normalize(gl_NormalMatrix * ray.result_normal);
    vec4 albedo = vec4(ray.result_color, 1.0);

    vec2 lightMap = lmcoord;

/* RENDERTARGETS: 0,1,2,14,15 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(encodeNormal(normal), 0.0, 0.0);
    gl_FragData[2] = vec4(lightMap, 1.0, 1.0);
    gl_FragData[3] = vec4(albedo.rgb, 1.0);
    gl_FragData[4] = vec4(0.5 * normal + 0.5, 1.0);
}
