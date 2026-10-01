layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(0.03125, 0.03125);
#include "/lib/settings.glsl"
#define passDownsample
#define dstLevel 5
#include "/lib/bloom.glsl"
#include "/lib/bloom_compute.glsl"
void main() {
#ifdef bloom
    bloomDispatch();
#endif
}
