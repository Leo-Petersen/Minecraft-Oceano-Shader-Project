#ifndef SHARED_LIGHTING_GLSL
#define SHARED_LIGHTING_GLSL

float getTransparencyFactor() {
    return 0.5  * time[0] +   // sunrise
           0.6  * time[1] +   // day
           0.6  * time[2] +   // noon
           0.6  * time[3] +   // day
           0.5  * time[4] +   // sunset
           0.3 * time[5];     // night
}

float getShadowFactor() {
    return 0.75 * time[0] +
           1.0  * time[1] +
           1.0  * time[2] +
           1.0  * time[3] +
           0.75 * time[4] +
           0.25 * time[5];
}

float getTorchFactor() {
    return 1.0  * time[0] +
           0.33 * time[1] +
           0.33 * time[2] +
           0.33 * time[3] +
           1.0  * time[4] +
           1.0  * time[5];
}


float processSkyLight(float raw, float nightVision, float darknessLightFactor) {
    float sky = clamp(raw, ((1.0 - nightVision) * 0) + (0.5 * nightVision), 1.0);
    return pow(sky * (1.0 - darknessLightFactor), 0.5);
}

float processTorchLight(float rawTorch, float rawSky, float processedSky, 
                        float handlight, float darknessLightFactor) {
    float torch = rawTorch * (1.0 - darknessLightFactor * 0.5);
    float torchTimeBlend = mix(1.0, getTorchFactor(), rawSky);
    float torchmapLight = max(torch, handlight) * processedSky * torchTimeBlend;
    float torchmapCovered = max(torch, handlight) * (1.0 - processedSky);
    return (torchmapLight * 0.5) + torchmapCovered;
}


vec3 getTorchColor(float intensity) {
    vec3 base = vec3(torchR, torchG, torchB) / 255.0;
    vec3 warm = base * vec3(1.0, 0.7, 0.4);
    float t = clamp(intensity / 3.2, 0.0, 1.0);
    return mix(warm, base, sqrt(t));
}

vec3 getTorchLighting(float processedTorch, vec3 albedo) {
    float intensity = processedTorch * processedTorch * 3.2;
    return getTorchColor(intensity) * intensity * albedo;
}

#endif
