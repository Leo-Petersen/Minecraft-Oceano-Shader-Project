#define PARALLAX_EPSILON 0.001
#define SHADOW_EPSILON 0.01
#define HEIGHT_THRESHOLD 0.98

mat2 dFdxy = mat2(
    dFdx(vtexcoord.xy * vtexcoordam.pq),
    dFdy(vtexcoord.xy * vtexcoordam.pq)
);

vec4 readNormal(in vec2 coord) {
    return texture2DGradARB(normals, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dFdxy[0], dFdxy[1]);
}

float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

#define bayer4(a)   (bayer2(0.5*(a))*0.25+bayer2(a))
#define bayer8(a)   (bayer4(0.5*(a))*0.25+bayer2(a))
#define bayer16(a)  (bayer8(0.5*(a))*0.25+bayer2(a))
#define bayer32(a)  (bayer16(0.5*(a))*0.25+bayer2(a))
#define bayer64(a)  (bayer32(0.5*(a))*0.25+bayer2(a))

float randomJitter = fract(bayer64(gl_FragCoord.xy) + frameTimeCounter * 0.125) - 0.5;

vec2 calcParallax() {
    vec2 baseCoord = vtexcoord.xy * vtexcoordam.pq + vtexcoordam.st;
    
    float angleFactor = clamp(-viewVector.z, 0.15, 1.0);
    float effectiveFarDist = parallaxFarDist * angleFactor;
    if (dist >= effectiveFarDist) return baseCoord;

    vec4 normalSample = readNormal(vtexcoord.xy);

    vec3 normalMap = normalSample.xyz * 2.0 - 1.0;
    if (normalMap.x + normalMap.y < -1.999) return baseCoord;

    if (normalSample.a > HEIGHT_THRESHOLD) return baseCoord;

    float distFactor = (dist - parallaxNearDist) / (effectiveFarDist - parallaxNearDist);
    distFactor = clamp(distFactor * distFactor, 0.0, 1.0);
    if (distFactor >= 1.0) return baseCoord;
    
    float maxSteps = mix(parallaxQuality, MIN_PARALLAX_STEPS, distFactor);
    int steps = min(int(maxSteps), MAX_PARALLAX_STEPS);
    float stepDiv = 1.0 / maxSteps;
    
    float effectiveDepth = parallaxDepth * (1.0 - distFactor);
    float clampedZ = max(-viewVector.z, 0.15);
    vec2 stepUV = viewVector.xy * effectiveDepth / (clampedZ * maxSteps);
    vec2 coord = vtexcoord.xy;

    if (viewVector.z < -PARALLAX_EPSILON) {
        float jitter = (randomJitter + 0.5) * (1.0 - distFactor * 0.5);
        //float jitter = 1.0;
        
        vec2 prevCoord = coord;
        float prevRayHeight = 1.0;
        float prevSurfaceHeight = normalSample.a;
        
        coord += stepUV * jitter;
        float rayHeight = 1.0 - stepDiv * jitter;
        float surfaceHeight = readNormal(coord).a;

        for (int i = 0; i < MAX_PARALLAX_STEPS; i++) {
            if (i >= steps) break;
            
            if (rayHeight <= surfaceHeight) {
                float prevDiff = prevRayHeight - prevSurfaceHeight;
                float currDiff = rayHeight    - surfaceHeight;

                // Proper binary search with explicit brackets
                vec2  lo = prevCoord,  hi = coord;
                float loRay = prevRayHeight, hiRay = rayHeight;

                for (int b = 0; b < 6; b++) {
                    vec2  midCoord = (lo + hi) * 0.5;
                    float midRay   = (loRay + hiRay) * 0.5;
                    float midSurf  = readNormal(midCoord).a;

                    if (midRay < midSurf) {   // ray is below surface, pull back
                        hi    = midCoord;
                        hiRay = midRay;
                    } else {                   // ray is above surface, push forward
                        lo    = midCoord;
                        loRay = midRay;
                    }
                }
                coord = (lo + hi) * 0.5;
                break;
            }
            
            prevCoord = coord;
            prevRayHeight = rayHeight;
            prevSurfaceHeight = surfaceHeight;
            
            coord += stepUV;
            rayHeight -= stepDiv;
            surfaceHeight = readNormal(coord).a;
        }
    }
    
    return fract(coord) * vtexcoordam.pq + vtexcoordam.st;
}

float GetParallaxShadow(float depth, float fade, vec2 coord, vec3 lightVector, mat3 tbnMatrix) {
    if (fade >= 1.0 || depth > HEIGHT_THRESHOLD) return 1.0;
    
    vec3 parallaxdir = tbnMatrix * lightVector;
    parallaxdir.xy *= parallaxShadowDepth * 2.0;
    
    vec2 dcdx = dFdx(coord);
    vec2 dcdy = dFdy(coord);
    vec2 newvTexCoord = (coord - vtexcoordam.st) / vtexcoordam.pq;
    float sampleStep = 0.1 / float(parallaxShadowQuality);
    
    vec2 ptexCoord = fract(newvTexCoord + parallaxdir.xy * sampleStep) * vtexcoordam.pq + vtexcoordam.st;
    float texHeight = texture2DGrad(normals, coord, dcdx, dcdy).a;
    float texHeightOffset = texture2DGrad(normals, ptexCoord, dcdx, dcdy).a;
    
    float texFactor = clamp((depth - texHeightOffset) / sampleStep + 1.0, 0.0, 1.0);
    float height = mix(depth, texHeight, texFactor);
    float minShadow = 1.0;
    
    vec2 stepOffset = parallaxdir.xy * sampleStep;
    float stepHeight = parallaxdir.z * sampleStep;
    
    for (int i = 0; i < parallaxShadowQuality; i++) {
        float iJittered = float(i) + randomJitter;
        float currentHeight = height + stepHeight * iJittered;
        
        vec2 parallaxCoord = fract(newvTexCoord + stepOffset * iJittered) * vtexcoordam.pq + vtexcoordam.st;
        float offsetHeight = texture2DGrad(normals, parallaxCoord, dcdx, dcdy).a;
        
        float sampleShadow = clamp(1.0 - (offsetHeight - currentHeight) * parallaxShadowStrength, 0.0, 1.0);
        minShadow = min(minShadow, sampleShadow);
        
        if (minShadow < SHADOW_EPSILON) {
            minShadow = 0.0;
            break;
        }
    }
    
    return mix(minShadow * minShadow, 1.0, fade);
}

mat3 GetLightmapTBN(vec3 viewPos) {
    vec3 right = normalize(dFdx(viewPos));
    vec3 up    = normalize(dFdy(viewPos));
    vec3 forward = cross(right, up);
    
    return mat3(right, up, forward);
}

float DirectionalLightmap(float lightmap, float lightmapRaw, vec3 normal, mat3 tbn) {
    // skip if there's no light
    if (lightmap < 0.001) return lightmap;
    
    float gradientX = dFdx(lightmapRaw) * 256.0;
    float gradientY = dFdy(lightmapRaw) * 256.0;
    
    // skip if lightmap is uniform
    if (abs(gradientX) + abs(gradientY) < 0.001) return lightmap;
    
    vec3 lightDir = normalize(
        gradientX * tbn[0] +      // H
        gradientY * tbn[1] +      // V 
        0.0005    * tbn[2] 
    );
    
    float NdotL = dot(normal, lightDir);
    float modifier = pow(abs(NdotL), 1) * sign(NdotL) * lightmap;
    
    return pow(lightmap, max(1.0 - modifier, 0.001));
}