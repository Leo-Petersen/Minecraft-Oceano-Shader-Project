
#ifdef volumetricCloudFog

float cfDistort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

float cfBayer2(vec2 a){
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define cfBayer4(a)   (cfBayer2( .5*(a))*.25+cfBayer2(a))
#define cfBayer8(a)   (cfBayer4( .5*(a))*.25+cfBayer2(a))
#define cfBayer16(a)  (cfBayer8( .5*(a))*.25+cfBayer2(a))
#define cfBayer32(a)  (cfBayer16(.5*(a))*.25+cfBayer2(a))
#define cfBayer64(a)  (cfBayer32(.5*(a))*.25+cfBayer2(a))

float cfExpDepth(float dist){
    return (far * (dist - near)) / (dist * (far - near));
}

float cfGetDepth(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}

float cfShadowStep(sampler2D shadow, vec3 sPos) {
    return clamp(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).y, 0.0) * 4096, 0.0, 1.0);
}

vec4 cfShadowSpace(vec2 coord, float depth0) {
    vec3 ClipSpace = vec3(coord, depth0) * 2.0 - 1.0;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

float cfShape(vec2 xz) {
    vec2 p = xz * 0.012 + vec2(frameTimeCounter * CLOUD_FOG_SPEED * 0.1, 0.0);

    float shape = sin(p.x * 1.0 + p.y * 0.7) * 0.45
                + sin(p.x * 2.7 - p.y * 1.8) * 0.30
                + sin(p.y * 3.2 + p.x * 0.5) * 0.25;

    shape += rainStrength;

    float coverage = mix(CLOUD_FOG_COVERAGE, 1.0, rainStrength);
    float threshold = 1.0 - coverage;

    float edgeSoftness = mix(0.15, 0.4, rainStrength);
    return smoothstep(threshold - edgeSoftness, threshold + edgeSoftness, shape);
}


float cfGetDensity(vec3 wpos) {
    float h     = wpos.y;

    // Rain pulls fog lower and makes it thicker
    float heightDrop = rainStrength * 20.0;
    float thicknessGain = rainStrength * 15.0;

    float hLow  = CLOUD_FOG_HEIGHT - CLOUD_FOG_THICKNESS - heightDrop - thicknessGain;
    float hHigh = CLOUD_FOG_HEIGHT + CLOUD_FOG_THICKNESS - heightDrop + thicknessGain;

    if (h < hLow || h > hHigh) return 0.0;

    float hNorm = (h - hLow) / (hHigh - hLow);

    // Softer profile in rain; less defined edges, more uniform
    float bottomEdge = mix(0.12, 0.25, rainStrength);
    float topEdge    = mix(0.45, 0.6, rainStrength);
    float profile = smoothstep(0.0, bottomEdge, hNorm) * smoothstep(1.0, topEdge, hNorm);

    float shape = cfShape(wpos.xz);

    // Density increases in rain
    float rainDensity = mix(1.0, CLOUD_FOG_RAIN_DENSITY, rainStrength);

    return profile * shape * CLOUD_FOG_DENSITY * rainDensity * mix(0.0, 1.0, transitionFade);
}

#define CF_LIGHT_STEPS 6

float cfLightMarch(vec3 pos, vec3 lightDir) {
    float hHigh = CLOUD_FOG_HEIGHT + CLOUD_FOG_THICKNESS;

    float marchDist;
    if (lightDir.y > 0.01) {
        marchDist = min((hHigh - pos.y) / lightDir.y, CLOUD_FOG_THICKNESS * 8.0);
    } else {
        marchDist = CLOUD_FOG_THICKNESS * 4.0;
    }

    float stepLen = marchDist / float(CF_LIGHT_STEPS);
    float od = 0.0;

    for (int j = 0; j < CF_LIGHT_STEPS; j++) {
        vec3 sp = pos + lightDir * (float(j) + 0.5) * stepLen;
        od += cfGetDensity(sp) * stepLen;
    }

    return od;
}

float cfHG(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (12.566370 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

float cfPhase(float cosTheta) {
    return mix(cfHG(cosTheta, -0.25), cfHG(cosTheta, 0.6), 0.7);
}

float cfPowder(float od) {
    return 1.0 - exp(-od * 2.0);
}

// Estimate fog amount for a reflected ray looking up at the cloud slab
float cfReflectedFog(vec3 worldPos, vec3 reflectDir, vec3 camPos) {
    float hLow  = CLOUD_FOG_HEIGHT - CLOUD_FOG_THICKNESS;
    float hHigh = CLOUD_FOG_HEIGHT + CLOUD_FOG_THICKNESS;
    float camY  = camPos.y;

    // If reflected ray points downward, no fog
    if (reflectDir.y < 0.01) return 0.0;

    // Distance to enter and exit the slab along reflected ray
    float tLow  = (hLow - camY) / reflectDir.y;
    float tHigh = (hHigh - camY) / reflectDir.y;

    if (tLow < 0.0 && tHigh < 0.0) return 0.0;

    float tEnter = max(min(tLow, tHigh), 0.0);
    float tExit  = max(tLow, tHigh);
    float pathLength = tExit - tEnter;

    // Sample shape at the midpoint of the path
    vec3 midPoint = camPos + reflectDir * (tEnter + pathLength * 0.5);
    float shape = cfShape(midPoint.xz);

    // Optical depth through the slab
    float coverage = mix(CLOUD_FOG_COVERAGE, 1.0, rainStrength);
    float od = shape * coverage * CLOUD_FOG_DENSITY * pathLength * 0.04;

    return 1.0 - exp(-od);
}

float cfTemporalDither(vec2 coord, float time) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    float t = fract(time * 0.618033988749);
    return fract(magic.z * fract(dot(coord + t * 100.0, magic.xy)));
}

float cfStart = mix(CLOUD_FOG_START, 0.0, rainStrength);

vec4 getVolumetricCloudFog(vec3 camPos, vec3 fogCol) {

    // Dithering
    #ifdef TAA
    float dith = cfTemporalDither(gl_FragCoord.xy, frameTimeCounter);
    #else
    float dith = cfBayer64(gl_FragCoord.xy);
    #endif

    float sceneDepth = cfGetDepth(Depth);
    float renderDist = far;
    float maxRay     = min(sceneDepth, renderDist);

    if (maxRay < cfStart) return vec4(0.0, 0.0, 0.0, 1.0);

    // View & light direction (world space)
    vec3 clip0   = vec3(texcoord, 0.0) * 2.0 - 1.0;
    vec4 view0   = gbufferProjectionInverse * vec4(clip0, 1.0);
    vec3 viewDir = normalize(mat3(gbufferModelViewInverse) * (view0.xyz / view0.w));
    vec3 lightDir= normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);

    float cosTheta = dot(viewDir, lightDir);
    float phase    = cfPhase(cosTheta);
          phase    = max(phase, 0.08);

    // Ray march state
    float transmittance = 1.0;
    vec3  scattered     = vec3(0.0);
    float stepSize      = (maxRay - cfStart) / float(CLOUD_FOG_SAMPLES);

    // Extinction coefficients
    const float sigmaE     = 0.04;  // View ray extinction
    const float sigmaLight = 0.15;  // Light march extinction (higher for visible self-shadowing)

    for (int i = 0; i < CLOUD_FOG_SAMPLES; i++) {
        if (transmittance < 0.01) break;

        float ray = cfStart + (float(i) + dith * 0.7) * stepSize;

        // Reconstruct world position
        float expD = cfExpDepth(ray);
        vec3  clip = vec3(texcoord, expD) * 2.0 - 1.0;
        vec4  vw   = gbufferProjectionInverse * vec4(clip, 1.0);
        vec3  wpos = mat3(gbufferModelViewInverse) * (vw.xyz / vw.w)
                   + gbufferModelViewInverse[3].xyz + camPos;

        float distXZ = length(wpos.xz - camPos.xz);
        if (distXZ > renderDist) break;

        // --- Sample density ---
        float density = cfGetDensity(wpos);
        if (density < 0.001) continue;

        // Near/far fading applied to density
        float dist3D   = length(wpos - camPos);
        float nearFade = smoothstep(cfStart, cfStart + CLOUD_FOG_FADE_NEAR, dist3D);
        nearFade *= nearFade;
        density  *= nearFade;

        float farFade    = smoothstep(renderDist, renderDist * 0.75, dist3D);
        float renderFade = smoothstep(renderDist, renderDist * 0.75, distXZ);
        density *= farFade * renderFade;

        if (density < 0.001) continue;

        float hLow  = CLOUD_FOG_HEIGHT - CLOUD_FOG_THICKNESS;
        float hHigh = CLOUD_FOG_HEIGHT + CLOUD_FOG_THICKNESS;
        float hNorm = clamp((wpos.y - hLow) / (hHigh - hLow), 0.0, 1.0);
        float heightShade = mix(0.4, 1.0, hNorm);

        vec4 sc    = cfShadowSpace(texcoord, expD);
        sc.xy     *= cfDistort(sc.xy);
        vec3 sCoord= vec3(sc.xy, sc.z / 6.0) * 0.5 + 0.5;
        sCoord.z  -= 0.0005;

        float edgeDist = min(min(sCoord.x, 1.0 - sCoord.x), min(sCoord.y, 1.0 - sCoord.y));
        float inRange  = smoothstep(0.0, 0.05, edgeDist);
        float shadow   = mix(0.0, cfShadowStep(shadowtex1, sCoord), inRange);

        float lightOD       = cfLightMarch(wpos, lightDir);
        float lightTransmit = exp(-sigmaLight * lightOD);

        float powder    = cfPowder(lightOD);
        float powderMix = mix(1.0, powder, smoothstep(-0.1, 0.5, cosTheta));

        float ambient = CLOUD_FOG_MIN_BRIGHTNESS + 0.3;
        float rainDim = 1.0 - rainStrength * 0.8;
        float direct  = shadow * lightTransmit * powderMix * phase * heightShade * 5.0 * rainDim;
        float light   = ambient + direct;

        float tau       = density * sigmaE * stepSize;
        float stepTrans = exp(-tau);

        // Slight blue tint with depth
        float depthRatio = float(i) / float(CLOUD_FOG_SAMPLES);
        vec3 tintedFog   = fogCol * (1.0 + vec3(-0.05, 0.0, 0.08) * depthRatio)
                         * (1.0 - rainStrength * 0.7);

        // Energy-conserving in-scattering
        scattered    += tintedFog * light * (1.0 - stepTrans) * transmittance;
        transmittance*= stepTrans;
    }

    transmittance = max(transmittance, CLOUD_FOG_MIN_TRANSMIT);

    return vec4(scattered, transmittance);
}

#endif
