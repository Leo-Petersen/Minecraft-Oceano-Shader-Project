#version 120

#include "/lib/settings.glsl"

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec4 entityColor;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 viewNormal;
varying vec4 glcolor;

varying mat3 tbnMatrix;

#include "/lib/encode.glsl"

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	// Entity damage/flash color
	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);

	// LabPBR specular: R = smoothness, G = metalness
	vec2 specularMap = texture2D(specular, texcoord).rg;

	// LabPBR normal map: RG = normal XY, B = AO, A = height
	vec4 normalRaw = texture2D(normals, texcoord);
	vec2 normalXY = normalRaw.rg * 2.0 - 1.0;

	// Fall back to geometric normal when no valid normal map exists
	vec3 normalData;
	if (length(normalXY) > 0.003) {
		normalData = vec3(normalXY, sqrt(max(1.0 - dot(normalXY, normalXY), 0.0)));
		normalData *= tbnMatrix;
	} else {
		normalData = viewNormal;
	}

	vec2 lightMap = vec2(1.0);
		 lightMap.s = clamp(lmcoord.s - 1.0 / 32.0, 0.0, 1.0);
		 lightMap.t = clamp(lmcoord.t - 1.0 / 32.0, 0.0, 1.0);

/* RENDERTARGETS: 0,1,2,8,13 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodeNormal(normalData), specularMap.r, 1);
	gl_FragData[2] = vec4(lightMap, 0, 1);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[4] = vec4(0, 0, 1, 1.0);
}
