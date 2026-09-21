
float distort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

float getWaterShadowBias(vec3 SampleCoords) {
    float dist = length(SampleCoords.xy - 0.5);
    float distFactor = smoothstep(0.0, 0.5, dist);

    float NdotL = max(dot(viewNormal, shadowLightPosition * 0.01), 0.0);
    float slopeBias = 0.0004 * (1.0 - NdotL) * distFactor;
    float baseBias  = 0.0001 + dist * 0.0005;

    return baseBias + slopeBias;
}

vec3 shadowSample(vec3 worldPos) {
    vec4 shadowCoord = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    shadowCoord.xy *= distort(shadowCoord.xy);
    shadowCoord.z  /= 6.0;
    vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;

    float IGN = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    #ifdef TAA
        IGN = fract(IGN + float(frameCounter % 8) / 8.0);
    #endif
    float angle = IGN * 6.28318530718;

    float filterSize = 0.0025 * filterStr * (1.0 + rainT * 1.2);
    float bias       = getWaterShadowBias(SampleCoords);

    const float goldenAngle = 2.39996323;
    float goldenCos = cos(goldenAngle);
    float goldenSin = sin(goldenAngle);
    vec2 dir = vec2(cos(angle), sin(angle));

    float ShadowAccum = 0.0;
    for (int i = 0; i < lightingQuality; i++) {
        float radius = sqrt((float(i) + 0.5) / float(lightingQuality));
        vec2  offset = dir * radius;

        ShadowAccum += shadow2D(shadowtex1,
            vec3(SampleCoords.xy + offset * filterSize, SampleCoords.z - bias)).r;

        dir = vec2(
            dir.x * goldenCos - dir.y * goldenSin,
            dir.x * goldenSin + dir.y * goldenCos
        );
    }

    return vec3(ShadowAccum / float(lightingQuality));
}
