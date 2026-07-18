uniform int worldTime;

float ticks = worldTime;

float time[7] = float[7](((clamp(ticks, 22500.0, 24000.0) - 22500.0) / 1500.0) + (1.0 - (clamp(ticks, 0.0, 3000.0) / 3000.0)),          // Dusk
                          (clamp(ticks, 0.0, 3000.0) / 3000.0) - ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0),                    // Morning
                          ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0) - ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0),      // Noon
                          ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0) - ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0),     // Afternoon
                          ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(ticks, 12000.0, 13600.0) - 12000.0) / 1600.0),  // Sunset
                          ((clamp(ticks, 12000.0, 13600.0) - 12000.0) / 1600.0) - ((clamp(ticks, 22500.0, 24000.0) - 22500.0) / 1500.0),// Night
                          ((clamp(ticks, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(ticks, 23250.0, 24000.0) - 23250.0) / 750.0)); // Transition

float t1 = clamp((ticks - 12500.0) / 100.0, 0.0, 1.0)
         - clamp((ticks - 13500.0) / 100.0, 0.0, 1.0);

float t2 = clamp((ticks - 22400.0) / 100.0, 0.0, 1.0)
         - clamp((ticks - 23400.0) / 100.0, 0.0, 1.0);

float transitionFade = 1.0 - clamp(t1 + t2, 0.0, 1.0);