#version 430 compatibility

#include "/lib/settings.glsl"

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

uniform int frameCounter;

#include "/photonics/photonics.glsl"

varying vec3 playerPos;
varying vec3 blockNormal;

void main() {
    RayJob ray = RayJob(
        playerPos + rt_camera_position - 0.01 * blockNormal,  // origin
        mat3(shadowModelViewInverse) * vec3(0.0, 0.0, -1.0),  // direction (light direction)
        vec3(0), vec3(0), vec3(0), false                       // result defaults
    );

    ray_constraint = ivec3(ray.origin);
    trace_ray(ray);

    if (!ray.result_hit) discard;

    // Recalculate shadow depth from hit position
    vec3 hitPlayerPos = ray.result_position - rt_camera_position;
    vec3 shadowViewPos = (shadowModelView * vec4(hitPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    shadowClipPos.xyz /= shadowClipPos.w;

    // Apply distortion matching shadow.vsh
    float dist = length(shadowClipPos.xy);
    float distortFactor = (1.0 - shadowDistortion) + dist * shadowDistortion;
    shadowClipPos.xy /= distortFactor;
    shadowClipPos.z *= 0.2;

    gl_FragDepth = shadowClipPos.z * 0.5 + 0.5;
    gl_FragData[0] = vec4(ray.result_color, 1.0);
}
