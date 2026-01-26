#version 130

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D specular;
uniform vec4 entityColor;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;
#include "/lib/encode.glsl"


void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;
	vec2 specularMap = texture2D(specular, texcoord).rg;
	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
	vec2 lightMap = vec2(1.0);
		 lightMap.s = clamp(lmcoord.s - 1.0 / 32.0, 0.0, 1.0);
		 lightMap.t = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);

/* RENDERTARGETS: 0,1,2,13 */
	gl_FragData[0] = color; //colortex0
    gl_FragData[1] = vec4(encodeNormal(viewNormal), 0, 1);
	gl_FragData[2] = vec4(lightMap, 0, 1);
	gl_FragData[3] = vec4(0, 0, 1, 1);
}