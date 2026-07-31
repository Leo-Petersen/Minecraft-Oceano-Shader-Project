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

float getWaterBump(vec2 posxz, float waveM, float waveZ, float iswater, float viewDist) {
    float rainDrop = mix(1.0, 5.0, step(0.945, iswater));
    
    // Multiple octaves of waves at different scales
    float time = frameTimeCounter * 0.5;
    if (iswater < 0.5) {
        time = 0.0; // Static waves for non-water surfaces
    }
    
    // Large rolling waves
    vec2 largeWaveCoord = posxz * 0.003;
    float largeWave = sin(largeWaveCoord.x * 2.0 + time * 0.4) * 
                      cos(largeWaveCoord.y * 1.5 + time * 0.3) * 0.5;
    
    // Medium detail waves
    vec2 movement = vec2(0.0, time * 0.0001 * rainDrop) * waveM * 697.0;
    vec2 coord1 = posxz * waveZ * rotationMatrix * vec2(0.8, 1.0);
    vec2 coord2 = posxz * waveZ * rotationMatrix2 * vec2(1.0, 1.2);
    
    float noiseCoord1 = textureNoise((coord1 - movement) * 0.002);
    float noiseCoord2 = textureNoise((coord2 + movement * 0.9) * 0.003);
    
    float mediumWave = (1.0 - noiseCoord1 * 3.5) + (sqrt(noiseCoord2 * 6.5) * 1.2);
    
    vec2 rippleCoord = posxz * 0.002 + vec2(time * 0.004, time * 0.002);
    float ripples = textureNoise(rippleCoord) * 0.3;
    
    float wave = largeWave + mediumWave * 0.5 + ripples;
    float distanceFade = smoothstep(30.0, 120.0, viewDist);
    wave *= (1.0 - distanceFade * 0.6);
    wave *= mix(0.3, 1.0, iswater) * 0.05; 
    
    return wave;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float randangle, float viewDist) {
    const float deltaPos = 0.25;
    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);
    
    float h0 = getWaterBump(posxz, waveM, waveZ, iswater, viewDist);
    float h1 = getWaterBump(posxz + vec2(-deltaPos, 0.0), waveM, waveZ, iswater, viewDist);
    float h2 = getWaterBump(posxz + vec2(0.0, -deltaPos), waveM, waveZ, iswater, viewDist);

    float xDelta = (h0 - h1) * 4.0;
    float yDelta = (h0 - h2) * 4.0;

    float xySum = xDelta + yDelta;
    vec3 wave = normalize(vec3(xDelta, yDelta, 1.0 - xySum * xySum));

    return wave;
}

vec3 getParallaxDisplacement(vec3 posxz, float iswater, float viewDist) {
    
    vec2 offset = viewVector.xy * (4.0 * WaterDepth) / max(viewDist, 1.0);
    
    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);
    
    for(int i = 0; i < WaterPoints; i++){
        posxz.xz = getWaterBump(posxz.xz - posxz.y, waveM, waveZ, iswater, viewDist) * offset + posxz.xz;
    }
    
    return posxz;
}