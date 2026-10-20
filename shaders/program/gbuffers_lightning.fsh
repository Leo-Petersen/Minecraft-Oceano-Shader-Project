
#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform mat4 gbufferModelView;
uniform int frameCounter;

varying vec4 glcolor;

float interleavedGradientNoise(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
	vec2 noisePos = gl_FragCoord.xy;
	#ifdef TAA
	noisePos += 5.588238 * float(frameCounter & 63);
	#endif
	if (interleavedGradientNoise(noisePos) > glcolor.a * lightningDensity) discard;

	vec3 albedo = glcolor.rgb / max(glcolor.r, max(glcolor.g, glcolor.b));
	albedo *= vec3(0.92, 0.95, 1.0);

	vec3 upNormal = normalize(gbufferModelView[1].xyz);

/* RENDERTARGETS: 0,1,2,13 */
	gl_FragData[0] = vec4(albedo * lightningBrightness, 1.0);
	gl_FragData[1] = vec4(encodeNormal(upNormal), 0.0, 0.0);
	gl_FragData[2] = vec4(1.0, 1.0, 0.93, 1.0);
	gl_FragData[3] = vec4(1.0, 0.0, 1.0, 0.0);
}
