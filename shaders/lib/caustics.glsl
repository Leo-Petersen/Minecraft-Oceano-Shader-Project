	float textureNoise(vec2 coord) {
		return texture2D(noisetex, coord).r;
	}

	const float radiance = 0.3;
	const mat2 rotationMatrix = mat2(
		0.95533649, -0.29552021,
		0.29552021, 0.95533649
	);
	const mat2 rotationMatrix2 = mat2(
		0.95533649, 0.29552021,
		-0.29552021, 0.95533649
	);

	float getWaterBump(vec2 posxz, float waveM, float waveZ, float iswater) {
		float rainDrop = mix(1.0, 5.0, step(0.945, iswater));
		vec2 movement = vec2(0.0, frameTimeCounter * 0.0001 * rainDrop) * waveM * 697.0;

		vec2 coord1 = posxz * waveZ * rotationMatrix;
		coord1 *= vec2(1.5, 3.0);

		vec2 coord2 = posxz * waveZ * rotationMatrix2;
		coord2 *= vec2(2.0, 2.5);

		float noiseCoord1 = textureNoise((coord1 - movement) * 0.002);
		float noiseCoord2 = textureNoise((coord2 + movement * 0.9) * 0.003);

		#ifdef HQwater
			vec2 coord3 = posxz * waveZ * rotationMatrix2;
			coord3 *= vec2(20.0, 25.0);
			
			float noiseCoord3 = textureNoise((coord3 + movement * 5.0) * 0.0008);
			float noiseCoord4 = textureNoise((coord3 - movement * 4.5) * 0.0009);
			
			float wave = 1.0 - noiseCoord1 * 3.5;
			wave += sqrt(noiseCoord2 * 6.5) * 1.2;
			wave += sqrt(noiseCoord3 + noiseCoord4);
		#else
			float wave = 1.0 - noiseCoord1 * 3.5;
			wave += sqrt(noiseCoord2 * 6.5) * 1.2;
		#endif

		wave *= mix(0.3, 1.0, iswater) * 0.014;

		return wave;
	}

	vec3 getWaveHeight(vec2 posxz, float iswater, float randangle) {
		const float deltaPos = 0.25;
		float waveZ = mix(3.0, 0.25, iswater);
		float waveM = mix(0.0, 2.0, iswater);
		
		float h0 = getWaterBump(posxz, waveM, waveZ, iswater);
		float h1 = getWaterBump(posxz + vec2(-deltaPos, 0.0), waveM, waveZ, iswater);
		float h2 = getWaterBump(posxz + vec2(0.0, -deltaPos), waveM, waveZ, iswater);

		float xDelta = (h0 - h1) * 4.0;
		float yDelta = (h0 - h2) * 4.0;

		float xySum = xDelta + yDelta;
		vec3 wave = normalize(vec3(xDelta, yDelta, 1.0 - xySum * xySum));

		return wave;
	}

	vec3 waterCaustics(vec3 worldpos, float shadowVisibility){
		vec3 pos = worldpos + cameraPosition;
		float caustics = dot(getWaveHeight(pos.xz - pos.y, 1, 0).xyz * 2.0 - 1.0, vec3(1.0));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 12.0;
			  caustics = mix(1.0, caustics, shadowVisibility);
			  caustics = (caustics * 0.5) + 0.5;

		return vec3(caustics);
	}


	// vec3 waterCaustics(vec3 color, vec3 fpos){
	// 	vec3 wpos = toWorldSpace(gbufferModelViewInverse, fpos) + cameraPosition;

	// 	float caustics = dot(getWaveHeight(wpos.xz - wpos.y, 1.0).xyz * 2.0 - 1.0, vec3(1.88888));
	// 		  caustics = caustics * 0.1 + 0.9;
	// 		  caustics = clamp(caustics, 0.0, 1.0);
	// 		  caustics = pow(caustics, 8.0) * 30.0;
	// 		  caustics *= CausticMult * (mix(iswater * land2, 1.0 - (iswater + istransparent), isEyeInWater) * (1.0 - time[1].y * 0.5));
	// 		  caustics = mix(caustics, 1.0, 0.75 + 0.25 * (1.0 - mix(iswater, land, isEyeInWater)));

	// 	return color * caustics;
	// }
