# assets/ui/menu/MenuIcon.gd
# 程序化线描图标：不依赖 emoji / 位图，统一金色描边风格
extends Control

@export var kind: String = "crown"
@export var tint: Color = Color(0.95, 0.78, 0.35)
@export var deep: Color = Color(0.36, 0.22, 0.06)
@export var line_width: float = 3.2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var s: float = minf(size.x, size.y) * 0.5 * 0.86
	var w: float = maxf(1.5, line_width * s / 20.0)
	match kind:
		"crown":
			_crown(c, s, w)
		"coin":
			_coin(c, s, w)
		"gem":
			_gem(c, s, w)
		"trophy":
			_trophy(c, s, w)
		"sword":
			_sword(c, s, w)
		"chest":
			_chest(c, s, w)
		"deck":
			_deck(c, s, w)
		"medal":
			_medal(c, s, w)
		"palette":
			_palette(c, s, w)
		"shield":
			_shield(c, s, w)
		"flask":
			_flask(c, s, w)
		"globe":
			_globe(c, s, w)
		"replay":
			_replay(c, s, w)
		"gear":
			_gear(c, s, w)
		"quit":
			_quit(c, s, w)
		"chevron":
			_chevron(c, s, w)
		"back":
			_back(c, s, w)
		"star":
			_star(c, s, w)
		_:
			draw_circle(c, s * 0.7, tint)


func _crown(c: Vector2, s: float, w: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-0.86, 0.42) * s, c + Vector2(-0.86, -0.28) * s,
		c + Vector2(-0.44, 0.04) * s, c + Vector2(0.0, -0.62) * s,
		c + Vector2(0.44, 0.04) * s, c + Vector2(0.86, -0.28) * s,
		c + Vector2(0.86, 0.42) * s,
	])
	var col := tint
	col.a = 0.18
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), tint, w, true)
	draw_line(c + Vector2(-0.86, 0.42) * s, c + Vector2(0.86, 0.42) * s, tint, w, true)
	for p in [Vector2(-0.86, -0.28), Vector2(0.0, -0.62), Vector2(0.86, -0.28)]:
		draw_circle(c + p * s, w * 1.15, tint)
	draw_circle(c + Vector2(0.0, 0.16) * s, w * 0.9, deep)


func _coin(c: Vector2, s: float, w: float) -> void:
	draw_circle(c, s * 0.88, tint)
	var inner := tint.darkened(0.35)
	inner.a = 1.0
	draw_arc(c, s * 0.66, 0, TAU, 40, inner, w, true)
	draw_arc(c, s * 0.44, -0.4, 1.4, 16, Color(1, 1, 1, 0.75), w * 0.9, true)
	draw_circle(c, s * 0.14, deep)


func _gem(c: Vector2, s: float, w: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -0.9) * s, c + Vector2(0.78, -0.18) * s,
		c + Vector2(0, 0.92) * s, c + Vector2(-0.78, -0.18) * s,
	])
	var fill := tint
	fill.a = 0.85
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), Color(1, 1, 1, 0.85), w * 0.8, true)
	draw_line(c + Vector2(-0.78, -0.18) * s, c + Vector2(0.78, -0.18) * s, Color(1, 1, 1, 0.45), w * 0.6, true)
	draw_line(c + Vector2(-0.2, -0.78) * s, c + Vector2(0.2, -0.62) * s, Color(1, 1, 1, 0.5), w * 0.6, true)


func _trophy(c: Vector2, s: float, w: float) -> void:
	var cup := PackedVector2Array([
		c + Vector2(-0.62, -0.55) * s, c + Vector2(0.62, -0.55) * s,
		c + Vector2(0.44, 0.18) * s, c + Vector2(0.0, 0.46) * s,
		c + Vector2(-0.44, 0.18) * s,
	])
	draw_polyline(PackedVector2Array(cup + PackedVector2Array([cup[0]])), tint, w, true)
	draw_line(c + Vector2(-0.62, -0.55) * s, c + Vector2(-0.62, 0.4) * s, tint, w * 0.9, true)
	draw_line(c + Vector2(0.62, -0.55) * s, c + Vector2(0.62, 0.4) * s, tint, w * 0.9, true)
	draw_arc(c + Vector2(-0.5, -0.05) * s, s * 0.34, PI * 0.5, PI * 1.5, 20, tint, w * 0.9, true)
	draw_arc(c + Vector2(0.5, -0.05) * s, s * 0.34, -PI * 0.5, PI * 0.5, 20, tint, w * 0.9, true)
	draw_line(c + Vector2(0.0, 0.46) * s, c + Vector2(0.0, 0.68) * s, tint, w, true)
	draw_line(c + Vector2(-0.34, 0.72) * s, c + Vector2(0.34, 0.72) * s, tint, w, true)


