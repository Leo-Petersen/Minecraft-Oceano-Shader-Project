

float pi2wt = 3.14159 * 2.0 * (frameTimeCounter * 24.0);

vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
	vec3 ret;
	float magnitude,d0,d1,d2,d3;

	magnitude = sin(pi2wt*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;

	d0 = sin(pi2wt*f0);
	d1 = sin(pi2wt*f1);
	d2 = sin(pi2wt*f2);

	ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
	ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
	ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;

	return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
return move1+move2;
}

vec3 doVertexDisplacement(vec3 viewpos, vec3 worldpos){
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;

	float wavyMult = 1.0;
			
	vec3 waving1 = calcMove(worldpos.xyz, 0.0041, 0.0070, 0.0044, 0.0038, 0.0063, 0.0000, vec3(0.8,0.0,0.8), vec3(0.8,0.0,0.48)) * wavyMult;
			
	vec3 waving2 = calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5)) * wavyMult;

	//Leaves and vines//
	if ( mc_Entity.x == 11050 ||
		 mc_Entity.x == 11060 )	{
		viewpos.xyz += waving1 * 1.4 * (1 + rainStrength * 1.0);
	}
	//Cobwebs//
	if ( mc_Entity.x == 11080 )  {
		viewpos.xyz += waving2 * 0.1;
	}
	//Fire//
	if ( mc_Entity.x == 12153 && istopv > 0.9 )  {
		viewpos.xyz += waving2 * 2;
	}
	//Grass and Foliage//
	if ( mc_Entity.x == 11030 || 
		 mc_Entity.x == 11040  && istopv > 0.9 || 
		 mc_Entity.x == 11000  && istopv > 0.9 || 
		 mc_Entity.x == 11010 && istopv > 0.9|| 
		 mc_Entity.x == 11020 && istopv > 0.9) {
			
		viewpos.xyz += waving2 * 1.0 * (1 + rainStrength * 1);
		//viewpos.x -= (0.27 * rainStrength);
		viewpos.y += grassHeight; //Long grass lol
	}

	return viewpos;
}
