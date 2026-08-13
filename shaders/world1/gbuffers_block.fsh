#version 130

#include "/lib/settings.glsl"


uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex2;

uniform float frameTimeCounter;
uniform int frameCounter;
uniform ivec2 atlasSize; 
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

varying float dist;
varying float isportal;
uniform float viewWidth;
uniform float viewHeight;
varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 vtexcoord;
varying vec3 viewNormal;
varying vec3 viewVector;
varying vec3 wpos;
varying vec3 worldViewDir;
varying vec4 glcolor;
varying vec4 vtexcoordam;

varying mat3 tbnMatrix;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

#include "/world1/lib/parallax.glsl"
#include "/world1/lib/encode.glsl"

float portalHash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float portalNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(portalHash(i), portalHash(i + vec2(1.0, 0.0)), f.x),
		mix(portalHash(i + vec2(0.0, 1.0)), portalHash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float portalFbm(vec2 p, float t) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * portalNoise(p);
		p = p * 2.1 + vec2(t * 0.1, t * 0.13);
		// Rotate each octave
		float a = 0.5 + t * 0.02;
		float s = sin(a); float c = cos(a);
		p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
		amp *= 0.5;
	}
	return val;
}

vec3 endPortalStars(vec2 uv, float depth, float t) {
	vec2 gridID = floor(uv);
	vec2 gridUV = fract(uv) - 0.5;
	
	float starRand = portalHash(gridID + depth * 73.0);
	float starRand2 = portalHash(gridID * 1.7 + depth * 31.0);
	
	// Only some cells have stars
	float starPresence = step(0.85, starRand);
	
	// Star position jitter within cell
	vec2 starPos = vec2(portalHash(gridID + 0.5) - 0.5, portalHash(gridID + 1.5) - 0.5) * 0.7;
	float starDist = length(gridUV - starPos);
	
	// Twinkle
	float twinkle = sin(t * (2.0 + starRand * 4.0) + starRand2 * 6.28) * 0.4 + 0.6;
	
	// Star brightness falloff
	float star = smoothstep(0.05, 0.0, starDist) * starPresence * twinkle;
	
	// Star color, mostly white with hints of blue/purple
	vec3 starCol = mix(vec3(0.8, 0.85, 1.0), vec3(0.6, 0.5, 1.0), starRand2);
	
	// Rare bright stars
	float isBright = step(0.95, starRand);
	star = mix(star, star * 12.5, isBright);
	
	return starCol * star;
}

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	//float material = texture2D(colortex2, texcoord).p;
	#ifdef Parallax
    vec2 parallaxedUV = calcParallax();
	#else
	vec2 parallaxedUV = texcoord;
	#endif

	vec2 specularMap = texture2D(specular, parallaxedUV).rg;
	vec3 normalData = texture2D(normals, parallaxedUV).rgb*2.0-1.0;
	     normalData.z = sqrt(1.0-dot(normalData.xy, normalData.xy));	
		 normalData *= tbnMatrix;

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

	if (isportal > 0.0) {
		float t = frameTimeCounter * 0.0026;
		vec3 viewDir = worldViewDir;
		
		vec2 baseUV = wpos.xz * 0.5;
		
		vec3 finalColor = vec3(0.0);
		
		for (int i = 0; i < 4; i++) {
			float depth = float(i) / 3.0;
			
			// Parallax into the portal
			vec2 parallax = (viewDir.xz / max(abs(viewDir.y), 0.1)) * depth * 1.15;
			
			// Rotate each layer for swirl
			float layerAngle = t * (0.1 + depth * 0.08) + depth * 1.5;
			float s = sin(layerAngle); float c = cos(layerAngle);
			vec2 rotUV = vec2(
				(baseUV.x + parallax.x) * c - (baseUV.y + parallax.y) * s,
				(baseUV.x + parallax.x) * s + (baseUV.y + parallax.y) * c
			);
			
			vec2 starUV = rotUV * (8.0 + depth * 16.0);
			starUV += vec2(t * 0.05 * (1.0 + depth), t * 0.03 * (1.0 - depth * 0.5));
			
			float depthFade = 1.0 - depth * 0.6;
			vec3 stars = endPortalStars(starUV, depth, t) * depthFade;
			
			finalColor += stars;
		}
		
		// Nebula layers
		for (int i = 0; i < 3; i++) {
			float depth = float(i) / 2.0;
			vec2 parallax = (viewDir.xz / max(abs(viewDir.y), 0.1)) * depth * 1.1;
			
			float layerAngle = t * (0.05 + depth * 0.06) + depth * 1.0;
			float s = sin(layerAngle); float c = cos(layerAngle);
			vec2 rotUV = vec2(
				(baseUV.x + parallax.x) * c - (baseUV.y + parallax.y) * s,
				(baseUV.x + parallax.x) * s + (baseUV.y + parallax.y) * c
			);
			
			vec2 nebulaUV = rotUV * (1.5 + depth * 3.0);
			
			float nebula = portalFbm(nebulaUV, t * 0.5 + depth * 2.0);
			nebula = pow(nebula, 2.0);
			
			vec3 nebulaCol;
			if (i == 0) nebulaCol = vec3(0.1, 0.05, 0.3);
			else if (i == 1) nebulaCol = vec3(0.05, 0.1, 0.35);
			else nebulaCol = vec3(0.15, 0.05, 0.25);
			
			float depthFade = 1.0 - depth * 0.4;
			finalColor += nebulaCol * nebula * depthFade * 1.5;
		}
		
		// pulse
		float pulse = sin(t * 0.8) * 0.08 + 0.92;
		finalColor *= pulse;
		
		vec3 voidBase = vec3(0.01, 0.005, 0.03);
		finalColor = max(finalColor, voidBase);
		
		color.rgb = pow(finalColor, vec3(1.5));
		color.a = 1.0;
	}

#ifdef PHOTONICS_ENABLED
/* RENDERTARGETS: 0,1,2,13,14,15 */
#else
/* RENDERTARGETS: 0,1,2,13 */
#endif
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(normalData), specularMap);
	gl_FragData[2] = vec4(lmcoord, 0.0, shadowFactor);
	gl_FragData[3] = vec4(0.0, 0.0, 1.0, 1.0);
#ifdef PHOTONICS_ENABLED
	gl_FragData[4] = vec4(color.rgb, 1.0);
	gl_FragData[5] = vec4(0.5 * viewNormal + 0.5, 1.0);
#endif
}