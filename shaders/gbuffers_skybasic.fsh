#version 120

varying vec4 starData; //rgb = star color, a = flag for weather or not this pixel is a star.
varying vec4 gcolor;

varying vec4 position;
varying float stars;

uniform sampler2D colortex10;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float rainStrength;
uniform float screenBrightness;
uniform float nightVision;

uniform vec3 skyColor;

varying vec2 texcoord;

#include "/lib/time.glsl"
#include "/lib/skybox.glsl"
#include "/lib/settings.glsl"

/*
const int colortex10Format = R11F_G11F_B10F;
*/

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	//color = color + (color-luma)*strength*0.1;
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

void main() {
	
  vec4 color = gcolor;

  vec3 skybox = getSkyTextureFromSequence(position.xyz);  
	   //Rain//
	   skybox += vec3(skyColor*0.5) * (rainStrength * 0.5);
	   //Adjust exposure and gamma//
	   skybox = pow(skybox, vec3(3.2))*2;
	   //skybox = luminance(skybox, 1.0);
	   skybox = clamp(skybox*(1-rainStrength*0.3), vec3(0.0), vec3(1.0));

	   //Draw default stars//
	//   if (starData.a > 0.5) {
	// 	   skybox = starData.rgb*5;
	//   }

/* DRAWBUFFERS:09 */
	gl_FragData[0] = vec4(skybox, 1.0);
	gl_FragData[1] = vec4(skybox, 1.0);
}