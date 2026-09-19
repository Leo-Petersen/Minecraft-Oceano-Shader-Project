#version 430 compatibility
layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(0.0625, 0.0625);
#include "/lib/settings.glsl"
#define PASS_DOWNSAMPLE
#define DST_LEVEL 4
#include "/lib/bloom.glsl"
#include "/lib/bloom_compute.glsl"
void main() {
#ifdef bloom
    bloomDispatch();
#endif
}
