#include "/lib/settings.glsl"

uniform sampler2D colortex15;
uniform float viewWidth, viewHeight;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform mat4  gbufferModelViewInverse;
uniform vec3  sunPosition;
uniform vec3  moonPosition;

#include "/lib/time.glsl"
#include "/lib/atmosphereLUT.glsl"
#include "/lib/lightningFlash.glsl"

varying vec2  texcoord;
varying vec3  rainLight;
varying float viewDist;
varying vec4  glcolor;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor  = gl_Color;

	vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewDist = length(viewPos);

	vec3 dir  = mat3(gbufferModelViewInverse) * viewPos;
	vec3 dirH = normalize(vec3(dir.x, 0.0, dir.z) + vec3(1e-4, 0.0, 0.0));
	dirH = normalize(vec3(dirH.x, 0.15, dirH.z));

	vec3 sunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
	vec3 moonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);

	rainLight  = atmSky(colortex15, vec2(viewWidth, viewHeight), dirH, sunDir);
	rainLight  = atmSkyFinish(rainLight, dirH, sunDir, moonDir);
	rainLight  = max(rainLight, vec3(0.0));
	rainLight += lightningSky(dirH);
}
