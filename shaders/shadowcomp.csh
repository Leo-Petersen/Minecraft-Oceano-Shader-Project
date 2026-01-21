#version 430 compatibility

#include "/lib/voxel_settings.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

const ivec3 workGroups = ivec3(16, 8, 16); // 128/8, 64/8, 128/8

uniform int frameCounter;

// Voxel texture containing block IDs
uniform usampler3D voxelSampler;

// Light propagation buffers (ping-pong)
writeonly uniform image3D floodfill_img;
writeonly uniform image3D floodfill_img_copy;
uniform sampler3D floodfillSampler;
uniform sampler3D floodfillSamplerCopy;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// 6-connected neighbor offsets
ivec3 offsets[6] = ivec3[6](
    ivec3( 1,  0,  0),
    ivec3(-1,  0,  0),
    ivec3( 0,  1,  0),
    ivec3( 0, -1,  0),
    ivec3( 0,  0,  1),
    ivec3( 0,  0, -1)
);

// Sample neighboring light and average (flood-fill)
vec3 getFloodfill(sampler3D img, ivec3 pos) {
    vec3 light = texelFetch(img, pos, 0).rgb;
    
    for (int i = 0; i < 6; i++) {
        ivec3 neighborPos = clamp(pos + offsets[i], ivec3(0), ivec3(VOXEL_VOLUME_SIZE - 1, VOXEL_VOLUME_SIZE / 2 - 1, VOXEL_VOLUME_SIZE - 1));
        light += texelFetch(img, neighborPos, 0).rgb;
    }
    
    return light / 7.01; // Slight falloff
}

#include "/lib/vx/blocklightColor.glsl"

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    
    // Account for camera movement
    ivec3 previousPos = ivec3(vec3(pos) - floor(previousCameraPosition) + floor(cameraPosition));
    previousPos = clamp(previousPos, ivec3(0), ivec3(VOXEL_VOLUME_SIZE - 1, VOXEL_VOLUME_SIZE / 2 - 1, VOXEL_VOLUME_SIZE - 1));
    
    // Get voxel ID at this position
    uint voxel = texelFetch(voxelSampler, pos, 0).r;
    
    vec3 light = vec3(0.0);
    
    // Check if this voxel should propagate light (air or transparent)
    // Voxel 0 = air, 1 = solid non-emissive, 200-216 = stained glass
    bool canPropagate = (voxel == 0u) || (voxel >= 200u && voxel <= 216u);
    
    // Ping-pong between buffers each frame
    if (canPropagate) {
        if ((frameCounter & 1) == 0) {
            light = getFloodfill(floodfillSampler, previousPos);
        } else {
            light = getFloodfill(floodfillSamplerCopy, previousPos);
        }
        
        // Apply tint for colored glass
        if (voxel >= 200u && voxel <= 216u) {
            uint tintIndex = min(voxel - 200u, 16u);
            vec3 tint = blocklightTintArray[tintIndex];
            light *= pow(tint, vec3(FLOODFILL_RADIUS));
        }
    }
    
    // If this is an emissive block, emit its color
    if (voxel >= 2u && voxel < 200u) {
        vec3 emitColor = getBlocklightColor(int(voxel));
        light = pow(emitColor, vec3(FLOODFILL_RADIUS));
    }
    
    // Store result in the other buffer (ping-pong)
    if ((frameCounter & 1) == 0) {
        imageStore(floodfill_img_copy, pos, vec4(light, float(voxel)));
    } else {
        imageStore(floodfill_img, pos, vec4(light, float(voxel)));
    }
}
