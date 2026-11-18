extends Control
const EmoteCatalog = preload("res://scripts/data/EmoteCatalog.gd")
# Web/原生统一表情徽章：不依赖 emoji 字体，用彩色圆牌 + 中文短标绘制。

var emote_id: String = ""
var _texture: Texture2D = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/emotes/%s.png" % emote_id
	if ResourceLoader.exists(path):
		_texture = load(path)
	queue_redraw()

func _draw():
	var d: Dictionary = EmoteCatalog.display(emote_id)
	var col := Color(String(d.get("color", "#FFD24A")))
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.95))
	draw_circle(c, r - 3.0, col)
	draw_arc(c, r - 1.5, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 2.0, true)
	if _texture:
		var ts: float = r * 1.52
		draw_texture_rect(_texture, Rect2(c - Vector2(ts * 0.5, ts * 0.5), Vector2(ts, ts)), false)
	else:
		var nm := String(d.get("name", "表情"))
		var short := nm.substr(0, 2) if nm.length() >= 2 else nm
		var font := get_theme_default_font()
		var fs: int = int(maxf(12.0, r * 0.55))
		var tw := font.get_string_size(short, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), short, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.10, 0.08, 0.03))
