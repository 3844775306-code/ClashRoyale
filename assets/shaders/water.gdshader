// 河水：分层流动波纹 + 浪花高光 + 粼光 + 岸边白沫
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.07, 0.26, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.20, 0.54, 0.68);
uniform vec3 foam_color : source_color = vec3(0.88, 0.97, 1.0);
uniform vec3 sparkle_color : source_color = vec3(1.0, 1.0, 0.95);

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// 两层流动波纹
	float w1 = sin(uv.x * 17.0 - t * 1.2 + sin(uv.y * 9.0 + t * 0.7) * 1.6);
	float w2 = sin(uv.x * 8.0 + t * 0.6 + uv.y * 4.0);
	float flow = w1 * 0.55 + w2 * 0.45;
	// 深浅变化
	float band = floor(clamp(flow * 0.5 + 0.5, 0.0, 1.0) * 3.0) / 3.0;
	vec3 col = mix(deep_color, shallow_color, band);
	// 浪花
	float crest = smoothstep(0.70, 1.0, flow);
	col = mix(col, foam_color, crest * 0.55);
	// 粼光
	float spark = sin(uv.x * 90.0 + uv.y * 40.0 - t * 2.5);
	spark = smoothstep(0.94, 1.0, spark) * (0.4 + 0.6 * sin(t * 1.3 + uv.x * 12.0));
	col = mix(col, sparkle_color, clamp(spark, 0.0, 1.0) * 0.18);
	// 靠岸白沫
	float edge = smoothstep(0.44, 0.5, abs(uv.y - 0.5));
	col = mix(col, foam_color, edge * 0.62);
	ALBEDO = col;
}
