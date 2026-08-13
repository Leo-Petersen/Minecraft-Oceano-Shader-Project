#include "/lib/vx/blocklightColor.glsl"

vec3 getHandLightColor(int itemId) {
    vec3 color = getBlocklightColor(itemId);
    if (length(color) < 0.001) {
        return vec3(torchR, torchG, torchB) / 255.0; // fallback to default
    }
    return color;
}