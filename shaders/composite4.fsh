#version 130

// TO-DO: Filter with TAA to drag performance back

#define sunShafts
#define sunShaftSamples 40
#define sunShaftStrength 0.55
#define sunShaftThreshold 0.55
#define sunShaftDecay 0.965
#define sunShaftDensity 0.85

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform int worldTime;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float viewWidth, viewHeight;
uniform float rainStrength;

float ticks = worldTime;
float transitionFade = 1.0-(
    clamp(0.00333333*ticks - 40.,0.0,1.0)-
    clamp(0.00333333*ticks - 49,0.0,1.0)+
    clamp(0.005*ticks - 105.,0.0,1.0)-
    clamp(0.005*ticks - 119.,0.0,1.0)
);

void main() {

    vec3 color = texture2D(colortex0, texcoord).rgb;
    float Depth = texture2D(depthtex0, texcoord).r;

    if (Depth == 1) {
        #ifdef sunShafts
            vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
            vec2 sunScreen = clip.xy / clip.w * 0.5 + 0.5;

            vec3 sunWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
            float dayFade = smoothstep(-0.04, 0.16, sunWorld.y) * (1.0 - rainStrength * 0.7);
            float inFront = step(0.0, clip.w);

            vec2 d = abs(sunScreen - 0.5);
            float onScreen = 1.0 - smoothstep(0.5, 1.15, max(d.x, d.y));

            float gate = dayFade * inFront * onScreen;

            if (gate > 0.001) {
                vec2 delta = (texcoord - sunScreen) * (sunShaftDensity / float(sunShaftSamples));
                vec2 pos = texcoord;
                float decay = 1.0;
                vec3 shaft = vec3(0.0);

                for (int i = 0; i < sunShaftSamples; i++) {
                    pos -= delta;
                    vec2 sp = clamp(pos, 0.0, 1.0);

                    // FIX FOR BRDF BEING INCLUDED
                    // Only the sky contributes to shafts, solid geometry acts as an occluder
                    // Stops bright surfaces being smeared in
                    float skyMask = step(0.9999, texture2D(depthtex0, sp).r);

                    vec3 s = texture2D(colortex0, sp).rgb;
                    float l = dot(s, vec3(0.2126, 0.7152, 0.0722));

                    vec3 bright = s * smoothstep(sunShaftThreshold, sunShaftThreshold + 0.5, l) * skyMask;
                    shaft += bright * decay;
                    decay *= sunShaftDecay;
                }
                shaft /= float(sunShaftSamples);

                float radial = 1.0 - smoothstep(0.0, 1.1, length(texcoord - sunScreen));

                color += shaft * (sunShaftStrength * transitionFade * gate * radial);
            }
        #endif
    }

/* RENDERTARGETS: 0 */
    gl_FragData[0] = vec4(color, 1.0);
}
