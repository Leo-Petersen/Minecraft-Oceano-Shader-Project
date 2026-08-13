#version 130

#include "/lib/settings.glsl"

uniform sampler2D lightmap;

varying vec2 lmcoord;
varying vec4 glcolor;

void main() {
	vec4 color = glcolor;
	color *= texture2D(lightmap, lmcoord);
	//color.a = .6;

#ifdef PHOTONICS_ENABLED
/* RENDERTARGETS: 0,14,15 */
#else
/* RENDERTARGETS: 0 */
#endif
	gl_FragData[0] = color; //gcolor
#ifdef PHOTONICS_ENABLED
	gl_FragData[1] = vec4(color.rgb, 1.0);
	gl_FragData[2] = vec4(0.5, 0.5, 1.0, 1.0);
#endif
}