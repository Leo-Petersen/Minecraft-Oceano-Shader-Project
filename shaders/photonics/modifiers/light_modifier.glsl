void modify_light(inout Light light, vec3 world_pos) {
    if (light.index < 0) {
        light.color *= 6.67;
    }
}