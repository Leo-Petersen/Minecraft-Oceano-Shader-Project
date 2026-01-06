/*
The code within this .glsl file is entirely written and owned by DeDelner.
Permission to use this code was given by DeDelner, all rights belong to them.
Find their project here:
https://www.curseforge.com/minecraft/customization/projectluma
*/

mat2 rotate2d(float angle) {
  return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

vec2 projectSky(vec3 dir, float rotation) {

  const ivec2 resolution     = ivec2(8192, 3072);
  const vec2  tileSize       = resolution / vec2(4, 3);
  const vec2  tileSizeDivide = (0.5 * tileSize) - 1.5;

  dir.xz *= rotate2d(-rotation);
  dir.xyz = vec3(dir.z, -dir.y, -dir.x);

  vec2 coord = vec2(0.0);
  if (abs(dir.y) > abs(dir.x) && abs(dir.y) > abs(dir.z)) {
    dir /= abs(dir.y);
    coord.x = dir.x * tileSizeDivide.x + tileSize.x * 1.5;
    coord.y = -(dir.y < 0.0 ? 1 : -1) * dir.z * tileSizeDivide.y + tileSize.y * (dir.y < 0.0 ? 0.5 : 2.5);
  } else if (abs(dir.x) > abs(dir.y) && abs(dir.x) > abs(dir.z)) {
    dir /= abs(dir.x);
    coord.x = (dir.x < 0.0 ? -1 : 1) * dir.z * tileSizeDivide.x + tileSize.x * (dir.x < 0.0 ? 0.5 : 2.5);
    coord.y = dir.y * tileSizeDivide.y + tileSize.y * 1.5;
  } else {
    dir /= abs(dir.z);
    coord.x = (dir.z < 0.0 ? 1 : -1) * dir.x * tileSizeDivide.x + tileSize.x * (dir.z < 0.0 ? 1.5 : 3.5);
    coord.y = dir.y * tileSizeDivide.y + tileSize.y * 1.5;
  }

  return coord / resolution;

}

vec3 getSkyTextureFromSequence(vec3 pos) {
  vec4 worldPos = gbufferModelViewInverse * vec4(pos.xyz, 1.0);

  float rotation = (clamp(worldTime > 21000.0? 0.0 : worldTime, 0.0, 12000.0) / 24000.0) * 5.0;

	// config = vec4(x offset, y offset, time, rotation offset)
  vec4 config[2] = vec4[2](vec4(0.0), vec4(0.0));

  vec3 first = vec3(0.0);
  vec3 second = vec3(0.0);
  vec3 rain = vec3(0.0);
  vec3 stars = vec3(0.0);

  if (time[0] > 0.01) {
    config[0] = vec4(0.0, 0.0, time[0], 0.0);
  } else if (time[2] > 0.01) {
    config[0] = vec4(0.5, 0.0, time[2], 0.0);
  } else if (time[4] > 0.01) {
    config[0] = vec4(0.75, 0.0, time[4], 0.55);
  }

  if (time[1] > 0.01) {
    config[1] = vec4(0.25, 0.0, time[1], 0.0);
  } else if (time[3] > 0.01) {
    config[1] = vec4(0.25, 0.0, time[3], 0.0);
  } else if (time[5] > 0.01) {
    config[1] = vec4(0.0, 0.5, time[5] * mix(0.2 * (2.2 + screenBrightness), 1.0, nightVision), 0.0);
  }

  if (rainStrength < 1.0) {
    first = texture2D(colortex10, projectSky(worldPos.xyz, rotation + config[0].w) * vec2(0.25, 0.5) + config[0].xy).rgb * config[0].z * (1.0 - rainStrength);
    second = texture2D(colortex10, projectSky(worldPos.xyz, rotation + config[1].w) * vec2(0.25, 0.5) + config[1].xy).rgb * config[1].z * (1.0 - rainStrength);
    if (time[5] > 0.0) stars = texture2D(colortex10, projectSky(worldPos.xyz, worldTime / 12000.0) * vec2(0.25, 0.5) + vec2(0.25, 0.5)).rgb * time[5] * (1.0 - rainStrength) * 3.0;
  }

  if (rainStrength > 0.0) {
    if (time[5] > 0.0) rain = texture2D(colortex10, projectSky(worldPos.xyz, worldTime / 12000.0) * vec2(0.25, 0.5) + vec2(0.0, 0.5)).rgb * time[5] * mix(0.1 * (1.0 + screenBrightness), 1.0, nightVision) * rainStrength * 3.6;
    rain += texture2D(colortex10, projectSky(worldPos.xyz, worldTime / 3000.0) * vec2(0.25, 0.5) + vec2(0.5, 0.5)).rgb * rainStrength * mix(1.0, 0.04 + screenBrightness * 0.04, time[5] * (1.0 - nightVision));
  }

	return first + second + rain + (stars * 0.2 + max(stars - 0.1, 0.0));

}

vec3 toNDC(vec3 pos){
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = pos * 2. - 1.;
    vec4 fragpos = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragpos.xyz / fragpos.w;
}
