#version 120

varying vec2 texcoord;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex8;
uniform sampler2D depthtex0;

#include "/lib/settings.glsl"

#ifdef BLOOM
	float pw = 1.0 / viewWidth;
	float ph = 1.0 / viewHeight;

	vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
		float scale = exp2(lod);
		float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;
		vec2 centerOffset = vec2(0.125 * pw, 0.25 * ph);
		vec3 bloom = texture2D(colortex8, (coord / scale + offset) * resScale + centerOffset).rgb;
		bloom = bloom * bloom * bloom * bloom * 18.0;
		return bloom;
	}

	void Bloom(inout vec3 color, vec2 coord) {
		vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0, 0.0));
		vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.51, 0.0));
		vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.51, 0.26));
		vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.645, 0.26));
		vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.7175, 0.26));

		vec3 blur = (blur1 * 5.51 + blur2 * 5.30 + blur3 * 4.71 + blur4 * 3.85 + blur5 * 2.85) / 22.22;
		color += blur;
	}
#endif

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

	#ifdef BLOOM
		Bloom(color, texcoord);
	#endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}