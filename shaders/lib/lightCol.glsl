
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
vec3 sunCol = (vec3(255, 100, 32)/255 * (time2[0].x) + 
			   vec3(255, 251, 225)/255 * (time2[0].y) 	+ 
			   vec3(255, 100, 32)/255 * (time2[1].x)  + 
			   vec3(3, 3, 4)/255 * (time2[1].y))*2;

////Light Colour////
// vec3 sunlightCol = (vec3(255, 70, 0)/255 * 0.4 * (time2[0].x) + 
// 				   vec3(255, 220, 165)/255 * 0.5 * (time2[0].y)  + 
// 			   	   vec3(255, 70, 0)/255 * 0.4 * (time2[1].x)  + 
// 				   vec3(30, 32, 64)/255 * 0.65 * (time2[1].y)) + 
// 					((1 - time2[1].y)*(vec3(skyColor) * (rainStrength * 0.9))) + 
// 					((time2[1].y)*(vec3(0.1+skyColor) * (rainStrength * 0.9)));

vec3 sunlightCol = (
				vec3(255, 155, 85)/255  * 0.45 * time[0] +   
				vec3(255, 240, 235)/255 * 0.55  * time[1] +   
				vec3(255, 240, 235)/255 * 0.55  * time[2] +   
				vec3(255, 240, 235)/255 * 0.55  * time[3] +   
				vec3(255, 155, 85)/255  * 0.45  * time[4] +   
				vec3(55, 65, 85)/255    * 0.8  * time[5]    
				) + ((1.0 - time[5]) * (vec3(skyColor) * (rainStrength * 0.2))) 
				+ ((time[5]) * (vec3(0.1 + skyColor) * (rainStrength * 2.5)));

////Ambient Colour////
// vec3 ambientColor = (vec3(10, 50, 100)/255 * (time2[0].x) +  
// 				 	 vec3(10, 50, 100)/255 * (time2[0].y)  +
// 				 	 vec3(10, 50, 100)/255 * (time2[1].x)  +  
// 				 	 vec3(0, 5, 30)/255 * time2[1].y); 	

vec3 ambientShadowColor = (vec3(30, 40, 100)/255);

// vec3 shadowCol = (vec3(60, 50, 180)/255 * (time2[0].x) +  
// 				 vec3(100, 90, 200)/255  * (time2[0].y)  +
// 				 vec3(60, 50, 180)/255  * (time2[1].x)  +  
// 				 vec3(20, 50, 130)/255 * time2[1].y);

vec3 shadowCol = pow((vec3(70,80,200)/255 *(time[0]) + 
			      vec3(85, 120, 200)/255 * (time[1]) + 
			      vec3(85, 120, 200)/255 * (time[2]) + 
			      vec3(85, 120, 200)/255 * (time[3]) + 
			      vec3(70,80,200)/255 * (time[4]) +
			      vec3(33,50,127)/255 * 1.4 * (time[5])), vec3(2.2)) *     
				(1.0 + rainStrength * 0.5);

////Fog////
vec3 fogCol = (vec3(255, 100, 50)/255 * (time[0]) + 
			   vec3(30, 80, 255)/255 * (time[1]) + 
			   vec3(30, 80, 255)/255 * (time[2]) + 
			   vec3(30, 80, 255)/255 * (time[3]) + 
			   vec3(255, 100, 50)/255 * (time[4])  + 
			   (vec3(40, 90, 255)/255 * (time[5])) * (1.0 - rainStrength)) + 
					((1 - time[5])*(vec3(skyColor) * (rainStrength * 0.45))) + 
					((time[5])*(vec3(0.1+skyColor) * (rainStrength * 0.25)));

vec3 fogCol2 = (vec3(190, 140, 90)/255 * 0.3 * (time[0]) +    
               vec3(220, 210, 230)/255 * (time[1]) +    
               vec3(240, 240, 245)/255 * (time[2]) +    
               vec3(220, 210, 230)/255 * (time[3]) +    
               vec3(190, 140, 90)/255 * 0.3 * (time[4]) +     
               vec3(25, 35, 60)/255 * 0.7 * (time[5])) *     
               (1.0 - rainStrength * 0.5) + 
               skyColor * rainStrength * 0.35;

vec3 atmoColor = (vec3(255, 180, 130)/255 * 0.1 * (time[0]) +   
                  vec3(85, 130, 200)/255  * 0.9  * (time[1]) +   
                  vec3(110, 148, 210)/255 * 1.0  * (time[2]) +   
                  vec3(95, 135, 195)/255  * 0.85 * (time[3]) +   
                  vec3(255, 165, 110)/255 * 0.1  * (time[4]) +   
                  vec3(20, 30, 70)/255    * 0.15 * (time[5])     
                 ) * clamp(transitionFade, 0.6, 1.0);

float fogStrength = 0.3;

vec3 fogColor = fogCol * (1 - time2[1].y * 0.6) + vec3(skyColor*0.2) * (1 - time2[1].y * 0.6) * (rainStrength);
