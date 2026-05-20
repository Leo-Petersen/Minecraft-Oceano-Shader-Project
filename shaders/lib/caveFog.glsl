vec3 CaveFog(
    vec3 color,
    vec3 worldPos,
    float rawSkyLight,
    float heldLight,
    float density,
    float emission
) {
    float caveFactor = 1.0 - smoothstep(0.05, 0.5, rawSkyLight);
    if (caveFactor < 0.001) return color;

    float dist = pow(length(worldPos.xz) / 20.0, 0.75);

    vec3 caveFogColor = pow(vec3(0.035, 0.04, 0.055), vec3(0.9));

    // Torch only lights nearby fog, falls off with distance // WIP
    // float torchInfluence = clamp(heldLight / 15.0, 0.0, 1.0);
    // float torchFalloff = exp(-dist * 0.2);
    // vec3 torchFogTint = vec3(torchR, torchG, torchB)/255;
    // caveFogColor = mix(caveFogColor, torchFogTint*0.6, torchInfluence * torchFalloff);

    float fogAmount = 1.0 - exp(-density * dist);
    fogAmount = clamp(fogAmount*1.24*caveFogStrength, 0.0, 0.8);

    fogAmount *= 1.0 - emission*0.5; // Reduce fog density based on emission, but don't eliminate it entirely

    return mix(color, caveFogColor, fogAmount * caveFactor);
}