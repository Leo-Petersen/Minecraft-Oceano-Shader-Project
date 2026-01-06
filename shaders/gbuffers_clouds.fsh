#version 120
#include "/lib/settings.glsl"

#ifdef defaultClouds
    uniform sampler2D texture;
    uniform sampler2D colortex1;

    uniform vec3 skyColor;

    uniform float rainStrength;

    varying vec2 texcoord;
    varying vec4 glcolor;

    #include "/lib/time.glsl"
    #include "/lib/lightCol.glsl"
#endif

void main() {
    #ifdef defaultClouds
    	float timeFactor = 1.0 * (time[0]) +  
                           1.0 * (time[1]) +
                           1.0 * (time[2]) + 
                           1.0 * (time[3]) + 
                           1.0 * (time[4]) + 
                           2.5 * (time[5]);

        vec4 color = texture2D(texture, texcoord) * glcolor;
            color.a = 1.0;
            //color.rgb *= 1.5;
            color.rgb *= (sunlightCol * 1.5 * timeFactor);
            
    /* DRAWBUFFERS:0 */
        gl_FragData[0] = color; //gcolor
    #endif
}