extends Control

var value: float = 0.0
var max_value: float = 1.0
var fill_color: Color = Color(0.30, 0.92, 0.42)
var display_text: String = ""

func set_data(v: float, m: float, color: Color, text: String) -> void:
	value = v
	max_value = max(m, 0.001)
	fill_color = color
	display_text = text
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 2.0 or h <= 2.0:
		return
	var radius: int = int(h * 0.5)
	# 外框阴影 + 深色底
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.02, 0.02, 0.04, 0.55)
	shadow.set_corner_radius_all(radius)
	draw_style_box(shadow, Rect2(1, 2, w - 2, h - 2))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.16, 0.98)
	bg.border_color = Color(0.38, 0.32, 0.20, 0.9)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)
	draw_style_box(bg, Rect2(1, 0, w - 2, h - 1))
	# 填充（双色渐变感：上亮下暗）
	var ratio: float = clampf(value / max_value, 0.0, 1.0)
	if ratio > 0.005:
		var fw: float = maxf(2.0, (w - 4.0) * ratio)
		var top := StyleBoxFlat.new()
		top.bg_color = fill_color.lightened(0.22)
		top.set_corner_radius_all(radius)
		draw_style_box(top, Rect2(2, 2, fw, (h - 4.0) * 0.52))
		var bot := StyleBoxFlat.new()
		bot.bg_color = fill_color.darkened(0.20)
		bot.set_corner_radius_all(radius)
		draw_style_box(bot, Rect2(2, 2 + (h - 4.0) * 0.52, fw, (h - 4.0) * 0.48))
		# 顶部高光
		draw_rect(Rect2(4, 3, maxf(1.0, fw - 4), 2.0), Color(1, 1, 1, 0.38))
		# 末端高光点
		draw_circle(Vector2(minf(2 + fw - 2, w - 3), h * 0.5), maxf(1.2, h * 0.16), Color(1, 1, 1, 0.28))
	# 文字
	var font := get_theme_default_font()
	var fs: int = int(h * 0.62)
	var text_w: float = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx: float = (w - text_w) * 0.5
	var ty: float = h * 0.5 + fs * 0.34
	draw_string(font, Vector2(tx + 1, ty + 1), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(tx, ty), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.96))
