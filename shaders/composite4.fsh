#version 130
#extension GL_ARB_shader_texture_lod : enable

varying vec2 texcoord;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex13;
uniform sampler2D depthtex0;

#include "/lib/settings.glsl"

#ifdef BLOOM
    const bool colortex0MipmapEnabled = true;

    float bayer2(vec2 a) {
        a = floor(a);
        return fract(dot(a, vec2(0.5, a.y * 0.75)));
    }

    #define bayer4(a)   (bayer2(0.5 * (a)) * 0.25 + bayer2(a))
    #define bayer8(a)   (bayer4(0.5 * (a)) * 0.25 + bayer2(a))
    #define bayer16(a)  (bayer8(0.5 * (a)) * 0.25 + bayer2(a))
    #define bayer32(a)  (bayer16(0.5 * (a)) * 0.25 + bayer2(a))
    #define bayer64(a)  (bayer32(0.5 * (a)) * 0.25 + bayer2(a))

    float dither64 = bayer64(gl_FragCoord.xy);

    float ph = 0.8 / min(360.0, viewHeight);
    float pw = ph / aspectRatio;

    float weight[6] = float[6](0.0556, 0.1667, 0.2777, 0.2777, 0.1667, 0.0556);

vec3 BloomTile(float lod, vec2 coord, vec2 offset) {
    vec3 bloom = vec3(0.0);
    float scale = exp2(lod);
    coord = (coord - offset) * scale;
    float padding = 0.5 + 0.005 * scale;

    if (abs(coord.x - 0.5) < padding && abs(coord.y - 0.5) < padding) {
        for (int i = 0; i < 6; i++) {
            for (int j = 0; j < 6; j++) {
                float wg = weight[i] * weight[j];
                vec2 pixelOffset = vec2((float(i) - 2.5) * pw, (float(j) - 2.5) * ph);
                vec2 sampleCoord = coord + pixelOffset * scale;
                vec3 sampleColor = texture2D(colortex0, sampleCoord).rgb;

                float brightness = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
                
                // Original non-emissive behavior
                float brightnessWeight = smoothstep(0.6, 1.0, brightness);
                
                // Only check emission for actual terrain
                float depth = texture2D(depthtex0, sampleCoord).r;
                if (depth < 1.0) {
                    float emission = texture2D(colortex13, sampleCoord).r;
                    
                    // Override only for emissive pixels
                    if (emission > 0.01) {
                        float emissiveThreshold = 0.6 - emission * 0.4;
                        brightnessWeight = smoothstep(emissiveThreshold, 1.0, brightness);
                        brightnessWeight *= 1.0 + emission * 5.0;
                    }
                }
                
                bloom += sampleColor * wg * brightnessWeight;
            }
        }
    }

    return pow(bloom / 32.0, vec3(0.25));
}
#endif

void main() {

    #ifdef BLOOM
        vec2 bloomCoord = texcoord * viewHeight * 0.8 / min(360.0, viewHeight);
        vec3 blur = BloomTile(1.0, bloomCoord, vec2(0.0, 0.0));
        blur += BloomTile(2.0, bloomCoord, vec2(0.51, 0.0));
        blur += BloomTile(3.0, bloomCoord, vec2(0.51, 0.26));
        blur += BloomTile(4.0, bloomCoord, vec2(0.645, 0.26));
        blur += BloomTile(5.0, bloomCoord, vec2(0.7175, 0.26));
        blur += BloomTile(6.0, bloomCoord, vec2(0.645, 0.3325));
        blur += BloomTile(7.0, bloomCoord, vec2(0.670625, 0.3325));

        // Apply dithering
        blur = clamp(blur + (dither64 - 0.5) / 384.0, vec3(0.0), vec3(1.0));

        /* DRAWBUFFERS:8 */
        gl_FragData[0] = vec4(blur, 1.0);
    #else
        /* DRAWBUFFERS:8 */
        gl_FragData[0] = vec4(vec3(0.0), 1.0);
    #endif
}