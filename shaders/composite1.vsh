#version 120

varying vec2 texcoord;
varying vec2 lmcoord;

void main(){
	gl_Position = ftransform();
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	texcoord = gl_MultiTexCoord0.xy;	
}