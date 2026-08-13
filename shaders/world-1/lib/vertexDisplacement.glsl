vec2 windDirection = vec2(windDirectionX, windDirectionY);

vec2 calcGust(vec3 worldpos) {
	float proj = dot(worldpos.xz, windDirection);
	float phase = frameTimeCounter * foliageWindSpeed - proj * foliageWindWaveLength;
	float g = sin(phase) * 0.5 + 0.5;
	g = pow(g, foliageWindSharpness); // long calm/brief peaks
	return vec2(foliageWindFloor + g * (1.0 - foliageWindFloor), phase);
}

vec3 calcFlutter(vec3 worldpos) {
	float t = frameTimeCounter * foliageFlutterSpeed;
	float s = foliageFlutterScale;
	float a = sin(t        + worldpos.x * s + worldpos.z * s * 0.7);
	float b = sin(t * 1.37 + worldpos.z * s - worldpos.y * s * 0.5);
	float c = sin(t * 0.83 + worldpos.y * s + worldpos.x * s * 0.6);
	return vec3(a + b * 0.5, c * 0.4, b + a * 0.5);
}

vec3 windDisplace(vec3 worldpos, float strength, float lean) {
	vec2  gust    = calcGust(worldpos);
	vec3  flutter = calcFlutter(worldpos);

	vec3 local = flutter * 0.035 * gust.x;

	float leanWave = sin(gust.y) * gust.x;
	vec3 push = vec3(windDirection.x, 0.0, windDirection.y) * leanWave * 0.09 * lean;

	push.y += gust.x * gust.x * 0.015 * lean;

	return (local + push) * strength;
}


vec3 doVertexDisplacement(vec3 viewpos, vec3 worldpos){

	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;

	float rainBoost = 1.0 + rainStrength * 1.0;

	if ( mc_Entity.x == 11050 ) {
		viewpos.xyz += windDisplace(worldpos, 1.4 * rainBoost, 1.0);
	}

	if ( mc_Entity.x == 11060 ) {
		vec3 disp = windDisplace(worldpos, 1.4 * rainBoost, 1.0);
		// this should fix vines clipping into blocks they are placed on
		disp -= gl_Normal * min(dot(disp, gl_Normal), 0.0);
		viewpos.xyz += disp;
	}

	if ( mc_Entity.x == 11080 ) {
		vec3 flutter = calcFlutter(worldpos) * 0.01;
		viewpos.xyz += flutter;
	}

	if ( mc_Entity.x == 51 && istopv > 0.9 ) {
		vec3 flutter = calcFlutter(worldpos);
		viewpos.xz += flutter.xz * 0.08;
		viewpos.y  += abs(flutter.y) * 0.05;
	}

	if ( mc_Entity.x == 11030 ||
	     mc_Entity.x == 11040 && istopv > 0.9 ||
	     mc_Entity.x == 11000 && istopv > 0.9 ||
	     mc_Entity.x == 11010 && istopv > 0.9 ||
	     mc_Entity.x == 11020 && istopv > 0.9 ) {

		viewpos.xyz += windDisplace(worldpos, 1.15 * rainBoost, 0.8);
		viewpos.y += grassHeight; // Long grass, misc/meme option
	}

	return viewpos;
}