func _sword(c: Vector2, s: float, w: float) -> void:
	var blade := PackedVector2Array([
		c + Vector2(0.0, -0.92) * s, c + Vector2(0.2, -0.6) * s,
		c + Vector2(0.2, 0.34) * s, c + Vector2(-0.2, 0.34) * s,
		c + Vector2(-0.2, -0.6) * s,
	])
	var fill := tint
	fill.a = 0.2
	draw_colored_polygon(blade, fill)
	draw_polyline(PackedVector2Array(blade + PackedVector2Array([blade[0]])), tint, w * 0.8, true)
	draw_line(c + Vector2(-0.56, 0.34) * s, c + Vector2(0.56, 0.34) * s, tint, w * 1.6, true)
	draw_line(c + Vector2(0.0, 0.34) * s, c + Vector2(0.0, 0.86) * s, tint, w * 1.4, true)
	draw_circle(c + Vector2(0.0, 0.86) * s, w * 1.2, tint)


func _chest(c: Vector2, s: float, w: float) -> void:
	var body := Rect2(c + Vector2(-0.8, -0.08) * s, Vector2(1.6, 0.92) * s)
	draw_rect(body, tint, false, w)
	draw_arc(c + Vector2(0, -0.08) * s, s * 0.8, PI, TAU, 28, tint, w, true)
	draw_line(c + Vector2(-0.8, -0.08) * s, c + Vector2(0.8, -0.08) * s, tint, w * 0.8, true)
	draw_rect(Rect2(c + Vector2(-0.14, -0.02) * s, Vector2(0.28, 0.3) * s), tint, false, w * 0.8)
	draw_circle(c + Vector2(0.0, 0.14) * s, w * 0.7, tint)
	draw_line(c + Vector2(-0.55, 0.24) * s, c + Vector2(-0.55, 0.84) * s, tint, w * 0.9, true)
	draw_line(c + Vector2(0.55, 0.24) * s, c + Vector2(0.55, 0.84) * s, tint, w * 0.9, true)


func _deck(c: Vector2, s: float, w: float) -> void:
	draw_rect(Rect2(c + Vector2(-0.62, -0.7) * s, Vector2(0.8, 1.1) * s), tint, false, w * 0.8)
	draw_rect(Rect2(c + Vector2(-0.42, -0.82) * s, Vector2(0.8, 1.1) * s), tint, false, w * 0.8)
	draw_rect(Rect2(c + Vector2(-0.22, -0.94) * s, Vector2(0.8, 1.1) * s), tint, false, w * 0.9)
	draw_line(c + Vector2(-0.02, -0.6) * s, c + Vector2(0.4, -0.6) * s, tint, w * 0.7, true)
	draw_line(c + Vector2(-0.02, -0.36) * s, c + Vector2(0.4, -0.36) * s, tint, w * 0.7, true)


func _medal(c: Vector2, s: float, w: float) -> void:
	draw_circle(c + Vector2(0, 0.14) * s, s * 0.52, tint)
	draw_circle(c + Vector2(0, 0.14) * s, s * 0.3, tint.darkened(0.45))
	draw_circle(c + Vector2(0, 0.14) * s, s * 0.3, tint, false, w * 0.8)
	var ribbon := tint.darkened(0.2)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-0.5, -0.4) * s, c + Vector2(-0.18, -0.5) * s,
		c + Vector2(-0.05, 0.02) * s, c + Vector2(-0.3, 0.08) * s,
	]), ribbon)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.5, -0.4) * s, c + Vector2(0.18, -0.5) * s,
		c + Vector2(0.05, 0.02) * s, c + Vector2(0.3, 0.08) * s,
	]), ribbon)


func _palette(c: Vector2, s: float, w: float) -> void:
	draw_arc(c + Vector2(0, 0.0) * s, s * 0.72, -0.6, TAU - 0.5, 36, tint, w, true)
	draw_arc(c + Vector2(0.42, 0.18) * s, s * 0.3, 0.6, 2.8, 20, tint, w * 0.9, true)
	draw_circle(c + Vector2(-0.26, -0.3) * s, w * 0.9, tint)
	draw_circle(c + Vector2(0.16, -0.4) * s, w * 0.9, tint)
	draw_circle(c + Vector2(-0.42, 0.14) * s, w * 0.9, tint)


func _shield(c: Vector2, s: float, w: float) -> void:
	var sh := PackedVector2Array([
		c + Vector2(0, -0.92) * s, c + Vector2(0.72, -0.6) * s,
		c + Vector2(0.68, 0.16) * s, c + Vector2(0, 0.9) * s,
		c + Vector2(-0.68, 0.16) * s, c + Vector2(-0.72, -0.6) * s,
	])
	var fill := tint
	fill.a = 0.16
	draw_colored_polygon(sh, fill)
	draw_polyline(PackedVector2Array(sh + PackedVector2Array([sh[0]])), tint, w, true)
	draw_line(c + Vector2(0, -0.62) * s, c + Vector2(0, 0.6) * s, tint, w * 1.2, true)
	draw_line(c + Vector2(-0.36, -0.14) * s, c + Vector2(0.36, -0.14) * s, tint, w * 1.2, true)


