
#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform sampler2D texture;
uniform mat4 gbufferModelView;

varying vec2 texcoord;
varying vec4 glcolor;

void main() {
	if (glcolor.a < 0.5) discard;

	vec3 albedo = texture2D(texture, texcoord).rgb * glcolor.rgb;

	vec3 upNormal = normalize(gbufferModelView[1].xyz);

/* RENDERTARGETS: 0,1,2,13 */
	gl_FragData[0] = vec4(albedo * beamBrightness, 1.0);
	gl_FragData[1] = vec4(encodeNormal(upNormal), 0.0, 0.0);
	gl_FragData[2] = vec4(1.0, 1.0, 0.93, 1.0);
	gl_FragData[3] = vec4(1.0, 0.0, 1.0, 0.0);
}
