# assets/ui/menu/MenuCardPiece.gd
# 卡牌展台单卡：金边卡框 + 透明卡面插画 + 投影/高光，悬停抬起
extends Control

const GOLD := Color(0.94, 0.76, 0.36)
const GOLD_DEEP := Color(0.55, 0.36, 0.10)
const GOLD_LIGHT := Color(1.0, 0.93, 0.72)
const INK := Color(0.03, 0.05, 0.10)
const NAVY := Color(0.075, 0.10, 0.20)
const PLATE := Color(0.11, 0.15, 0.28)

var card_name := "骑士"
var hero := false          # 中央大卡
var _art: Texture2D = null
var _name_font: Font
var _sb_outer: StyleBoxFlat
var _sb_inner: StyleBoxFlat
var _sb_plate: StyleBoxFlat
var _sb_glow: StyleBoxFlat
var _hovered := false
var _base_z := 0
var _t := 0.0
static var _shadow_tex: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	_load_art()
	_name_font = load("res://assets/fonts/STZHONGS.TTF")
	_rebuild_styles()
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	_rebuild_styles()


func _load_art() -> void:
	var path := "res://assets/cards_rendered/%s.png" % card_name
	if ResourceLoader.exists(path):
		_art = load(path)


func _rebuild_styles() -> void:
	_sb_outer = _make_sb(GOLD_DEEP, 15, 2, Color(0.22, 0.14, 0.03, 1.0))
	_sb_inner = _make_sb(NAVY, 13, 2, GOLD)
	_sb_plate = _make_sb(PLATE, 9, 0, Color(0, 0, 0, 0))
	_sb_glow = _make_sb(Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 18, 0, Color(0, 0, 0, 0))
	queue_redraw()


func _make_sb(bg: Color, radius: int, border: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	return sb


func _process(delta: float) -> void:
	_t += delta
	if hero:
		queue_redraw()


func _on_mouse_entered() -> void:
	_hovered = true
	_base_z = z_index
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.07, 1.07), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	z_index = 10


func _on_mouse_exited() -> void:
	_hovered = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	z_index = _base_z


func _draw() -> void:
	var sz := size
	if sz.x < 8.0:
		return
	# 中央卡的呼吸光晕
	if hero and _sb_glow:
		var pulse: float = 0.5 + 0.5 * sin(_t * 1.6)
		_sb_glow.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.10 + 0.08 * pulse)
		draw_style_box(_sb_glow, Rect2(Vector2(-10, -10), sz + Vector2(20, 20)))
	# 落地投影
	var shadow_center := Vector2(sz.x * 0.5, sz.y * 0.97)
	draw_set_transform(shadow_center, 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, sz.x * 0.46, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 卡框层次
	draw_style_box(_sb_outer, Rect2(Vector2(2, 2), sz - Vector2(4, 4)))
	draw_style_box(_sb_inner, Rect2(Vector2(7, 7), sz - Vector2(14, 14)))
	draw_style_box(_sb_plate, Rect2(Vector2(12, 12), sz - Vector2(24, 24)))
	# 卡面（给底部铭牌留出空间）
	var pad := 10.0
	var reserve := 34.0 if hero else 28.0
	var area := Rect2(Vector2(pad, pad + 2.0), sz - Vector2(pad * 2.0, pad * 2.0 + reserve))
	if _art != null:
		var tex_size := Vector2(_art.get_width(), _art.get_height())
		var fit: float = minf(area.size.x / tex_size.x, area.size.y / tex_size.y)
		var draw_size := tex_size * fit
		var pos := area.position + (area.size - draw_size) * 0.5 + Vector2(0, 2.0)
		draw_texture_rect(_art, Rect2(pos, draw_size), false)
	# 斜向高光
	draw_polygon(
		PackedVector2Array([Vector2(9, 9), Vector2(sz.x * 0.52, 9),
			Vector2(9, sz.y * 0.46)]),
		PackedColorArray([Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.0)]))
	# 四角铆钉
	for p in [Vector2(14, 14), Vector2(sz.x - 14, 14), Vector2(14, sz.y - 14), Vector2(sz.x - 14, sz.y - 14)]:
		draw_circle(p, 2.4, GOLD_LIGHT)
	# 中央卡顶部小徽标
	if hero:
		draw_circle(Vector2(sz.x * 0.5, 12), 7.0, INK)
		draw_circle(Vector2(sz.x * 0.5, 12), 4.4, GOLD)
