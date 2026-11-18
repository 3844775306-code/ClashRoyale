# assets/ui/menu/MenuBackdrop.gd
# 主菜单氛围背景：夜空渐变 + 皇家光晕 + 透视木地板竞技场 + 漂浮金尘 + 暗角
# 完全程序化绘制，不依赖位图素材；每帧重绘约 200 个图元，桌面/移动均可接受。
extends Control

const INK := Color(0.016, 0.024, 0.055)
const SKY_MID := Color(0.045, 0.075, 0.17)
const SKY_LOW := Color(0.075, 0.11, 0.24)
const HORIZON := Color(0.12, 0.16, 0.32)
const WOOD := Color(0.085, 0.058, 0.038)
const WOOD_ALT := Color(0.115, 0.078, 0.050)
const WOOD_DARK := Color(0.045, 0.028, 0.018)
const STONE := Color(0.15, 0.20, 0.31)
const GOLD := Color(0.94, 0.76, 0.36)
const ROYAL := Color(0.25, 0.42, 0.95)
const EMBER := Color(1.0, 0.58, 0.30)

var with_floor := true
var _t := 0.0
var _glow_tex: Texture2D
var _vignette_tex: Texture2D
var _dust: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_tex = _radial_texture(
		[Color(1.0, 0.82, 0.42, 0.55), Color(1.0, 0.62, 0.22, 0.16), Color(1.0, 0.45, 0.10, 0.0)],
		[0.0, 0.45, 1.0], 512)
	_vignette_tex = _radial_texture(
		[Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.78)],
		[0.0, 0.60, 1.0], 512)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	for i in 78:
		_dust.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(0.9, 2.8),
			"speed": rng.randf_range(0.008, 0.032),
			"phase": rng.randf_range(0.0, TAU),
			"warm": rng.randf() < 0.68,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 4.0 or sz.y < 4.0:
		return
	_draw_sky(sz)
	_draw_beams(sz)
	_draw_corners(sz)
	_draw_glows(sz)
	if with_floor:
		_draw_floor(sz)
	_draw_dust(sz)
	_draw_vignette(sz)


# ---------------- 四角卷草装饰 ----------------
func _draw_corners(sz: Vector2) -> void:
	var col := Color(GOLD.r, GOLD.g, GOLD.b, 0.14)
	var col2 := Color(GOLD.r, GOLD.g, GOLD.b, 0.07)
	var m := 26.0
	var a := 150.0
	# 左上
	draw_line(Vector2(m, m + a), Vector2(m, m), col, 2.0, true)
	draw_line(Vector2(m, m), Vector2(m + a, m), col, 2.0, true)
	draw_arc(Vector2(m + 34, m + 34), 20.0, 0.0, PI * 0.5, 14, col2, 2.0, true)
	draw_arc(Vector2(m + 34, m + 34), 30.0, 0.0, PI * 0.5, 18, col2, 1.2, true)
	# 右上
	draw_line(Vector2(sz.x - m, m + a), Vector2(sz.x - m, m), col, 2.0, true)
	draw_line(Vector2(sz.x - m, m), Vector2(sz.x - m - a, m), col, 2.0, true)
	draw_arc(Vector2(sz.x - m - 34, m + 34), 20.0, PI * 0.5, PI, 14, col2, 2.0, true)
	draw_arc(Vector2(sz.x - m - 34, m + 34), 30.0, PI * 0.5, PI, 18, col2, 1.2, true)
	# 左下
	draw_line(Vector2(m, sz.y - m - a), Vector2(m, sz.y - m), col, 2.0, true)
	draw_line(Vector2(m, sz.y - m), Vector2(m + a, sz.y - m), col, 2.0, true)
	draw_arc(Vector2(m + 34, sz.y - m - 34), 20.0, PI * 1.5, TAU, 14, col2, 2.0, true)
	# 右下
	draw_line(Vector2(sz.x - m, sz.y - m - a), Vector2(sz.x - m, sz.y - m), col, 2.0, true)
	draw_line(Vector2(sz.x - m, sz.y - m), Vector2(sz.x - m - a, sz.y - m), col, 2.0, true)
	draw_arc(Vector2(sz.x - m - 34, sz.y - m - 34), 20.0, PI, PI * 1.5, 14, col2, 2.0, true)


