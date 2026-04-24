	vec3 waterCaustics(vec3 worldpos, float shadowVisibility){
		vec3 pos = worldpos + cameraPosition;
		float caustics = dot(getWaveHeight(pos.xz - pos.y, 1.0, 0.0, 0.0).xyz * 2.0 - 1.0, vec3(1.0));
			  caustics = caustics * 0.1 + 0.9;
			  caustics = clamp(caustics, 0.0, 1.0);
			  caustics = pow(caustics, 8.0) * 14.0;
			  caustics = mix(1.0, caustics, shadowVisibility);
			  caustics = (caustics * 0.5) + 0.5;

		return vec3(caustics);
	}