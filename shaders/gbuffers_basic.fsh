#version 130

uniform sampler2D lightmap;

varying vec2 lmcoord;
varying vec4 glcolor;

void main() {
	vec4 color = glcolor;
	color *= texture2D(lightmap, lmcoord);
	//color.a = .6;

/* RENDERTARGETS: 0,1,2,13 */
	gl_FragData[0] = color; //gcolor
    gl_FragData[1] = vec4(vec2(0.0), vec2(1));
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 1.0, 1.0); 
}