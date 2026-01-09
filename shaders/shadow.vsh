#version 430 compatibility
#extension GL_ARB_shader_image_load_store : enable

#include "/lib/settings.glsl"

varying float iswater;

varying vec2 texcoord;
varying vec4 color;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec3 at_midBlock;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

// Voxel 3D texture for storing block IDs
writeonly uniform uimage3D voxel_img;

#include "/lib/vertexDisplacement.glsl"
#include "/lib/vx/voxelization.glsl"

vec4 calcShadowDistortion(in vec4 pos) {
    float distortFactor = (1.0 - shadowDistortion) + length(pos.xy) * shadowDistortion;
    pos.xy /= distortFactor;
    return pos;
}

uint getVoxelId(int entityId) {
    // Torch (ID 50)
    if (entityId == 50) return 2u;
    // Lantern (ID 10050)
    if (entityId == 10050) return 2u;
    // Glowstone (ID 89)
    if (entityId == 89) return 3u;
    // Sea Lantern (ID 169)
    if (entityId == 169) return 4u;
    // Lava (ID 10)
    if (entityId == 10) return 5u;
    // Fire (ID 51)
    if (entityId == 51) return 6u;
    // Redstone Torch (ID 76)
    if (entityId == 76) return 7u;
    // Jack o Lantern (ID 91)
    if (entityId == 91) return 8u;
    // Furnace lit (ID 62)
    if (entityId == 62) return 9u;
    // Magma Block (ID 213)
    if (entityId == 213) return 10u;
    // Soul Fire/Torch (ID 10052)
    if (entityId == 10052) return 11u;
    // Crying Obsidian (ID 10225)
    if (entityId == 10225) return 12u;
    // Redstone Wire (ID 55)
    if (entityId == 55) return 13u;
    // End Rod (ID 198)
    if (entityId == 198) return 14u;
    // Shroomlight (ID 10230)
    if (entityId == 10230) return 15u;
    // Beacon (ID 138)
    if (entityId == 138) return 16u;
    // Redstone Lamp lit (ID 10124)
    if (entityId == 10124) return 3u; // Same as glowstone
    // Campfire (ID 10231)
    if (entityId == 10231) return 2u; // Same as torch
    // Froglight Ochre (ID 10235)
    if (entityId == 10235) return 17u;
    // Froglight Verdant (ID 10236)
    if (entityId == 10236) return 18u;
    // Froglight Pearlescent (ID 10237)
    if (entityId == 10237) return 19u;
    // Amethyst (ID 10233)
    if (entityId == 10233) return 20u;
    // Candles (ID 10232)
    if (entityId == 10232) return 2u;
    // Glow Lichen (ID 10234)
    if (entityId == 10234) return 20u;
    // Sculk (ID 10238)
    if (entityId == 10238) return 4u; // Cyan like sea lantern
    // Respawn Anchor (ID 10239)
    if (entityId == 10239) return 12u; // Same as crying obsidian
    // Nether Portal (ID 10240)
    if (entityId == 10240) return 12u;
    
    return 0u; // Not an emissive block
}

void main() {

    vec4 position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

    #ifdef wavingFoliage
        position.xyz = doVertexDisplacement(position.xyz, position.xyz + cameraPosition);
    #endif
    
    position = shadowProjection * shadowModelView * position;
    position = calcShadowDistortion(position);

    gl_Position = position;
    gl_Position.z /= 6.0;

    if (mc_Entity.x == 13000) {
        iswater = 1.00;
    }

    texcoord = gl_MultiTexCoord0.st;
    color = gl_Color;

    #ifdef VoxelLighting
    int entityId = int(mc_Entity.x);
    uint voxelId = getVoxelId(entityId);
    
    if (voxelId > 0u) {
        updateVoxelMap(voxelId);
    }
    #endif
}