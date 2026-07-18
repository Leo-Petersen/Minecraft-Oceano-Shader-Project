#version 130

varying vec4 starData; //rgb = star color, a = flag for whether this pixel is a star.
varying vec4 gcolor;

varying vec4 position;
varying float stars;

uniform sampler2D colortex15;   // sky-view LUT

uniform float viewWidth, viewHeight;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float rainStrength;
uniform float screenBrightness;
uniform float nightVision;

uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying vec2 texcoord;

#include "/lib/time.glsl"
#include "/lib/settings.glsl"
#include "/lib/atmosphereLUT.glsl"

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	//color = color + (color-luma)*strength*0.1;
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

vec3 getSkyDir() {
    vec2 ndc = gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0;
    vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
    viewPos /= viewPos.w;
    return normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);
}

vec3 moonSky(vec3 rd, vec3 moonDir) {
    float up = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 tint = vec3(0.05, 0.09, 0.20);
    float glow = atmPhaseM(dot(rd, moonDir), 0.6) * 0.5;
    float moonUp = clamp(moonDir.y * 2.0, 0.0, 1.0);
    return (tint * up + vec3(0.25, 0.30, 0.45) * glow) * moonUp;
}

void main() {
    vec3 rd  = getSkyDir();
    vec2 res = vec2(viewWidth, viewHeight);

    vec3 sunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 moonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);

    vec3 sky = atmSky(colortex15, res, rd, sunDir);

    float night = smoothstep(0.02, -0.10, sunDir.y);
    sky += moonSky(rd, moonDir) * night;

    sky += skyColor * 0.5 * (rainStrength * 0.5);
    sky *= (1.0 - rainStrength * 0.3);

    sky = luminance(sky, 1.12);

    if (starData.a > 0.5) {
        sky += starData.rgb * 4.0 * night * (1.0 - rainStrength);
    }

    sky = max(sky, vec3(0.0));

/* DRAWBUFFERS:09 */
    gl_FragData[0] = vec4(sky, 1.0);
    gl_FragData[1] = vec4(sky, 1.0);
}
