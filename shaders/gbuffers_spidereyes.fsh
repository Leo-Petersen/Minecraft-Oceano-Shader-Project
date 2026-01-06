#version 130

uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;


void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	     //color.rgb *= (dot(vec3(0.3086, 0.6094, 0.0820), color.rgb))*80.0;

/* RENDERTARGETS: 0,13 */
	gl_FragData[0] = color; //gcolor
	gl_FragData[1] = vec4(1, 0.0, 0.0, 1.0);
}