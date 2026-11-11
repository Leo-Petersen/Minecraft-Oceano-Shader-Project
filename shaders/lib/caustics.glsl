// Raw caustic pattern from the wave normals
float waterCausticPattern(vec3 worldpos) {
	vec3 pos = worldpos + cameraPosition;
	float caustics = dot(getWaveHeight(pos.xz - pos.y, 1.0, 0.0, 0.0).xyz * 2.0 - 1.0, vec3(1.0));
			caustics = caustics * 0.1 + 0.9;
			caustics = clamp(caustics, 0.0, 1.0);
	return pow(caustics, 8.0) * 14.0;
}

// Pattern value for flat water: normal (0,0,1) gives 0.8^8 * 14 = 2.3488
const float waterCausticFlatValue = 2.3488;

// Caustic intensity used by the light shafts
vec3 waterCaustics(vec3 worldpos, float shadowVisibility){
	float caustics = waterCausticPattern(worldpos);
			caustics = mix(1.0, caustics, shadowVisibility);
			caustics = (caustics * 0.5) + 0.5;

	return vec3(caustics);
}

// Caustic light on surfaces under water
vec3 waterCausticsLight(vec3 worldpos, float shadowVisibility){
	float caustics = waterCausticPattern(worldpos) / waterCausticFlatValue;
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

    const int causticSteps = 4;
    const float causticMaxDist = 4.0;
    float stepSize = causticMaxDist / float(causticSteps);

    // The march is a straight line and ShadowSpace() is linear, so its shadow-space position is start + t * step
    vec4 sStart = ShadowSpace(worldPos);
    vec4 sStep  = shadowProjection * (shadowModelView * vec4(toWaterDir * stepSize, 0.0));

    float lastAboveT = 0.0;
    float waterHitT  = 0.0;
    bool found = false;

    for (int i = 1; i <= causticSteps; i++) {
        vec4 sCoord = sStart + sStep * float(i);
        sCoord.xy *= distort(sCoord.xy);
        sCoord.z /= 6.0;
        vec2 sUV = sCoord.xy * 0.5 + 0.5;

        if (any(lessThan(sUV, vec2(0.001))) || any(greaterThan(sUV, vec2(0.999)))) continue;

        float waterTag = texture2D(shadowcolor1, sUV).r;
        if (waterTag > 0.5) {
            waterHitT = float(i);
            found = true;
            break;
        }
        lastAboveT = float(i);
    }

    if (!found) return vec3(0.0);

    // Reject if water is too far from the fragment, basically stops caustics from appearing too far from water
    // (toWaterDir is normalized, so the distance is t * stepSize)
    float waterDist = waterHitT * stepSize;
    if (waterDist > 8.0) return vec3(0.0);

    // Bisection, refine the boundary between last non-water and first water sample
    float lo = lastAboveT;
    float hi = waterHitT;
    for (int j = 0; j < 5; j++) {
        float mid = (lo + hi) * 0.5;
        vec4 sCoord = sStart + sStep * mid;
        sCoord.xy *= distort(sCoord.xy);
        sCoord.z /= 6.0;
        vec2 sUV = sCoord.xy * 0.5 + 0.5;
        float waterTag = texture2D(shadowcolor1, sUV).r;
        if (waterTag > 0.5) hi = mid; else lo = mid;
    }
    float waterY = worldPos.y + toWaterDir.y * stepSize * ((lo + hi) * 0.5);

    if (waterY >= worldPos.y) return vec3(0.0);

    // Compute reflection point 'W' on the water surface ('W' for water!)
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