# ---------------- 夜空 ----------------
func _draw_sky(sz: Vector2) -> void:
	var strips := 72
	for i in strips:
		var t0 := float(i) / float(strips)
		var t1 := float(i + 1) / float(strips)
		var col: Color
		if t0 < 0.55:
			col = INK.lerp(SKY_MID, t0 / 0.55)
		else:
			col = SKY_MID.lerp(SKY_LOW, (t0 - 0.55) / 0.45)
		var y0 := sz.y * t0
		var y1 := sz.y * t1 + 1.0
		draw_rect(Rect2(0, y0, sz.x, y1 - y0), col)
	# 地平线暖色过渡
	var hy := sz.y * 0.70
	var g := 26
	for i in g:
		var a := (1.0 - float(i) / float(g)) * 0.10
		draw_rect(Rect2(0, hy - float(i) * 3.0, sz.x, 3.2), Color(0.95, 0.62, 0.28, a))


func _draw_beams(sz: Vector2) -> void:
	# 左上 / 右上两束斜射光，营造舞台感
	var top := Color(1.0, 0.80, 0.42, 0.055)
	var none := Color(1.0, 0.80, 0.42, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(-sz.x * 0.05, 0), Vector2(sz.x * 0.34, 0),
			Vector2(sz.x * 0.62, sz.y * 0.55), Vector2(sz.x * 0.10, sz.y * 0.62)]),
		PackedColorArray([top, top, none, none]))
	draw_polygon(
		PackedVector2Array([Vector2(sz.x * 1.05, 0), Vector2(sz.x * 0.68, 0),
			Vector2(sz.x * 0.42, sz.y * 0.5), Vector2(sz.x * 0.92, sz.y * 0.58)]),
		PackedColorArray([top, top, none, none]))


func _draw_glows(sz: Vector2) -> void:
	# 标题后方皇家光晕
	_draw_glow(sz, Vector2(sz.x * 0.5, sz.y * 0.175), sz.x * 1.05, 0.55)
	# 卡牌展台后方暖光
	_draw_glow(sz, Vector2(sz.x * 0.5, sz.y * 0.335), sz.x * 0.82, 0.42)
	# 左下角冷色余晖
	_draw_glow(sz, Vector2(sz.x * 0.06, sz.y * 0.74), sz.x * 0.65, 0.20, Color(0.35, 0.55, 1.0, 0.35))


func _draw_glow(sz: Vector2, center: Vector2, diameter: float, alpha: float,
		tint: Color = Color(1, 1, 1, 1)) -> void:
	if _glow_tex == null:
		return
	var r := Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))
	var col := tint
	col.a *= alpha
	draw_texture_rect(_glow_tex, r, false, col)


