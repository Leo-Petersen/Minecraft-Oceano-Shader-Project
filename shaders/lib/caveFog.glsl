vec3 applyCaveFog(
    vec3 color,
    vec3 worldPos,
    float rawSkyLight,
    float heldLight,
    float density
) {
    float caveFactor = 1.0 - smoothstep(0.05, 0.5, rawSkyLight);
    if (caveFactor < 0.001) return color;

    float dist = length(worldPos.xyz);

    vec3 caveFogColor = vec3(0.035, 0.04, 0.055);

    // Torch only lights nearby fog, falls off with distance // WIP
    float torchInfluence = clamp(heldLight / 15.0, 0.0, 1.0);
    float torchFalloff = exp(-dist * 0.15);
    vec3 torchFogTint = vec3(0.08, 0.05, 0.025);
    caveFogColor = mix(caveFogColor, torchFogTint*8, torchInfluence * torchFalloff);

    float fogAmount = 1.0 - exp(-density * dist);
    fogAmount = clamp(fogAmount, 0.0, 0.55);

    return mix(color, caveFogColor, fogAmount * caveFactor);
}