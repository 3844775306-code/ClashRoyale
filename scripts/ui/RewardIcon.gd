extends Control

const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

var kind: String = "gold"
var amount: int = 1
var card_name: String = ""
var card_id: int = 0
var accent: Color = Color(0.96, 0.72, 0.24)
var _texture: Texture2D = null
static var _official_map: Dictionary = {}
static var _official_loaded: bool = false

func setup(p_kind: String, p_amount: int = 1, p_card_name: String = "", p_card_id: int = 0) -> void:
	kind = p_kind
	amount = p_amount
	card_name = p_card_name
	card_id = p_card_id
	if kind == "card" or kind == "wild":
		var path := ""
		if card_id > 0:
			path = _official_path(card_id)
		if path == "" or not ResourceLoader.exists(path):
			path = "res://assets/cards_web/%s.png" % card_name
		if not ResourceLoader.exists(path):
			path = "res://assets/cards_rendered/%s.png" % card_name
		if ResourceLoader.exists(path):
			_texture = load(path)
		if card_id > 0:
			accent = CARD_RARITY.rarity_color_by_id(card_id)
	queue_redraw()

static func _official_path(card_id: int) -> String:
	if not _official_loaded:
		_official_loaded = true
		var f := FileAccess.open("res://data/official_card_art.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_official_map = parsed
	return String(_official_map.get(str(card_id), ""))

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1 or h <= 1:
		return
	var center := Vector2(w * 0.5, h * 0.5)
	match kind:
		"gold":
			_draw_coins(center, minf(w, h))
		"gems":
			_draw_gem(center, minf(w, h))
		"chest":
			_draw_chest(Rect2(2, h * 0.14, w - 4, h * 0.78))
		"wild":
			_draw_card_back(Rect2(w * 0.10, h * 0.06, w * 0.80, h * 0.82))
		"emote":
			_draw_emote(center, minf(w, h))
		_:
			_draw_card(Rect2(w * 0.08, h * 0.04, w * 0.84, h * 0.86))
	if amount > 1:
		_draw_amount_badge(w, h)

func _draw_card(rect: Rect2) -> void:
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.04, 0.05, 0.09, 1.0)
	border.border_color = accent
	border.set_border_width_all(2)
	border.set_corner_radius_all(8)
	draw_style_box(border, rect)
	if _texture:
		var inner := rect.grow(-3)
		var tex_size: Vector2 = _texture.get_size()
		var scale: float = minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
		var draw_size := tex_size * scale
		var pos := inner.position + (inner.size - draw_size) * 0.5
		draw_texture_rect(_texture, Rect2(pos, draw_size), false)
	else:
		var r2 := rect.grow(-5)
		draw_rect(r2, Color(0.16, 0.14, 0.22, 1.0))
		_draw_centered_text(card_name, r2, 12, Color(0.9, 0.9, 0.95))

func _draw_card_back(rect: Rect2) -> void:
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.10, 0.16, 0.28, 1.0)
	border.border_color = accent
	border.set_border_width_all(2)
	border.set_corner_radius_all(8)
	draw_style_box(border, rect)
	var inner := rect.grow(-6)
	draw_rect(inner, Color(0.16, 0.28, 0.48, 1.0))
	for i in range(3):
		var y: float = inner.position.y + inner.size.y * (0.25 + i * 0.25)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.15), 1.0)
	_draw_centered_text("?", rect, int(rect.size.y * 0.55), Color(1, 0.92, 0.55))

func _draw_coins(center: Vector2, d: float) -> void:
	for i in range(3):
		var c: Vector2 = center + Vector2(-d * 0.10 + i * d * 0.10, d * 0.10 - i * d * 0.12)
		draw_circle(c, d * 0.26, Color(0.54, 0.34, 0.06))
		draw_circle(c, d * 0.23, Color(1.0, 0.76, 0.20))
		draw_circle(c, d * 0.15, Color(1.0, 0.88, 0.42))
		draw_circle(c, d * 0.07, Color(1.0, 0.70, 0.14))

func _draw_gem(center: Vector2, d: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -d * 0.40),
		center + Vector2(d * 0.30, -d * 0.10),
		center + Vector2(d * 0.22, d * 0.36),
		center + Vector2(0, d * 0.44),
		center + Vector2(-d * 0.22, d * 0.36),
		center + Vector2(-d * 0.30, -d * 0.10),
	])
	draw_colored_polygon(pts, Color(0.18, 0.66, 0.90))
	var hi := PackedVector2Array([
		center + Vector2(0, -d * 0.38),
		center + Vector2(d * 0.20, -d * 0.10),
		center + Vector2(0, d * 0.10),
		center + Vector2(-d * 0.20, -d * 0.10),
	])
	draw_colored_polygon(hi, Color(0.50, 0.92, 1.0))
	draw_line(center + Vector2(0, -d * 0.38), center + Vector2(0, d * 0.42), Color(0.05, 0.40, 0.65, 0.7), 2.0)

func _draw_chest(rect: Rect2) -> void:
	var body_color := Color(0.48, 0.28, 0.12)
	var lid_color := Color(0.62, 0.38, 0.16)
	var band_color := accent
	var body := StyleBoxFlat.new()
	body.bg_color = body_color
	body.set_corner_radius_all(10)
	draw_style_box(body, Rect2(rect.position.x + 2, rect.position.y + rect.size.y * 0.36, rect.size.x - 4, rect.size.y * 0.62))
	var lid := StyleBoxFlat.new()
	lid.bg_color = lid_color
	lid.set_corner_radius_all(11)
	draw_style_box(lid, Rect2(rect.position.x, rect.position.y + rect.size.y * 0.12, rect.size.x, rect.size.y * 0.42))
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.34, rect.size.x, 5), band_color)
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.44, rect.position.y + rect.size.y * 0.12, rect.size.x * 0.12, rect.size.y * 0.84), band_color)
	draw_circle(Vector2(rect.position.x + rect.size.x * 0.50, rect.position.y + rect.size.y * 0.56), maxf(3, rect.size.x * 0.08), Color(1, 0.90, 0.55))

func _draw_emote(center: Vector2, d: float) -> void:
	draw_circle(center, d * 0.36, Color(0.96, 0.72, 0.22))
	draw_circle(center, d * 0.30, Color(1.0, 0.92, 0.58))
	draw_circle(center + Vector2(-d * 0.10, -d * 0.06), d * 0.035, Color(0.10, 0.08, 0.04))
	draw_circle(center + Vector2(d * 0.10, -d * 0.06), d * 0.035, Color(0.10, 0.08, 0.04))
	draw_arc(center + Vector2(0, d * 0.06), d * 0.14, 0.15, PI - 0.15, 16, Color(0.55, 0.25, 0.04), maxf(2, d * 0.035))

func _draw_amount_badge(w: float, h: float) -> void:
	var font := get_theme_default_font()
	var fs: int = maxi(12, int(minf(w, h) * 0.20))
	var txt := "×%d" % amount
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw: float = tw + 12
	var bh: float = fs + 8
	var r := Rect2(w - bw - 1, h - bh - 1, bw, bh)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.03, 0.04, 0.07, 0.94)
	badge.border_color = Color(1.0, 0.82, 0.30)
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(int(bh * 0.35))
	draw_style_box(badge, r)
	var ty: float = r.position.y + bh * 0.5 + fs * 0.34
	draw_string(font, Vector2(r.position.x + 6, ty + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(r.position.x + 6, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.62))

func _draw_centered_text(text: String, rect: Rect2, fs: int, color: Color) -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y * 0.5 + fs * 0.35)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
