uniform int worldTime;

float ticks = worldTime;

float atmCelRaw    = fract(ticks / 24000.0 - 0.25);
float atmCelAngle  = atmCelRaw + ((1.0 - (cos(atmCelRaw * 3.14159265) + 1.0) * 0.5) - atmCelRaw) / 3.0;
float sunElevation = cos(atmCelAngle * 6.28318531);

float tDawn = ((clamp(ticks, 22500.0, 23250.0) - 22500.0) / 750.0)
            - ((clamp(ticks, 23250.0, 24000.0) - 23250.0) / 3750.0)
            + 0.8 * (1.0 - clamp(ticks, 0.0, 3000.0) / 3000.0);

float tNoon = ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0)
            - ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0);

float tAfternoon = ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0)
                 - ((clamp(ticks, 9000.0, 12750.0) - 9000.0) / 3750.0);

float tSunset = ((clamp(ticks, 9000.0, 12750.0) - 9000.0) / 3750.0)
              - ((clamp(ticks, 12750.0, 13500.0) - 12750.0) / 750.0);

float tNight = ((clamp(ticks, 12750.0, 13500.0) - 12750.0) / 750.0)
             - ((clamp(ticks, 22500.0, 23250.0) - 22500.0) / 750.0);

float tMorning = 1.0 - (tDawn + tNoon + tAfternoon + tSunset + tNight);

float tTransition = ((clamp(ticks, 12000.0, 12750.0) - 12000.0) / 750.0)
                  - ((clamp(ticks, 23250.0, 24000.0) - 23250.0) / 750.0);

float time[7] = float[7](tDawn, tMorning, tNoon, tAfternoon, tSunset, tNight, tTransition);

#define atmSwapInner 0.03
#define atmSwapOuter 0.20

float transitionFade = smoothstep(atmSwapInner, atmSwapOuter, abs(sunElevation));
