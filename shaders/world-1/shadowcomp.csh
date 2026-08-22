#version 430 compatibility

#include "/lib/voxel_settings.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

const ivec3 workGroups = ivec3(16, 8, 16); // 128/8, 64/8, 128/8

uniform int frameCounter;

uniform usampler3D voxelSampler;

writeonly uniform image3D floodfill_img;
writeonly uniform image3D floodfill_img_copy;
uniform sampler3D floodfillSampler;
uniform sampler3D floodfillSamplerCopy;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

const ivec3 volumeMax = ivec3(VOXEL_VOLUME_SIZE - 1, VOXEL_VOLUME_SIZE / 2 - 1, VOXEL_VOLUME_SIZE - 1);

ivec3 offsets[6] = ivec3[6](
    ivec3( 1,  0,  0),
    ivec3(-1,  0,  0),
    ivec3( 0,  1,  0),
    ivec3( 0, -1,  0),
    ivec3( 0,  0,  1),
    ivec3( 0,  0, -1)
);

// Check if a position is inside the voxel volume
bool isValidPos(ivec3 pos) {
    return all(greaterThanEqual(pos, ivec3(0))) && all(lessThanEqual(pos, volumeMax));
}

// Check if a voxel ID allows light propagation
// ID 0 = air (propagates)
// ID 1 = solid block (blocks light)
// ID 2-199 = emissive (emits, doesn't propagate through)
// ID 200-216 = colored glass
bool canLightPropagate(uint voxelId) {
    return (voxelId == 0u) || (voxelId >= 200u && voxelId <= 216u);
}

vec3 getFloodfill(sampler3D img, ivec3 pos, bool validPos) {
    // If the center position is invalid, return zero light
    if (!validPos) return vec3(0.0);

    vec3 light = texelFetch(img, pos, 0).rgb;
    float count = 1.0;

    for (int i = 0; i < 6; i++) {
        ivec3 neighborPos = pos + offsets[i];

        // Only sample from valid neighbor positions
        if (isValidPos(neighborPos)) {
            light += texelFetch(img, neighborPos, 0).rgb;
            count += 1.0;
        }
    }

    return light / (count + 0.01); // Slight falloff
}

float getHeatRising(sampler3D img, ivec3 pos, bool validPos) {
    if (!validPos) return 0.0;

    float below = 0.0;
    ivec3 belowPos = pos + ivec3(0, -1, 0);
    if (isValidPos(belowPos)) below = texelFetch(img, belowPos, 0).a;

    ivec3 latOff[4] = ivec3[4](ivec3(1,0,0), ivec3(-1,0,0), ivec3(0,0,1), ivec3(0,0,-1));
    float lat = 0.0;
    float lc  = 0.0;
    for (int i = 0; i < 4; i++) {
        ivec3 n = pos + latOff[i];
        if (isValidPos(n)) { lat += texelFetch(img, n, 0).a; lc += 1.0; }
    }
    lat = (lc > 0.0) ? lat / lc : 0.0;

    return clamp((below * RISE_BUOYANCY + lat * RISE_SPREAD) * RISE_DECAY, 0.0, 1.0);
}

#include "/lib/vx/blocklightColor.glsl"

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);

    // Calculate previous position for temporal reprojection
    ivec3 previousPos = ivec3(vec3(pos) - floor(previousCameraPosition) + floor(cameraPosition));

    // Check if previous position is valid BEFORE using it
    bool validPreviousPos = isValidPos(previousPos);

    uint voxel = texelFetch(voxelSampler, pos, 0).r;

    vec3  light = vec3(0.0);
    float heat  = 0.0;

    // Check if this voxel can propagate light (air or colored glass)
    bool canPropagate = canLightPropagate(voxel);

    if (canPropagate) {
        if ((frameCounter & 1) == 0) {
            light = getFloodfill(floodfillSampler,     previousPos, validPreviousPos);
            heat  = getHeatRising(floodfillSampler,     previousPos, validPreviousPos);
        } else {
            light = getFloodfill(floodfillSamplerCopy, previousPos, validPreviousPos);
            heat  = getHeatRising(floodfillSamplerCopy, previousPos, validPreviousPos);
        }
    }

    // Emissive blocks (IDs 2-199) emit their own color
    if (voxel >= 2u && voxel < 200u) {
        vec3 emitColor = getBlocklightColor(int(voxel));
        light = pow(emitColor, vec3(FLOODFILL_RADIUS));
    }

    // Lava (5), Magma (10), Fire (6)
    if (voxel == 5u || voxel == 10u || voxel == 6u) {
        heat = 1.0;
    }

    if ((frameCounter & 1) == 0) {
        imageStore(floodfill_img_copy, pos, vec4(light, heat));
    } else {
        imageStore(floodfill_img, pos, vec4(light, heat));
    }
}
