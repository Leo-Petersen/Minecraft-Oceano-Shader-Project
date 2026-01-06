#version 120

uniform sampler2D lightmap;

varying vec2 lmcoord;
varying vec4 glcolor;

void main() {
	vec4 color = glcolor;
	color *= texture2D(lightmap, lmcoord);
	//color.a = .6;

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color; //gcolor
    gl_FragData[1] = vec4(vec2(0.0), vec2(1));
}