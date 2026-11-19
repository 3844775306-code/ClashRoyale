# assets/ui/menu/IntroLayer.gd
# 开场动画绘制层：王冠描边生成 + 皇家辉光 + 冲击波 + 余烬粒子
extends Control

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const INK := Color(0.020, 0.030, 0.062)
const EMBER := Color(1.0, 0.590, 0.300)

# 与 IntroAnimation 同步的时间轴
const T_CROWN_START := 0.18
const T_CROWN_END := 0.74
const T_RING := 0.74
const T_CROWN_FADE := 1.02

var t := 0.0
var crown_center := Vector2(400, 585)
var title_center := Vector2(400, 250)

var _embers: Array = []
var _rng := RandomNumberGenerator.new()
var _glow_tex: Texture2D
var _title_glow_tex: Texture2D

# 皇冠轮廓（归一化坐标，与 MenuIcon 王冠一致）
const CROWN_PTS := [
	Vector2(-0.86, 0.42), Vector2(-0.86, -0.28), Vector2(-0.44, 0.04),
	Vector2(0.0, -0.62), Vector2(0.44, 0.04), Vector2(0.86, -0.28),
	Vector2(0.86, 0.42), Vector2(-0.86, 0.42),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(800, 1600)
	_glow_tex = _radial_texture(
		[Color(1.0, 0.78, 0.42, 0.55), Color(1.0, 0.62, 0.26, 0.18), Color(1.0, 0.45, 0.10, 0.0)],
		[0.0, 0.45, 1.0], 512)
	_title_glow_tex = _radial_texture(
		[Color(1.0, 0.86, 0.55, 0.5), Color(1.0, 0.68, 0.30, 0.14), Color(1.0, 0.5, 0.15, 0.0)],
		[0.0, 0.4, 1.0], 512)
	_rng.seed = 91307
	for i in 54:
		_embers.append({
			"delay": _rng.randf_range(0.0, 0.42),
			"dir": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.35)).normalized(),
			"speed": _rng.randf_range(60.0, 260.0),
			"size": _rng.randf_range(1.2, 3.4),
			"life": _rng.randf_range(0.45, 1.0),
			"warm": _rng.randf() < 0.8,
		})


