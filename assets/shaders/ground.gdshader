// 战场草地：程序噪声贴图 + 明暗交替棋盘格 + 1 米格线
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 arena_cells = vec2(18.0, 31.0);
uniform float uv_tiles = 9.0;
uniform vec3 line_color : source_color = vec3(0.10, 0.17, 0.08);
uniform float line_strength = 0.26;
uniform float checker_strength = 0.10;
// 沙色地块（与 grass.png 参考一致，按 1 米单元格改色，不额外叠加网格）
uniform vec3 path_color : source_color = vec3(0.72, 0.56, 0.34);
uniform vec2 path_origin = vec2(-9.0, -15.5);
uniform vec2 path_size = vec2(18.0, 31.0);
uniform float lane_x1 = -5.5;
uniform float lane_x2 = 5.5;
uniform float pad_z_player = 9.0;
uniform float pad_z_enemy = -9.0;
uniform float king_z_player = 12.5;
uniform float king_z_enemy = -12.5;

float band(float v, float lo, float hi) {
	return step(lo, v) * step(v, hi);
}

float path_mask(vec2 w) {
	vec2 c = floor(w) + 0.5;   // 单元格中心（世界坐标，米）
	float m = 0.0;
	// 公主/王子塔：中心周围 9 格（3x3）
	float padP = step(abs(c.x - lane_x1), 1.01) + step(abs(c.x - lane_x2), 1.01);
	padP *= step(abs(c.y - pad_z_player), 1.01);
	m = max(m, padP);
	float padE = step(abs(c.x - lane_x1), 1.01) + step(abs(c.x - lane_x2), 1.01);
	padE *= step(abs(c.y - pad_z_enemy), 1.01);
	m = max(m, padE);
	// 国王塔：中心周围 16 格（4x4，中心在 12/13 格分界 z=±12.5）
	m = max(m, step(abs(c.x), 2.01) * step(abs(c.y - king_z_player), 2.01));
	m = max(m, step(abs(c.x), 2.01) * step(abs(c.y - king_z_enemy), 2.01));
	// 1 格宽兵线：桥头 → 王塔排（第 12 格）
	m = max(m, step(abs(c.x - lane_x1), 0.51) * step(1.5, c.y) * step(c.y, 12.51));
	m = max(m, step(abs(c.x - lane_x2), 0.51) * step(1.5, c.y) * step(c.y, 12.51));
	m = max(m, step(abs(c.x - lane_x1), 0.51) * step(c.y, -1.49) * step(-12.51, c.y));
	m = max(m, step(abs(c.x - lane_x2), 0.51) * step(c.y, -1.49) * step(-12.51, c.y));
	// 横带：离桥第 12 格，1 格高，连接两条兵线
	m = max(m, step(abs(c.y - 12.5), 0.01) * step(abs(c.x), 5.51));
	m = max(m, step(abs(c.y + 12.5), 0.01) * step(abs(c.x), 5.51));
	return clamp(m, 0.0, 1.0);
}
void fragment() {
	vec3 col = texture(grass_tex, UV * uv_tiles).rgb;
	vec2 cell = UV * arena_cells;
	vec2 cid = floor(cell);
	// 明暗交替棋盘（1 米一格）
	float parity = mod(cid.x + cid.y, 2.0);
	col *= 1.0 + (parity * 2.0 - 1.0) * checker_strength;
	// 沙色地块：直接改格子颜色
	vec2 wpos2 = path_origin + UV * path_size;
	float pm = path_mask(wpos2);
	vec3 tan_col = path_color * (0.82 + 0.22 * col.r);
	col = mix(col, tan_col, pm);
	// 最后一排：仅国王塔正后方 6 格可用，其余格子改为背景色
	float last_row = max(step(cid.y, 0.5), step(30.5, cid.y));
	float back_usable = step(5.5, cid.x) * step(cid.x, 11.5);
	col = mix(col, vec3(0.20, 0.27, 0.16), last_row * (1.0 - back_usable) * 0.94);
	// 柔和格线
	vec2 dist = 0.5 - abs(fract(cell) - 0.5);
	vec2 w = fwidth(cell) * 1.2;
	float line = 0.0;
	line = max(line, 1.0 - smoothstep(0.0, 0.045 + w.x, dist.x));
	line = max(line, 1.0 - smoothstep(0.0, 0.045 + w.y, dist.y));
	col = mix(col, line_color, clamp(line, 0.0, 1.0) * line_strength);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
