# assets/ui/Challenges.gd
# 挑战 / 锦标赛：消耗宝石进入，达成胜场领奖励，输满 3 场淘汰；进度存 PlayerData.challenge_state
extends Control

const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const CHALLENGES := preload("res://scripts/core/Challenges.gd")
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const EMBER := Color(1.0, 0.590, 0.300)
const GREEN := Color(0.48, 0.92, 0.60)

var _font: Font
var _list: VBoxContainer
var _status: VBoxContainer
var _msg: Label


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	UiComponents.add_background(self)
	UiComponents.make_header(self, "挑战 / 锦标赛", _on_back, true)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = UiComponents.HEADER_H + 12
	margin.offset_bottom = -28
	margin.offset_left = 24
	margin.offset_right = -24
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 20
	scroll.follow_focus = true
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	_msg = _label("", 15, EMBER)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_msg)

	_status = VBoxContainer.new()
	_status.add_theme_constant_override("separation", 8)
	vbox.add_child(_status)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	vbox.add_child(_list)

	_rebuild()


func _rebuild() -> void:
	for c in _status.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	var active := CHALLENGES.active()
	var def := CHALLENGES.active_def()
	if not active.is_empty() and not def.is_empty():
		_status.add_child(_active_card(active, def))
	for d in CHALLENGES.all():
		_list.add_child(_challenge_card(d, active))


func _active_card(active: Dictionary, def: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 132)
	p.add_theme_stylebox_override("panel", _sb(Color(0.10, 0.085, 0.05, 0.96), 16, 2, GOLD, 8))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.offset_top = 12
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	h.add_child(_icon("medal", 40.0, GOLD))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	info.add_child(_label("进行中：%s" % String(def.get("name", "挑战")), 20, GOLD_LIGHT, true))
	info.add_child(_label("胜 %d / %d   负 %d（输满 %d 场淘汰）" % [
		int(active.get("wins", 0)), int(def.get("target", 8)),
		int(active.get("losses", 0)), int(def.get("max_losses", 3))], 13, PARCHMENT))

	var abandon := Button.new()
	abandon.text = "放弃"
	abandon.focus_mode = Control.FOCUS_NONE
	abandon.custom_minimum_size = Vector2(96, 44)
	_style_secondary(abandon)
	abandon.pressed.connect(func():
		CHALLENGES.abandon()
		_msg.text = "已放弃当前挑战"
		_rebuild())
	h.add_child(abandon)
	return p


func _challenge_card(d: Dictionary, active: Dictionary) -> Control:
	var id := String(d.get("id", ""))
	var active_id := String(active.get("id", ""))
	var is_active := active_id == id
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 152)
	p.add_theme_stylebox_override("panel", _sb(Color(0.045, 0.065, 0.13, 0.9), 18, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.5) if is_active else Color(1, 1, 1, 0.10), 8))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.offset_top = 12
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(58, 58)
	badge.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.035, 0.075, 0.95), 29, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.4)))
	h.add_child(badge)
	var ic = ICON.new()
	ic.kind = String(d.get("icon", "medal"))
	ic.tint = GOLD
	ic.size = Vector2(30, 30)
	ic.position = Vector2(14, 14)
	badge.add_child(ic)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	h.add_child(info)
	info.add_child(_label(String(d.get("name", "")), 20, PARCHMENT, true))
	info.add_child(_label(String(d.get("desc", "")), 12, MUTED))
	info.add_child(_label("目标 %d 胜 · 奖励 %d 金币 + %d 宝石" % [
		int(d.get("target", 0)), int(d.get("reward_gold", 0)), int(d.get("reward_gems", 0))], 12, GOLD))

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	var cost := _label("宝石 %d 进入" % int(d.get("entry_gems", 0)), 13, Color(0.62, 0.80, 1.0))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(cost)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 46)
	if is_active:
		btn.text = "继续挑战"
		_style_primary(btn)
		btn.pressed.connect(func(): _continue_mode(String(d.get("mode_id", "standard"))))
	else:
		btn.text = "开始挑战"
		_style_primary(btn)
		var cid := id
		btn.pressed.connect(func(): _start_challenge(cid))
	right.add_child(btn)
	return p


func _start_challenge(id: String) -> void:
	var res := CHALLENGES.start(id)
	if not bool(res.get("ok", false)):
		_msg.text = String(res.get("msg", "无法开始挑战"))
		_rebuild()
		return
	var def: Dictionary = res.get("def", {})
	_continue_mode(String(def.get("mode_id", "standard")))


func _continue_mode(mode_id: String) -> void:
	var mode: Dictionary = BATTLE_MODES.get_by_id(mode_id)
	BATTLE_MODES.set_mode(mode)
	if String(mode.get("win_condition", "")) == "duel" or String(mode.get("deck", "")) == "duel":
		BATTLE_MODES.start_duel(_duel_player_decks(), _duel_enemy_decks())
	var deck := String(mode.get("deck", ""))
	if deck == "draft" or deck == "swap_draft":
		get_tree().change_scene_to_file("res://scenes/draft_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _duel_player_decks() -> Array:
	var out: Array = []
	for d in PlayerData.custom_decks:
		var arr: Array = []
		for cid in Array(d):
			if int(cid) > 0:
				arr.append(int(cid))
		if arr.size() >= 8:
			out.append(arr)
	while out.size() < 3:
		out.append([4, 8, 11, 9, 44, 10, 17, 71])
	return out.slice(0, 3)


func _duel_enemy_decks() -> Array:
	var classics: Array = BATTLE_MODES.classic_decks()
	classics.shuffle()
	var out: Array = []
	for i in range(3):
		out.append(Array(classics[i % classics.size()]).duplicate())
	return out


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _icon(kind: String, px: float, tint: Color) -> Control:
	var ic = ICON.new()
	ic.kind = kind
	ic.tint = tint
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	return ic


func _label(text: String, fs: int, color: Color, use_display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if use_display and _font != null:
		l.add_theme_font_override("font", _font)
	return l


func _style_primary(btn: Button) -> void:
	var sb := _sb(Color(0.93, 0.71, 0.28), 14, 2, GOLD_LIGHT, 6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", _sb(Color(0.98, 0.78, 0.34), 14, 2, Color(1, 0.96, 0.80), 8))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.80, 0.60, 0.22), 14, 2, GOLD_LIGHT, 4))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	btn.add_theme_font_size_override("font_size", 16)
	if _font != null:
		btn.add_theme_font_override("font", _font)


func _style_secondary(btn: Button) -> void:
	var sb := _sb(Color(0.07, 0.10, 0.19, 0.95), 14, 1, Color(1, 1, 1, 0.18))
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate()
	hv.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	btn.add_theme_color_override("font_color", PARCHMENT)
	btn.add_theme_font_size_override("font_size", 15)


func _sb(bg: Color, radius: int, border := 0, border_col := Color(0, 0, 0, 0), shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	return s
