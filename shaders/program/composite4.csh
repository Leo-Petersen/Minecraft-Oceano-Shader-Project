layout(local_size_x = 16, local_size_y = 16) in;
const vec2 workGroupsRender = vec2(0.25, 0.25);

#include "/lib/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;

layout(rgba16f) writeonly uniform image2D shaft_img;

#include "/lib/sunShafts.glsl"

void main() {
#ifdef sunShafts
    ivec2 lp = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(shaft_img);
    if (any(greaterThanEqual(lp, size))) return;

    float gate;
    vec2 sunScreen = sunShaftScreen(gate);
    if (gate <= 0.001) return;

    vec2 uv = (vec2(lp) + 0.5) / vec2(size);
    imageStore(shaft_img, lp, vec4(sunShaftMarch(uv, sunScreen), 1.0));
#endif
}
