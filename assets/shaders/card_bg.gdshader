shader_type canvas_item;
// 卡牌创意背景 + 扫描加载（无独立射线，与卡面图共用同一条射线；未扫深灰白/已扫浅灰白，全扫完恢复彩色）
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 top_color : source_color = vec4(0.20, 0.34, 0.22, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.08, 0.13, 0.09, 1.0);
uniform vec4 accent : source_color = vec4(0.55, 0.65, 0.90, 1.0);
uniform int theme = 0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);
	float d = length((uv - vec2(0.5, 0.44)) * vec2(1.0, 1.2));
	col += accent.rgb * 0.18 * smoothstep(0.75, 0.0, d);
	float stripe = step(0.5, fract((uv.x + uv.y) * 9.0));
	col += vec3(0.05) * stripe * 0.25;
	if (theme == 1) {
		float cloud = smoothstep(0.55, 0.85, fract(uv.y * 2.0 + sin(uv.x * 8.0) * 0.15));
		col = mix(col, vec3(0.95, 0.97, 1.0), cloud * 0.22);
	} else if (theme == 2) {
		vec2 cell = floor(uv * 26.0);
		float rnd = hash(cell);
		float star = step(0.965, rnd);
		col += vec3(1.0, 0.96, 0.88) * star * (0.35 + 0.45 * hash(cell + 3.0));
		col += accent.rgb * 0.10 * smoothstep(0.6, 0.0, length(uv - vec2(0.30, 0.35)));
	} else if (theme == 3) {
		col += vec3(0.9, 0.45, 0.20) * smoothstep(0.85, 0.45, uv.y) * 0.25;
	} else {
		float g = hash(floor(uv * 40.0));
		col += vec3(0.03, 0.05, 0.02) * (g - 0.5);
	}
	col *= 1.0 - smoothstep(0.62, 1.0, uv.y) * 0.45;
	float corner = step(uv.x + uv.y, 0.16) + step(uv.x + uv.y, 1.84) * step(1.68, uv.x + uv.y);
	col = mix(col, accent.rgb, corner * 0.55);

	bool full = progress > 0.999;
	if (!full) {
		vec2 p = uv - vec2(0.5);
		float ang = atan(p.y, p.x);
		float start = -PI * 0.5;
		float delta = mod(ang - start + TAU, TAU);
		float swept = step(delta, TAU * progress);
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 gray_unswept = mix(vec3(lum), vec3(0.50, 0.51, 0.55), 0.78);
		vec3 gray_swept = mix(vec3(lum), vec3(0.76, 0.77, 0.80), 0.86);
		col = mix(gray_unswept, gray_swept, swept);
	}
	COLOR = vec4(col, 1.0);
}
