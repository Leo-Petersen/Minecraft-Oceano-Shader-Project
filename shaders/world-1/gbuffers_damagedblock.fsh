#version 130

#include "/lib/settings.glsl"
#include "/world-1/lib/encode.glsl"

uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord)*glcolor; //*glcolor
	
#ifdef PHOTONICS_ENABLED
/* RENDERTARGETS: 0,1,14 */
#else
/* DRAWBUFFERS:01 */
#endif
	gl_FragData[0] = color; //gcolor
	gl_FragData[1] = vec4(encodeNormal(viewNormal), 1, 1);
#ifdef PHOTONICS_ENABLED
	gl_FragData[2] = vec4(color.rgb, 1.0);
#endif
}