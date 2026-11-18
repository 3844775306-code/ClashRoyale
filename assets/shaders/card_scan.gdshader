shader_type canvas_item;
// 卡牌顺时针扫描加载：未扫=深灰白，已扫=浅灰白；全部扫完才恢复彩色并隐藏射线
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.y, p.x);
	float start = -PI * 0.5;
	float delta = mod(ang - start + TAU, TAU);
	float swept = step(delta, TAU * progress);
	bool full = progress > 0.999;

	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray_unswept = mix(vec3(lum), vec3(0.56, 0.57, 0.61), 0.72);
	vec3 gray_swept = mix(vec3(lum), vec3(0.84, 0.85, 0.88), 0.82);
	vec3 gray_col = mix(gray_unswept, gray_swept, swept);
	c.rgb = full ? c.rgb : gray_col;

	if (!full) {
		float ray_angle = start + TAU * progress;
		float d = abs(mod(ang - ray_angle + PI, TAU) - PI);
		float ray = 1.0 - step(0.045, d);
		ray *= step(0.05, length(p));
		c.rgb += vec3(1.0, 0.96, 0.82) * ray * 0.85;
	}
	COLOR = c;
}