# ---------------- 透视木质竞技场 ----------------
func _draw_floor(sz: Vector2) -> void:
	var hy := sz.y * 0.70
	var rows := 18
	var cols := 9
	for i in rows:
		var t0 := float(i) / float(rows)
		var t1 := float(i + 1) / float(rows)
		var y0: float = hy + (sz.y - hy + 12.0) * pow(t0, 1.75)
		var y1: float = hy + (sz.y - hy + 12.0) * pow(t1, 1.75)
		var spread: float = lerpf(0.48, 1.35, t0)
		var stagger: float = 0.5 if i % 2 == 0 else 0.0
		for c in cols:
			var xt0: float = (float(c) + stagger) / float(cols)
			var xt1: float = (float(c) + 1.0 + stagger) / float(cols)
			if xt0 < 0.0 or xt1 > 1.0:
				continue
			var x0t: float = sz.x * (0.5 + (xt0 - 0.5) * spread)
			var x1t: float = sz.x * (0.5 + (xt1 - 0.5) * spread)
			var col: Color = WOOD if (c + i) % 2 == 0 else WOOD_ALT
			col.a = 1.0
			var shade: float = lerpf(0.55, 0.28, t0)
			draw_colored_polygon(
				PackedVector2Array([Vector2(x0t, y0), Vector2(x1t, y0),
					Vector2(x1t, y1), Vector2(x0t, y1)]),
				col.lerp(WOOD_DARK, shade))
		# 板缝
		draw_line(Vector2(0, y0), Vector2(sz.x, y0), Color(0.05, 0.03, 0.02, 0.35), 1.0)
	# 中央石道
	for i in rows:
		var t0 := float(i) / float(rows)
		var t1 := float(i + 1) / float(rows)
		var y0: float = hy + (sz.y - hy + 12.0) * pow(t0, 1.75)
		var y1: float = hy + (sz.y - hy + 12.0) * pow(t1, 1.75)
		var hw0: float = sz.x * lerpf(0.045, 0.13, t0)
		var hw1: float = sz.x * lerpf(0.045, 0.13, t1)
		var stone: Color = STONE
		stone.a = 1.0
		stone = stone.lerp(Color(0.05, 0.07, 0.12), lerpf(0.25, 0.05, t0))
		draw_colored_polygon(
			PackedVector2Array([Vector2(sz.x * 0.5 - hw0, y0), Vector2(sz.x * 0.5 + hw0, y0),
				Vector2(sz.x * 0.5 + hw1, y1), Vector2(sz.x * 0.5 - hw1, y1)]), stone)
		# 石道金边
		draw_line(Vector2(sz.x * 0.5 - hw0, y0), Vector2(sz.x * 0.5 - hw1, y1),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 1.2)
		draw_line(Vector2(sz.x * 0.5 + hw0, y0), Vector2(sz.x * 0.5 + hw1, y1),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 1.2)
		# 石缝
		if i % 2 == 0:
			draw_line(Vector2(sz.x * 0.5 - hw1, y0), Vector2(sz.x * 0.5 + hw1, y0),
				Color(0.02, 0.03, 0.06, 0.45), 1.0)
	# 地平线亮线
	draw_line(Vector2(0, hy), Vector2(sz.x, hy), Color(GOLD.r, GOLD.g, GOLD.b, 0.28), 1.6)
	draw_line(Vector2(0, hy + 2), Vector2(sz.x, hy + 2), Color(ROYAL.r, ROYAL.g, ROYAL.b, 0.18), 1.2)
	# 底部压暗，保证按钮区可读
	for i in 24:
		var a: float = 0.05 + float(i) / 24.0 * 0.26
		draw_rect(Rect2(0, sz.y - float(24 - i) * (sz.y * 0.26 / 24.0), sz.x,
			sz.y * 0.26 / 24.0 + 1.0), Color(0.01, 0.015, 0.03, a))


# ---------------- 金尘 ----------------
func _draw_dust(sz: Vector2) -> void:
	for d in _dust:
		var x: float = float(d.x) * sz.x + sin(_t * 0.35 + float(d.phase)) * 14.0
		var base_y: float = float(d.y) * sz.y
		var y: float = fposmod(base_y - _t * float(d.speed) * sz.y, sz.y)
		var tw: float = 0.35 + 0.35 * sin(_t * 1.6 + float(d.phase))
		var col: Color = EMBER if bool(d.warm) else Color(0.55, 0.75, 1.0)
		col.a = tw * 0.55
		draw_circle(Vector2(x, y), float(d.r), col)
		if bool(d.warm):
			draw_circle(Vector2(x, y), float(d.r) * 2.6, Color(col.r, col.g, col.b, col.a * 0.18))


# ---------------- 暗角 ----------------
func _draw_vignette(sz: Vector2) -> void:
	if _vignette_tex == null:
		return
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, 0.85))


# ---------------- 纹理生成 ----------------
func _radial_texture(colors: Array, offsets: Array, px: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	var cols := PackedColorArray()
	for c in colors:
		cols.append(c)
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
