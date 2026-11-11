
// TO-DO: Filter with TAA to drag performance back

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shaftSampler;
uniform int worldTime;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;

#include "/lib/sunShafts.glsl"

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

    bool pixelIsSky = (Depth == 1.0);
    #ifdef DISTANT_HORIZONS
    pixelIsSky = pixelIsSky && (texture2D(dhDepthTex0, texcoord).r >= 1.0);
    #endif
    if (pixelIsSky) {
        #ifdef sunShafts
            float gate;
            vec2 sunScreen = sunShaftScreen(gate);

            if (gate > 0.001) {
                vec3 shaft = textureLod(shaftSampler, texcoord, 0.0).rgb;
                float radial = 1.0 - smoothstep(0.0, 1.1, length(texcoord - sunScreen));

                color += shaft * (sunShaftStrength * transitionFade * gate * radial);
            }
        #endif
    }

/* RENDERTARGETS: 0 */
    gl_FragData[0] = vec4(color, 1.0);
}
