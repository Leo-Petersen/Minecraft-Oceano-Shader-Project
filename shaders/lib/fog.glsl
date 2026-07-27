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

float shadowStep(sampler2DShadow shadow, vec3 sPos) {
    return shadow2D(shadow, sPos).r;
}

vec2 DistortPosition(in vec2 position){
    float CenterDistance = length(position);
    float DistortionFactor = mix(1.0, CenterDistance, 0.9);
    return position / DistortionFactor;
}

vec4 ShadowSpace(float depth0) {
    vec3 ClipSpace = vec3(texcoord, depth0) * 2.0 - 1.0;
    vec4 ViewW = gbufferProjectionInverse * vec4(ClipSpace, 1.0);
    vec3 View = ViewW.xyz / ViewW.w;
    vec4 World = gbufferModelViewInverse * vec4(View, 1.0);
    vec4 ShadowSpace = shadowProjection * shadowModelView * World;
    return ShadowSpace;
}

vec3 getFog(vec3 color, vec3 cameraPosition, vec3 worldPos, vec3 volumeColor, float iswater, float glare, vec3 sunCol, float transitionFade, vec3 skyCol, float sunAngleCosine){
    
    #ifdef volumetricLight
        float startRay = 1.0;
        const float endRay = 128.0;
        float increment = 64.0/volumetricFogQuality;
              increment *= (1.0 + rainStrength * 1.6);
        
        #ifdef TAA
        dither64 = fract(dither64 + frameTimeCounter * 8.0);
        #endif

        startRay += dither64 * increment;

        float weight = -increment / (startRay - 128.0);
        float ray = 0.0;

        vec3 lightDir = normalize(mat3(gbufferModelViewInverse) * -shadowLightPosition);
        vec3 startWorldPos = mat3(gbufferModelViewInverse) * vec3(0.0) + gbufferModelViewInverse[3].xyz;
        
        float sceneDepthLinear = getDepthVol(Depth);

        vec3 clip0  = vec3(texcoord, expDepth(startRay)) * 2.0 - 1.0;
        vec4 vw0    = gbufferProjectionInverse * vec4(clip0, 1.0);
        vec3 view0  = vw0.xyz / vw0.w;
        vec3 viewK  = view0 / startRay;

        mat4 shadowMat = shadowProjection * shadowModelView * gbufferModelViewInverse;
        vec4 shadowA   = shadowMat * vec4(viewK, 0.0);
        vec4 shadowB   = shadowMat[3];

        vec3 worldA = mat3(gbufferModelViewInverse) * viewK; 
        vec3 worldB = gbufferModelViewInverse[3].xyz;

        for (; startRay < endRay; startRay += increment) {
            if (startRay > sceneDepthLinear) break;

            vec4 shadowCoord = shadowA * startRay + shadowB;
            shadowCoord.xy *= distort(shadowCoord.xy);
            shadowCoord.z /= 6.0;
            vec3 SampleCoords = shadowCoord.xyz * 0.5 + 0.5;
            SampleCoords.z -= 0.0005;
                
            float shadowSampleBack = shadowStep(shadowtex1, SampleCoords);

            if (isEyeInWater > 0.9) {
                vec3 currentWorldPos = worldA * startRay + worldB;
                
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
                       0.06 * (time[1]) +
                       0.06 * (time[2]) + 
                       0.06 * (time[3]) + 
                       0.06 * (time[4]) + 
                       0.06 * (time[5]);

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
               altitudeFog *= (1.0 - altitudeFactor);
               altitudeFog *= timeFactor * 0.05 + sunAngleCosine * 0.1 * (1 - rainStrength);

         float rainFogDepth = length(worldPos.xz) / 20.0;
             rainFogDepth = (1.0 - exp(-0.1 * pow(rainFogDepth, 0.75)));
             rainFogDepth = clamp(rainFogDepth, 0.0, 0.85);

         float rainAltFactor = (worldPos.y + eyeAltitude + 1000.0 - altitude) * 0.001;
               rainAltFactor = clamp(rainAltFactor, 0.0, 1.0);
               rainAltFactor = pow(rainAltFactor, 2.0);
               
               rainFogDepth *= (1.0 - rainAltFactor * 0.7);
               rainFogDepth *= rainStrength*3;

         float rayweight = ray * weight * 8.5 * pow(glare, 0.5) * timeFactor;
               rayweight *= clamp(altitudeFog, 0.025, 1.9) * 100.0;
               rayweight += clamp(altitudeFog * 5010.0 * timeFactor * ray * weight, 0.0, 1.9);
               rayweight *= transitionFade;
               rayweight *= 0.25 * (1.0 + isEyeInWater * 8.0);
          if (isEyeInWater > 0.9){
            rayweight = clamp(rayweight, 0.0, 1.0);
          } else {
            rayweight = clamp(rayweight, 0.0, 0.5 * (1.0 - rainStrength * 0.4));
          }

         float rawVolumetric = ray * weight * timeFactor;
         float scatteredRain = rawVolumetric * rainStrength * 0.2;

         float sunLum = dot(sunCol, vec3(0.2126, 0.7152, 0.0722));
         vec3 scatterColor = mix(sunCol * 0.3, vec3(sunLum * 0.3), 0.7);

         float volLum = dot(volumeColor, vec3(0.2126, 0.7152, 0.0722));
         vec3 rainFogBase = mix(volumeColor * 0.35, vec3(volLum * 0.3), 0.6);
         rainFogBase += vec3(0.01, 0.011, 0.014) * time[5];
        
         volumeColor = mix(volumeColor, sunCol, pow(sunAngleCosine, 2.3) * 0.5 * (1 - rainStrength));

        if (isEyeInWater > 0.9) {
            vec3 finalFogCol = mix(color, volumeColor * vec3(0.72), rayweight);
            color = clamp(finalFogCol, vec3(0.0), vec3(1.0));
        } else {
            float shaftW = ray * weight * 8.5 * pow(glare, 0.5) * timeFactor;
            shaftW *= 10.0;
            shaftW *= transitionFade * 0.25 * FogStrength;
            shaftW  = clamp(shaftW, 0.0, 0.6 * (1.0 - rainStrength * 0.4));

            vec3  sunDirW = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
            float VoL = clamp(dot(normalize(worldPos), sunDirW), -1.0, 1.0);

            float gg   = shaftAnisotropy * shaftAnisotropy;
            float hg   = (1.0 - gg) / pow(1.0 + gg - 2.0 * shaftAnisotropy * VoL, 1.5);
            float hgHi = (1.0 - gg) / pow(1.0 + gg - 2.0 * shaftAnisotropy, 1.5);   // VoL = +1
            float hgLo = (1.0 - gg) / pow(1.0 + gg + 2.0 * shaftAnisotropy, 1.5);   // VoL = -1
            float forward = clamp((hg - hgLo) / (hgHi - hgLo), 0.0, 1.0);

            float sunW = ray * weight * 8.5 * forward * timeFactor;
            sunW *= 10.0 * shaftStrength;
            sunW *= transitionFade * 0.25 * FogStrength;
            sunW  = clamp(sunW, 0.0, shaftMax * (1.0 - rainStrength * 0.4));

            shaftW += sunW;

            vec3 clearCol = color + sunCol * 0.72 * shaftW;

            if (rainStrength > 0.001) {
                float mistD = 1.0 - exp(-length(worldPos.xz) * 0.0016);
                float mistH = exp(-max(worldPos.y + eyeAltitude - 70.0, 0.0) / 42.0);
                float mist = clamp(mistD * mistH, 0.0, 0.85 * (1 - rainStrength * 0.6)) * rainStrength;

                float vl = dot(volumeColor, vec3(0.2126, 0.7152, 0.0722));
                vec3 mistCol = mix(volumeColor, vec3(vl) * vec3(0.95, 0.98, 1.03), 0.8) * 1.15;

                mistCol += vec3(dot(sunCol, vec3(0.2126, 0.7152, 0.0722))) * 0.05 * ray * weight * timeFactor;

                clearCol = mix(clearCol, mistCol, mist);
            }

            color = max(clearCol, vec3(0.0));
        }
    #else
        float altitudeFog = (1.0 - (exp(-50.0 * pow(length(worldPos.xz) / pow(far, startFactor) * closeFactor * 0.125, 3.25))));
            altitudeFog *= (1.0 - altitudeFactor) * FogStrength * 1.3 * (0.50 * timeFactor);
            altitudeFog = clamp(altitudeFog, 0.0, 1.9);

        float rayweight = clamp(0.042, 0.0, 1.0);

        vec3 finalFogCol = (isEyeInWater == 1.0) ? mix(color, volumeColor * vec3(0.55), rayweight * altitudeFog) : color;
        color = clamp(finalFogCol, vec3(0.0), vec3(1.0));
    #endif

    return color;
}
