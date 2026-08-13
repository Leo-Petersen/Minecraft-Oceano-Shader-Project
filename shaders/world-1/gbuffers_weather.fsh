#version 130

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform vec3 skyColor;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	color *= texture2D(lightmap, lmcoord);
	color.rgb *= skyColor;
	color.rgb *= 2;
	color.a *= 0.4;

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}