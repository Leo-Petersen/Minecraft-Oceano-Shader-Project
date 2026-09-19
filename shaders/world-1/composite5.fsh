#version 130

// Just read the finished level 1 tile and add it to the scene

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex8;

#include "/lib/settings.glsl"
#include "/lib/bloom.glsl"

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

    #ifdef bloom
        vec2 buf = vec2(viewWidth, viewHeight);
        vec2 off = vec2(bloomLevelOffset(1));
        vec2 sz  = vec2(bloomLevelSize(1));
        vec2 uv  = (off + texcoord * sz) / buf;
        uv = clamp(uv, (off + 0.5) / buf, (off + sz - 0.5) / buf);
        color += textureLod(colortex8, uv, 0.0).rgb * bloomStrength;
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}
