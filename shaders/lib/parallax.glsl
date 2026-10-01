//  References:
//     T. Kaneko et al., "Detailed Shape Representation with Parallax
//        Mapping", ICAT 2001. (Original parallax mapping)
//
//     M. McGuire, M. McGuire, "Steep Parallax Mapping", I3D 2005 poster.
//        (Fixed-step linear search through the height field)
//
//     N. Tatarchuk, "Dynamic Parallax Occlusion Mapping with Approximate
//        Soft Shadows", I3D 2006. (POM march and soft self-shadowing)
//
//     F. Policarpo, M. M. Oliveira, J. Comba, "Real-Time Relief Mapping on
//        Arbitrary Polygonal Surfaces", I3D 2005. (Binary search refinement)
//
//     E. Risser, M. Shah, S. Pattanaik, "Faster Relief Mapping Using the
//        Secant Method", Journal of Graphics Tools 12(3), 2007. (Secant step)
//
//     LabPBR Material Standard, shaderLABS. (Height in normal map alpha)
//

#ifndef pomViewVector
    #define pomViewVector viewVector
#endif

#define pomSamplesPerTexel 1.0   // linear search density
#define pomRefineSteps      3     // bisection steps after the first hit
#define pomMinSteps         4.0
#define pomMaxLod           4.0
#define pomTop               0.98  // heights above this are treated as the top surface

mat2 dFdxy = mat2(
    dFdx(vtexcoord.xy * vtexcoordam.pq),
    dFdy(vtexcoord.xy * vtexcoordam.pq)
);

vec2  parallaxTileCoord = vtexcoord.xy;
float parallaxHeight    = 1.0;
vec2  parallaxGradient  = vec2(0.0);
vec2  parallaxGradientSmooth = vec2(0.0);
bool  parallaxActive    = false;
float parallaxDepthUsed = 0.0;

vec2  pomCells = vec2(16.0);
float pomLod   = 0.0;

// Seams, when the neighbouring block across a tile edge shows a different
// texture, the ray must not wrap into this block's texture again
bvec2 pomWall = bvec2(false);
vec2  parallaxWallDir = vec2(0.0);

// returns true (and the wall gradient) if tileCoord is past a wall edge
bool pomSeam(vec2 tileCoord, out vec2 grad) {
    grad = vec2(0.0);
    if (pomWall.x && (tileCoord.x < 0.0 || tileCoord.x > 1.0)) { grad.x = tileCoord.x > 1.0 ? 64.0 : -64.0; return true; }
    if (pomWall.y && (tileCoord.y < 0.0 || tileCoord.y > 1.0)) { grad.y = tileCoord.y > 1.0 ? 64.0 : -64.0; return true; }
    return false;
}

vec2 pomToAtlas(vec2 tileCoord) {
    return fract(tileCoord) * vtexcoordam.pq + vtexcoordam.st;
}

float pomTap(vec2 cell) {
    vec2 c = mod(cell, pomCells);
    return textureLod(normals, (c + 0.5) / pomCells * vtexcoordam.pq + vtexcoordam.st, pomLod).a;
}

// Heights of the 2x2 texel block starting at cell i
vec4 pomQuad(vec2 i) {
#if __VERSION__ >= 400
    if (pomLod == 0.0 && i.x >= 0.0 && i.y >= 0.0 && i.x + 1.0 < pomCells.x && i.y + 1.0 < pomCells.y) {
        vec4 g = textureGather(normals, (i + 1.0) / pomCells * vtexcoordam.pq + vtexcoordam.st, 3);
        return vec4(g.w, g.z, g.x, g.y);
    }
#endif
    return vec4(pomTap(i), pomTap(i + vec2(1.0, 0.0)), pomTap(i + vec2(0.0, 1.0)), pomTap(i + vec2(1.0, 1.0)));
}

float pomSharpness(float dh) {
    float slope = abs(dh) * parallaxDepthUsed * pomCells.x;
    const float lo = 1.5 * parallaxSmoothness, hi = 4.0 * parallaxSmoothness + 0.001;
    return clamp((slope + 0.0005 - lo) * (1.0 / (hi - lo)), 0.0, 1.0);
}

