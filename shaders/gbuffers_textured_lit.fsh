#version 130

#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform sampler2D texture;
uniform mat4 gbufferModelView;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	
	vec3 upNormal = normalize(gbufferModelView[1].xyz);

/* RENDERTARGETS: 0,1,2,13,8 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodeNormal(upNormal), 0, 1.0);
	gl_FragData[2] = vec4(lmcoord, 0.0, 1.0); 
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0); 
}