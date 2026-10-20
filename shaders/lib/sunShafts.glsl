#if !defined NETHER && !defined END
    #define sunShafts
#endif
#define sunShaftSamples 40
#define sunShaftStrength 0.55
#define sunShaftThreshold 0.55
#define sunShaftDecay 0.965
#define sunShaftDensity 0.85

vec2 sunShaftScreen(out float gate) {
    vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
    vec2 sunScreen = clip.xy / clip.w * 0.5 + 0.5;

    vec3 sunWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    float dayFade = smoothstep(-0.04, 0.16, sunWorld.y) * (1.0 - rainStrength * 0.7);
    float inFront = step(0.0, clip.w);

    vec2 d = abs(sunScreen - 0.5);
    float onScreen = 1.0 - smoothstep(0.5, 1.15, max(d.x, d.y));

    gate = dayFade * inFront * onScreen;
    return sunScreen;
}

vec3 sunShaftMarch(vec2 uv, vec2 sunScreen) {
    vec2 delta = (uv - sunScreen) * (sunShaftDensity / float(sunShaftSamples));
    vec2 pos = uv;
    float decay = 1.0;
    vec3 shaft = vec3(0.0);

    for (int i = 0; i < sunShaftSamples; i++) {
        pos -= delta;
        vec2 sp = clamp(pos, 0.0, 1.0);

        float skyMask = step(0.9999, textureLod(depthtex0, sp, 0.0).r);
        #ifdef DISTANT_HORIZONS
        skyMask *= step(0.9999, textureLod(dhDepthTex0, sp, 0.0).r);
        #endif

        vec3 s = textureLod(colortex0, sp, 0.0).rgb;
        float l = dot(s, vec3(0.2126, 0.7152, 0.0722));

        vec3 bright = s * smoothstep(sunShaftThreshold, sunShaftThreshold + 0.5, l) * skyMask;
        shaft += bright * decay;
        decay *= sunShaftDecay;
    }
    return shaft / float(sunShaftSamples);
}
