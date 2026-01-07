
#ifdef volumetricCloudFog

float distort(vec2 pos) {
    return 1.0 / ((1.0 - shadowDistortion) + length(pos) * shadowDistortion);
}

float cloudBayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define cloudBayer4(a)   (cloudBayer2( .5*(a))*.25+cloudBayer2(a))
#define cloudBayer8(a)   (cloudBayer4( .5*(a))*.25+cloudBayer2(a))
#define cloudBayer16(a)  (cloudBayer8( .5*(a))*.25+cloudBayer2(a))
#define cloudBayer32(a)  (cloudBayer16(.5*(a))*.25+cloudBayer2(a))
#define cloudBayer64(a)  (cloudBayer32(.5*(a))*.25+cloudBayer2(a))

float cloudExpDepth(float dist){
    return (far * (dist - near)) / (dist * (far - near));
}

float cloudGetDepth(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}


float cloudShadowStep(sampler2D shadow, vec3 sPos) {
    return clamp(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).y, 0.0) * 4096, 0.0, 1.0);
}

vec4 cloudShadowSpace(vec2 coord, float depth0) {
    vec3 ClipSpace = vec3(coord, depth0) * 2.0f - 1.0f;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0f);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

#endif

// Noise functions for cloud density //
float cloudHash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float valueNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float c000 = cloudHash(i);
    float c100 = cloudHash(i + vec3(1.0, 0.0, 0.0));
    float c010 = cloudHash(i + vec3(0.0, 1.0, 0.0));
    float c110 = cloudHash(i + vec3(1.0, 1.0, 0.0));
    float c001 = cloudHash(i + vec3(0.0, 0.0, 1.0));
    float c101 = cloudHash(i + vec3(1.0, 0.0, 1.0));
    float c011 = cloudHash(i + vec3(0.0, 1.0, 1.0));
    float c111 = cloudHash(i + vec3(1.0, 1.0, 1.0));
    
    return mix(
        mix(mix(c000, c100, f.x), mix(c010, c110, f.x), f.y),
        mix(mix(c001, c101, f.x), mix(c011, c111, f.x), f.y),
        f.z
    );
}

float cloudFBM(vec3 p, float detailLevel) {
    float n = valueNoise(p) * 0.65;
    if (detailLevel > 0.3) {
        n += valueNoise(p * 2.0 + 0.5) * 0.35;
    }
    return n;
}

// Density calculation //
float getCloudDensity(vec3 wpos, float detailLevel, out float hNormOut) {
    float h = wpos.y;
    float hLow = CLOUD_FOG_HEIGHT - CLOUD_FOG_THICKNESS;
    float hHigh = CLOUD_FOG_HEIGHT + CLOUD_FOG_THICKNESS;
    
    if (h < hLow || h > hHigh) {
        hNormOut = 0.0;
        return 0.0;
    }
    
    float hNorm = (h - hLow) / (hHigh - hLow + 0.001);
    hNormOut = hNorm;
    
    float heightGrad = pow(smoothstep(0.0, 0.3, hNorm), 0.7) * smoothstep(1.0, 0.15, hNorm);
    
    if (heightGrad < 0.001) return 0.0;
    
    float t = frameTimeCounter * CLOUD_FOG_SPEED;
    vec3 p = wpos * 0.01 + vec3(
        t * 0.1, 
        sin(t * 0.02) * 0.05,
        t * 0.04
    );
    
    float n = cloudFBM(p, detailLevel);
    float coverage = mix(CLOUD_FOG_COVERAGE, 0.8, rainStrength);
    float density = max(n - (1.0 - coverage), 0.0);
    
    float selfShadow = 1.0 - hNorm * 0.3;
    
    return density * heightGrad * selfShadow * CLOUD_FOG_DENSITY * 4.0 * mix(0.3, 1.0, transitionFade);
}

float getCloudDensity(vec3 wpos, float detailLevel) {
    float unused;
    return getCloudDensity(wpos, detailLevel, unused);
}

// Temporal dithering for TAA //
float cloudTemporalDither(vec2 coord, float time) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    float t = fract(time * 0.618033988749);
    return fract(magic.z * fract(dot(coord + t * 100.0, magic.xy)));
}

// Main volumetric cloud fog function //
float cloudStart = mix(CLOUD_FOG_START, 0.0, rainStrength);

