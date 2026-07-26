#version 430 compatibility

uniform float rainStrength;

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(16, 4, 1);          // ceil(256/16) x ceil(64/16)

layout(rgba16f) uniform writeonly image2D colorimg14;

#include "/lib/atmosphereLUT.glsl"

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    if (px.x >= int(atmosTransSize.x) || px.y >= int(atmosTransSize.y)) return;

    vec2 uv = (vec2(px) + 0.5) / atmosTransSize;
    imageStore(colorimg14, px + ivec2(atmosTransOrg), vec4(atmGenTransmittance(uv), 1.0));
}
