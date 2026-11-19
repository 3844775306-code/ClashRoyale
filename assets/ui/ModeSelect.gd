# assets/ui/ModeSelect.gd
# 对战模式选择：标准 / 双倍 / 三倍 / 七倍圣水 / 突然死亡 / 经典卡组 / 友谊战自定义
extends Control

const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
const CUSTOM_PANEL := preload("res://scripts/ui/CustomModePanel.gd")

const INK := Color(0.020, 0.030, 0.062)
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const EMBER := Color(1.0, 0.590, 0.300)

var _font: Font
var _modes: Array = []
var _selected_id: String = "standard"
var _custom: Dictionary = {"elixir": 1.0, "sudden_death": false, "level": "own"}
var _list: VBoxContainer
var _custom_box: VBoxContainer


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_modes = BATTLE_MODES.all()
	_selected_id = BATTLE_MODES.current_id()
	var env_sel := OS.get_environment("CR_SELECT_MODE")
	if env_sel != "":
		_selected_id = env_sel
	_custom = BATTLE_MODES.custom_config()
	UiComponents.add_background(self)
	UiComponents.make_header(self, "对战模式", _on_back, true)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = UiComponents.HEADER_H + 12
	margin.offset_bottom = -104
	margin.offset_left = 26
	margin.offset_right = -26
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	margin.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	_rebuild_list()

	# 底部开始按钮
	var holder := Control.new()
	holder.anchor_left = 0.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = 26
	holder.offset_right = -26
	holder.offset_top = -92
	holder.offset_bottom = -30
	add_child(holder)

	var start := Button.new()
	start.focus_mode = Control.FOCUS_NONE
	start.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.71, 0.28), 22, 2, GOLD_LIGHT, 10))
	start.add_theme_stylebox_override("hover", _sb(Color(0.98, 0.78, 0.34), 22, 2, Color(1, 0.96, 0.80), 12))
	start.add_theme_stylebox_override("pressed", _sb(Color(0.80, 0.60, 0.22), 22, 2, GOLD_LIGHT, 8))
	start.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 22))
	start.pressed.connect(_on_start)
	holder.add_child(start)
	var t := _label("开始对战", 28, Color(0.19, 0.11, 0.02), true)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start.add_child(t)


func _rebuild_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	for m in _modes:
		if bool(m.get("party", false)):
			continue
		_list.add_child(_mode_row(m))
	if _selected_id == "custom":
		_custom_box = VBoxContainer.new()
		_custom_box.add_theme_constant_override("separation", 8)
		_list.add_child(_custom_box)
		_build_custom_options(_custom_box)


func _mode_row(m: Dictionary) -> Control:
	var id := String(m.get("id", ""))
	var selected := id == _selected_id
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 104)
	var normal := _sb(Color(0.045, 0.065, 0.13, 0.84), 18, 1, Color(1, 1, 1, 0.10), 8)
	var hover := _sb(Color(0.075, 0.105, 0.21, 0.95), 18, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 10)
	var chosen := _sb(Color(0.10, 0.085, 0.055, 0.96), 18, 2, GOLD, 12)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", normal)
	card.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 18))
	card.pressed.connect(func(): _select(id))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -16
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(58, 58)
	badge.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.035, 0.075, 0.95), 29, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.4 if selected else 0.22)))
	hbox.add_child(badge)
	var ic = ICON.new()
	ic.kind = String(m.get("icon", "sword"))
	ic.tint = GOLD if selected else Color(0.80, 0.82, 0.88)
	ic.size = Vector2(30, 30)
	ic.position = Vector2(14, 14)
	badge.add_child(ic)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(texts)
	var name_lbl := _label(String(m.get("name", "")), 21, GOLD_LIGHT if selected else PARCHMENT, true)
	texts.add_child(name_lbl)
	texts.add_child(_label(String(m.get("desc", "")), 12, MUTED))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(172, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)
	var rules := BATTLE_MODES.mode_label(m)
	if rules != "":
		var r := _label(rules, 12, EMBER)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.custom_minimum_size = Vector2(172, 0)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(r)
	var chev = ICON.new()
	chev.kind = "chevron"
	chev.tint = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	chev.size = Vector2(16, 16)
	chev.custom_minimum_size = Vector2(16, 16)
	right.add_child(chev)

	if selected:
		var corner := Panel.new()
		corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var csb := _sb(Color(0, 0, 0, 0), 18, 1, GOLD_LIGHT)
		corner.add_theme_stylebox_override("panel", csb)
		card.add_child(corner)
	return card


func _build_custom_options(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()
	var panel = CUSTOM_PANEL.new()
	panel.editable = true
	panel.changed.connect(func(cfg):
		_custom = cfg.duplicate(true))
	box.add_child(panel)

func _option_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(label_text, 15, PARCHMENT)
	l.custom_minimum_size = Vector2(96, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


func _toggle_button(text: String, active: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.custom_minimum_size = Vector2(88, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", GOLD_LIGHT if active else MUTED)
	var on := _sb(Color(0.14, 0.10, 0.045, 0.95), 14, 2, GOLD)
	var off := _sb(Color(0.05, 0.07, 0.13, 0.9), 14, 1, Color(1, 1, 1, 0.16))
	b.add_theme_stylebox_override("normal", on if active else off)
	b.add_theme_stylebox_override("hover", on if active else off)
	b.add_theme_stylebox_override("pressed", on if active else off)
	b.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	return b


func _select(id: String) -> void:
	_selected_id = id
	_rebuild_list()


func _on_start() -> void:
	var mode := BATTLE_MODES.get_by_id(_selected_id)
	if bool(mode.get("custom", false)):
		BATTLE_MODES.set_custom_config(_custom)
		mode = BATTLE_MODES.current()
	BATTLE_MODES.set_mode(mode)
	if String(mode.get("win_condition", "")) == "duel":
		BATTLE_MODES.start_duel(_duel_player_decks(), _duel_enemy_decks())
	var deck_src := String(mode.get("deck", "custom"))
	if deck_src == "draft":
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
			if out.size() >= 3:
				break
	while out.size() < 3:
		out.append(PlayerData.get_active_deck().duplicate())
	return out


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
