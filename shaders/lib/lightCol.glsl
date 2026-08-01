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

//Sun Colour//
vec3 sunCol = atmHueMix(
			  (vec3(255, 140, 50)/255 * (time2[0].x) +
			   vec3(255, 251, 225)/255 * (time2[0].y) 	+
			   vec3(255, 140, 50)/255 * (time2[1].x)  +
			   vec3(3, 3, 4)/255 * (time2[1].y))*2,
			  atmSunHue);

//Sunlight Colour//
vec3 sunlightCol = rainGrey(atmHueMix((
				vec3(255, 198, 148)/255 * 0.42 * time[0] +   // sunrise
				vec3(255, 250, 245)/255  * 0.58  * time[1] +   // morning
				vec3(255, 250, 245)/255  * 0.58  * time[2] +   // noon
				vec3(255, 250, 245)/255  * 0.58  * time[3] +   // evening
				vec3(255, 198, 148)/255 * 0.42 * time[4] +   // sunset
				vec3(40, 70, 120)/255    * 0.75  * time[5]     // night
				) + ((1.0 - time[5]) * (vec3(skyColor) * (rainStrength * 0.2)))
				+ (time[5] * rainStrength * (vec3(0.1) + skyColor * 0.6 + vec3(0.020, 0.023, 0.030))),
				atmSunHue),
                rainStrength * 0.88);

//Ambient Shadow Colour//
vec3 ambientShadowColor = vec3(20, 30, 55)/255;;

//Shadow Distance Colour//
vec3 shadowDistColor = rainGrey((vec3(20, 30, 55)/255 * (time[0]) +
                  vec3(20, 30, 55)/255 * (time[1]) +
                  vec3(20, 30, 55)/255 * (time[2]) +
                  vec3(20, 30, 55)/255 * (time[3]) +
                  vec3(20, 30, 55)/255 * (time[4]) +
                  vec3(20, 30, 80)/255 * 0.2 * (time[5])
                 ) * clamp(transitionFade, 0.55, 1.0),
                rainStrength * 0.30) * (1 - rainStrength * 0.66);

//Shadow Colour//
vec3 shadowCol = rainGrey(
                 (vec3(23, 49, 150)/255 * (time[0] + time[1] + time[2] + time[3] + time[4]) + //wrapped because these values are all the same
                  vec3(6, 2, 69)/255 * (time[5])),
                  rainStrength * 0.9) * (1.0 - rainStrength * 0.25);

//Fog Color//
vec3 fogCol = rainGrey(atmHueMix((
				mix(vec3(250, 160, 120), vec3(115, 150, 200) * 0.8, rainStrength)/255 * (time[0]) +
				vec3(115, 150, 200)/255 * (time[1]) +
				vec3(130, 165, 205)/255 * (time[2]) +
				vec3(115, 150, 200)/255 * (time[3]) +
				mix(vec3(250, 160, 120), vec3(115, 150, 200) * 0.8, rainStrength)/255 * (time[4])  +
				(vec3(55, 80, 130)/255 * (time[5])) * (1.0 - rainStrength)) +
						((1 - time[5])*(vec3(skyColor) * (rainStrength * 0.45))) +
						((time[5])*(vec3(0.1+skyColor) * (rainStrength * 0.25))),
				atmAmbHue),
                rainStrength * 0.30);

//Cloud Fog Colour//
vec3 cloudFogCol = atmHueMix((mix(
			(
				vec3(255, 160, 100)/255  * 0.95 * time[0] +
				vec3(245, 245, 250)/255  * 0.95 * time[1] +
				vec3(250, 250, 255)/255  * 0.95 * time[2] +
				vec3(245, 240, 235)/255  * 0.95 * time[3] +
				vec3(255, 160, 100)/255  * 0.95 * time[4] +
				vec3(40, 50, 170)/255     * 0.75 * time[5]
			) + ((1.0 - time[5]) * (vec3(skyColor) * (rainStrength * 0.2)))
			+ ((time[5]) * (vec3(0.1 + skyColor) * (rainStrength * 1.5))),
			vec3(0.52, 0.55, 0.62) * 2.0 * (1.0 - time[5] * 0.9),
			rainStrength * 0.95
			) + vec3(0.03, 0.06, 0.2) * rainStrength * time[5]),
			atmAmbHue);

float fogStrength = 0.3;

vec3 fogColor = fogCol * (1 - time2[1].y * 0.6) + vec3(skyColor*0.2) * (1 - time2[1].y * 0.6) * (rainStrength);

//Atmosphere Color//
vec3 atmoColor = rainGrey(atmHueMix((vec3(255, 178, 120)/255 * 0.60 * (time[0]) +
                  vec3(85, 130, 200)/255  * 0.85  * (time[1]) +
                  vec3(110, 148, 210)/255 * 0.85  * (time[2]) +
                  vec3(95, 135, 195)/255  * 0.85 * (time[3]) +
                  vec3(255, 178, 120)/255 * 0.60  * (time[4]) +
                  vec3(20, 30, 70)/255    * 0.15 * (time[5])
                  ) * clamp(transitionFade, 0.6, 1.0), atmAmbHue),
                  rainStrength * 0.30);
