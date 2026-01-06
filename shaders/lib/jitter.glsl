uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;

//Jitter offset from Chocapic13
const vec2 jitter[8] = vec2[8](vec2( 0.5, -0.333333),
                               vec2(-0.25, 0.333333),
                               vec2( 0.75, 0.111111),
                               vec2( 0.125, -0.777778),
                               vec2(-0.375, 0.555556),
                               vec2( 0.625, -0.111111),
                               vec2(-0.125, 0.777778),
                               vec2( 0.875, -0.555556));
							   
vec2 taaJitter(vec2 coord, float w){
	return jitter[int(mod(frameCounter,8))]*(w/vec2(viewWidth,viewHeight)) + coord;
}