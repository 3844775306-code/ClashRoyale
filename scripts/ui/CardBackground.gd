extends Control
# 程序化卡牌背景：渐变底 + 中心光晕 + 斜纹 + 角饰 + 底部压暗 + 星点

var accent: Color = Color(0.45, 0.55, 0.85)
var seed_value: int = 0

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return
	var top_col: Color = Color(0.16, 0.20, 0.34).lerp(accent, 0.22)
	var bot_col: Color = Color(0.06, 0.07, 0.12)
	# 垂直渐变（分段模拟）
	var bands: int = 24
	for i in range(bands):
		var t0: float = float(i) / float(bands)
		var c: Color = top_col.lerp(bot_col, t0)
		draw_rect(Rect2(0, t0 * h, w, h / float(bands) + 1.0), c)
	# 中心光晕（同心圆逼近）
	var center := Vector2(w * 0.5, h * 0.46)
	for i in range(6, 0, -1):
		var rr: float = w * 0.10 * float(i)
		draw_circle(center, rr, Color(accent.r, accent.g, accent.b, 0.035))
	# 斜纹
	var stripes: int = 7
	for i in range(stripes):
		var x: float = -h + float(i) * (w + h) / float(stripes)
		draw_line(Vector2(x, 0), Vector2(x + h * 0.55, h), Color(1, 1, 1, 0.028), 2.0)
	# 底部压暗（给名字条）
	for i in range(10):
		var t: float = float(i) / 10.0
		draw_rect(Rect2(0, h * (0.72 + 0.028 * float(i)), w, h * 0.03), Color(0, 0, 0, 0.05 + 0.03 * t))
	# 角饰（上下三角）
	var acc := Color(accent.r, accent.g, accent.b, 0.85)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.22, 0), Vector2(0, h * 0.16)]), acc)
	draw_colored_polygon(PackedVector2Array([Vector2(w, h), Vector2(w * 0.78, h), Vector2(w, h * 0.84)]), acc)
	# 星点（确定性随机）
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	for i in range(10):
		var px: float = rng.randf_range(0.08, 0.92) * w
		var py: float = rng.randf_range(0.06, 0.70) * h
		var s: float = rng.randf_range(0.8, 2.0)
		draw_circle(Vector2(px, py), s, Color(1.0, 0.97, 0.85, rng.randf_range(0.20, 0.55)))
