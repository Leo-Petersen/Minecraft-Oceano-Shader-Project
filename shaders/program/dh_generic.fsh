#include "/lib/settings.glsl"
#include "/lib/encode.glsl"

uniform float far;
uniform vec3  cameraPosition;

varying vec3  viewNormal;
varying vec3  worldpos;
varying vec4  glcolor;

void main() {
    if (length(worldpos.xz - cameraPosition.xz) < far) discard;

    if (glcolor.a < 0.1) discard;

    vec3 beamColor = glcolor.rgb;

/* RENDERTARGETS: 0,1,2,13 */
    gl_FragData[0] = vec4(beamColor * beamBrightness, 1.0);
    gl_FragData[1] = vec4(encodeNormal(normalize(viewNormal)), 0.0, 0.0);
    gl_FragData[2] = vec4(1.0, 1.0, 0.93, 1.0);
    gl_FragData[3] = vec4(1.0, 0.0, 1.0, 0.0);
}
