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

// Interleaved gradient noise
float interleavedGradientNoise(vec2 coord) {
    return fract(52.9829189 * fract(dot(coord, vec2(0.06711056, 0.00583715))));
}

float parallaxJitter = interleavedGradientNoise(gl_FragCoord.xy) * 0.5 - 0.25;

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
        float jitter = (parallaxJitter + 0.5) * (1.0 - distFactor * 0.5);
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
                float currDiff = surfaceHeight - rayHeight;
                float heightJump = surfaceHeight - prevSurfaceHeight;

                // Steep wall detection: if the surface rose sharply in one step,
                // binary search oscillates on the discontinuity causing per-pixel noise.
                // Use linear interpolation instead
                if (heightJump > stepDiv * 2.0) {
                    float t = prevDiff / max(prevDiff + currDiff, 0.0001);
                    coord = mix(prevCoord, coord, t);
                } else {
                    // Smooth surface: binary search for precision
                    vec2  lo = prevCoord,  hi = coord;
                    float loRay = prevRayHeight, hiRay = rayHeight;

                    for (int b = 0; b < 6; b++) { // 6 ?
                        vec2  midCoord = (lo + hi) * 0.5;
                        float midRay   = (loRay + hiRay) * 0.5;
                        float midSurf  = readNormal(midCoord).a;

                        if (midRay < midSurf) {
                            hi    = midCoord;
                            hiRay = midRay;
                        } else {
                            lo    = midCoord;
                            loRay = midRay;
                        }
                    }
                    coord = (lo + hi) * 0.5;
                }
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
        float iJittered = float(i) + parallaxJitter;
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