vec3 waterCaustics(vec3 worldpos, float shadowVisibility){
	vec3 pos = worldpos + cameraPosition;
	float caustics = dot(getWaveHeight(pos.xz - pos.y, 1.0, 0.0, 0.0).xyz * 2.0 - 1.0, vec3(1.0));
			caustics = caustics * 0.1 + 0.9;
			caustics = clamp(caustics, 0.0, 1.0);
			caustics = pow(caustics, 8.0) * 14.0;
			caustics = mix(1.0, caustics, shadowVisibility);
			caustics = (caustics * 0.5) + 0.5;

	return vec3(caustics);
}


vec3 reflectedWaterCaustics(
    vec3 worldPos, vec3 worldNormal, vec3 sunDirWorld,
    float skyLight, float iswater,
    float fragmentSunVisibility,
    float causticTimeFactor
) {
    if (iswater > 0.5)        return vec3(0.0);
    if (sunDirWorld.y < 0.05) return vec3(0.0);
    if (skyLight < 0.1)       return vec3(0.0);

    vec3 reflectedLightDir = vec3(-sunDirWorld.x, sunDirWorld.y, -sunDirWorld.z);

    // Incidence of reflected light on this surface
    float incidence = max(-dot(worldNormal, reflectedLightDir), 0.0);
    if (incidence < 0.01) return vec3(0.0);

    float shadowMask = 1.0 - smoothstep(0.53, 0.6, fragmentSunVisibility);
    if (shadowMask < 0.01) return vec3(0.0);

    // March from fragment toward the water surface along the reverse reflection path.
    vec3 toWaterDir = normalize(vec3(sunDirWorld.x, -sunDirWorld.y, sunDirWorld.z));

    const int STEPS = 16;
    const float MAX_DIST = 24.0;
    float stepSize = MAX_DIST / float(STEPS);

    vec3 lastAbovePos = worldPos;
    vec3 waterHitPos  = vec3(0.0);
    bool found = false;

    for (int i = 1; i <= STEPS; i++) {
        vec3 samplePos = worldPos + toWaterDir * float(i) * stepSize;

        vec4 sCoord = ShadowSpace(samplePos);
        sCoord.xy *= distort(sCoord.xy);
        sCoord.z /= 6.0;
        vec2 sUV = sCoord.xy * 0.5 + 0.5;

        if (any(lessThan(sUV, vec2(0.001))) || any(greaterThan(sUV, vec2(0.999)))) continue;

        float waterTag = texture2D(shadowcolor1, sUV).r;
        if (waterTag > 0.5) {
            waterHitPos = samplePos;
            found = true;
            break;
        }
        lastAbovePos = samplePos;
    }

    if (!found) return vec3(0.0);

    // Reject if water is too far from the fragment, basically stops caustics from appearing too far from water
    float waterDist = length(waterHitPos - worldPos);
    if (waterDist > 8.0) return vec3(0.0);

    // Bisection: refine the boundary between last non-water and first water sample
    vec3 lo = lastAbovePos;
    vec3 hi = waterHitPos;
    for (int j = 0; j < 5; j++) {
        vec3 mid = (lo + hi) * 0.5;
        vec4 sCoord = ShadowSpace(mid);
        sCoord.xy *= distort(sCoord.xy);
        sCoord.z /= 6.0;
        vec2 sUV = sCoord.xy * 0.5 + 0.5;
        float waterTag = texture2D(shadowcolor1, sUV).r;
        if (waterTag > 0.5) hi = mid; else lo = mid;
    }
    float waterY = ((lo + hi) * 0.5).y;

    if (waterY >= worldPos.y) return vec3(0.0);

    // Compute reflection point 'W' on the water surface (W sounds like a good name)
    float heightAboveWater = worldPos.y - waterY;
    float t = heightAboveWater / sunDirWorld.y;
    if (t <= 0.0 || t > 64.0) return vec3(0.0);

    vec3 W = vec3(worldPos.x + sunDirWorld.x * t, waterY,
                  worldPos.z + sunDirWorld.z * t);

    // Sample the wave caustic pattern at W
    vec3 wpos = W + cameraPosition;
    float caust = dot(getWaveHeight(wpos.xz, 1.0, 0.0, 0.0).xyz * 2.0 - 1.0, vec3(1.0));
    caust = caust * 0.1 + 0.9;
    caust = clamp(caust, 0.0, 1.0);
    caust = pow(caust, 8.0) * 14.0;

    // Falloff with height above water
    float distToWater = length(W - worldPos);
    float distFalloff = exp(-distToWater * 0.15);

    vec3 tint = vec3(0.72, 0.92, 1.0);
    float intensity = caust * incidence * shadowMask * skyLight * distFalloff * 0.44 * causticTimeFactor * reflectedCausticsStrength;
          intensity = pow(intensity, 5);

    return tint * intensity;
}