#ifndef BLOOM_COMPUTE_GLSL
#define BLOOM_COMPUTE_GLSL

// Compute dualfilter bloom, i.e. a progressive downsample/upsample pyramid
// Thanks to the following sources, huge help on learning this new method:
//   Jorge Jimenez, "Next Generation Post Processing in Call of Duty:
//     Advanced Warfare", SIGGRAPH 2014.
//     https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare/
//   "Physically Based Bloom", LearnOpenGL (reference implementation of the above).
//     https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
//   Firefly-reduction weighting: "Karis average", Brian Karis (Epic Games),
//     SIGGRAPH 2014 Advances course. https://advances.realtimerendering.com/s2014/
//   Léna Piquet (Froyok), "Custom Bloom Post-Process in Unreal Engine".
//     https://www.froyok.fr/blog/2021-12-ue4-custom-bloom/

uniform sampler2D colortex0;
uniform sampler2D colortex8;
uniform sampler2D colortex13;
uniform sampler2D depthtex0;
layout(rgba16f) uniform image2D colorimg8;

// brightpass
vec3 bloomSource(ivec2 coord) {
    coord = clamp(coord, ivec2(0), bloomBufSize() - 1);
    vec3 c = texelFetch(colortex0, coord, 0).rgb;
    c = max(c, vec3(0.0));
    if (any(isnan(c)) || any(isinf(c))) c = vec3(0.0);
    float b = bloomLuma(c);
    float w = smoothstep(0.6, 1.0, b);
    if (texelFetch(depthtex0, coord, 0).r < 1.0) {
        float em = texelFetch(colortex13, coord, 0).r;
        if (em > 0.01) {
            float t = 0.6 - em * 0.4;
            w = smoothstep(t, 1.0, b) * (1.0 + em * 5.0);
        }
    }
    return c * w;
}

// read a source texel
vec3 loadSrc(int srcLvl, ivec2 coord) {
    if (srcLvl == 0) return bloomSource(coord);
    ivec2 sz = bloomLevelSize(srcLvl);
    coord = clamp(coord, ivec2(0), sz - 1);
    return texelFetch(colortex8, bloomLevelOffset(srcLvl) + coord, 0).rgb;
}

#ifdef PASS_DOWNSAMPLE

#ifdef FIRST_DOWNSAMPLE
// 16x16 outputs == a 36 wide region.
shared vec3 lds[36][36];
#endif

void bloomDispatch() {
    const int srcLvl = DST_LEVEL - 1;
    ivec2 dstSize = bloomLevelSize(DST_LEVEL);
    ivec2 grp = ivec2(gl_WorkGroupID.xy) * 16;
    ivec2 lid = ivec2(gl_LocalInvocationID.xy);
    ivec2 dst = grp + lid;

#ifdef FIRST_DOWNSAMPLE
    // stage the bright passed scene into shared memory
    ivec2 srcBase = grp * 2 - 2;
    for (int idx = int(gl_LocalInvocationIndex); idx < 36 * 36; idx += 256) {
        ivec2 t = ivec2(idx % 36, idx / 36);
        lds[t.y][t.x] = loadSrc(0, srcBase + t);
    }
    barrier();
    if (any(greaterThanEqual(dst, dstSize))) return;

    ivec2 b0 = lid * 2 + 2;   // LDS index of source texel

    // each tap is a 2x2 block average
    #define B(dx, dy) lds[b0.y + (dy)][b0.x + (dx)]
    vec3 a = (B(-2, 2) + B(-1, 2) + B(-2, 3) + B(-1, 3)) * 0.25;
    vec3 b = (B( 0, 2) + B( 1, 2) + B( 0, 3) + B( 1, 3)) * 0.25;
    vec3 c = (B( 2, 2) + B( 3, 2) + B( 2, 3) + B( 3, 3)) * 0.25;
    vec3 d = (B(-2, 0) + B(-1, 0) + B(-2, 1) + B(-1, 1)) * 0.25;
    vec3 e = (B( 0, 0) + B( 1, 0) + B( 0, 1) + B( 1, 1)) * 0.25;
    vec3 f = (B( 2, 0) + B( 3, 0) + B( 2, 1) + B( 3, 1)) * 0.25;
    vec3 g = (B(-2,-2) + B(-1,-2) + B(-2,-1) + B(-1,-1)) * 0.25;
    vec3 h = (B( 0,-2) + B( 1,-2) + B( 0,-1) + B( 1,-1)) * 0.25;
    vec3 i = (B( 2,-2) + B( 3,-2) + B( 2,-1) + B( 3,-1)) * 0.25;
    vec3 j = (B(-1, 1) + B( 0, 1) + B(-1, 2) + B( 0, 2)) * 0.25;
    vec3 k = (B( 1, 1) + B( 2, 1) + B( 1, 2) + B( 2, 2)) * 0.25;
    vec3 l = (B(-1,-1) + B( 0,-1) + B(-1, 0) + B( 0, 0)) * 0.25;
    vec3 m = (B( 1,-1) + B( 2,-1) + B( 1, 0) + B( 2, 0)) * 0.25;
    #undef B

    // plain 13 tap weights
    vec3 result = (a + c + g + i) * 0.03125
                + (b + d + f + h) * 0.0625
                + (e + j + k + l + m) * 0.125;
                
#else
    if (any(greaterThanEqual(dst, dstSize))) return;

    // one bilinear tap per sample, centered on the block corner.
    vec2 buf  = vec2(viewWidth, viewHeight);
    vec2 sOff = vec2(bloomLevelOffset(srcLvl));
    vec2 sSz  = vec2(bloomLevelSize(srcLvl));
    vec2 lo = sOff + 0.5;
    vec2 hi = sOff + sSz - 0.5;
    vec2 ctr = sOff + (vec2(dst) + 0.5) * 2.0;
    #define S(ox, oy) textureLod(colortex8, clamp(ctr + vec2(ox, oy), lo, hi) / buf, 0.0).rgb
    vec3 a = S(-2, 2), b = S( 0, 2), c = S( 2, 2);
    vec3 d = S(-2, 0), e = S( 0, 0), f = S( 2, 0);
    vec3 g = S(-2,-2), h = S( 0,-2), i = S( 2,-2);
    vec3 j = S(-1, 1), k = S( 1, 1), l = S(-1,-1), m = S( 1,-1);
    #undef S
    vec3 result = (a + c + g + i) * 0.03125
                + (b + d + f + h) * 0.0625
                + (e + j + k + l + m) * 0.125;
#endif

    imageStore(colorimg8, bloomLevelOffset(DST_LEVEL) + dst, vec4(result, 1.0));
}
#endif


