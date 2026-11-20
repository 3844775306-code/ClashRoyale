extends VBoxContainer
# 自定义派对规则面板：圣水、突然死亡、等级、卡组来源、胜利条件、特种兵。

const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
const BATTLE_MANAGER_SCRIPT := preload("res://scripts/core/BattleManager.gd")
const COMMANDO_PICKER := preload("res://scripts/ui/CommandoCardPicker.gd")
static var _commando_cards: Array = []
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)

signal changed(cfg: Dictionary)

var editable: bool = true
var _cfg: Dictionary = {}

func _ready() -> void:
	_cfg = BATTLE_MODES.custom_config()
	add_theme_constant_override("separation", 8)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	add_child(_title("自定义派对规则"))
	_row("圣水", "elixir", [[1.0, "1x"], [2.0, "2x"], [3.0, "3x"], [7.0, "7x"]])
	_row("突然死亡", "sudden_death", [[false, "关"], [true, "开"]])
	_row("等级", "level", [["own", "玩家等级"], ["fixed", "固定 11 级"]])
	_row("卡组", "deck", [["custom", "自定义"], ["classic", "经典"], ["draft", "选卡"], ["swap_draft", "双向"], ["mirror", "镜像"], ["mega", "18 卡"]])
	_row("胜利", "win_condition", [["", "摧毁"], ["touchdown", "冲线"]])
	_row("特种兵", "commando", [[false, "关"], [true, "开"]])
	if bool(_cfg.get("commando", false)):
		_commando_picker()
	if String(_cfg.get("deck", "custom")) == "draft" or String(_cfg.get("deck", "")) == "swap_draft":
		_row("选卡数", "draft_choices", [[2, "2选1"], [3, "3选1"], [4, "4选1"]])

func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", GOLD_LIGHT)
	return l

func _row(label: String, key: String, options: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(66, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", PARCHMENT)
	h.add_child(l)
	var current = _cfg.get(key)
	for opt in options:
		var val = opt[0]
		var b := Button.new()
		b.text = String(opt[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 34)
		b.add_theme_font_size_override("font_size", 12)
		var active: bool = _same(current, val)
		b.add_theme_color_override("font_color", GOLD_LIGHT if active else MUTED)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.09, 0.04, 0.98) if active else Color(0.05, 0.07, 0.13, 0.95)
		sb.border_color = GOLD if active else Color(1, 1, 1, 0.15)
		sb.set_border_width_all(2 if active else 1)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.disabled = not editable
		b.pressed.connect(_apply_value.bind(key, val))
		h.add_child(b)
	add_child(h)

func _commando_cards_list() -> Array:
	if not _commando_cards.is_empty():
		return _commando_cards
	var bm = BATTLE_MANAGER_SCRIPT.new()
	bm.load_card_configs()
	for cfg in bm.configs:
		if cfg == null or int(cfg.card_id) < 4 or int(cfg.card_id) == 123:
			continue
		if float(cfg.cost) <= 0.0:
			continue
		if int(cfg.type) == Config.UnitType.BUILDING:
			continue
		if bm._is_spell_like(int(cfg.card_id)):
			continue
		_commando_cards.append({"id": int(cfg.card_id), "name": String(cfg.card_name)})
	bm.free()
	_commando_cards.sort_custom(func(a, b): return int(a.id) < int(b.id))
	return _commando_cards


func _commando_picker() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "兵种"
	l.custom_minimum_size = Vector2(66, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", PARCHMENT)
	h.add_child(l)

	var current_id: int = int(_cfg.get("commando_card_id", 0))
	var current_name := "随机（每局）"
	for c in _commando_cards_list():
		if int(c.get("id", 0)) == current_id:
			current_name = String(c.get("name", current_name))
			break

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 58)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not editable
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.065, 0.13, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.945, 0.765, 0.36, 0.55)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.075, 0.10, 0.19, 0.98)
	hover.border_color = Color(0.945, 0.765, 0.36, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_open_commando_picker)
	h.add_child(btn)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(38, 48)
	tex.size = Vector2(38, 48)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if current_id > 0:
		var path := "res://assets/cards_web/%s.png" % current_name
		if not ResourceLoader.exists(path):
			path = "res://assets/cards_rendered/%s.png" % current_name
		if ResourceLoader.exists(path):
			tex.texture = load(path)
	row.add_child(tex)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 0)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)
	var nm := Label.new()
	nm.text = current_name
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", PARCHMENT)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(nm)
	var sub := Label.new()
	sub.text = "点击选择官方卡图兵种" if current_id > 0 else "每局从全部兵种随机"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", MUTED)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(sub)
	var arrow := Label.new()
	arrow.text = "选择 ›"
	arrow.add_theme_font_size_override("font_size", 12)
	arrow.add_theme_color_override("font_color", GOLD_LIGHT)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	add_child(h)


func _open_commando_picker() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var picker = COMMANDO_PICKER.new()
	picker.setup(_commando_cards_list(), int(_cfg.get("commando_card_id", 0)), func(cid):
		_apply_value("commando_card_id", cid))
	scene.add_child(picker)


func _same(a, b) -> bool:
	if a is float or b is float:
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)

func _apply_value(key: String, val) -> void:
	_cfg[key] = val
	if key == "deck":
		_cfg["draft_choices"] = 4 if String(val) != "swap_draft" else 2
		_cfg["draft_picks"] = 8 if String(val) != "swap_draft" else 4
	BATTLE_MODES.set_custom_config(_cfg)
	changed.emit(_cfg.duplicate(true))
	_rebuild()
