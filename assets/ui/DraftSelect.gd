# assets/ui/DraftSelect.gd
# 选卡对战（Draft / Triple Draft）：每轮从 N 张候选里选 1 张，共 8 轮；AI 同步轮抽。
# 选完写入 BattleModes.draft_decks()，随后进入战斗。
extends Control

const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const EMBER := Color(1.0, 0.590, 0.300)

var _font: Font
var _choices := 4
var _round := 0
var _pool: Array = []
var _player: Array = []
var _enemy: Array = []
var _picked_row: HBoxContainer
var _progress: Label
var _choices_grid: GridContainer
var _configs: Dictionary = {}
var _busy := false


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	var env_mode := OS.get_environment("CR_MODE_ID")
	if env_mode != "":
		BATTLE_MODES.set_mode(BATTLE_MODES.get_by_id(env_mode))
	var mode := BATTLE_MODES.current()
	if String(mode.get("deck", "")) != "draft":
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	_choices = int(mode.get("draft_choices", 4))
	_load_configs()
	UiComponents.add_background(self)
	UiComponents.make_header(self, "选卡对战", _on_back, true)
	_build()
	_refresh()


func _load_configs() -> void:
	var bm = preload("res://scripts/core/BattleManager.gd").new()
	bm.load_card_configs()
	_pool.clear()
	for cfg in bm.configs:
		if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123:
			_configs[int(cfg.card_id)] = cfg
			_pool.append(int(cfg.card_id))
	bm.free()
	_pool.shuffle()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = UiComponents.HEADER_H + 12
	margin.offset_bottom = -190
	margin.offset_left = 24
	margin.offset_right = -24
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_progress = _label("", 20, GOLD_LIGHT, true)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_progress)

	var hint := _label("pick 一张加入卡组，对手也会同步选卡", 13, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	_choices_grid = GridContainer.new()
	_choices_grid.columns = 2 if _choices >= 4 else 3
	_choices_grid.add_theme_constant_override("h_separation", 14)
	_choices_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_choices_grid)

	# 底部已选卡组
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -172
	bottom.offset_bottom = -24
	bottom.add_theme_constant_override("separation", 6)
	add_child(bottom)
	var picked_title := _label("我的卡组（8 张）", 14, Color(0.86, 0.82, 0.70))
	bottom.add_child(picked_title)
	_picked_row = HBoxContainer.new()
	_picked_row.add_theme_constant_override("separation", 8)
	bottom.add_child(_picked_row)


func _refresh() -> void:
	_progress.text = "第 %d / 8 手 · %d 选 1" % [_round + 1, _choices]
	for c in _choices_grid.get_children():
		c.queue_free()
	var offer: Array = _draw_offer() if _round < 8 else []
	if _round < 8:
		for cid in offer:
			_choices_grid.add_child(_choice_tile(int(cid)))
	# 已选卡
	for c in _picked_row.get_children():
		c.queue_free()
	for cid in _player:
		_picked_row.add_child(_picked_mini(int(cid)))
	for i in range(8 - _player.size()):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(78, 100)
		slot.add_theme_stylebox_override("panel", _sb(Color(0.03, 0.05, 0.10, 0.8), 10, 1, Color(1, 1, 1, 0.10)))
		_picked_row.add_child(slot)
	var auto := OS.get_environment("CR_DRAFT_AUTO")
	if auto != "" and _round < 8 and not _busy:
		_busy = true
		call_deferred("_auto_pick", offer)


func _draw_offer() -> Array:
	var remaining: Array = []
	for cid in _pool:
		if not _player.has(cid) and not _enemy.has(cid):
			remaining.append(cid)
	var offer: Array = []
	for cid in remaining:
		if offer.size() >= _choices:
			break
		offer.append(cid)
	return offer


func _auto_pick(offer: Array) -> void:
	await get_tree().create_timer(0.1).timeout
	_busy = false
	if offer.is_empty():
		return
	_pick(int(offer[randi() % offer.size()]))


func _choice_tile(cid: int) -> Control:
	var cfg = _configs.get(cid)
	if cfg == null:
		return Control.new()
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(352, 300)
	btn.add_theme_stylebox_override("normal", _sb(Color(0.04, 0.06, 0.12, 0.92), 18, 1, Color(1, 1, 1, 0.14), 8))
	btn.add_theme_stylebox_override("hover", _sb(Color(0.09, 0.12, 0.24, 0.96), 18, 2, GOLD, 12))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.03, 0.04, 0.09, 0.96), 18, 2, GOLD, 6))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 18))
	btn.pressed.connect(func(): _pick(cid))

	var art := _art(cfg)
	var tex := TextureRect.new()
	tex.texture = art
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.position = Vector2(18, 14)
	tex.size = Vector2(316, 214)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex)

	var cost_badge := Panel.new()
	cost_badge.position = Vector2(12, 10)
	cost_badge.size = Vector2(40, 40)
	cost_badge.add_theme_stylebox_override("panel", _sb(Color(0.30, 0.18, 0.55, 0.95), 20, 2, GOLD_LIGHT))
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cost_badge)
	var cost_lbl := _label(str(int(cfg.cost)), 20, Color.WHITE, true)
	cost_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)

	var name_plate := Panel.new()
	name_plate.position = Vector2(0, 238)
	name_plate.size = Vector2(352, 52)
	name_plate.add_theme_stylebox_override("panel", _sb(Color(0.015, 0.025, 0.055, 0.94), 12, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.35)))
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_plate)
	var name_lbl := _label(String(cfg.card_name), 20, GOLD_LIGHT, true)
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_plate.add_child(name_lbl)
	UiComponents.hover_scale(btn, 1.02)
	return btn


func _picked_mini(cid: int) -> Control:
	var cfg = _configs.get(cid)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(78, 100)
	p.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.07, 0.14, 0.95), 10, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.45)))
	var tex := TextureRect.new()
	tex.texture = _art(cfg)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.position = Vector2(5, 4)
	tex.size = Vector2(68, 66)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)
	var l := _label(String(cfg.card_name) if cfg else "", 10, PARCHMENT)
	l.position = Vector2(0, 74)
	l.size = Vector2(78, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


func _art(cfg) -> Texture2D:
	if cfg == null:
		return null
	var path := "res://assets/cards_rendered/%s.png" % String(cfg.card_name)
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _pick(cid: int) -> void:
	if _round >= 8:
		return
	_player.append(cid)
	# AI 同步取一张（避开玩家已选）
	var remaining: Array = []
	for x in _pool:
		if not _player.has(x) and not _enemy.has(x):
			remaining.append(x)
	if remaining.size() > 0:
		_enemy.append(int(remaining[randi() % remaining.size()]))
	else:
		_enemy.append(cid)
	_round += 1
	if _round >= 8:
		_finish_draft()
		return
	_refresh()


func _finish_draft() -> void:
	BATTLE_MODES.set_draft_decks(_player, _enemy)
	_progress.text = "选卡完成，准备开战…"
	for c in _choices_grid.get_children():
		c.queue_free()
	await get_tree().create_timer(0.55).timeout
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


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
