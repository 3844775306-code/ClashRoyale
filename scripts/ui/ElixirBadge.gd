extends Control
# 圣水费用徽章：紫色水滴形 3D 图标 + 费用数字
var cost: int = 1
var display_text: String = ""

func set_cost(v: int) -> void:
	cost = v
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0:
		return
	var s: float = minf(size.x, size.y)
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.55
	var r: float = s * 0.30
	var pts := _drop(cx, cy, r)
	# 深色外轮廓
	var outer := _scale_pts(pts, cx, cy, 1.16)
	draw_colored_polygon(outer, Color(0.12, 0.05, 0.22, 0.95))
	# 主体（深紫 → 亮紫分层）
	draw_colored_polygon(pts, Color(0.40, 0.18, 0.72))
	var mid := _scale_pts(pts, cx, cy - r * 0.10, 0.86)
	draw_colored_polygon(mid, Color(0.55, 0.30, 0.92))
	var hi := _scale_pts(pts, cx - r * 0.16, cy - r * 0.34, 0.60)
	draw_colored_polygon(hi, Color(0.76, 0.56, 1.0, 0.92))
	# 高光点
	draw_circle(Vector2(cx - r * 0.26, cy - r * 0.52), r * 0.13, Color(1.0, 0.96, 1.0, 0.9))
	# 底部暗边
	draw_arc(Vector2(cx, cy + r * 0.05), r * 0.92, deg_to_rad(20), deg_to_rad(160), 24, Color(0.20, 0.07, 0.36, 0.55), 2.5)
	# 数字（白色带深色描边）
	var font := get_theme_default_font()
	var txt := display_text if display_text != "" else str(cost)
	var fs: int = int(s * 0.46)
	var pos := Vector2(cx - s * 0.5, cy + fs * 0.34)
	for off in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_string(font, pos + off, txt, HORIZONTAL_ALIGNMENT_CENTER, s, fs, Color(0.10, 0.04, 0.18))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, s, fs, Color(1, 1, 1))

func _drop(cx: float, cy: float, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(cx, cy - r * 1.95))
	var steps: int = 20
	for i in range(steps + 1):
		var a: float = deg_to_rad(-56.0) + deg_to_rad(292.0) * float(i) / float(steps)
		p.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return p

func _scale_pts(pts: PackedVector2Array, cx: float, cy: float, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(cx, cy) + (p - Vector2(cx, cy)) * k)
	return out
