#version 130

#include "/lib/settings.glsl"


uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex10;

uniform vec3 skyColor;

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float nightVision;             
uniform float screenBrightness;

uniform ivec2 atlasSize; 
uniform vec3 shadowLightPosition;

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
#include "/lib/skyboxreflected.glsl"

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.3086, 0.6094, 0.0820));
	//color = color + (color-luma)*strength*0.1;
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

void main() {
    #ifdef Parallax
    vec2 parallaxedUV = calcParallax();
    #else
    vec2 parallaxedUV = texcoord;
    #endif

    vec3 fragpos = toNDC(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z));
    vec4 terrainColor = vec4(texture2DGradARB(texture, parallaxedUV, dFdxy[0], dFdxy[1]) * glcolor);
    vec4 specularData = texture2D(specular, parallaxedUV);
    vec2 specularMap = specularData.rg;
    float emission = specularData.a < 0.99 ? specularData.a : 0.0;

    vec4 normalRaw = texture2D(normals, parallaxedUV);
    
    vec2 normalXY = normalRaw.rg * 2.0 - 1.0;
    vec3 normalData = vec3(normalXY, sqrt(1.0 - dot(normalXY, normalXY)));
         normalData *= tbnMatrix;
    
    float textureAO = normalRaw.b;
    float surfaceHeight = texture2DGradARB(normals, parallaxedUV, dFdxy[0], dFdxy[1]).a;

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

	// Reflected skybox
	vec3 reflectedVector = reflect(fragpos, normalize(normalData)) * 300.0;
	vec3 skybox = getSkyTextureFromSequence(position.xyz+reflectedVector);
		 skybox += vec3(skyColor*0.5) * (rainStrength * 0.5);
	     skybox = pow(skybox, vec3(3.2))*2;
	     skybox = luminance(skybox, 1.15);
	     skybox = clamp(skybox*(1-rainStrength*0.6), vec3(0.0), vec3(1.0));

/* RENDERTARGETS: 0,1,2,8,13 */
	gl_FragData[0] = terrainColor;
	gl_FragData[1] = vec4(encodeNormal(normalData), specularMap);
	gl_FragData[2] = vec4(lightMap, material, shadowFactor);
	#ifdef Reflections
	gl_FragData[3] = vec4(skybox, 1.0);
	#endif
	gl_FragData[4] = vec4(emission, surfaceHeight, textureAO, 1.0);
}
