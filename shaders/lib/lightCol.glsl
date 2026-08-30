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
    return mix(orig, physHue * b, 0.6);
}

vec3 atmTint(vec3 c, vec3 physHue, float s) {
    float b = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return mix(c, physHue * b, clamp(s, 0.0, 1.0));
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

float atmDN    = smoothstep(-0.08, 0.08, sunElevation);
float atmNight = 1.0 - atmDN;
float atmGlow  = smoothstep(0.35, 0.05, sunElevation) 
               * smoothstep(-0.10, 0.00, sunElevation); 

float atmMoon = 1.0 - smoothstep(-0.22, -0.08, sunElevation);

mat2 time2 = mat2(vec2(
				((clamp(ticks, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(ticks, 0.0f, 2000.0f)/2000.0f)),
				((clamp(ticks, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),
				vec2(
				((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(ticks, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);

//// Sun / Moon Disc Colour ////
vec3 sunDisc  = atmTint(mix(vec3(255, 240, 214)/255, vec3(255, 140, 50)/255, atmGlow), atmSunHue, 0.85);
vec3 moonDisc = vec3(3, 3, 4)/255;
vec3 sunCol   = (sunDisc * atmDN + moonDisc * atmMoon);

//// Sunlight Colour ////
float atmDayLum = mix(0.12, 0.58, smoothstep(0.05, 0.40, sunElevation));
float atmMoonLum = mix(0.42, 1.0, smoothstep(-0.08, -0.22, atmSunTrue.y));
vec3 atmDayLight  = atmSunHue * atmDayLum;
vec3 atmMoonLight = vec3(40, 70, 115)/255 * 0.7 * atmMoonLum;

vec3 sunlightCol = rainGrey(
			atmDayLight * atmDN
			+ atmMoonLight * atmMoon
			+ (atmDN   * (vec3(skyColor) * (rainStrength * 0.2)))
			+ (atmNight * rainStrength * (vec3(0.1) + skyColor * 0.6 + vec3(0.020, 0.023, 0.030))),
			rainStrength * 0.88);

//// Ambient Shadow Colour ////
vec3 ambientShadowColor = vec3(20, 30, 55)/255;

//// Shadow Distance Colour ////
vec3 shadowDistColor = rainGrey(
                  mix(vec3(20, 30, 80)/255 * 0.15 * (1.0 - rainStrength), vec3(20, 30, 55)/255, atmDN),
                  rainStrength * 0.30) * (1.0 - rainStrength * 0.66);

//// Shadow Colour ////
vec3 shadowCol = rainGrey(
                 mix(vec3(6, 2, 69)/255, vec3(23, 49, 150)/255, atmDN),
                 rainStrength * 0.9) * (1.0 - rainStrength * 0.25);

//// Fog Color ////
vec3 fogDay   = vec3(120, 158, 203)/255;
vec3 fogNight = vec3(55, 80, 130)/255 * (1.0 - rainStrength);
vec3 fogWarm  = mix(vec3(250, 160, 120), vec3(115, 150, 200) * 0.8, rainStrength)/255;
vec3 fogBase  = mix(mix(fogNight, fogDay, atmDN), fogWarm, atmGlow);
vec3 fogCol = rainGrey(atmTint(
					fogBase
					+ (atmDN   * (vec3(skyColor) * (rainStrength * 0.45)))
					+ (atmNight * (vec3(0.1) + skyColor) * (rainStrength * 0.25)),
					atmAmbHue, 0.85 * atmDN),
                rainStrength * 0.30);

//// Cloud Fog Colour ////
vec3 cloudDay   = vec3(249, 249, 254)/255 * 0.95;
vec3 cloudNight = vec3(40, 50, 100)/255 * 0.75;
vec3 cloudWarm  = vec3(255, 160, 100)/255 * 0.95;
vec3 cloudBase  = mix(mix(cloudNight, cloudDay, atmDN), cloudWarm, atmGlow);
vec3 cloudFogCol = atmTint(mix(
				cloudBase
				+ (atmDN   * (vec3(skyColor) * (rainStrength * 0.2)))
				+ (atmNight * (vec3(0.1) + skyColor) * (rainStrength * 1.5)),
				vec3(0.52, 0.55, 0.62) * 2.0 * (1.0 - atmNight * 0.9),
				rainStrength * 0.95
				) + vec3(0.03, 0.06, 0.2) * rainStrength * atmNight,
				atmAmbHue, 0.6 * atmDN);

float fogStrength = 0.3;

vec3 fogColor = fogCol * (1.0 - atmNight * 0.6) + vec3(skyColor * 0.2) * (1.0 - atmNight * 0.6) * (rainStrength);

//// Atmosphere Color ////
vec3 atmoDay   = vec3(105, 145, 205)/255 * 0.85;
vec3 atmoNight = vec3(20, 30, 70)/255 * 0.28;
vec3 atmoWarm  = vec3(255, 178, 120)/255 * 0.60;
vec3 atmoBase  = mix(mix(atmoNight, atmoDay, atmDN), atmoWarm, atmGlow);
vec3 atmoColor = rainGrey(atmTint(atmoBase, atmAmbHue, 0.75 * atmDN)
                  * clamp(transitionFade, 0.6, 1.0),
                  rainStrength * 0.30);
