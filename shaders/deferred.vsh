#version 120

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 upPosition;

attribute vec4 mc_Entity;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 upVec;
varying vec3 Normal;
varying vec4 glcolor;

void main() {

	upVec = upPosition * 0.01;

	glcolor = gl_Color;

	gl_Position = ftransform();
	Normal = normalize(gl_NormalMatrix*gl_Normal);

	texcoord.xy = gl_MultiTexCoord0.st;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}