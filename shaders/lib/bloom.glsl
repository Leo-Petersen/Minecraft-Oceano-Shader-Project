#ifndef BLOOM_GLSL
#define BLOOM_GLSL

// Shared helpers for the compute dualfilter bloom.
// The pyramid is packed into a single HDR buffer (colortex8) as a
// horizontal strip of shrinking tiles: level 1 is halfres, level 2
// quarterres, etc etc etc so on so forth...

uniform float viewWidth;
uniform float viewHeight;

float bloomLuma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

ivec2 bloomBufSize() { return ivec2(int(viewWidth), int(viewHeight)); }

// Size in texels of a given pyramid level (level 0 == full res)
ivec2 bloomLevelSize(int lvl) {
    return ivec2(ceil(vec2(viewWidth, viewHeight) / exp2(float(lvl))));
}

// Topleft texel of a level's tile inside the atlas.
ivec2 bloomLevelOffset(int lvl) {
    ivec2 o = ivec2(0);
    for (int i = 1; i < lvl; i++) o.x += bloomLevelSize(i).x + 2;
    return o;
}

#endif
