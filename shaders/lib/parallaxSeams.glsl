// Identifies an atlas tile from its centre UV. Used to tell whether the block
// across a seam shows the same texture or a different one
uint parallaxTileId(vec2 midUV) {
    uvec2 t = uvec2(clamp(floor(midUV * 65536.0 + 0.5), 0.0, 65535.0));
    return (t.x << 16u) | t.y;
}
vec2 parallaxTileMid(uint id) {
    return vec2(float(id >> 16u), float(id & 0xFFFFu)) / 65536.0;
}

const int pomSeamSizeX = 64;
const int pomSeamSizeY = 32;
const int pomSeamSizeZ = 64;

int parallaxFaceIndex(vec3 n) {
    vec3 a = abs(n);
    if (a.x > a.y && a.x > a.z) return n.x > 0.0 ? 0 : 1;
    if (a.y > a.z)              return n.y > 0.0 ? 2 : 3;
    return n.z > 0.0 ? 4 : 5;
}

ivec3 parallaxSeamCell(vec3 playerPos) {
    return ivec3(floor(playerPos + fract(cameraPosition) + vec3(pomSeamSizeX, pomSeamSizeY, pomSeamSizeZ) * 0.5));
}

bool parallaxSeamInside(ivec3 c) {
    return all(greaterThanEqual(c, ivec3(0))) && all(lessThan(c, ivec3(pomSeamSizeX, pomSeamSizeY, pomSeamSizeZ)));
}
