#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform vec3 shadowLightPosition;
uniform int isEyeInWater;

varying vec2 texcoord;
varying vec2 lmcoord;

float material = texture2D(colortex2, texcoord).p;
float iswater = float(material > 0.08 && material < 0.10);
float Depth = texture2D(depthtex0, texcoord).r;

vec3 nvec3(vec4 pos){
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos){
    return vec4(pos.xyz, 1.0);
}

#include "/lib/settings.glsl"
#include "/lib/time.glsl"

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	
	float undergroundFix = clamp(mix(max(lmcoord.t-2.0/16.0,0.0)*1.14285714286,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)), 0.0, 1.0);

	vec4 screenPos = vec4(texcoord, Depth, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	vec3 fragpos2 = vec3(texcoord.st, texture2D(depthtex1, texcoord.st).r);
		 fragpos2 = nvec3(gbufferProjectionInverse * nvec4(fragpos2 * 2.0 - 1.0));
	
    float Pi2 = 6.28318530718; // Pi*2
    float Directions = 12.0;
    float Quality = 2.0;
    float Size = 10.0;
   
    vec2 Radius = Size/vec2(viewWidth, viewHeight);
	
	#ifdef fogBlur
    // https://www.shadertoy.com/view/Xltfzj //
	//Water blur//
	if (iswater == 1.0){
	float depthFog = 1.0 - clamp(exp2(-distance(viewPos.xyz, fragpos2) * 0.14), 0.0, 1.0); // Beer's Law
		for( float d=0.0; d<Pi2; d+=Pi2/Directions)
			{
				for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
				{
					color += texture2D(colortex0, texcoord+vec2(cos(d),sin(d))*Radius*i*depthFog);		
				}
			}
		// Output to screen
		color /= Quality * Directions;
	}

	//Rain Blur
	if (Depth < 0.9) {
		if (rainStrength > 0.0){
			float fogDepth = length(worldPos.xz) / 150;
				fogDepth = pow(fogDepth, 6.0);
				fogDepth = 1.0 - exp(-0.1 * fogDepth);
				fogDepth = clamp(fogDepth, 0.0, 0.5);

			for( float d=0.0; d<Pi2; d+=Pi2/Directions)
				{
					for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
					{
						color += texture2D(colortex0, texcoord+vec2(cos(d),sin(d))*Radius*i*fogDepth*1.5*rainStrength*undergroundFix);		
					}
				}
			// Output to screen
			color /= Quality * Directions;
		}
	}

	//Cave Blur
	// if (undergroundFix == 0.0){
	// 	float fogDepth = length(worldPos.xz) / 100;
	// 		  fogDepth = pow(fogDepth, 8.0);
	// 		  fogDepth = 1.0 - exp(-0.1 * fogDepth);
	// 		  fogDepth = clamp(fogDepth, 0.0, 0.2);

	// 	for( float d=0.0; d<Pi2; d+=Pi2/Directions)
	// 		{
	// 			for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
	// 			{
	// 				color += texture2D(colortex0, texcoord+vec2(cos(d),sin(d))*Radius*i*fogDepth*1.5);		
	// 			}
	// 		}
	// 	// Output to screen
	// 	color /= Quality * Directions;
	// }

	//Underwater//
	if (isEyeInWater == 1.0){
		float fogDepth = length(worldPos.xz) / 21;
			  fogDepth = pow(fogDepth, 2.0);
			  fogDepth = 1.0 - exp(-1.2 * fogDepth);
			  fogDepth = clamp(fogDepth, 0.0, 0.5);
			  Quality += 2.0;
			  Directions += 3.0;
			  

		for( float d=0.0; d<Pi2; d+=Pi2/Directions)
			{
				for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
				{
					color += texture2D(colortex0, texcoord+vec2(cos(d),sin(d))*Radius*i*fogDepth*2.55);		
				}
			}
		// Output to screen
	
		color /= Quality * Directions;
	}

	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}