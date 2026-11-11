
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float far;
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform int isEyeInWater;
uniform int frameCounter;

varying vec2 texcoord;

float material = texture2D(colortex2, texcoord).p;
float iswater = float(material > 0.08 && material < 0.10);
float Depth = texture2D(depthtex0, texcoord).r;

vec3 atmSunTrue = normalize(mat3(gbufferModelViewInverse) * sunPosition);

float Depth1 = texture2D(depthtex1, texcoord).r;

#include "/lib/settings.glsl"
#include "/lib/time.glsl"
#include "/lib/lightCol.glsl"
#include "/lib/dh.glsl"

#define waterBlurTaps 10
#define underwaterBlurTaps 16

vec4 spiralBlur(vec4 center, vec2 radius, int taps, float rotation) {
	vec4 sum = center;
	for (int k = 0; k < taps; k++) {
		float r = sqrt((float(k) + 0.5) / float(taps));
		float a = float(k) * 2.39996323 + rotation;
		sum += texture2D(colortex0, texcoord + vec2(cos(a), sin(a)) * radius * r);
	}
	return sum / float(taps + 1);
}

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	
	float undergroundFix = clamp(mix(max(texture2D(colortex2, texcoord).t-2.0/16.0,0.0)*1.14285714286,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)), 0.0, 1.0);

	bool fromDH;
	vec4 viewPos = vec4(reconstructViewPos(texcoord, Depth, fromDH), 1.0);
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz + gbufferModelViewInverse[3].xyz;

	vec3 fragpos2 = reconstructViewPosOpaque(texcoord, Depth1);
	
    float Pi2 = 6.28318530718; // Pi*2
    float Directions = 12.0;
    float Quality = 2.0;
    float Size = 10.0;
   
    vec2 Radius = Size/vec2(viewWidth, viewHeight);

	float blurRot = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
	#ifdef TAA
		blurRot = fract(blurRot + float(frameCounter % 8) * 0.125);
	#endif
	blurRot *= Pi2;
	
	#ifdef fogBlur
    // https://www.shadertoy.com/view/Xltfzj //
	//Water blur//
	if (iswater == 1.0){
	float depthFog = 1.0 - clamp(exp2(-distance(viewPos.xyz, fragpos2) * 0.14), 0.0, 1.0); // Beer's Law
		color = spiralBlur(color, Radius * depthFog, waterBlurTaps, blurRot);
	}

	#ifdef rainfogBlur
	//Rain Blur
	if (!isSky(texcoord, Depth)) {
		if (rainStrength > 0.0){
			float fogDepth = length(worldPos.xz) / 120.0;
				  fogDepth = pow(fogDepth, 1.5);
				  fogDepth = 1.0 - exp(-0.3 * fogDepth);
				  fogDepth = clamp(fogDepth, 0.0, 0.5);

			for( float d=0.0; d<Pi2; d+=Pi2/Directions)
				{
					for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
					{
						color += texture2D(colortex0, texcoord+vec2(cos(d),sin(d))*Radius*i*fogDepth*1.5*rainStrength*undergroundFix);		
					}
				}
			// Output to screen
			color /= Quality * Directions + 1.0;
		}
	}
	#endif

	//Underwater//
	if (isEyeInWater == 1.0){
		float fogDepth = length(worldPos.xz) / 21;
			  fogDepth = pow(fogDepth, 2.0);
			  fogDepth = 1.0 - exp(-1.2 * fogDepth);
			  fogDepth = clamp(fogDepth, 0.0, 0.5);

		color = spiralBlur(color, Radius * fogDepth * 2.55, underwaterBlurTaps, blurRot);
	}

	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}
