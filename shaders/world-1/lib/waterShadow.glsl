float Visibility(in sampler2DShadow ShadowMap, in vec3 SampleCoords) {
    return shadow2D(ShadowMap, vec3(SampleCoords.xy, SampleCoords.z - 0.001)).r;
}

float distort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

const int shadowSamples = 1;
const int ShadowSamplesPerSize = 2 * shadowSamples + 1;
const int TotalSamples = ShadowSamplesPerSize * ShadowSamplesPerSize;

vec3 shadowSample(vec3 worldPos) {
    vec4 shadowCoord = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    shadowCoord.xy *= distort(shadowCoord.xy);
    shadowCoord.z /= 6.0;
    vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;

    float RandomAngle = texture2D(noisetex, texcoord * 20.0).r * 100.0;
    float cosTheta = cos(RandomAngle);
    float sinTheta = sin(RandomAngle);
    mat2 Rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) 
                  / shadowMapResolution;
    vec3 ShadowAccum = vec3(0.0);

    for (int x = -shadowSamples; x <= shadowSamples; x++) {
        for (int y = -shadowSamples; y <= shadowSamples; y++) {
            vec2 Offset = Rotation * vec2(x, y);
            vec3 CurrentSampleCoordinate = vec3(SampleCoords.xy + Offset, 
                                                 SampleCoords.z);
            ShadowAccum += Visibility(shadowtex1, CurrentSampleCoordinate);
        }
    }

    ShadowAccum /= TotalSamples;
    return ShadowAccum;
}
