#version 430 compatibility

#include "/lib/settings.glsl"


uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex10;
uniform sampler2D noisetex;
uniform float far;

uniform int frameCounter;

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float nightVision;             
uniform float screenBrightness;
uniform float wetness;

uniform ivec2 atlasSize; 
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying float material;
varying float dist;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;

varying vec3 viewNormal;
varying vec3 worldpos;
varying vec3 sunVec;
varying vec3 viewVector;

varying vec4 glcolor;
varying vec4 vtexcoordam;
varying vec4 position;

varying mat3 tbnMatrix;

#include "/lib/parallax.glsl"
#include "/lib/encode.glsl"
#include "/lib/time.glsl"
#include "/lib/puddles.glsl"

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.3086, 0.6094, 0.0820));
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

vec3 toNDC(vec3 pos){
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = pos * 2. - 1.;
    vec4 fragpos = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragpos.xyz / fragpos.w;
}

// This is here to make it appear in the settings menu, dont ask me why it doesn't appear otherwise
#ifdef parallaxTAA
#endif

float Bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float Bayer4(vec2 a)  { return Bayer2(0.5 * a) * 0.25 + Bayer2(a); }
float Bayer8(vec2 a)  { return Bayer4(0.5 * a) * 0.25 + Bayer2(a); }

