#version 130

// TO-DO: Filter with TAA to drag performance back

#define SUNSHAFTS 1
#define SUNSHAFT_SAMPLES 40
#define SUNSHAFT_STRENGTH 0.55
#define SUNSHAFT_THRESHOLD 0.55
#define SUNSHAFT_DECAY 0.965
#define SUNSHAFT_DENSITY 0.85

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float viewWidth, viewHeight;
uniform float rainStrength;

void main() {

    vec3 color = texture2D(colortex0, texcoord).rgb;
    float Depth = texture2D(depthtex0, texcoord).r;

    if (Depth == 1) {
        #if SUNSHAFTS == 1
            vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
            vec2 sunScreen = clip.xy / clip.w * 0.5 + 0.5;

            vec3 sunWorld = normalize(mat3(gbufferModelViewInverse) * sunPosition);
            float dayFade = smoothstep(-0.04, 0.16, sunWorld.y) * (1.0 - rainStrength * 0.7);
            float inFront = step(0.0, clip.w);

            vec2 d = abs(sunScreen - 0.5);
            float onScreen = 1.0 - smoothstep(0.5, 1.15, max(d.x, d.y));

            float gate = dayFade * inFront * onScreen;

            if (gate > 0.001) {
                vec2 delta = (texcoord - sunScreen) * (SUNSHAFT_DENSITY / float(SUNSHAFT_SAMPLES));
                vec2 pos = texcoord;
                float decay = 1.0;
                vec3 shaft = vec3(0.0);

                for (int i = 0; i < SUNSHAFT_SAMPLES; i++) {
                    pos -= delta;
                    vec3 s = texture2D(colortex0, clamp(pos, 0.0, 1.0)).rgb;
                    float l = dot(s, vec3(0.2126, 0.7152, 0.0722));

                    vec3 bright = s * smoothstep(SUNSHAFT_THRESHOLD, SUNSHAFT_THRESHOLD + 0.5, l);
                    shaft += bright * decay;
                    decay *= SUNSHAFT_DECAY;
                }
                shaft /= float(SUNSHAFT_SAMPLES);

                float radial = 1.0 - smoothstep(0.0, 1.1, length(texcoord - sunScreen));

                color += shaft * (SUNSHAFT_STRENGTH * gate * radial);
            }
        #endif
    }

/* RENDERTARGETS: 0 */
    gl_FragData[0] = vec4(color, 1.0);
}
