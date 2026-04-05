// Gust-based foliage wind
vec2 WIND_DIR = vec2(WIND_DIR_X, WIND_DIR_Z);

vec2 calcGust(vec3 worldpos) {
	float proj = dot(worldpos.xz, WIND_DIR);
	float phase = frameTimeCounter * GUST_SPEED - proj * GUST_WAVELENGTH;
	float g = sin(phase) * 0.5 + 0.5;      // 0..1
	g = pow(g, GUST_SHARPNESS);             // sharpen: long calm, brief peaks
	return vec2(GUST_FLOOR + g * (1.0 - GUST_FLOOR), phase);
}

vec3 calcFlutter(vec3 worldpos) {
	float t = frameTimeCounter * FLUTTER_SPEED;
	float s = FLUTTER_SCALE;
	float a = sin(t        + worldpos.x * s + worldpos.z * s * 0.7);
	float b = sin(t * 1.37 + worldpos.z * s - worldpos.y * s * 0.5);
	float c = sin(t * 0.83 + worldpos.y * s + worldpos.x * s * 0.6);
	return vec3(a + b * 0.5, c * 0.4, b + a * 0.5);
}

// Main displacement for leaves / foliage.
// strength = overall multiplier (leaves get more than grass tops, etc.)
// lean     = how much the thing bends into the wind during gusts (0 = none)
vec3 windDisplace(vec3 worldpos, float strength, float lean) {
	vec2  gust    = calcGust(worldpos);
	vec3  flutter = calcFlutter(worldpos);

	// Local wiggle: scales with gust so calm = subtle, gust = lively
	vec3 local = flutter * 0.035 * gust.x;

	// Directional lean: during a gust, cluster pushes in wind direction.
	float leanWave = sin(gust.y) * gust.x;
	vec3 push = vec3(WIND_DIR.x, 0.0, WIND_DIR.y) * leanWave * 0.09 * lean;

	// Slight vertical bob during gusts
	push.y += gust.x * gust.x * 0.015 * lean;

	return (local + push) * strength;
}


vec3 doVertexDisplacement(vec3 viewpos, vec3 worldpos){

	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;

	float rainBoost = 1.0 + rainStrength * 1.0;

	// Leaves: full strength, strong lean
	if ( mc_Entity.x == 11050 ) {
		viewpos.xyz += windDisplace(worldpos, 1.4 * rainBoost, 1.0);
	}

	// Vines: sway freely along the wall and outward, but never into it
	if ( mc_Entity.x == 11060 ) {
		vec3 disp = windDisplace(worldpos, 1.4 * rainBoost, 1.0);
		// gl_Normal points outward from the wall the vine is attached to.
		// Kill any displacement component going *into* the wall.
		// This should fix vines clipping into blocks its placed on
		disp -= gl_Normal * min(dot(disp, gl_Normal), 0.0);
		viewpos.xyz += disp;
	}

	// Cobwebs: tiny wiggle, no lean
	if ( mc_Entity.x == 11080 ) {
		vec3 flutter = calcFlutter(worldpos) * 0.01;
		viewpos.xyz += flutter;
	}

	// Fire: reuse flutter for flickering, only top vertices
	if ( mc_Entity.x == 51 && istopv > 0.9 ) {
		vec3 flutter = calcFlutter(worldpos);
		viewpos.xz += flutter.xz * 0.08;
		viewpos.y  += abs(flutter.y) * 0.05;
	}

	// Grass and tall foliage: bend from the base (only top vertices move).
	// Lower lean factor than leaves so grass streaks with wind rather than
	// uprooting itself.
	if ( mc_Entity.x == 11030 ||
	     mc_Entity.x == 11040 && istopv > 0.9 ||
	     mc_Entity.x == 11000 && istopv > 0.9 ||
	     mc_Entity.x == 11010 && istopv > 0.9 ||
	     mc_Entity.x == 11020 && istopv > 0.9 ) {

		viewpos.xyz += windDisplace(worldpos, 1.15 * rainBoost, 0.8);
		viewpos.y += grassHeight; // Long grass
	}

	return viewpos;
}
