// ============================================================================
// VOXELIZATION UTILITIES
// Coordinate conversion and voxel map updating
// ============================================================================

#include "/lib/voxel_settings.glsl"

const vec3 voxelVolumeSize = vec3(VOXEL_VOLUME_SIZE, VOXEL_VOLUME_SIZE * 0.5, VOXEL_VOLUME_SIZE);

vec3 worldToVoxel(vec3 worldPos) {
    return worldPos + fract(cameraPosition) + voxelVolumeSize * 0.5;
}

vec3 voxelToWorld(vec3 voxelPos) {
    return voxelPos - fract(cameraPosition) - voxelVolumeSize * 0.5;
}

bool isInsideVoxelVolume(vec3 voxelPos) {
    vec3 normalized = voxelPos / voxelVolumeSize;
    return all(greaterThanEqual(normalized, vec3(0.0))) && all(lessThanEqual(normalized, vec3(1.0)));
}

void updateVoxelMap(uint id) {
    vec3 modelPos = gl_Vertex.xyz + at_midBlock / 64.0;
    vec3 viewPos  = (gl_ModelViewMatrix * vec4(modelPos, 1.0)).xyz;
    vec3 shadowPos = (shadowModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 voxelPos = worldToVoxel(shadowPos);

    if (isInsideVoxelVolume(voxelPos) && id > 0u) {
        imageStore(voxel_img, ivec3(voxelPos), uvec4(id, 0u, 0u, 0u));
    }
}