// interpolation weight and its derivative
vec2 pomWeight(float f, float k) {
    const float a = 0.5 - parallaxEdgeChamfer, b = 0.5 + parallaxEdgeChamfer;
    float x  = (f - a) / (b - a);
    float r  = clamp(x, 0.0, 1.0);
    float dr = (x > 0.0 && x < 1.0) ? 1.0 / (b - a) : 0.0;
    return vec2(mix(f, r, k), mix(1.0, dr, k));
}

float pomHeight(vec2 tileCoord, out vec2 grad) {
    if (pomSeam(tileCoord, grad)) return 1.0;
    vec2 p = tileCoord * pomCells - 0.5;
    vec2 i = floor(p), f = p - i;
    vec4 h = pomQuad(i);
    vec2 w0 = pomWeight(f.x, pomSharpness(h.y - h.x));
    vec2 w1 = pomWeight(f.x, pomSharpness(h.w - h.z));
    float a = mix(h.x, h.y, w0.x);
    float b = mix(h.z, h.w, w1.x);
    vec2 wy = pomWeight(f.y, pomSharpness(b - a));
    grad.x = mix((h.y - h.x) * w0.y, (h.w - h.z) * w1.y, wy.x) * pomCells.x;
    grad.y = (b - a) * wy.y * pomCells.y;
    return mix(a, b, wy.x);
}

float pomHeight(vec2 tileCoord) { vec2 g; return pomHeight(tileCoord, g); }

// Used only by the linear search
float pomHeightMarch(vec2 tileCoord) {
    vec2 g;
    if (pomSeam(tileCoord, g)) return 1.0;
    return pomTap(floor(tileCoord * pomCells));
}

// Plain bilinear height field
float pomHeightSmooth(vec2 tileCoord, out vec2 grad) {
    if (pomSeam(tileCoord, grad)) return 1.0;
    vec2 p = tileCoord * pomCells - 0.5;
    vec2 i = floor(p), f = p - i;
    vec4 h = pomQuad(i);
    float a = mix(h.x, h.y, f.x), b = mix(h.z, h.w, f.x);
    grad = vec2(mix(h.y - h.x, h.w - h.z, f.y) * pomCells.x, (b - a) * pomCells.y);
    return mix(a, b, f.y);
}
float pomHeightSmooth(vec2 tileCoord) { vec2 g; return pomHeightSmooth(tileCoord, g); }

float parallaxHeightSmoothHit = 1.0;
void pomHitData(vec2 tileCoord, out vec2 gradCrisp, out vec2 gradSmooth) {
    vec2 p = tileCoord * pomCells - 0.5;
    vec2 i = floor(p), f = p - i;
    vec4 h = pomQuad(i);
    // crisp gradient
    vec2 w0 = pomWeight(f.x, pomSharpness(h.y - h.x));
    vec2 w1 = pomWeight(f.x, pomSharpness(h.w - h.z));
    float a = mix(h.x, h.y, w0.x), b = mix(h.z, h.w, w1.x);
    vec2 wy = pomWeight(f.y, pomSharpness(b - a));
    gradCrisp = vec2(mix((h.y - h.x) * w0.y, (h.w - h.z) * w1.y, wy.x) * pomCells.x, (b - a) * wy.y * pomCells.y);
    // smooth gradient and height
    float sa = mix(h.x, h.y, f.x), sb = mix(h.z, h.w, f.x);
    gradSmooth = vec2(mix(h.y - h.x, h.w - h.z, f.y) * pomCells.x, (sb - sa) * pomCells.y);
    parallaxHeightSmoothHit = mix(sa, sb, f.y);
}

