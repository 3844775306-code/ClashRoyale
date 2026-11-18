shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// 火焰/激光光束：噪声流动 + 闪烁 + 软边，避免纯色实体光柱
uniform vec4 color : source_color = vec4(1.0, 0.40, 0.10, 1.0);
uniform float energy = 2.0;
uniform float seed = 0.0;
uniform float scroll = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float t = TIME * scroll + seed;
	float n = noise(vec2(UV.x * 9.0, UV.y * 16.0 - t * 3.2));
	float n2 = noise(vec2(UV.x * 4.0 + 2.7, UV.y * 8.0 - t * 1.6));
	float flare = noise(vec2(UV.x * 20.0, UV.y * 40.0 - t * 6.0));
	float flick = 0.82 + 0.18 * sin(TIME * 21.0 + seed * 9.0) + 0.06 * flare;
	float a = clamp(0.22 + 0.85 * n + 0.18 * flare, 0.0, 1.0) * flick;
	ALBEDO = color.rgb * (0.65 + 0.70 * n2);
	EMISSION = color.rgb * energy * (0.45 + 0.95 * n2 + 0.25 * flare) * flick;
	ALPHA = a;
}
