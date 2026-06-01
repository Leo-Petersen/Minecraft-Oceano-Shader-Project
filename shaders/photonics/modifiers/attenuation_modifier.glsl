vec3 modify_attenuation(
    Light light,
    vec3 to_light,
    vec3 sample_pos,
    vec3 source_pos,
    vec3 geometry_normal,
    vec3 texture_normal
) {
    float distance_squared = dot(to_light, to_light);
    float light_dist_inv = inversesqrt(distance_squared);
    vec3 light_dir = to_light * light_dist_inv;
    if (dot(light_dir, geometry_normal) < 0.01) return vec3(0.0);

    float att = 1.0 / (distance_squared * light.falloff * light.attenuation.y + light.attenuation.x);
    att *= clamp(dot(texture_normal, light_dir), 0.0, 1.0);

    return att * light.color;
}