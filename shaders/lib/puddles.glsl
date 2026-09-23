//Modified version of raindrops from https://www.shadertoy.com/view/wt2yW3
vec2 hash3( vec2 p )
{
    vec2 q = vec2(dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)));
    return fract(sin(q)*43758.5453);
}

float raindropNoise(in vec2 x)
{
    float intensity = 0.15;
    x *= intensity;

    vec2 p = floor(x);
    vec2 f = fract(x);

    float va = 0.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        vec2 g = vec2( float(i),float(j) );
        vec2 o = hash3(p + g);
        vec2 r = ((g - f) + o.xy) / intensity;
        float d = sqrt(dot(r,r));

        // each cell gets its own drop timing
        float dropCycle = 2.5;
        float cellTime = mod(frameTimeCounter + o.x * dropCycle, dropCycle);
        
        // ripple expands outward from center
        float rippleSpeed = 1.0;
        float rippleRadius = cellTime * rippleSpeed;
        
        // ring only at the wavefront edge
        float ringWidth = 0.15;
        float ring = smoothstep(ringWidth, 0.0, abs(d - rippleRadius));
        
        // fade out over lifetime
        float dropLife = 1.2;
        float fade = 1.0 - (cellTime / dropLife);
        fade = max(fade, 0.0);
        fade *= fade; 
        
        va += ring * fade;
    }

    va *= rainStrength;
    return va;
}

#define PUDDLE_BASE_FREQ 0.00013 
#define PUDDLE_OCTAVES   2
#define PUDDLE_SOFT      0.22

float puddleFbm(vec2 wp){
    float f = PUDDLE_BASE_FREQ;
    float v = 0.0, a = 0.6, tot = 0.0;
    for (int i = 0; i < PUDDLE_OCTAVES; i++){
        v   += a * texture2D(noisetex, wp * f).x;
        tot += a;
        f   *= 2.0;   // lacunarity 2
        a   *= 0.5;   // gain 0.5
    }
    return v / tot;   // ~0..1, smooth
}

float getRainPuddles(vec2 worldPos, float iswet){
    float field = puddleFbm(worldPos);

    // Coverage rises with wetness.
    float cover = mix(0.30, 0.60, clamp(iswet, 0.0, 1.0));

    // Smooth depth
    float d = clamp((cover - field) / PUDDLE_SOFT, 0.0, 1.0);
    return d * d * (3.0 - 2.0 * d);
}

#ifdef PUDDLE_REFLECTION
float rippleH(vec2 p){ return raindropNoise(10.0 * p); }

vec3 puddles(in vec3 color, in vec3 worldPos, in vec3 reflectedskyBoxCol, in vec3 viewPos, in vec2 lightMap, float iswet, float distFactor, float puddleMask) {
    if (puddleMask < 0.001 || isEyeInWater > 0.9) return color;

    vec2  rp = worldPos.xz + cameraPosition.xz;
    float e  = 0.15;
    float hx = rippleH(rp + vec2(e,0)) - rippleH(rp - vec2(e,0));
    float hy = rippleH(rp + vec2(0,e)) - rippleH(rp - vec2(0,e));

    vec3  waterN = normalize(viewNormal + vec3(-hx, 0.0, -hy) * rainStrength * 0.6);

    #define PUDDLE_SHEEN 0.06
    float ndv     = clamp(dot(waterN, -normalize(viewPos.xyz)), 0.0, 1.0);
    float fresnel = PUDDLE_SHEEN + (1.0 - PUDDLE_SHEEN) * pow(1.0 - ndv, 5.0);

    reflectedskyBoxCol *= (1.0 - time[5] * 0.84);
    vec4  refl    = raytracePuddles(reflectedskyBoxCol, viewPos.xyz, waterN, 6);
    vec3  reflCol = mix(reflectedskyBoxCol, refl.rgb, refl.a);

    float skyAccess = pow(lightMap.t, 8.0);          // no sky reflection indoors
    float m = puddleMask * distFactor * skyAccess;

    color = mix(color, reflCol, fresnel * m);
    return color;
}
#endif