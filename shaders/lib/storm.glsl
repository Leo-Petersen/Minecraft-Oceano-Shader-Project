#ifndef stormGlslIncluded
#define stormGlslIncluded

// Thunderstorm factor, 0 in clear weather and rain, 1 during a thunderstorm
uniform float thunderStrength;

#ifndef stormIntensity
#define stormIntensity 1.0
#endif

#define atmStorm (clamp(thunderStrength * rainStrength, 0.0, 1.0) * stormIntensity)

#endif
