
#ifdef volumetricFog
float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer8(a)   (bayer4(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer16(a)  (bayer8(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer32(a)  (bayer16(0.5 * (a)) * 0.25 + bayer2(a))
#define bayer64(a)  (bayer32(0.5 * (a)) * 0.25 + bayer2(a))
float dither64 = bayer64(gl_FragCoord.xy);

float expDepth(float dist){
    return (far * (dist - near)) / (dist * (far - near));
}

float getDepthVol(float depth) {
    return (near * far) / (near * depth + (far * (1.0 - depth)));
}

float shadowStep(sampler2D shadow, vec3 sPos) {
    return clamp(1.0 - max(sPos.z - texture2D(shadow, sPos.xy).y, 0.0) * 4096, 0.0, 1.0);
}

vec2 DistortPosition(in vec2 position){
    float CenterDistance = length(position);
    float DistortionFactor = mix(1.0f, CenterDistance, 0.9f);
    return position / DistortionFactor;
}

vec4 ShadowSpace(float depth0) {
    vec3 ClipSpace = vec3(texcoord, depth0) * 2.0f - 1.0f;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0f);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

vec3 getFog(vec3 color, vec3 cameraPosition, vec3 worldPos, vec3 volumeColor, float iswater, float glare, vec3 sunCol, float transitionFade, vec3 skyCol, float sunAngleCosine){
    
    #ifdef volumetricLight
        float startRay = 1.0;
        const float endRay = 128.0;
        float increment = 64.0/volumetricFogQuality;
        
        #ifdef TAA
        dither64 = fract(dither64 + frameTimeCounter * 8.0);
        #endif

        startRay += dither64 * increment;

        float weight = -increment / (startRay - 128.0);
        float ray = 0.0;

        vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * -shadowLightPosition);
        vec3 startWorldPos = mat3(gbufferModelViewInverse) * vec3(0.0) + gbufferModelViewInverse[3].xyz;
        
        float sceneDepthLinear = getDepthVol(Depth);
        
        for (; startRay < endRay; startRay += increment) {
            if (startRay > sceneDepthLinear) break;

            vec4 shadowCoord = ShadowSpace(expDepth(startRay));
            shadowCoord.xy *= distort(shadowCoord.xy);
            shadowCoord.z /= 6.0;
            vec3 SampleCoords = shadowCoord.xyz * 0.5f + 0.5f;
            SampleCoords.z -= 0.0005;
                
            float shadowSampleBack = shadowStep(shadowtex1, SampleCoords);

            if (isEyeInWater > 0.9) {
                vec3 ClipSpace = vec3(texcoord, expDepth(startRay)) * 2.0f - 1.0f;
                vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
                vec3 View = ViewW.xyz / ViewW.w;
                vec4 World = gbufferModelViewInverse * vec4(View, 1.0f);
                vec3 currentWorldPos = World.xyz;
                
                vec3 lightRayDir = lightDir; 
                
                float distToSurface = abs(currentWorldPos.y - startWorldPos.y) / abs(lightRayDir.y);
                vec3 causticSamplePos = currentWorldPos + lightRayDir * distToSurface;
                causticSamplePos.y = startWorldPos.y;
                
                vec3 causticValue = waterCaustics(causticSamplePos, 1.0);
                float causticStrength = causticValue.x;
                
                vec3 viewDir = normalize(currentWorldPos - cameraPosition);
                float viewLightAngle = dot(viewDir, lightDir);
                causticStrength *= 0.5 + 0.5 * max(0.0, viewLightAngle); 
                
                shadowSampleBack *= causticStrength;
            }
            ray += shadowSampleBack;
        }

    float startFactor = 1.0;
    #else
        float weight = 1.0;
        float ray = 0.5;
        float startFactor = 0.3;
    #endif

    float closeFactor = 1.0;

    float altitude = FogAltitude; 
    #ifndef volumetricLight
    closeFactor *= 0.2;
    #endif

    float timeFactor = 0.06 * (time[0]) +  
                       0.11 * (time[1]) +
                       0.14 * (time[2]) + 
                       0.11 * (time[3]) + 
                       0.06 * (time[4]) + 
                       0.02 * (time[5]);

    if (isEyeInWater > 0.9){
        glare = 1.0;
        closeFactor = 0.0;
        volumeColor = vec3(0.0, 0.36, 0.51) * 0.5 * (1.0 - time2[1].y * 0.8);
        volumeColor = pow(volumeColor, vec3(1.8));
        
        #ifdef volumetricLight
        vec3 underwaterLightColor = sunCol * vec3(0.5, 0.65, 0.8) * 0.3;
        volumeColor = mix(volumeColor, volumeColor + underwaterLightColor, ray * weight * 0.25);
        #endif
    }

    float altitudeFactor = (worldPos.y + eyeAltitude + 1000.0 - altitude) * 0.001;
    if (altitudeFactor > 0.965 && altitudeFactor < 1.0) {
        altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.965) * 28.57);
    }
    altitudeFactor = pow(altitudeFactor, 10.0 - (rainStrength * 9.0));

    #ifdef volumetricLight
    float altitudeFog = (1.0 - (exp(-50.0 * pow(length(worldPos.xz) / pow(far, startFactor) * closeFactor * 0.155, 2.5 - (2.0 * rainStrength)))));
          altitudeFog *= (1.0 - altitudeFactor) * FogStrength;
          altitudeFog *= timeFactor * 0.3 + sunAngleCosine * 0.1;

    float rainFogDepth = length(worldPos.xz) / 20.0;
          rainFogDepth = (1.0 - exp(-0.2 * pow(rainFogDepth, 1.0)));
          rainFogDepth = clamp(rainFogDepth, 0.0, 0.85);
          rainFogDepth *= rainStrength;

    float rayweight = ray * weight * 4.0 * pow(glare, 0.5) * timeFactor;
          rayweight *= clamp(altitudeFog, 0.025, 1.9) * 100.0;
          rayweight += clamp(altitudeFog * 5010.0 * timeFactor * ray * weight, 0.0, 1.9);
          rayweight *= transitionFade;
          rayweight *= 0.25 * (1.0 + isEyeInWater * 8.0);
          if (isEyeInWater > 0.9){
            rayweight = clamp(rayweight, 0.0, 1.0);
          } else {
            rayweight = clamp(rayweight, 0.0, 0.5 * (1.0 - rainStrength * 0.4));
          }
    
    vec3 rainVolume = (rayweight * (vec3(0.1, 0.1, 0.11)) * 3.0 * rainFogDepth) + skyColor * 0.2 + (vec3(0.01, 0.011, 0.014) * time[5]);
         rainVolume = mix(color, rainVolume * 0.6, rainFogDepth);

         volumeColor = mix(volumeColor, sunCol, pow(sunAngleCosine, 2.3) * 0.5);

    vec3 finalFogCol = mix(color, volumeColor * vec3(0.72 * (1.0 - (rainStrength - isEyeInWater) * 0.9)), rayweight);
        if (isEyeInWater < 1.0) finalFogCol = (finalFogCol * (1.0 - rainStrength)) + (rainVolume * rainStrength);		 

    color = clamp(finalFogCol, vec3(0.0), vec3(1.0));

    #else

    float altitudeFog = (1.0 - (exp(-50.0 * pow(length(worldPos.xz) / pow(far, startFactor) * closeFactor * 0.125, 3.25))));
          altitudeFog *= (1.0 - altitudeFactor) * FogStrength * 1.3 * (0.50 * timeFactor);
          altitudeFog = clamp(altitudeFog, 0.0, 1.9);

        if (isEyeInWater == 1.0){
          altitudeFog *= 1;
        }
    float rayweight = clamp(0.042, 0.0, 1.0);
              
    vec3 finalFogCol = mix(color, volumeColor * vec3(0.55), rayweight * altitudeFog);
         finalFogCol = clamp(finalFogCol, vec3(0.0), vec3(1.0));
    color = finalFogCol = clamp(finalFogCol, vec3(0.0), vec3(1.0));
    
    #endif
    
    return color;
}
#endif