#ifdef PASS_UPSAMPLE
const float BLOOM_RADIUS = 1.0;   // tent spread in source texels

vec3 tapAtlas(vec2 p, vec2 lo, vec2 hi, vec2 buf) {
    return textureLod(colortex8, clamp(p, lo, hi) / buf, 0.0).rgb;
}

void bloomDispatch() {
    const int srcLvl = DST_LEVEL + 1;   // smaller, already accumulated level
    ivec2 dstSize = bloomLevelSize(DST_LEVEL);

    ivec2 dst = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(dst, dstSize))) return;

    vec2 buf     = vec2(viewWidth, viewHeight);
    vec2 srcOff  = vec2(bloomLevelOffset(srcLvl));
    vec2 srcSize = vec2(bloomLevelSize(srcLvl));
    vec2 lo = srcOff + 0.5;
    vec2 hi = srcOff + srcSize - 0.5;

    // Map this dst texel center into the halfsize source tile
    vec2 base = srcOff + (vec2(dst) + 0.5) * 0.5;
    float R = BLOOM_RADIUS;

    vec3 s00 = tapAtlas(base + vec2(-R, -R), lo, hi, buf);
    vec3 s10 = tapAtlas(base + vec2( 0, -R), lo, hi, buf);
    vec3 s20 = tapAtlas(base + vec2( R, -R), lo, hi, buf);
    vec3 s01 = tapAtlas(base + vec2(-R,  0), lo, hi, buf);
    vec3 s11 = tapAtlas(base,                lo, hi, buf);
    vec3 s21 = tapAtlas(base + vec2( R,  0), lo, hi, buf);
    vec3 s02 = tapAtlas(base + vec2(-R,  R), lo, hi, buf);
    vec3 s12 = tapAtlas(base + vec2( 0,  R), lo, hi, buf);
    vec3 s22 = tapAtlas(base + vec2( R,  R), lo, hi, buf);

    // 3x3 tent == (1 2 1 / 2 4 2 / 1 2 1) / 16.
    vec3 up = (s11 * 4.0
             + (s10 + s01 + s21 + s12) * 2.0
             + (s00 + s20 + s02 + s22)) / 16.0;

    ivec2 addr = bloomLevelOffset(DST_LEVEL) + dst;
    vec3 base_c = imageLoad(colorimg8, addr).rgb;   // this level's own downsample
    imageStore(colorimg8, addr, vec4(base_c + up, 1.0));
}
#endif

#endif
