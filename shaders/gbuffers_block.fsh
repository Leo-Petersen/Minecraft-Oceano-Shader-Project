#version 130

#include "/lib/settings.glsl"


uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float frameTimeCounter;
uniform ivec2 atlasSize; 
uniform vec3 shadowLightPosition;

varying float dist;
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
	vec4 color = texture2D(texture, texcoord) * glcolor;
	#ifdef Parallax
    vec2 parallaxedUV = calcParallax();
	#else
	vec2 parallaxedUV = texcoord;
	#endif

	vec2 specularMap = texture2D(specular, parallaxedUV).rg;
	vec3 normalData = texture2D(normals, parallaxedUV).rgb*2.0-1.0;
	     normalData.z = sqrt(1.0-dot(normalData.xy, normalData.xy));	
		 normalData *= tbnMatrix;

	float shadowFactor = 1.0;
	#ifdef Parallax
		#ifdef ParallaxShadow
			float surfaceDepth = texture2DGradARB(normals, parallaxedUV, dFdxy[0], dFdxy[1]).a;
			float parallaxFade = clamp(dist * 0.04, 0.0, 1.0);
			if (dot(viewNormal, shadowLightPosition) > 0) {
				shadowFactor = GetParallaxShadow(surfaceDepth, parallaxFade, parallaxedUV, normalize(shadowLightPosition), tbnMatrix);
			}
		#endif
	#endif

/* RENDERTARGETS: 0,1,2,13 */
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(normalData), specularMap);
	gl_FragData[2] = vec4(lmcoord, 0.0, shadowFactor);
	gl_FragData[3] = vec4(0.0, 0.0, 1.0, 1.0); 
}