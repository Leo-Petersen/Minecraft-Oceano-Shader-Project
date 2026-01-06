uniform int worldTime;

float ticks = worldTime;

float time[7] = float[7](((clamp(ticks, 21000.0, 24000.0) - 21000.0) / 3000.0) + (1.0 - (clamp(ticks, 0.0, 3000.0) / 3000.0)),          // Dusk
                          (clamp(ticks, 0.0, 3000.0) / 3000.0) - ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0),                    // Morning
                          ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0) - ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0),      // Noon
                          ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0) - ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0),     // Afternoon
                          ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(ticks, 12000.0, 15000.0) - 12000.0) / 3000.0),  // Sunset
                          ((clamp(ticks, 12000.0, 15000.0) - 12000.0) / 3000.0) - ((clamp(ticks, 21000.0, 24000.0) - 21000.0) / 3000.0),// Night
                          ((clamp(ticks, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(ticks, 23250.0, 24000.0) - 23250.0) / 750.0)); // Transition

float transitionFade = 1.0-(
    clamp(0.00333333*ticks - 40.,0.0,1.0)-
    clamp(0.00333333*ticks - 49,0.0,1.0)+
    clamp(0.005*ticks - 105.,0.0,1.0)-
    clamp(0.005*ticks - 119.,0.0,1.0)
);

