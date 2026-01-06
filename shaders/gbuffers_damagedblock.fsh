#version 120

#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord)*glcolor; //*glcolor
	
/* DRAWBUFFERS:01 */
	gl_FragData[0] = color; //gcolor
	gl_FragData[1] = vec4(encodeNormal(viewNormal), 1, 1);
}