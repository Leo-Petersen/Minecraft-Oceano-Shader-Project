float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer8(a)   (bayer4(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer16(a)  (bayer8(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer32(a)  (bayer16(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer64(a)  (bayer32(0.5 * (a)) * 0.25 + bayer2(a))
float dither64 = bayer64(gl_FragCoord.xy);

float expDepth(float dist){
    return (far * (dist - near)) / (dist * (far - near));
}

float getDepthVol(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}

float shadowStep(sampler2DShadow shadow, vec3 sPos) {
    return shadow2D(shadow, sPos).r;
}

vec2 DistortPosition(in vec2 position){
    float CenterDistance = length(position);
    float DistortionFactor = mix(1.0, CenterDistance, 0.9);
    return position / DistortionFactor;
}

vec4 ShadowSpace(float depth0) {
    vec3 ClipSpace = vec3(texcoord, depth0) * 2.0 - 1.0;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

float hgPhase(float cosT, float g){
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(max(1.0 + g2 - 2.0 * g * cosT, 1e-4), 1.5));
}

vec3 getFog(vec3 color, vec3 cameraPosition, vec3 worldPos, vec3 volumeColor, float iswater, float glare, vec3 sunCol, float transitionFade, vec3 skyCol, float sunAngleCosine){

#ifdef volumetricLight
    const float shaftDensity = 0.030;   // how much light the medium scatters per block
    const float fogHeightK   = 24.0;    // vertical falloff of the shaft medium (blocks)
    const float fogFloor     = 0.05;    // thin uniform term so high air still shafts

    float increment = 64.0 / volumetricFogQuality;
          increment *= (1.0 + rainStrength * 1.6);
    float startRay = 1.0;
    const float endRay = 128.0;

    #ifdef TAA
    dither64 = fract(dither64 + frameTimeCounter * 8.0);
    #endif
    startRay += dither64 * increment;

    float sceneDepthLinear = getDepthVol(Depth);

    vec3 clip0  = vec3(texcoord, expDepth(startRay)) * 2.0 - 1.0;
    vec4 vw0    = gbufferProjectionInverse * vec4(clip0, 1.0);
    vec3 view0  = vw0.xyz / vw0.w;
    vec3 viewK  = view0 / startRay;

    mat4 shadowMat = shadowProjection * shadowModelView * gbufferModelViewInverse;
    vec4 shadowA   = shadowMat * vec4(viewK, 0.0);
    vec4 shadowB   = shadowMat[3];

    vec3 worldA = mat3(gbufferModelViewInverse) * viewK;
    vec3 worldB = gbufferModelViewInverse[3].xyz;

    vec3 startWorldPos = worldB;
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * -shadowLightPosition);

    float stepWorld = increment * length(worldA);

    vec3  sunDirW  = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3  viewDirW = normalize(worldPos);
    float VoL      = clamp(dot(viewDirW, sunDirW), -1.0, 1.0);
    float gF       = clamp(shaftAnisotropy, 0.0, 0.95);
    float phaseSun = mix(hgPhase(VoL, -0.15), hgPhase(VoL, gF), 0.72);

    vec3 sunLight = sunCol;
    bool eyeWater = (isEyeInWater > 0.9);
    if (eyeWater) sunLight = sunCol * vec3(0.55, 0.72, 0.9);

    vec3  shafts   = vec3(0.0);
    float transmit = 1.0;

    for (; startRay < endRay; startRay += increment) {
        if (startRay > sceneDepthLinear) break;

        vec4 shadowCoord = shadowA * startRay + shadowB;
        shadowCoord.xy *= distort(shadowCoord.xy);
        shadowCoord.z /= 6.0;
        vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;
        SampleCoords.z -= 0.0005;
        float sunVis = shadowStep(shadowtex1, SampleCoords);

        vec3 wp = worldA * startRay + worldB;
        float altBlocks = wp.y + eyeAltitude;
        float density = max(exp(-max(altBlocks - FogAltitude, 0.0) / fogHeightK), fogFloor);

        if (eyeWater) {
            float distToSurface = abs(wp.y - startWorldPos.y) / max(abs(lightDir.y), 1e-3);
            vec3 cp = wp + lightDir * distToSurface; cp.y = startWorldPos.y;
            float caus = waterCaustics(cp, 1.0).x;
            caus *= 0.5 + 0.5 * max(0.0, dot(normalize(wp - cameraPosition), lightDir));
            sunVis *= caus;
        }

        float sigmaS = shaftDensity * density * FogStrength;
        float stepTr = exp(-sigmaS * stepWorld);
        float integ  = (1.0 - stepTr) / max(sigmaS, 1e-5);

        shafts   += transmit * (sunLight * sunVis * phaseSun * sigmaS) * integ;
        transmit *= stepTr;
    }

    shafts *= shaftStrength * transitionFade * (1.0 - rainStrength);

    color = max(color + shafts, vec3(0.0));
#endif

    return color;
}
