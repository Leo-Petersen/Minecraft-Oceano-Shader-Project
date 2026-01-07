#version 130

#include "/lib/settings.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 atlasSize; 
uniform vec3 shadowLightPosition;

varying float dist;
varying float material;
varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;
varying vec3 viewNormal;
varying vec3 viewVector;
varying vec4 glcolor;
varying vec4 vtexcoordam;

varying mat3 tbnMatrix;

#include "/lib/parallax.glsl"
#include "/lib/encode.glsl"

void main() {
	#ifdef Parallax
    vec2 parallaxedUV = calcParallax();
	#else
	vec2 parallaxedUV = texcoord;
	#endif

	vec4 color = texture2DGradARB(texture, parallaxedUV, dFdxy[0], dFdxy[1]) * glcolor;

	vec4 specularData = texture2D(specular, parallaxedUV);
	vec2 specularMap = specularData.rg;
	specularMap.g = 1;
	float emission = specularData.a < 0.99 ? specularData.a : 0.0;

	vec4 normalRaw = texture2D(normals, parallaxedUV);
	
	// LabPBR: RG = encoded normal XY, B = AO, A = height
	vec2 normalXY = normalRaw.rg * 2.0 - 1.0;
	vec3 normalData = vec3(normalXY, sqrt(1.0 - dot(normalXY, normalXY)));
		 normalData *= tbnMatrix;
	
	// LabPBR AO from blue channel
	float textureAO = normalRaw.b;

	// Get surface height for parallax
	float surfaceHeight = texture2DGradARB(normals, parallaxedUV, dFdxy[0], dFdxy[1]).a;

	vec2 lightMap = vec2(1.0);
		 lightMap.s = clamp(lmcoord.s - 1.0 / 32.0, 0.0, 1.0);
		 lightMap.t = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);

	// if (material > 0.06 && material < 0.09){
	// 	color.rgb *= 1.7;
	// 	color.rgb *= dot(vec3(0.3086, 0.6094, 0.0820), color.rgb);
	// }

	float shadowFactor = 1.0;
	#ifdef Parallax
		#ifdef ParallaxShadow
			float parallaxFade = clamp(dist * 0.04, 0.0, 1.0);
			if (dot(viewNormal, shadowLightPosition) > 0) {
				shadowFactor = GetParallaxShadow(surfaceHeight, parallaxFade, parallaxedUV, normalize(shadowLightPosition), tbnMatrix);
			}
		#endif
	#endif

/* RENDERTARGETS: 0,1,2,8,13 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodeNormal(normalData), specularMap);
	gl_FragData[2] = vec4(lightMap, material, shadowFactor);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0); // No skybox reflection for hand, but write to buffer to fix issues
	gl_FragData[4] = vec4(emission, surfaceHeight, textureAO, 1.0);
}
