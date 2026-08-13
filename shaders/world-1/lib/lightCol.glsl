#ifndef atmosphereSun
vec3 atmSun = vec3(1.0);
vec3 atmAmb = vec3(1.0);
#endif

// unit luminance physical hues
float atmSunLum = dot(atmSun, vec3(0.2126, 0.7152, 0.0722));
float atmAmbLum = dot(atmAmb, vec3(0.2126, 0.7152, 0.0722));
vec3 atmSunHue = (atmSunLum > 1e-3) ? atmSun / atmSunLum : vec3(1.0);
vec3 atmAmbHue = (atmAmbLum > 1e-3) ? atmAmb / atmAmbLum : vec3(1.0);

vec3 atmHueMix(vec3 orig, vec3 physHue) {
    float b = dot(orig, vec3(0.2126, 0.7152, 0.0722));
    return mix(orig, physHue * b, 0.6); // 0 is the original colours, 1 is the PBR approach. This is a terrible temp fix. Not sure just yet how to stylise a 'pbr' atmosphere...
}

vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

vec3 rainGrey(vec3 c, float amt) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return mix(c, vec3(l) * vec3(0.94, 0.97, 1.04), clamp(amt, 0.0, 1.0));
}

mat2 time2 = mat2(vec2(
				((clamp(ticks, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(ticks, 0.0f, 2000.0f)/2000.0f)),
				((clamp(ticks, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),

				vec2(

				((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(ticks, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time2[0].x.xy = sunrise and noon. time[1].xy = sunset and mindight.

vec3 sunlightCol        = vec3(0.95, 0.45, 0.22) * 0.85;
vec3 sunCol             = vec3(1.00, 0.52, 0.28);
vec3 ambientShadowColor = vec3(0.16, 0.07, 0.05);
vec3 shadowCol          = vec3(0.22, 0.08, 0.05);
vec3 shadowDistColor    = vec3(0.18, 0.08, 0.06);
vec3 atmoColor          = vec3(0.28, 0.11, 0.07);
vec3 fogCol             = vec3(0.22, 0.06, 0.04);
vec3 fogColor           = vec3(0.22, 0.06, 0.04);
vec3 cloudFogCol        = vec3(0.24, 0.09, 0.06);

float fogStrength = 0.3;