// COMPLETELY REWORKED TO BE ONE COHERENT MODEL!!! as opposed to the old magic number system.

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

float rainAmt = clamp(rainStrength, 0.0, 1.0);
float rainT = rainAmt * rainAmt * (3.0 - 2.0 * rainAmt);
float rainDirect  = pow(1.0 - rainAmt, 1.6);
float rainScatter = 1.0 - rainDirect;

const float rainDesat     = 0.00; // 0 = normal hue, 1 = grey
const float rainAmbDayLum = 0.32; // flat overcast level, daytime
const float rainAmbNgtLum = 0.10; // flat overcast level, night

vec3  rainGreyHue = mix(atmAmbHue, vec3(1.0), rainDesat) * vec3(0.97, 0.99, 1.05);
float rainAmbLum  = mix(rainAmbDayLum, rainAmbNgtLum, atmNight);
vec3  rainAmbient = rainGreyHue * rainAmbLum;

//// Sun / Moon Disc Colour ////
vec3 sunDisc  = atmTint(mix(vec3(255, 240, 214)/255, vec3(255, 140, 50)/255, atmGlow), atmSunHue, 0.85);
vec3 moonDisc = vec3(3, 3, 4)/255;
vec3 sunCol   = (sunDisc * atmDN + moonDisc * atmMoon);

//// Sunlight Colour ////
float atmDayLum = mix(0.16, 0.58, smoothstep(0.05, 0.65, sunElevation));
float atmMoonLum = mix(0.42, 1.0, smoothstep(-0.08, -0.22, atmSunTrue.y));
vec3 atmDayLight  = atmSunHue * atmDayLum;
vec3 atmMoonLight = vec3(40, 70, 115)/255 * 0.7 * atmMoonLum;

vec3 sunlightClear = atmDayLight * atmDN + atmMoonLight * atmMoon;
vec3 sunlightCol = mix(sunlightClear, rainAmbient, rainT);

//// Ambient Shadow Colour ////
vec3 ambientShadowColor = vec3(20, 30, 55)/255;

//// Shadow Distance Colour ////
vec3 shadowDistClear = mix(vec3(20, 30, 80)/255 * 0.15, vec3(20, 30, 55)/255, atmDN);
vec3 shadowDistColor = mix(shadowDistClear, rainAmbient * 0.80, rainT);

//// Shadow Colour ////
vec3 shadowClear = mix(vec3(6, 2, 69)/255, vec3(23, 49, 150)/255, atmDN);
vec3 shadowCol   = mix(shadowClear, rainAmbient * 0.90, rainT);

//// Fog Color ////
vec3 fogDay   = vec3(120, 158, 203)/255;
vec3 fogNight = vec3(55, 80, 130)/255;
vec3 fogWarm  = vec3(250, 160, 120)/255;
vec3 fogBase  = mix(mix(fogNight, fogDay, atmDN), fogWarm, atmGlow);
vec3 fogCol = mix(atmTint(fogBase, atmAmbHue, 0.85 * atmDN), rainAmbient * 1.15, rainT);

//// Cloud Fog Colour ////
vec3 cloudDay   = vec3(249, 249, 254)/255 * 0.95;
vec3 cloudNight = vec3(40, 50, 100)/255 * 0.75;
vec3 cloudWarm  = vec3(255, 160, 100)/255 * 0.95;
vec3 cloudBase  = mix(mix(cloudNight, cloudDay, atmDN), cloudWarm, atmGlow);
vec3 cloudFogCol = atmTint(mix(cloudBase, rainAmbient * 1.20, rainT), atmAmbHue, 0.6 * atmDN);

float fogStrength = 0.3;

vec3 fogColor = fogCol * (1.0 - atmNight * 0.6);

//// Atmosphere Color ////
vec3 atmoDay   = vec3(105, 145, 205)/255 * 0.85;
vec3 atmoNight = vec3(20, 30, 70)/255 * 0.28;
vec3 atmoWarm  = vec3(255, 178, 120)/255 * 0.60;
vec3 atmoBase  = mix(mix(atmoNight, atmoDay, atmDN), atmoWarm, atmGlow);
vec3 atmoClear = atmTint(atmoBase, atmAmbHue, 0.75 * atmDN) * clamp(transitionFade, 0.6, 1.0);
vec3 atmoColor = mix(atmoClear, rainAmbient, rainT);
