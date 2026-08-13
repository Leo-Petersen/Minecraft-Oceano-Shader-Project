#version 430 compatibility

uniform float rainStrength;

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(2, 2, 1);           // ceil(32/16) x ceil(32/16)

layout(rgba16f) uniform writeonly image2D colorimg14;

#include "/world1/lib/atmosphereLUT.glsl"

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    if (px.x >= int(atmosMsSize.x) || px.y >= int(atmosMsSize.y)) return;

    vec2 uv = (vec2(px) + 0.5) / atmosMsSize;
    imageStore(colorimg14, px + ivec2(atmosMsOrg), vec4(atmGenMultiScatter(uv), 1.0));
}
