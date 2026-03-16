
vec3 luminance(vec3 color, float strength) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  	color = mix(color, vec3(luma), vec3(1.0 - strength));
	return color;
}

mat2 time2 = mat2(vec2(
				((clamp(ticks, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(ticks, 0.0f, 2000.0f)/2000.0f)),
				((clamp(ticks, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f)),

				vec2(

				((clamp(ticks, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f),
				((clamp(ticks, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(ticks, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f))
);	//time2[0].x.xy = sunrise and noon. time[1].xy = sunset and mindight.

////Sun Colour////
vec3 sunCol = (vec3(255, 140, 50)/255 * (time2[0].x) + 
			   vec3(255, 251, 225)/255 * (time2[0].y) 	+ 
			   vec3(255, 140, 50)/255 * (time2[1].x)  + 
			   vec3(3, 3, 4)/255 * (time2[1].y))*2;

////Sunlight Colour////
vec3 sunlightCol = (
				vec3(255, 175, 100)/255  * 0.45 * time[0] +   // sunrise
				vec3(255, 250, 248)/255 * 0.55  * time[1] +   // morning
				vec3(255, 250, 248)/255 * 0.55  * time[2] +   // noon
				vec3(255, 250, 248)/255 * 0.55  * time[3] +   // evening
				vec3(255, 175, 100)/255  * 0.45 * time[4] +   // sunset
				vec3(40, 70, 120)/255    * 0.6  * time[5]     // night
				) + ((1.0 - time[5]) * (vec3(skyColor) * (rainStrength * 0.2))) 
				+ ((time[5]) * (vec3(0.1 + skyColor) * (rainStrength * 2.5)));

///Ambient Shadow Colour//// (doesnt change)
vec3 ambientShadowColor = vec3(20, 30, 55)/255;;

////Shadow Distance Colour//// (what fake bounce light fades into with distance)
vec3 shadowDistColor = (vec3(20, 30, 80)/255 * 0.3 * (time[0]) +   
                  vec3(20, 30, 55)/255  * 1  * (time[1]) +   
                  vec3(20, 30, 55)/255 * 1  * (time[2]) +   
                  vec3(20, 30, 55)/255  * 1 * (time[3]) +   
                  vec3(20, 30, 80)/255 * 0.3  * (time[4]) +   
                  vec3(20, 30, 80)/255    * 0.2 * (time[5])     
                 ) * clamp(transitionFade, 0.55, 1.0);

////Shadow Colour////
vec3 shadowCol = (vec3(3, 8, 150)/255 * (time[0]) + 
                  vec3(23, 49, 150)/255 * (time[1]) + 
                  vec3(23, 49, 150)/255 * (time[2]) + 
                  vec3(23, 49, 150)/255 * (time[3]) + 
                  vec3(3, 8, 150)/255 * (time[4]) +
                  vec3(6, 2, 69)/255 * (time[5])) *     
                  (1.0 + rainStrength * 0.5);

////Fog Color////
vec3 fogCol = (
				vec3(255, 100, 50)/255 * (time[0]) + 
				vec3(30, 80, 255)/255 * (time[1]) + 
				vec3(30, 80, 255)/255 * (time[2]) + 
				vec3(30, 80, 255)/255 * (time[3]) + 
				vec3(255, 100, 50)/255 * (time[4])  + 
				(vec3(40, 90, 255)/255 * (time[5])) * (1.0 - rainStrength)) + 
						((1 - time[5])*(vec3(skyColor) * (rainStrength * 0.45))) + 
						((time[5])*(vec3(0.1+skyColor) * (rainStrength * 0.25)));

vec3 cloudFogCol = (mix(
			(
				vec3(255, 160, 100)/255  * 0.5 * time[0] +
				vec3(245, 245, 250)/255  * 0.95 * time[1] +  
				vec3(250, 250, 255)/255  * 0.95 * time[2] +
				vec3(245, 240, 235)/255  * 0.95 * time[3] +  
				vec3(255, 160, 100)/255  * 0.5 * time[4] +
				vec3(40, 50, 115)/255     * 0.23 * time[5] 
			) + ((1.0 - time[5]) * (vec3(skyColor) * (rainStrength * 0.2)))
			+ ((time[5]) * (vec3(0.1 + skyColor) * (rainStrength * 2.5))),
			vec3(0.55, 0.57, 0.6)*1.6 * (1.0 - time[5] * 0.9),
			rainStrength * 0.85
		) + vec3(0.03, 0.06, 0.2) * 1.5 * rainStrength * time[5]);

float fogStrength = 0.3;

vec3 fogColor = fogCol * (1 - time2[1].y * 0.6) + vec3(skyColor*0.2) * (1 - time2[1].y * 0.6) * (rainStrength);

////Atmosphere Color////
vec3 atmoColor = (vec3(255, 180, 130)/255 * 0.3 * (time[0]) +   
                  vec3(85, 130, 200)/255  * 0.85  * (time[1]) +   
                  vec3(110, 148, 210)/255 * 0.85  * (time[2]) +   
                  vec3(95, 135, 195)/255  * 0.85 * (time[3]) +   
                  vec3(255, 165, 110)/255 * 0.3  * (time[4]) +   
                  vec3(20, 30, 70)/255    * 0.15 * (time[5])     
                 ) * clamp(transitionFade, 0.6, 1.0);