#version 120

uniform sampler2D lightmap;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;
#include "/lib/encode.glsl"

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
		 color.rgb *= 2.0;

/* DRAWBUFFERS:01 */
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 1, 1);
}