vec2 calcParallax() {
    vec2 baseCoord = vtexcoord.xy * vtexcoordam.pq + vtexcoordam.st;

    float fade = clamp((dist - float(parallaxNearDist)) / float(max(parallaxFarDist - parallaxNearDist, 1)), 0.0, 1.0);
    fade = fade * fade * (3.0 - 2.0 * fade);
    if (fade >= 1.0) return baseCoord;

    vec3 V = pomViewVector;
    float vLen = length(V);
    if (vLen < 1e-6) return baseCoord;
    V /= vLen;
    float NdotV = -V.z;
    if (NdotV <= 0.001) return baseCoord;

    parallaxDepthUsed = parallaxDepth * (1.0 - fade);

    // Level of detail
    vec2 atlasRes = vec2(textureSize(normals, 0));
    vec2 tileRes  = max(floor(vtexcoordam.pq * atlasRes + 0.5), vec2(1.0));
    float fa = length(dFdxy[0] * atlasRes), fb = length(dFdxy[1] * atlasRes);
    float footprint = max(max(fa, fb) * 0.25, min(fa, fb));
    pomLod   = clamp(floor(log2(max(footprint, 1.0))), 0.0, pomMaxLod);
    pomCells = max(tileRes / exp2(pomLod), vec2(1.0));

    vec2 total = V.xy / max(NdotV, 0.02) * parallaxDepthUsed;
    float cells = length(total * pomCells);
    float dt = 1.0 / max(cells * pomSamplesPerTexel, pomMinSteps);

    #ifdef pomSeamLookup

    vec2 rayEnd = vtexcoord.xy + total;
    if (rayEnd.x < 0.0 || rayEnd.x > 1.0) pomWall.x = parallaxSeamIsWall(vec2(total.x > 0.0 ? 1.0 : -1.0, 0.0));
    if (rayEnd.y < 0.0 || rayEnd.y > 1.0) pomWall.y = parallaxSeamIsWall(vec2(0.0, total.y > 0.0 ? 1.0 : -1.0));
    #endif

    vec2  prevC = vtexcoord.xy;
    float prevR = 1.0;
    float prevS = pomHeightMarch(prevC);
    if (prevS >= pomTop) {
        parallaxHeight = prevS;
        return baseCoord;
    }

    vec2  c = prevC;
    float r = 1.0, s = prevS;
    for (int i = 0; i < parallaxQuality; i++) {
        prevC = c; prevR = r; prevS = s;
        r = max(r - dt, 0.0);
        c = vtexcoord.xy + total * (1.0 - r);
        s = pomHeightMarch(c);
        if (r <= s || r <= 0.0) break;
    }

    if (r > s) {    // ran out of steps, take the last position
        vec2 wg; if (pomSeam(c, wg)) c = clamp(c, vec2(0.0005), vec2(0.9995));
        parallaxTileCoord = c;
        parallaxHeight = r;
        return pomToAtlas(c);
    }

    // Bisection
    vec2  aC = prevC; float aR = prevR, aS = prevS;
    vec2  bC = c;     float bR = r,     bS = s;
    aS = pomHeight(aC); bS = pomHeight(bC);
    for (int j = 0; j < pomRefineSteps; j++) {
        vec2  mC = 0.5 * (aC + bC);
        float mR = 0.5 * (aR + bR);
        float mS = pomHeight(mC);
        if (mR <= mS) { bC = mC; bR = mR; bS = mS; }
        else          { aC = mC; aR = mR; aS = mS; }
    }
    float da = aR - aS, db = bS - bR;
    float t  = clamp(da / max(da + db, 1e-6), 0.0, 1.0);

    parallaxTileCoord = mix(aC, bC, t);
    parallaxHeight    = mix(aR, bR, t);
    vec2 g;
    vec2 wallGrad;
    if (pomSeam(bC, wallGrad)) {
        // hit the wall at a seam
        parallaxTileCoord = vec2(pomWall.x ? clamp(parallaxTileCoord.x, 0.0005, 0.9995) : parallaxTileCoord.x,
                                 pomWall.y ? clamp(parallaxTileCoord.y, 0.0005, 0.9995) : parallaxTileCoord.y);
        parallaxGradient = parallaxGradientSmooth = wallGrad;
        parallaxWallDir  = sign(wallGrad);
    } else {
        vec2 gs;
        pomHitData(parallaxTileCoord, g, gs);
        parallaxGradient       = g  * parallaxDepthUsed;
        parallaxGradientSmooth = gs * parallaxDepthUsed;
    }
    parallaxActive    = true;
    return pomToAtlas(parallaxTileCoord);
}


