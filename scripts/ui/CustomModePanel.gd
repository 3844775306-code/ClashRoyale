extends VBoxContainer
# 自定义派对规则面板：圣水、突然死亡、等级、卡组来源、胜利条件、特种兵。

const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
const BATTLE_MANAGER_SCRIPT := preload("res://scripts/core/BattleManager.gd")
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
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 34)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 12)
	opt.add_item("随机（每局）")
	opt.set_item_metadata(0, 0)
	var current_id: int = int(_cfg.get("commando_card_id", 0))
	var selected_idx := 0
	var cards: Array = _commando_cards_list()
	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		opt.add_item(String(c.name))
		opt.set_item_metadata(i + 1, int(c.id))
		if int(c.id) == current_id:
			selected_idx = i + 1
	opt.select(selected_idx)
	opt.disabled = not editable
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.13, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	opt.add_theme_stylebox_override("normal", sb)
	opt.add_theme_stylebox_override("hover", sb)
	opt.add_theme_stylebox_override("pressed", sb)
	opt.item_selected.connect(func(idx):
		var cid: int = int(opt.get_item_metadata(idx))
		_apply_value("commando_card_id", cid))
	h.add_child(opt)
	add_child(h)


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
