#version 430 compatibility

uniform float rainStrength;

layout(local_size_x = 16, local_size_y = 16) in;
const ivec3 workGroups = ivec3(12, 7, 1);          // ceil(192/16) x ceil(108/16)

layout(rgba16f) uniform writeonly image2D colorimg15;

uniform sampler2D colortex14;
uniform float viewWidth, viewHeight;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;

#include "/lib/atmosphereLUT.glsl"

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    if (px.x >= int(atmosSkySize.x) || px.y >= int(atmosSkySize.y)) return;

    vec2 uv  = (vec2(px) + 0.5) / atmosSkySize;
    vec2 res = vec2(viewWidth, viewHeight);

    vec3 sunDirWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float sunElev = asin(clamp(sunDirWorld.y, -1.0, 1.0));
    vec3 sunLocal = vec3(cos(sunElev), sin(sunElev), 0.0);

    float camAltKm = max(0.0, (cameraPosition.y - 63.0)) / 1000.0;

    // both transmittance and multiscatter live in colortex14
    vec3 sky = atmGenSkyView(uv, sunLocal, camAltKm, colortex14, colortex14, res);
    imageStore(colorimg15, px + ivec2(atmosSkyOrg), vec4(sky, 1.0));
}
