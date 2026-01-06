#version 120

uniform sampler2D texture;

uniform float rainStrength;

varying float iswater;

varying vec2 texcoord;
varying vec4 color;

void main() {
	vec4 fragcolor = texture2D(texture,texcoord.xy) * color;

	if (iswater == 1.0){
		//fragcolor.a *= 0.8;
		//fragcolor.rgb *= 1.5;
		fragcolor.rgb *= (dot(vec3(0.2126, 0.7152, 0.0722), fragcolor.rgb) + 1.0 * (1-rainStrength));
	}
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = fragcolor;
}