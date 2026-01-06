#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
		 color.rgb *= 0.0;

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}