void main() {
    #ifdef DISTANT_HORIZONS
    float dither = Bayer8(gl_FragCoord.xy);
    float minDist = (dither - 0.75) * 16.0 + far;
    if (dist >= minDist) discard;
    #endif

    #ifdef Parallax
    vec2 parallaxedUV = calcParallax();
    #else
    vec2 parallaxedUV = texcoord;
    #endif

    vec3 fragpos = toNDC(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z));

    vec4 albedoSample = textureGrad(texture, parallaxedUV, dFdxy[0], dFdxy[1]);
    if (albedoSample.a < 0.1) discard;
    vec4 terrainColor = albedoSample * glcolor;
    vec4 specularData = texture2D(specular, parallaxedUV);
    vec4 normalRaw = texture2D(normals, parallaxedUV);
    
    vec2 specularMap = specularData.rg;
    float emission = specularData.a < 1.0 ? clamp(specularData.a * 1.004 - 0.004, 0.0, 1.0) : 0.0;

    float specularBlue = specularData.b * 255.0;
    float porosity = 0.0;
    float labSSS   = 0.0;
    if (specularBlue < 65.0) {
        porosity = specularBlue / 64.0;
    } else {
        labSSS = (specularBlue - 65.0) / 190.0;
    }

    bool isLeaves     = (material > 0.005 && material < 0.02);
    bool isGrassBlock = (material > 0.025 && material < 0.04);

    if (labSSS > 0.01) {
        labSSS *= 0.6;
        if (isGrassBlock) labSSS = min(labSSS, 0.45);
    } else {
        if (isLeaves)          labSSS = 0.75;
        else if (isGrassBlock) labSSS = 0.45;
    }
    
    vec2 normalXY = normalRaw.rg * 2.0 - 1.0;
    vec3 normalData = vec3(normalXY, sqrt(max(1.0 - dot(normalXY, normalXY), 0.0)));
         normalData *= tbnMatrix;

    #define normalTiltStrength 1.0
    #define normalTiltMax 0.5

    float faceTilt   = 1.0 - clamp(dot(normalize(normalData), normalize(viewNormal)), 0.0, 1.0);
    float pRough     = 1.0 - specularMap.r;   // perceptual roughness
    float tiltKernel = min(normalTiltStrength * faceTilt * faceTilt, normalTiltMax);
    float widened    = pow(clamp(pRough * pRough * pRough * pRough + tiltKernel, 0.0, 1.0), 0.25);
    specularMap.r    = 1.0 - widened;
    
    float textureAO = normalRaw.b;
    float surfaceHeight = textureGrad(normals, parallaxedUV, dFdxy[0], dFdxy[1]).a;

    #ifdef rainReflection
        float wetness01 = wetness;
        #ifdef alwaysPuddles
            wetness01 = 1.0;
        #endif

        vec3  worldNormal = normalize(mat3(gbufferModelViewInverse) * viewNormal);
        float flatFace    = smoothstep(0.55, 0.95, worldNormal.y);

        vec3  worldRel    = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
        vec2  wpos        = worldRel.xz + cameraPosition.xz;
        float puddleField = getRainPuddles(wpos, wetness01);

        #define POOL_FILL 0.90
        float fillLevel   = POOL_FILL * puddleField;

        float distFade    = 1.0 - smoothstep(64.0, 128.0, length(worldRel.xz));

        float rawSky      = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);
        float skyExposure = smoothstep(12.5 / 16.0, 14.75 / 16.0, rawSky);

        float wetPresence = flatFace * smoothstep(0.0, 0.25, wetness01) * distFade * skyExposure;

        float poolMask    = smoothstep(0.05, 0.35, puddleField) * wetPresence;

        float underWater  = smoothstep(fillLevel + 0.012, fillLevel - 0.012, surfaceHeight) * wetPresence;
        float waterDepth  = max(fillLevel - surfaceHeight, 0.0);

        float wetFilm     = max(poolMask, underWater);

        normalData = normalize(mix(normalData, viewNormal, underWater));

        float soak        = mix(0.72, 0.30, porosity);
        terrainColor.rgb *= mix(1.0, soak, wetFilm);

        #define WATER_TINT    vec3(0.45, 0.62, 0.68) 
        #define WATER_CLARITY 5.0
        float absorb      = 1.0 - exp(-waterDepth * WATER_CLARITY);
        terrainColor.rgb  = mix(terrainColor.rgb, terrainColor.rgb * WATER_TINT, absorb * underWater);

        #define WET_FILM_SMOOTH 0.72
        specularMap.r     = mix(specularMap.r, WET_FILM_SMOOTH, poolMask);   // normal wet puddle
        specularMap.r     = mix(specularMap.r, 0.96, underWater);            // flat pool water
        specularMap.g     = mix(specularMap.g, 0.04, wetFilm);              // water F0 across the whole footprint
    #else
        float wetFilm = 0.0;
    #endif

    float shadowFactor = 1.0;
    #ifdef Parallax
        #ifdef ParallaxShadow
            float parallaxFade = clamp(dist * 0.04, 0.0, 1.0);
            if (dot(viewNormal, shadowLightPosition) > 0) {
                shadowFactor = GetParallaxShadow(surfaceHeight, parallaxFade, parallaxedUV, normalize(shadowLightPosition), tbnMatrix);
            }
        #endif
    #endif

    vec2 lightMap = vec2(1.0);
         lightMap.s = clamp(lmcoord.s - 1.0 / 32.0, 0.0, 1.0);
         lightMap.t = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);

	#ifdef Parallax
	mat3 lightmapTBN = GetLightmapTBN(fragpos);
	lightMap.x = DirectionalLightmap(lightMap.x, lmcoord.x, normalData, lightmapTBN);
	lightMap.y = DirectionalLightmap(lightMap.y, lmcoord.y, normalData, lightmapTBN);
	#endif

    #ifdef whiteWorld
        terrainColor.rgb = vec3(1.0);
    #endif	

#ifdef PHOTONICS_ENABLED
/* RENDERTARGETS: 0,1,2,8,13,14,15 */
#else
/* RENDERTARGETS: 0,1,2,8,13 */
#endif
	gl_FragData[0] = terrainColor;
	gl_FragData[1] = vec4(encodeNormal(normalData), specularMap);
	gl_FragData[2] = vec4(lightMap, material, shadowFactor);
	gl_FragData[4] = vec4(emission, wetFilm, textureAO, labSSS);
#ifdef PHOTONICS_ENABLED
	gl_FragData[5] = vec4(terrainColor.rgb, 1.0);
	gl_FragData[6] = vec4(0.5 * viewNormal + 0.5, 1.0);
#endif
}
