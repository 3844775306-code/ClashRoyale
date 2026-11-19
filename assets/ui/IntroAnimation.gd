# assets/ui/IntroAnimation.gd
# 开场动画「王冠登场」：2.55s，可轻触跳过
# 时间轴：黑场 → 王冠描边成型(0.18-0.74) → 冲击波/余烬(0.74) →
#         标题盖章(1.00) → CLASH ROYALE(1.24) → 卡牌飞入菜单卡位(1.42) →
#         元素淡出(2.02) → 黑幕淡出(2.12-2.50) → 菜单可交互
extends Control

signal music_started
signal finished

const LAYER := preload("res://assets/ui/menu/IntroLayer.gd")
const CARD_PIECE := preload("res://assets/ui/menu/MenuCardPiece.gd")

const INK := Color(0.020, 0.030, 0.062)
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const MUTED := Color(0.630, 0.680, 0.795)

const T_CROWN_START := 0.18
const T_CROWN_END := 0.74
const T_TITLE := 1.00
const T_EYEBROW := 1.24
const T_CARDS := 1.42
const T_ELEM_FADE := 2.02
const T_COVER_FADE := 2.12
const T_END := 2.52
const T_MUSIC := 1.28

# 与菜单卡牌展台完全一致的终态布局
const CARD_DATA := [
	{"name": "火球", "rot": -14.0, "x": -238.0, "y": 46.0, "w": 172.0, "h": 200.0},
	{"name": "公主", "rot": -7.0, "x": -122.0, "y": 18.0, "w": 176.0, "h": 206.0},
	{"name": "骑士", "rot": 0.0, "x": 0.0, "y": 0.0, "w": 214.0, "h": 248.0},
	{"name": "飞龙宝宝", "rot": 7.0, "x": 122.0, "y": 18.0, "w": 176.0, "h": 206.0},
	{"name": "皮卡超人", "rot": 14.0, "x": 238.0, "y": 46.0, "w": 172.0, "h": 200.0},
]

static var _played := false
var _t := 0.0
var _frozen := false
var _music_sent := false
var _sfx_crown := false
var _sfx_title := false
var _skipping := false

var _cover: ColorRect
var _layer: Control
var _title_holder: Control
var _title: Label
var _eyebrow: Label
var _hint: Label
var _cards: Array = []
var _font: Font
var _crown_sfx: AudioStream
var _title_sfx: AudioStream


func _ready() -> void:
	var freeze := OS.get_environment("CR_INTRO_T")
	if freeze != "":
		_frozen = true
	if _played and not _frozen:
		music_started.emit()
		finished.emit()
		queue_free()
		return
	add_to_group("intro_animation")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	# 开场不使用召唤/部署音效，避免被误听成女巫生产单位的声音
	_crown_sfx = null
	_title_sfx = null

	_cover = ColorRect.new()
	_cover.color = INK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)

	_layer = LAYER.new()
	add_child(_layer)

	# 标题（终态与菜单标题位置一致，盖板淡出时无缝衔接）
	_title_holder = Control.new()
	_title_holder.position = Vector2(20, 186)
	_title_holder.size = Vector2(760, 128)
	_title_holder.pivot_offset = Vector2(380, 64)
	_title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_holder)
	_title = Label.new()
	_title.text = "皇室战争"
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 92)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	if _font != null:
		_title.add_theme_font_override("font", _font)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_holder.add_child(_title)

	_eyebrow = Label.new()
	_eyebrow.text = "C L A S H   R O Y A L E"
	_eyebrow.anchor_left = 0.0
	_eyebrow.anchor_right = 1.0
	_eyebrow.offset_top = 156
	_eyebrow.offset_bottom = 182
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.add_theme_font_size_override("font_size", 15)
	_eyebrow.add_theme_color_override("font_color", Color(0.93, 0.895, 0.79, 0.7))
	_eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eyebrow)

	# 卡牌
	var center := Vector2(400, 528)
	for i in CARD_DATA.size():
		var d: Dictionary = CARD_DATA[i]
		var piece = CARD_PIECE.new()
		piece.card_name = d.name
		piece.hero = i == 2
		piece.size = Vector2(d.w, d.h)
		piece.pivot_offset = piece.size * 0.5
		piece.position = center + Vector2(d.x, d.y) - piece.size * 0.5
		piece.rotation = deg_to_rad(float(d.rot))
		piece.z_index = 3 - absi(i - 2)
		piece.modulate.a = 0.0
		add_child(piece)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.append({
			"node": piece,
			"base": piece.position,
			"rot": piece.rotation,
			"delay": T_CARDS + float(i) * 0.075,
		})

	_hint = Label.new()
	_hint.text = "轻触跳过"
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -128
	_hint.offset_bottom = -96
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	# 开发截图：固定时间轴
	if _frozen:
		_t = clampf(float(freeze), 0.0, T_END)
	_apply(0.0)