// Replaces the normal on walls and slopes with the true surface normal
vec3 parallaxNormal(vec3 tangentNormal) {
#ifdef ParallaxSlopeNormals
    if (parallaxActive) {
        vec3 slopeN = normalize(vec3(-parallaxGradientSmooth, 1.0));
        float w = smoothstep(0.3, 1.2, length(parallaxGradient));
        return normalize(mix(tangentNormal, slopeN, w));
    }
#endif
    return tangentNormal;
}

float parallaxShadow(vec3 lightTangent) {

    if (parallaxDepthUsed <= 0.0) return 1.0;
    vec3 L = normalize(lightTangent);
    float grazing = smoothstep(-0.08, 0.0, L.z);
    if (grazing <= 0.0) return 0.0;
    if (parallaxHeight >= 0.999) return grazing;
    float startH = min(parallaxHeight, parallaxHeightSmoothHit);

    float rise  = 1.0 - startH;
    vec2  total = L.xy / max(L.z, 0.05) * parallaxDepthUsed * rise;
    int   n     = int(clamp(ceil(length(total * pomCells)), 3.0, float(parallaxShadowQuality)));

    float penumbra = parallaxShadowSoftness * 0.1;
    float horizPerDepth = length(L.xy) / max(L.z, 0.05) * rise;
    float occ = -penumbra;
    for (int i = 1; i <= parallaxShadowQuality; i++) {
        if (i > n) break;
        // samples get denser towards the end of the ray
        float t    = float(i) / float(n);
        float k    = 1.0 - (1.0 - t) * (1.0 - t);
        float rayH = startH + rise * k;
        float h    = pomHeightSmooth(parallaxTileCoord + total * k);

        occ = max(occ, (h - rayH) / (k * horizPerDepth + 1e-4));
        if (occ >= penumbra) break;
    }
    return (1.0 - smoothstep(-penumbra, penumbra, occ)) * grazing;
}

// Packs the parallax self shadow (high 4 bits)
float parallaxPackShadow(float shadow) {
    float s = floor(clamp(shadow, 0.0, 1.0) * 15.0 + 0.5);
    float d = 0.0;
    if (parallaxActive) d = floor(clamp((1.0 - parallaxHeight) * parallaxDepthUsed / parallaxDepth, 0.0, 1.0) * 15.0 + 0.5);
    return (s * 16.0 + (15.0 - d)) / 255.0;
}

// Cavity occlusion
float parallaxAO() {
#ifdef ParallaxAO
    if (parallaxActive) return mix(1.0, 0.45 + 0.55 * parallaxHeight, clamp(parallaxDepthUsed * 4.0, 0.0, 1.0));
#endif
    return 1.0;
}

mat3 GetLightmapTBN(vec3 viewPos) {
    vec3 right = normalize(dFdx(viewPos));
    vec3 up    = normalize(dFdy(viewPos));
    vec3 forward = cross(right, up);

    return mat3(right, up, forward);
}

float DirectionalLightmap(float lightmap, float lightmapRaw, vec3 normal, mat3 tbn) {
    // skip if there's no light
    if (lightmap < 0.001) return lightmap;

    float gradientX = dFdx(lightmapRaw) * 256.0;
    float gradientY = dFdy(lightmapRaw) * 256.0;

    // skip if lightmap is uniform
    if (abs(gradientX) + abs(gradientY) < 0.001) return lightmap;

    vec3 lightDir = normalize(
        gradientX * tbn[0] +      // H
        gradientY * tbn[1] +      // V
        0.0005    * tbn[2]
    );

    float NdotL = dot(normal, lightDir);
    float modifier = pow(abs(NdotL), 1.0) * sign(NdotL) * lightmap;

    return pow(lightmap, max(1.0 - modifier, 0.001));
}
