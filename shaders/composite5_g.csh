#version 430 compatibility
layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(0.25, 0.25);
#include "/lib/settings.glsl"
#define PASS_UPSAMPLE
#define DST_LEVEL 2
#include "/lib/bloom.glsl"
#include "/lib/bloom_compute.glsl"
void main() {
#ifdef bloom
    bloomDispatch();
#endif
}
