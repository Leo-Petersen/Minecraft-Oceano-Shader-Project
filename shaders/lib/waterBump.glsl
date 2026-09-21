float textureNoise(vec2 coord) {
    return texture2D(noisetex, coord).r;
}

const float radiance = 0.3;
const mat2 rotationMatrix = mat2(
    0.95533649, -0.29552021,
    0.29552021, 0.95533649
);
const mat2 rotationMatrix2 = mat2(
    0.95533649, 0.29552021,
    -0.29552021, 0.95533649
);

float rainRipple(vec2 uv, float t) {
    vec2 id = floor(uv);
    vec2 gv = fract(uv) - 0.5;
    float n = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5453);
    float life = fract(t + n);
    float d    = length(gv);
    float front = life * 0.7;
    float ring = sin(40.0 * (d - front));
    float mask = smoothstep(0.5, 0.0, d)
               * (1.0 - life)
               * smoothstep(front + 0.08, front, d);
    return ring * mask;
}

float getWaterBump(vec2 posxz, float waveM, float waveZ, float iswater, float footprint) {
    float rainDrop = mix(1.0, 5.0, step(0.945, iswater));

    // Multiple octaves of waves at different scales
    float time = frameTimeCounter * 0.5;
    if (iswater < 0.5) {
        time = 0.0; // Static waves for non water surfaces
    }

    // Large rolling waves (wavelength ~1000 blocks, never aliases, kept at all distances)
    vec2 largeWaveCoord = posxz * 0.003;
    float largeWave = sin(largeWaveCoord.x * 2.0 + time * 0.4) *
                      cos(largeWaveCoord.y * 1.5 + time * 0.3) * 0.5;

    // Medium detail waves
    vec2 movement = vec2(0.0, time * 0.0001 * rainDrop) * waveM * 697.0;
    vec2 coord1 = posxz * waveZ * rotationMatrix * vec2(0.8, 1.0);
    vec2 coord2 = posxz * waveZ * rotationMatrix2 * vec2(1.0, 1.2);

    float noiseCoord1 = textureNoise((coord1 - movement) * 0.002);
    float noiseCoord2 = textureNoise((coord2 + movement * 0.9) * 0.003);

    float mediumWave = (1.0 - noiseCoord1 * 3.5)
                     + (pow(max(noiseCoord2 * 6.5, 0.0), waveCrestExp) * 1.2);

    vec2 rippleCoord = posxz * 0.002 + vec2(time * 0.004, time * 0.002);
    float ripples = textureNoise(rippleCoord) * 0.3;

    // Footprint-driven band limiting (Nyquist): fade any octave whose surface
    // features are finer than the pixel, since those can only alias into the
    // normal and show up as distant reflection shimmer. footprint is world
    // units per pixel, so each threshold is roughly that octave's feature size.
    float mediumFade = smoothstep(3.0, 9.0, footprint);   // medium-wave noise ~8m features
    float rippleFade = smoothstep(0.8, 2.5, footprint);   // ripple noise ~2m features
    mediumWave *= (1.0 - mediumFade);
    ripples    *= (1.0 - rippleFade);

    float wave = largeWave + mediumWave * 0.5 + ripples;

    wave *= mix(0.3, 1.0, iswater) * 0.05;

    #ifdef RainRipples
        if (iswater > 0.5 && rainStrength > 0.01) {
            float rt = frameTimeCounter;
            float rings = rainRipple(posxz * 1.4, rt)
                        + rainRipple(posxz * 1.4 + 41.7, rt * 1.17) * 0.7;
            float ripFade = 1.0 - smoothstep(0.25, 0.7, footprint);   // ~0.7m grid features
            wave += rings * 0.006 * rainStrength * ripFade;
        }
    #endif

    return wave;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float randangle, float viewDist) {
    // World units one pixel covers on the surface. On flat water this equals
    // fwidth(worldXZ) exactly, and it grows at grazing angles.
    vec2  fw        = fwidth(posxz);
    float footprint = max(fw.x, fw.y);

    // The gradient step must not be finer than the footprint, or it samples
    // sub-pixel wave detail and the normal turns to noise. 0.25 keeps near
    // water identical to the old behaviour.
    float deltaPos = max(0.25, footprint);

    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);

    float h0 = getWaterBump(posxz,                       waveM, waveZ, iswater, footprint);
    float h1 = getWaterBump(posxz + vec2(-deltaPos, 0.0), waveM, waveZ, iswater, footprint);
    float h2 = getWaterBump(posxz + vec2(0.0, -deltaPos), waveM, waveZ, iswater, footprint);

    // Divide by the actual step so slope magnitude is consistent. At deltaPos
    // 0.25 this is the old * 4.0; as the footprint grows the normal flattens.
    float xDelta = (h0 - h1) / deltaPos;
    float yDelta = (h0 - h2) / deltaPos;

    return normalize(vec3(xDelta, yDelta, 1.0));
}

vec3 getParallaxDisplacement(vec3 posxz, float iswater, float viewDist) {
    vec2  fw        = fwidth(posxz.xz);
    float footprint = max(fw.x, fw.y);

    vec2 offset = viewVector.xy * (6.0 * WaterDepth) / max(viewDist, 1.0);
    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);

    for (int i = 0; i < WaterPoints; i++) {
        posxz.xz = getWaterBump(posxz.xz - posxz.y, waveM, waveZ, iswater, footprint) * offset + posxz.xz;
    }
    return posxz;
}