func _draw() -> void:
	if t < T_CROWN_START - 0.02:
		return
	var sz := size
	# 背景聚光：平滑径向辉光（贴图，无同心圆断层）
	var glow_t: float = clampf((t - T_CROWN_START) / 0.6, 0.0, 1.0)
	var fade_t: float = clampf((t - T_CROWN_FADE) / 0.26, 0.0, 1.0)
	var fade: float = 1.0 - fade_t
	var base_alpha: float = glow_t * fade
	if _glow_tex != null and base_alpha > 0.001:
		var d := 980.0
		draw_texture_rect(_glow_tex, Rect2(crown_center - Vector2(d, d) * 0.5, Vector2(d, d)),
			false, Color(1, 1, 1, 0.55 * base_alpha))
		var d2 := 460.0
		draw_texture_rect(_glow_tex, Rect2(crown_center - Vector2(d2, d2) * 0.5, Vector2(d2, d2)),
			false, Color(1, 0.95, 0.85, 0.30 * base_alpha))
	# 标题盖章闪光
	if _title_glow_tex != null and t > 0.98 and t < 1.42:
		var ft: float = clampf((t - 0.98) / 0.44, 0.0, 1.0)
		var fa: float = (1.0 - ft) * 0.7
		var fd: float = lerpf(560.0, 900.0, ft)
		draw_texture_rect(_title_glow_tex, Rect2(title_center - Vector2(fd, fd) * 0.5, Vector2(fd, fd)),
			false, Color(1, 1, 1, fa))

	# 王冠描边生长
	var prog: float = clampf((t - T_CROWN_START) / (T_CROWN_END - T_CROWN_START), 0.0, 1.0)
	var scale_px: float = 118.0 + 10.0 * sin(t * 3.0) * prog
	if t > 0.92:
		scale_px += (t - 0.92) * 150.0
	var pts := PackedVector2Array()
	for p in CROWN_PTS:
		pts.append(crown_center + Vector2(p.x, p.y) * scale_px)
	if prog > 0.0:
		_draw_path_part(pts, prog, Color(GOLD.r, GOLD.g, GOLD.b, 0.95 * fade), 4.0)
		# 描边外发光
		_draw_path_part(pts, prog, Color(1.0, 0.85, 0.45, 0.16 * fade), 14.0)
	# 填充
	if prog > 0.6:
		var fill_a: float = clampf((prog - 0.6) / 0.4, 0.0, 1.0) * 0.22 * fade
		var poly := PackedVector2Array()
		for i in CROWN_PTS.size() - 1:
			poly.append(pts[i])
		draw_colored_polygon(poly, Color(1.0, 0.80, 0.40, fill_a))
		# 三个尖角星点
		for sp in [Vector2(-0.86, -0.28), Vector2(0.0, -0.62), Vector2(0.86, -0.28)]:
			draw_circle(crown_center + sp * scale_px, 4.0 + 2.0 * fill_a, Color(1.0, 0.92, 0.68, fill_a * 2.2))
	# 冲击波
	if t > T_RING:
		var rt: float = clampf((t - T_RING) / 0.55, 0.0, 1.0)
		if rt < 1.0:
			var rr: float = lerpf(40.0, 340.0, rt)
			draw_arc(crown_center, rr, 0, TAU, 48, Color(1.0, 0.82, 0.45, (1.0 - rt) * 0.5), 3.0, true)
			draw_arc(crown_center, rr * 0.72, 0, TAU, 40, Color(0.55, 0.72, 1.0, (1.0 - rt) * 0.22), 2.0, true)
	# 旋转金色弧线
	if prog > 0.15 and t < 1.25:
		var rot: float = t * 1.6
		for i in 3:
			var a0: float = rot + float(i) * TAU / 3.0
			draw_arc(crown_center, scale_px * 1.28, a0, a0 + 0.85, 24,
				Color(1.0, 0.85, 0.5, 0.20 * base_alpha), 2.0, true)
	# 余烬
	var emit_t: float = t - T_RING
	if emit_t > 0.0 and fade > 0.0:
		for e in _embers:
			var age: float = emit_t - float(e.delay)
			if age <= 0.0 or age > float(e.life):
				continue
			var dir: Vector2 = e.dir
			var pos: Vector2 = crown_center + dir * float(e.speed) * age + Vector2(0, 150.0 * age * age)
			var k: float = age / float(e.life)
			var col: Color = EMBER if bool(e.warm) else Color(0.55, 0.75, 1.0)
			col.a = (1.0 - k) * 0.85 * fade
			draw_circle(pos, float(e.size) * (1.0 - 0.5 * k), col)
			if bool(e.warm):
				draw_circle(pos, float(e.size) * 3.0, Color(col.r, col.g, col.b, col.a * 0.14))


func _draw_path_part(pts: PackedVector2Array, prog: float, col: Color, width: float) -> void:
	if pts.size() < 2:
		return
	var total := 0.0
	var lens: Array = []
	for i in range(1, pts.size()):
		var l: float = pts[i].distance_to(pts[i - 1])
		lens.append(l)
		total += l
	if total <= 0.0:
		return
	var remain: float = total * prog
	for i in range(1, pts.size()):
		var seg: float = float(lens[i - 1])
		if remain <= 0.0:
			break
		if remain >= seg:
			draw_line(pts[i - 1], pts[i], col, width, true)
			remain -= seg
		else:
			var t2: float = remain / seg
			var p := pts[i - 1].lerp(pts[i], t2)
			draw_line(pts[i - 1], p, col, width, true)
			remain = 0.0


func _radial_texture(colors: Array, offsets: Array, px: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t2 := GradientTexture2D.new()
	t2.gradient = g
	t2.width = px
	t2.height = px
	t2.fill = GradientTexture2D.FILL_RADIAL
	t2.fill_from = Vector2(0.5, 0.5)
	t2.fill_to = Vector2(1.0, 0.5)
	return t2
