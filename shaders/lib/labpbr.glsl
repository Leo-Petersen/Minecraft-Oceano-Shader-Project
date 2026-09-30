#ifndef LABPBR_INCLUDED
#define LABPBR_INCLUDED

// LabPBR Docs: https://shaderlabs.org/wiki/LabPBR_Material_Standard

// References for Material Reflections and PBR Metals:
//
//   LabPBR Material Standard              https://shaderlabs.org/wiki/LabPBR_Material_Standard
//   Karis 2013, Real Shading in UE4       https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
//   Karis 2014, PBS on Mobile             https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
//   Lagarde & de Rousiers 2014, Frostbite https://seblagarde.wordpress.com/2015/07/14/siggraph-2014-moving-frostbite-to-physically-based-rendering/
//   Fdez-Aguera 2019, Multiscatter IBL    https://www.jcgt.org/published/0008/01/03/

struct LabMaterial {
    float roughness;    // perceptual roughness (1 - smoothness)
    float alpha;        // GGX alpha = roughness^2
    vec3  F0;
    float metalness;    // LabPBR metals are binary *thumbs up*
    int   metalId;      // 0 to 7 for hardcoded metals (230 to 237) when HARDCODED_METALS is on, else -1. See docs
};

#ifdef HARDCODED_METALS

// from the LabPBR spec
const vec3 labMetalN[8] = vec3[8](
    vec3(2.9114,  2.9497,  2.5845),     // iron
    vec3(0.18299, 0.42108, 1.3734),     // gold
    vec3(1.3456,  0.96521, 0.61722),    // aluminum
    vec3(3.1071,  3.1812,  2.3230),     // chrome
    vec3(0.27105, 0.67693, 1.3164),     // copper
    vec3(1.9100,  1.8300,  1.4400),     // lead
    vec3(2.3757,  2.0847,  1.8453),     // platinum
    vec3(0.15943, 0.14512, 0.13547)     // silver
);
const vec3 labMetalK[8] = vec3[8](
    vec3(3.0893, 2.9318, 2.7670),
    vec3(3.4242, 2.3459, 1.7704),
    vec3(7.4746, 6.3995, 5.3031),
    vec3(3.3314, 3.3291, 3.1350),
    vec3(3.6092, 2.6248, 2.2921),
    vec3(3.5100, 3.4000, 3.1800),
    vec3(4.2655, 3.7153, 3.1365),
    vec3(3.9291, 3.1900, 2.3808)
);

// Unpolarized Fresnel reflectance of a conductor at incidence cosine cosT
vec3 fresnelConductor(float cosT, vec3 n, vec3 k) {
    float c2    = cosT * cosT;
    vec3  n2k2  = n * n + k * k;
    vec3  twoNc = 2.0 * n * cosT;
    vec3  Rs = (n2k2 - twoNc + c2) / (n2k2 + twoNc + c2);
    vec3  Rp = (n2k2 * c2 - twoNc + 1.0) / (n2k2 * c2 + twoNc + 1.0);
    return 0.5 * (Rs + Rp);
}
#endif

LabMaterial decodeLabPBR(vec2 spec, vec3 albedo, float skyLight, float wet) {
    LabMaterial m;
    m.metalId = -1;

    int g = int(spec.g * 255.0 + 0.5);
    if (g >= 230) {
        m.metalness = 1.0;
        m.F0 = albedo;  // 255, and all metals when HARDCODED_METALS is off
        #ifdef HARDCODED_METALS
        // Albedo metals
        m.F0 = clamp(albedo * HC_METAL_BRIGHTNESS, 0.0, 1.0);
        if (g <= 237) {
            // The metal's measured reflectance sets the brightness
            m.metalId = g - 230;
            const vec3 lumW = vec3(0.2126, 0.7152, 0.0722);
            float lum     = dot(albedo, lumW);
            float metalF0 = dot(fresnelConductor(1.0, labMetalN[m.metalId], labMetalK[m.metalId]), lumW);
            vec3  tint    = albedo / max(sqrt(max(lum, 0.0) * HC_TINT_REF), 0.05);
            m.F0 = clamp(metalF0 * tint * HC_METAL_BRIGHTNESS, 0.0, 1.0);
        }
        #endif
    } else {
        m.metalness = 0.0;
        m.F0 = vec3(g > 0 ? spec.g : 0.04);
    }

    // smoothing where rain lands
    float wetMask = wet * clamp(pow(skyLight, 50.0), 0.0, 1.0);
    m.roughness = clamp((1.0 - spec.r) * (1.0 - 0.45 * wetMask), 0.02, 1.0);
    m.alpha     = m.roughness * m.roughness;
    return m;
}

// split sum environment BRDF (Karis, "Physically Based Shading on Mobile").
vec2 envBRDFApprox(float NoV, float roughness) {
    const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
    const vec4 c1 = vec4( 1.0,  0.0425,  1.040, -0.040);
    vec4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return vec2(-1.04, 1.04) * a004 + r.zw;
}

// Directional albedo of the specular lobe
vec3 specularAlbedo(LabMaterial m, float NoV) {
    vec2 AB = envBRDFApprox(NoV, m.roughness);
    vec3 E  = m.F0 * AB.x + AB.y;
    E *= 1.0 + m.F0 * (1.0 / max(AB.x + AB.y, 1e-3) - 1.0);
    #ifdef HARDCODED_METALS
    if (m.metalId >= 0) {
        vec3 n = labMetalN[m.metalId], k = labMetalK[m.metalId];
        vec3 F0c     = fresnelConductor(1.0, n, k);
        vec3 schlick = F0c + (1.0 - F0c) * pow(1.0 - NoV, 5.0);
        E *= fresnelConductor(NoV, n, k) / max(schlick, vec3(1e-4));
    }
    #endif
    return clamp(E, 0.0, 1.0);
}

// unpack the 8 bit per channel albedo deferred stores in colortex4.a
vec3 unpackAlbedo(float v) {
    v = floor(v + 0.5);
    float r = floor(v / 65536.0);
    float g = floor((v - r * 65536.0) / 256.0);
    return vec3(r, g, v - r * 65536.0 - g * 256.0) / 255.0;
}

// Frostbite dominant specular direction: rough lobes lean toward the normal.
vec3 specularDominantDir(vec3 N, vec3 R, float roughness) {
    float s = 1.0 - roughness;
    return normalize(mix(N, R, s * (sqrt(s) + roughness)));
}

#endif
