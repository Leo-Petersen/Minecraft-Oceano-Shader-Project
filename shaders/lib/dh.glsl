#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4  dhProjection;
uniform mat4  dhProjectionInverse;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float dhRenderDistance;
#endif

bool isSky(vec2 uv, float vanillaDepth) {
#ifdef DISTANT_HORIZONS
    return vanillaDepth >= 1.0 && texture2D(dhDepthTex0, uv).r >= 1.0;
#else
    return vanillaDepth >= 1.0;
#endif
}

// merging vanilla + DH depth
vec3 reconstructViewPos(vec2 uv, float vanillaDepth, out bool fromDH) {
    fromDH = false;
#ifdef DISTANT_HORIZONS
    if (vanillaDepth >= 1.0) {
        float dhd = texture2D(dhDepthTex0, uv).r;
        if (dhd < 1.0) {
            fromDH = true;
            vec4 clip = vec4(uv, dhd, 1.0) * 2.0 - 1.0;
            vec4 vp   = dhProjectionInverse * clip;
            return vp.xyz / vp.w;
        }
    }
#endif
    vec4 clip = vec4(uv, vanillaDepth, 1.0) * 2.0 - 1.0;
    vec4 vp   = gbufferProjectionInverse * clip;
    return vp.xyz / vp.w;
}

// used by the water depth fog
vec3 reconstructViewPosOpaque(vec2 uv, float vanillaDepth1) {
#ifdef DISTANT_HORIZONS
    if (vanillaDepth1 >= 1.0) {
        float dhd = texture2D(dhDepthTex1, uv).r;
        if (dhd < 1.0) {
            vec4 clip = vec4(uv, dhd, 1.0) * 2.0 - 1.0;
            vec4 vp   = dhProjectionInverse * clip;
            return vp.xyz / vp.w;
        }
    }
#endif
    vec4 clip = vec4(uv, vanillaDepth1, 1.0) * 2.0 - 1.0;
    vec4 vp   = gbufferProjectionInverse * clip;
    return vp.xyz / vp.w;
}

// far distance
#ifdef DISTANT_HORIZONS
    #define FOG_FAR max(far, dhRenderDistance)
#else
    #define FOG_FAR far
#endif

#ifdef DISTANT_HORIZONS
// Linearize a DH depth sample to view space Z
float dhLinearZ(float d, mat4 projInv) {
    vec4 v = projInv * (vec4(0.0, 0.0, d, 1.0) * 2.0 - 1.0);
    return v.z / v.w;
}

// light-trace shadow for DH terrain. Returns 0 (shadow) & 1 (lit)
float GetDHShadow(vec3 viewPosDH, vec3 lightVecView, float dither) {
    float shadow = 1.0;
    float thickness = 4.0;

    for (int i = 0; i < 16; i++) {
        float traceStep = exp2((i + dither) * 0.5 - 2.0);
        vec3 tracePos = viewPosDH + lightVecView * traceStep;

        vec4 p = dhProjection * vec4(tracePos, 1.0);
        p = p / p.w * 0.5 + 0.5;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) break;

        float traceZ = texture2D(dhDepthTex0, p.xy).r;
        float sceneZ = dhLinearZ(traceZ, dhProjectionInverse);
        float zDelta = -tracePos.z - (-sceneZ);

        shadow *= 1.0 - smoothstep(0.0, 0.5, zDelta)
                      * smoothstep(thickness + 1.0, thickness, zDelta);
        thickness += 0.5;
    }
    return shadow;
}
#endif