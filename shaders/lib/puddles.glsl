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

float getRainPuddles(vec2 worldPos, float iswet){
	worldPos *= 0.000325945241199;
	
	float noise = texture2D(noisetex, worldPos.xy).x;
		  noise = 2.8 * texture2D(noisetex, worldPos.xy * 0.4).x + noise;
		  noise = 0.2 * texture2D(noisetex, worldPos.xy * 1.0).x + noise;
	
	return clamp((0.98 * iswet) + (noise - 2.4), 0.0, 1.0);
}

vec3 puddles(in vec3 color, in vec3 worldPos, in vec3 reflectedskyBoxCol, in vec3 viewPos, in vec2 lightMap, float iswet, float surfaceHeight) {
    vec2 dropPos = worldPos.xz + cameraPosition.xz;

    float puddle = getRainPuddles(dropPos, iswet);
    
    // Height masking: raised parallax areas stay dry (Disabled for now)
    //float heightMask = smoothstep(1.0, 0.85, surfaceHeight);
    float heightMask = 1.0;
    #ifndef Parallax
          heightMask = 1.0;
    #endif
    
    // Raindrops
    float noiseVal = raindropNoise(10.0 * dropPos);
    float rainDistortion = noiseVal * 100.0;
    vec3 rainDrop = vec3(-dFdx(rainDistortion), -dFdy(rainDistortion), 1.0);
    rainDrop = normalize(rainDrop);

    // Normal for puddles
    vec3 rainDropNormal = mix(upVec, viewNormal, puddle);
         rainDropNormal = mix(viewNormal, rainDropNormal, heightMask);
    vec2 waveOffset = (worldPos.xz + cameraPosition.xz) * 10.0 - (worldPos.y + cameraPosition.y) * 10.0;
         rainDropNormal.xy += getWaveHeight(waveOffset, 0.95, 0.0).x;

    // Apply raindrop ripples where puddles exist
    rainDropNormal.xy += rainDrop.xy * puddle * rainStrength * heightMask;
    rainDropNormal = normalize(rainDropNormal);

    // Reflections
    reflectedskyBoxCol *= 1.5;
    vec4 rainreflection = raytracePuddles(reflectedskyBoxCol, viewPos.xyz, rainDropNormal, 6);
    float normalDotEyeRain = dot(viewNormal, -normalize(viewPos.xyz));
    vec3 reflectionCol = mix(reflectedskyBoxCol, rainreflection.rgb, rainreflection.a);

    // Modifiers
    float rainModifier = pow(lightMap.t, 50.0) * 70.0 * mix(1.0, 0.42, puddle) * iswet 
                         * clamp(dot(viewNormal, upVec), 0.0, 0.4);

    // Apply reflection
    if (rainMask != 0) {
        if (isEyeInWater < 0.9) {
            float reflectionFactor = pow(1.0 - normalDotEyeRain, 2.5) * rainModifier;
                  reflectionFactor = mix(reflectionFactor * 0.65, reflectionFactor, heightMask);
            color = mix(color, reflectionCol, reflectionFactor);
        }
    }

    return color;
}