vec4 getVolumetricCloudFog(vec3 camPos, vec3 fogCol) {
    
    #ifdef TAA
    float dith = cloudTemporalDither(gl_FragCoord.xy, frameTimeCounter);
    #else
    float dith = cloudBayer64(gl_FragCoord.xy);
    #endif
    
    float sceneDepth = cloudGetDepth(Depth);
    float renderDist = far;
    float maxRay = min(sceneDepth, renderDist);
    
    if (maxRay < cloudStart) return vec4(0.0, 0.0, 0.0, 1.0);
    
    vec3 clip0 = vec3(texcoord, 0.0) * 2.0 - 1.0;
    vec4 view0 = gbufferProjectionInverse * vec4(clip0, 1.0);
    vec3 viewDir = normalize(mat3(gbufferModelViewInverse) * (view0.xyz / view0.w));
    vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    
    float cosTheta = dot(viewDir, lightDir);
    
    const float kFront = 0.6;
    const float kBack = -0.3;
    float phaseFront = (1.0 - kFront * kFront) / (12.566 * pow(1.0 + kFront * cosTheta, 2.0));
    float phaseBack = (1.0 - kBack * kBack) / (12.566 * pow(1.0 + kBack * cosTheta, 2.0));
    float phase = mix(phaseBack, phaseFront, 0.7);
    
    float transmittance = 1.0;
    vec3 scattered = vec3(0.0);
    
    float stepSize = (maxRay - cloudStart) / float(CLOUD_FOG_SAMPLES);
    
    float viewLightDot = abs(dot(viewDir, lightDir));
    
    for (int i = 0; i < CLOUD_FOG_SAMPLES; i++) {
        if (transmittance < 0.02) break;
        
        float ray = cloudStart + (float(i) + dith) * stepSize;
        
        float expD = cloudExpDepth(ray);
        vec3 clip = vec3(texcoord, expD) * 2.0 - 1.0;
        vec4 vw = gbufferProjectionInverse * vec4(clip, 1.0);
        vec3 wpos = mat3(gbufferModelViewInverse) * (vw.xyz / vw.w) + gbufferModelViewInverse[3].xyz + camPos;
        
        float distXZ = length(wpos.xz - camPos.xz);
        if (distXZ > renderDist) break;
        
        float detailLevel = transmittance * (1.0 - float(i) / float(CLOUD_FOG_SAMPLES));
        
        float density = getCloudDensity(wpos, detailLevel);
        if (density < 0.001) continue;
        
        float dist3D = length(wpos - camPos);
        float nearFade = smoothstep(cloudStart, cloudStart + CLOUD_FOG_FADE_NEAR, dist3D);
        nearFade *= nearFade;
        
        density *= nearFade;
        if (density < 0.001) continue;
        
        float farFade = smoothstep(renderDist, renderDist * 0.95, dist3D);
        float renderFade = smoothstep(renderDist, renderDist * 0.95, distXZ);
        
        vec4 sc = cloudShadowSpace(texcoord, expD);
        sc.xy *= distort(sc.xy);
        vec3 sCoord = vec3(sc.xy, sc.z / 6.0) * 0.5 + 0.5;
        float bias = 0.0005 + 0.001 * (1.0 - viewLightDot);
        sCoord.z -= bias;
        float shadow = cloudShadowStep(shadowtex1, sCoord);
        
        float ambient = CLOUD_FOG_MIN_BRIGHTNESS + 0.3;
        float direct = shadow * phase * 1.2;
        float totalLight = (ambient + direct) * farFade * renderFade;
        
        float tau = density * 0.035 * stepSize;
        float stepTrans = exp(-tau);
        float absorption = tau < 0.001 ? tau : (1.0 - stepTrans);
                
        float depthRatio = float(i) / float(CLOUD_FOG_SAMPLES);
        vec3 tintedFog = fogCol * (1.0 + vec3(-0.05, 0.0, 0.08) * depthRatio) * (1-rainStrength*0.7);
        
        scattered += tintedFog * totalLight * (1.0 - stepTrans) * transmittance;
        transmittance *= stepTrans;
    }
    
    transmittance = max(transmittance, CLOUD_FOG_MIN_TRANSMIT);
    
    return vec4(scattered, transmittance);
}

#endif
