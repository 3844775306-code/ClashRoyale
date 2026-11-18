extends Control
# 圣水条：占 80% 屏宽，圆角长条 + 10 格分割 + 渐变能量 + 流光 + 末端高亮
var value: float = 0.0
var max_value: float = 10.0
var highlight_cost: int = 0
var _t: float = 0.0
var overflowing: bool = false

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 6.0:
		return
	var r: float = h * 0.5
	# 深紫轨道
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.05, 0.18, 0.97)
	track.border_color = Color(0.70, 0.50, 1.0, 0.9)
	track.set_border_width_all(2)
	track.set_corner_radius_all(int(r))
	draw_style_box(track, Rect2(0, 0, w, h))
	# 格子分割
	var cells: int = maxi(1, int(round(max_value)))
	for i in range(1, cells):
		var x: float = w * float(i) / float(cells)
		draw_line(Vector2(x, h * 0.22), Vector2(x, h * 0.80), Color(0.04, 0.02, 0.10, 0.75), 2.0)
	var fx: float = clampf(value / max_value, 0.0, 1.0) * w
	if fx > 1.0:
		var base_col := Color(0.40, 0.18, 0.72)
		var round_right: bool = fx >= w - 0.8
		if round_right:
			draw_rect(Rect2(r, 0.0, maxf(w - 2.0 * r, 1.0), h), base_col)
			draw_circle(Vector2(r, h * 0.5), r, base_col)
			draw_circle(Vector2(w - r, h * 0.5), r, base_col)
		elif fx > r * 2.0:
			draw_rect(Rect2(r, 0.0, maxf(fx - r, 1.0), h), base_col)
			draw_circle(Vector2(r, h * 0.5), r, base_col)
		else:
			draw_rect(Rect2(0.0, 0.0, maxf(fx, 1.0), h), base_col)
		# 垂直渐变（多层半透明紫）
		if fx > h:
			for k in range(4):
				var t0: float = float(k) / 4.0
				var col: Color = Color(0.80, 0.60, 1.0).lerp(Color(0.30, 0.10, 0.55), t0)
				col.a = 0.20
				draw_rect(Rect2(r * 0.7, h * (0.10 + t0 * 0.62), maxf(fx - r * 1.4, 1.0), h * 0.17), col)
		# 顶部光泽 / 底部暗边（纯矩形，避免多边形三角化问题）
		if fx > 6.0:
			draw_rect(Rect2(2.0, 2.0, fx - 4.0, h * 0.24), Color(0.86, 0.72, 1.0, 0.30))
			draw_rect(Rect2(2.0, h * 0.72, fx - 4.0, h * 0.24), Color(0.16, 0.05, 0.30, 0.28))
		# 流光
		var band_x: float = fmod(_t * 55.0, w + 80.0) - 40.0
		for k in range(3):
			var bx: float = band_x + float(k) * 34.0
			var x0: float = clampf(bx - 8.0, 1.0, fx - 1.0)
			var x1: float = clampf(bx + 8.0, 1.0, fx - 1.0)
			if x1 - x0 > 3.0 and bx > 0.0 and bx < fx:
				draw_rect(Rect2(x0, 2.0, x1 - x0, h - 4.0), Color(0.95, 0.88, 1.0, 0.10))

		# 末端亮边
		if fx < w - 1.0:
			draw_line(Vector2(fx, 3.0), Vector2(fx, h - 3.0), Color(0.90, 0.78, 1.0, 0.9), 2.0)
			draw_circle(Vector2(fx, h * 0.5), 5.0, Color(0.80, 0.62, 1.0, 0.45))	# 溢出效果：满圣水时紫色脉冲光 + 顶部溢出气泡
	if overflowing:
		var pulse: float = 0.55 + 0.45 * sin(_t * 6.5)
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.border_color = Color(0.86, 0.68, 1.0, 0.35 + 0.45 * pulse)
		glow.set_border_width_all(3)
		glow.set_corner_radius_all(int(r) + 2)
		draw_style_box(glow, Rect2(-3, -3, w + 6, h + 6))
		for i in range(3):
			var ph: float = fmod(_t * 0.9 + float(i) * 0.36, 1.0)
			var dx: float = w - 26.0 - float(i) * 14.0 + sin(_t * 3.0 + float(i)) * 4.0
			var dy: float = h * 0.30 - ph * h * 0.8
			var col: Color = Color(0.86, 0.68, 1.0, 0.65 * (1.0 - ph))
			_draw_drop(Vector2(dx, dy), h * 0.16, col)
	# 右侧圣水水滴图标
	_draw_drop(Vector2(h * 0.85, h * 0.5), h * 0.30, Color(0.82, 0.64, 1.0))
	# 选中卡费用高亮
	if highlight_cost > 0 and highlight_cost <= int(max_value):
		var hx: float = w * float(highlight_cost) / float(maxi(1, int(max_value)))
		draw_rect(Rect2(2.0, 1.5, maxf(hx - 3.0, 0.0), h - 3.0), Color(0.86, 0.76, 1.0, 0.16))
		draw_line(Vector2(hx, 2.0), Vector2(hx, h - 2.0), Color(0.90, 0.80, 1.0, 0.85), 1.5)
	# 数值
	var font := get_theme_default_font()
	var txt: String = "%.1f" % value
	draw_string(font, Vector2(w - 42.0, h * 0.5 + 6.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 16, Color(0.92, 0.86, 1.0, 0.95))

func _draw_drop(center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(center.x, center.y - r * 1.9))
	var steps: int = 18
	for i in range(steps + 1):
		var a: float = deg_to_rad(-56.0) + deg_to_rad(292.0) * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	var outer := PackedVector2Array()
	for p in pts:
		outer.append(center + (p - center) * 1.15)
	draw_colored_polygon(outer, Color(0.16, 0.06, 0.30, 0.9))
	draw_colored_polygon(pts, col)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(center + (p - center) * 0.62 + Vector2(-r * 0.12, -r * 0.18))
	draw_colored_polygon(inner, col.lightened(0.35))
	draw_circle(center + Vector2(-r * 0.22, -r * 0.38), r * 0.15, Color(1, 1, 1, 0.85))
func _fill_poly(rect: Rect2, radius: float, round_right: bool) -> PackedVector2Array:
	var rad: float = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var p := PackedVector2Array()
	var steps: int = 8
	for i in range(steps + 1):
		var a: float = PI * 0.5 + PI * 0.5 * float(i) / float(steps)
		p.append(Vector2(rect.position.x + rad + cos(a) * rad, rect.position.y + rad + sin(a) * rad))
	p.append(Vector2(rect.end.x - (rad if round_right else 0.0), rect.position.y))
	if round_right:
		for i in range(steps + 1):
			var a2: float = -PI * 0.5 + PI * 0.5 * float(i) / float(steps)
			p.append(Vector2(rect.end.x - rad + cos(a2) * rad, rect.position.y + rad + sin(a2) * rad))
		p.append(Vector2(rect.end.x, rect.end.y - rad))
		for i in range(steps + 1):
			var a3: float = PI * 0.5 * float(i) / float(steps)
			p.append(Vector2(rect.end.x - rad + cos(a3) * rad, rect.end.y - rad + sin(a3) * rad))
	else:
		p.append(Vector2(rect.end.x, rect.end.y))
	p.append(Vector2(rect.position.x + rad, rect.end.y))
	for i in range(steps + 1):
		var a4: float = PI * 0.5 + PI * 0.5 * float(i) / float(steps)
		p.append(Vector2(rect.position.x + rad + cos(a4) * rad, rect.position.y + rect.size.y - rad + sin(a4) * rad))
	return p
