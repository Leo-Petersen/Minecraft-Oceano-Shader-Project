#include "/lib/settings.glsl"

uniform sampler2D texture;
uniform int biome_precipitation;

varying vec2  texcoord;
varying vec3  rainLight;
varying float viewDist;
varying vec4  glcolor;

void main() {
	vec4 tex = texture2D(texture, texcoord) * glcolor;

	bool  snow  = biome_precipitation == 2;
	float alpha = tex.a * (snow ? snowOpacity : rainOpacity);

	alpha *= mix(0.35, 1.0, smoothstep(1.5, 8.0, viewDist));

	vec3 rgb = rainLight * (snow ? 1.0 : 0.65);

	vec4 color = vec4(rgb, alpha);

/* RENDERTARGETS: 0,13 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, color.a);
}
