// Sky/Atmosphere colour for dimensions
#if defined NETHER || defined END
vec3 dimensionSky(vec3 dir, vec3 sunDir) {
    float skyUp = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
    #if defined NETHER
        vec3 zenith  = vec3(0.13, 0.035, 0.022);
        vec3 horizon = vec3(0.24, 0.070, 0.045);
        return mix(horizon, zenith, skyUp);
    #else
        vec3 zenith  = vec3(0.020, 0.010, 0.050);
        vec3 horizon = vec3(0.090, 0.055, 0.150);
        vec3 sky = mix(horizon, zenith, skyUp) * 2.0;

        // End sun disc
        float sunCos  = dot(dir, sunDir);
        float sunDisc = smoothstep(0.9992, 0.9997, sunCos);
        float sunGlow = pow(max(sunCos, 0.0), 350.0) * 0.35
                      + pow(max(sunCos, 0.0),  40.0) * 0.14;
        return sky + vec3(1.00, 0.80, 0.92) * (sunDisc * 8.0 + sunGlow);
    #endif
}
#endif
