#define WaterDepth 1.00 //[0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00 5.50 6.00 6.50 7.00 7.50 8.00 8.50 9.00 9.50 10.00] //Depth of water
#define WaterPoints 2 //[2 4 6 8 16 32] 

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

float getWaterBump(vec2 posxz, float waveM, float waveZ, float iswater) {
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
    wave *= mix(0.3, 1.0, iswater) * 0.06; 
    
    return wave;
}

vec3 getWaveHeight(vec2 posxz, float iswater, float randangle) {
    const float deltaPos = 0.25;
    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);
    
    float h0 = getWaterBump(posxz, waveM, waveZ, iswater);
    float h1 = getWaterBump(posxz + vec2(-deltaPos, 0.0), waveM, waveZ, iswater);
    float h2 = getWaterBump(posxz + vec2(0.0, -deltaPos), waveM, waveZ, iswater);

    float xDelta = (h0 - h1) * 4.0;
    float yDelta = (h0 - h2) * 4.0;

    float xySum = xDelta + yDelta;
    vec3 wave = normalize(vec3(xDelta, yDelta, 1.0 - xySum * xySum));

    return wave;
}

vec3 getParallaxDisplacement(vec3 posxz, float iswater) {
    
    vec2 offset = viewVector.xy * (6.0 * WaterDepth) / max(dist, 1.0);
    
    float waveZ = mix(3.0, 0.25, iswater);
    float waveM = mix(0.0, 2.0, iswater);
    
    for(int i = 0; i < WaterPoints; i++){
        posxz.xz = getWaterBump(posxz.xz - posxz.y, waveM, waveZ, iswater) * offset + posxz.xz;
    }
    
    return posxz;
}