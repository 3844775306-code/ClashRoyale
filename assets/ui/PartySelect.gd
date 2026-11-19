# assets/ui/PartySelect.gd
# 派对模式入口：列出派对规则（双/三/七倍圣水、突然死亡、冲线），可配置派对专用卡组
extends Control

const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
const CUSTOM_PANEL := preload("res://scripts/ui/CustomModePanel.gd")

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const EMBER := Color(1.0, 0.590, 0.300)

var _font: Font
var _list: VBoxContainer
var _custom: Dictionary = {"elixir": 2.0, "sudden_death": false, "level": "fixed"}
var _selected_custom := false


func _ready() -> void:
	_custom = BATTLE_MODES.custom_config()
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	UiComponents.add_background(self)
	UiComponents.make_header(self, "派对模式", _on_back, true)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = UiComponents.HEADER_H + 12
	margin.offset_bottom = -32
	margin.offset_left = 24
	margin.offset_right = -24
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vbox.add_child(head)
	var info := _label("派对模式：特殊规则合集；除经典卡组/选卡外，卡牌与皇家塔固定 11 级并使用派对卡组", 13, MUTED)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(info)
	var deck_btn := Button.new()
	deck_btn.text = "配置派对卡组"
	deck_btn.focus_mode = Control.FOCUS_NONE
	deck_btn.custom_minimum_size = Vector2(180, 46)
	_style_secondary(deck_btn)
	deck_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/party_deck.tscn"))
	head.add_child(deck_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	for mode in BATTLE_MODES.all():
		var mid := String(mode.get("id", ""))
		if mid == "standard" or mid == "custom":
			continue
		_list.add_child(_mode_row(mode))
	_build_custom_panel(vbox)


func _mode_row(mode: Dictionary) -> Control:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 100)
	btn.add_theme_stylebox_override("normal", _sb(Color(0.045, 0.065, 0.13, 0.86), 18, 1, Color(1, 1, 1, 0.10), 8))
	btn.add_theme_stylebox_override("hover", _sb(Color(0.075, 0.105, 0.21, 0.95), 18, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 10))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.03, 0.045, 0.09, 0.95), 18, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 6))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 18))
	btn.pressed.connect(func(): _start_mode(String(mode.get("id", "double_elixir"))))

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.035, 0.075, 0.95), 28, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.4)))
	h.add_child(badge)
	var ic = ICON.new()
	ic.kind = String(mode.get("icon", "flask"))
	ic.tint = GOLD
	ic.size = Vector2(30, 30)
	ic.position = Vector2(13, 13)
	badge.add_child(ic)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(texts)
	texts.add_child(_label(String(mode.get("name", "")), 21, PARCHMENT, true))
	texts.add_child(_label(String(mode.get("desc", "")), 12, MUTED))

	var rules := BATTLE_MODES.mode_label(mode)
	var r := _label(rules if rules != "" else "派对规则", 12, EMBER)
	r.custom_minimum_size = Vector2(160, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	var chev = ICON.new()
	chev.kind = "chevron"
	chev.tint = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	chev.custom_minimum_size = Vector2(16, 16)
	chev.size = Vector2(16, 16)
	h.add_child(chev)
	return btn


func _build_custom_panel(root: VBoxContainer) -> void:
	var panel = CUSTOM_PANEL.new()
	panel.editable = true
	panel.changed.connect(func(cfg):
		_custom = cfg.duplicate(true))
	root.add_child(panel)
	var start := Button.new()
	start.text = "使用自定义规则开战"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(0, 48)
	_style_primary(start)
	start.pressed.connect(_start_custom)
	root.add_child(start)

func _start_custom() -> void:
	BATTLE_MODES.set_custom_config(_custom)
	var mode: Dictionary = BATTLE_MODES.get_by_id("custom")
	BATTLE_MODES.set_mode(mode)
	var deck := String(mode.get("deck", "custom"))
	if deck == "draft" or deck == "swap_draft":
		get_tree().change_scene_to_file("res://scenes/draft_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _start_mode(id: String) -> void:
	var mode: Dictionary = BATTLE_MODES.get_by_id(id)
	BATTLE_MODES.set_mode(mode)
	if String(mode.get("win_condition", "")) == "duel" or String(mode.get("deck", "")) == "duel":
		BATTLE_MODES.start_duel(_duel_player_decks(), _duel_enemy_decks())
	var deck := String(mode.get("deck", ""))
	if deck == "draft" or deck == "swap_draft":
		get_tree().change_scene_to_file("res://scenes/draft_select.tscn")
		return
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


func _label(text: String, fs: int, color: Color, use_display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if use_display and _font != null:
		l.add_theme_font_override("font", _font)
	return l


func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.71, 0.28), 14, 2, GOLD_LIGHT, 6))
	btn.add_theme_stylebox_override("hover", _sb(Color(0.98, 0.78, 0.34), 14, 2, Color(1, 0.96, 0.80), 8))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.80, 0.60, 0.22), 14, 2, GOLD_LIGHT, 4))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	btn.add_theme_font_size_override("font_size", 17)
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
