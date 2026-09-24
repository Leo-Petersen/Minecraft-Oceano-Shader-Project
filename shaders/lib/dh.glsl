#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4  dhProjection;
uniform mat4  dhProjectionInverse;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float dhRenderDistance;
#endif

#define DH_SSS_STRENGTH 0.5   // [0.2 0.3 0.4 0.5 0.6 0.7 0.8 1.0]
#define DH_SSS_FORWARD  0.7   // [0.4 0.5 0.6 0.7 0.8 0.9 1.0]  peak when looking toward the sun
#define DH_SSS_DEPTH 0.015

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

#ifdef DISTANT_HORIZONS
float getMergedViewZ(vec2 uv, sampler2D vanillaDepth) {
    float z = dhLinearZ(texture2D(dhDepthTex0, uv).r, dhProjectionInverse);
    float vd = texture2D(vanillaDepth, uv).r;
    if (vd < 1.0) {
        z = max(z, dhLinearZ(vd, gbufferProjectionInverse));   // view Z is negative, so max = closer
    }
    return z;
}

float GetDHTransmittance(vec3 viewPosDH, vec3 lightVecView, float dither,
                         sampler2D matTex, sampler2D vanillaDepth) {
    float density = 0.0;
    float traced  = 0.0;

    for (int i = 0; i < 8; i++) {
        float t = 0.75 * exp2((float(i) + dither) * 0.75);
        vec3 tracePos = viewPosDH + lightVecView * t;
        if (tracePos.z > -dhNearPlane) break;

        vec4 p = dhProjection * vec4(tracePos, 1.0);
        p.xy = p.xy / p.w * 0.5 + 0.5;
        if (any(lessThan(p.xy, vec2(0.0))) || any(greaterThan(p.xy, vec2(1.0)))) break;
        traced = t;

        float zDelta = getMergedViewZ(p.xy, vanillaDepth) - tracePos.z;
        float thickness = 2.0 + t * 0.25;
        float hit = smoothstep(0.0, 0.5, zDelta) * smoothstep(thickness + 2.0, thickness, zDelta);

        if (hit > 0.01) {
            float m = texture2D(matTex, p.xy).b;
            float isLeaf = float(m > 0.005 && m < 0.02);
            density += hit * mix(3.0, 0.8, isLeaf);
            if (density > 4.0) break;
        }
    }

    float trans = exp(-density);
    float confidence = smoothstep(2.0, 16.0, traced);
    return trans * mix(0.35, 1.0, confidence);
}
#endif

#if defined(DISTANT_HORIZONS) && defined(SubsurfaceScattering)
vec3 calculateSSS_DH(vec3 viewPos, vec3 normal, vec3 lightColor,
                     float sssAmount, float skyLight, float dither, float distFactor) {
    vec3 lightDir = normalize(shadowLightPosition);
    float NdotL = dot(normal, lightDir);
    float backface = clamp(1.0 - NdotL * 2.0, 0.0, 1.0);
    if (backface < 0.01) return vec3(0.0);

    float trans = GetDHTransmittance(viewPos, lightDir, dither, colortex2, depthtex1);
    trans *= trans;
    if (trans < 0.01) return vec3(0.0);

    float VdotL = dot(normalize(-viewPos), lightDir);
    float phase = mix(0.35, DH_SSS_FORWARD, clamp(-VdotL * 0.5 + 0.5, 0.0, 1.0));

    vec3 sss = lightColor * lightColor * phase * sssAmount * trans * backface * skyLight * 0.62;
    sss *= 1.0 - rainStrength * 0.65;
    sss *= DH_SSS_STRENGTH * mix(1.0, 0.5, distFactor);
    return sss;
}
#endif