func _flask(c: Vector2, s: float, w: float) -> void:
	draw_line(c + Vector2(-0.2, -0.86) * s, c + Vector2(-0.2, -0.36) * s, tint, w, true)
	draw_line(c + Vector2(0.2, -0.86) * s, c + Vector2(0.2, -0.36) * s, tint, w, true)
	draw_line(c + Vector2(-0.5, -0.86) * s, c + Vector2(0.5, -0.86) * s, tint, w, true)
	var body := PackedVector2Array([
		c + Vector2(-0.2, -0.36) * s, c + Vector2(-0.72, 0.74) * s,
		c + Vector2(0.72, 0.74) * s, c + Vector2(0.2, -0.36) * s,
	])
	var fill := tint
	fill.a = 0.14
	draw_colored_polygon(body, fill)
	draw_polyline(PackedVector2Array(body + PackedVector2Array([body[0]])), tint, w, true)
	draw_line(c + Vector2(-0.46, 0.28) * s, c + Vector2(0.46, 0.28) * s, tint, w * 0.9, true)
	draw_circle(c + Vector2(-0.1, 0.5) * s, w * 0.8, tint)
	draw_circle(c + Vector2(0.22, 0.4) * s, w * 0.6, tint)


func _globe(c: Vector2, s: float, w: float) -> void:
	draw_arc(c, s * 0.85, 0, TAU, 40, tint, w, true)
	draw_arc(c, s * 0.85, 0, TAU, 40, tint, w, true)
	draw_line(c + Vector2(0, -0.85) * s, c + Vector2(0, 0.85) * s, tint, w * 0.7, true)
	draw_line(c + Vector2(-0.85, 0) * s, c + Vector2(0.85, 0) * s, tint, w * 0.7, true)
	draw_arc(c + Vector2(0, 0) * s, s * 0.45, -PI * 0.5, PI * 0.5, 20, tint, w * 0.7, true)
	draw_arc(c + Vector2(0, 0) * s, s * 0.45, PI * 0.5, PI * 1.5, 20, tint, w * 0.7, true)


func _replay(c: Vector2, s: float, w: float) -> void:
	draw_arc(c, s * 0.72, -PI * 0.35, PI * 1.25, 30, tint, w, true)
	var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.72
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(0.02, -0.34) * s, tip + Vector2(0.32, 0.02) * s, tip + Vector2(-0.12, 0.12) * s,
	]), tint)
	var mid := c + Vector2(0.06, 0.02) * s
	draw_colored_polygon(PackedVector2Array([
		mid + Vector2(-0.16, -0.22) * s, mid + Vector2(0.3, 0.02) * s, mid + Vector2(-0.16, 0.26) * s,
	]), tint)


func _gear(c: Vector2, s: float, w: float) -> void:
	draw_arc(c, s * 0.46, 0, TAU, 32, tint, w * 1.2, true)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p1 := c + Vector2(cos(a), sin(a)) * s * 0.46
		var p2 := c + Vector2(cos(a), sin(a)) * s * 0.82
		draw_line(p1, p2, tint, w * 1.4, true)
	draw_circle(c, s * 0.16, tint)


func _quit(c: Vector2, s: float, w: float) -> void:
	draw_rect(Rect2(c + Vector2(-0.7, -0.8) * s, Vector2(0.92, 1.6) * s), tint, false, w)
	draw_line(c + Vector2(-0.34, 0) * s, c + Vector2(0.72, 0) * s, tint, w, true)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.72, 0) * s, c + Vector2(0.42, -0.22) * s, c + Vector2(0.42, 0.22) * s,
	]), tint)


func _back(c: Vector2, s: float, w: float) -> void:
	draw_line(c + Vector2(0.62, 0) * s, c + Vector2(-0.55, 0) * s, tint, w * 1.2, true)
	draw_polyline(PackedVector2Array([
		c + Vector2(-0.05, -0.52) * s, c + Vector2(-0.6, 0) * s, c + Vector2(-0.05, 0.52) * s,
	]), tint, w * 1.2, true)


func _chevron(c: Vector2, s: float, w: float) -> void:
	draw_polyline(PackedVector2Array([
		c + Vector2(-0.3, -0.5) * s, c + Vector2(0.22, 0) * s, c + Vector2(-0.3, 0.5) * s,
	]), tint, w * 1.2, true)


func _star(c: Vector2, s: float, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = s * (0.9 if i % 2 == 0 else 0.4)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var fill := tint
	fill.a = 0.25
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), tint, w * 0.8, true)