func _process(delta: float) -> void:
	if not _frozen:
		_t += delta
	_apply(delta)
	if _frozen:
		return
	if _t >= T_END:
		_played = true
		set_process(false)
		print("[Intro] finished")
		finished.emit()
		queue_free()


func _apply(_delta: float) -> void:
	# 音效 / 音乐节点
	if not _frozen:
		if not _sfx_crown and _t >= T_CROWN_START:
			_sfx_crown = true
			AudioManager.play_sfx(_crown_sfx)
		if not _sfx_title and _t >= T_TITLE:
			_sfx_title = true
			AudioManager.play_sfx(_title_sfx)
	if not _music_sent and _t >= T_MUSIC:
		_music_sent = true
		music_started.emit()

	# 黑幕
	var cover_a: float = 1.0
	if _t > T_COVER_FADE:
		cover_a = 1.0 - clampf((_t - T_COVER_FADE) / (T_END - T_COVER_FADE), 0.0, 1.0)
	_cover.color = Color(INK.r, INK.g, INK.b, cover_a)

	# 标题盖章
	var elem_fade: float = 1.0 - clampf((_t - T_ELEM_FADE) / 0.16, 0.0, 1.0)
	var tk: float = clampf((_t - T_TITLE) / 0.30, 0.0, 1.0)
	var ease_k: float = 1.0 - pow(1.0 - tk, 3.0)
	var title_alpha: float = clampf((_t - T_TITLE) / 0.10, 0.0, 1.0) * elem_fade
	_title_holder.visible = _t >= T_TITLE
	_title_holder.scale = Vector2.ONE * lerpf(1.42, 1.0, ease_k)
	_title_holder.modulate.a = title_alpha
	_title.modulate = Color(1, 1, 1, 1)

	# 眉标
	var ey_alpha: float = clampf((_t - T_EYEBROW) / 0.18, 0.0, 1.0) * elem_fade
	_eyebrow.modulate.a = ey_alpha

	# 卡牌飞入
	for item in _cards:
		var piece: Control = item.node
		var base: Vector2 = item.base
		var final_rot: float = item.rot
		var k: float = clampf((_t - float(item.delay)) / 0.42, 0.0, 1.0)
		var ek: float = 1.0 - pow(1.0 - k, 3.0)
		var start_pos: Vector2 = base + Vector2(0, 430)
		var start_rot: float = final_rot + (0.24 if base.x < 400.0 else -0.24)
		piece.position = start_pos.lerp(base, ek)
		piece.rotation = lerpf(start_rot, final_rot, ek)
		piece.scale = Vector2.ONE * lerpf(0.88, 1.0, ek)
		piece.modulate.a = clampf(k * 3.0, 0.0, 1.0) * elem_fade

	# 跳过提示
	var hint_a := 0.0
	if _t >= 0.55 and _t < 1.9:
		hint_a = clampf((_t - 0.55) / 0.25, 0.0, 1.0) * (1.0 - clampf((_t - 1.65) / 0.2, 0.0, 1.0))
	_hint.modulate.a = hint_a

	_layer.t = _t
	_layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _frozen:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed and _t < T_ELEM_FADE:
		_played = true
		_skipping = true
		_t = T_ELEM_FADE
		_cover.color = Color(INK.r, INK.g, INK.b, 1.0)
		if not _music_sent:
			_music_sent = true
			music_started.emit()


func _try_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null
