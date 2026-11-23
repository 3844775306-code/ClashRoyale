extends Control

const TILE = preload("res://scripts/ui/DeckCardTile.gd")
const DETAIL = preload("res://scripts/ui/CardDetailDialog.gd")
const TVIEW = preload("res://scripts/visuals/CardVisualCatalog.gd")
const TUMK = preload("res://scripts/visuals/UnitModelKit.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const TOWER_CATALOG = preload("res://scripts/data/TowerCatalog.gd")

const CLASSIC_DECKS := {
	"速弩": [55, 21, 4, 44, 11, 91, 20, 119],
	"速猪": [17, 71, 35, 39, 20, 11, 61, 91],
	"速转": [70, 22, 39, 20, 11, 91, 119, 61],
	"天狗": [82, 25, 8, 11, 20, 24, 5, 10],
	"石头人": [92, 37, 59, 36, 24, 107, 20, 104],
	"野猪骑士": [17, 12, 71, 35, 11, 91, 21, 119],
	"墓园": [85, 4, 107, 91, 35, 19, 24, 11],
	"飞桶": [40, 121, 67, 4, 91, 77, 33, 39],
}

var _all_cards: Array = []
var _cfgs: Dictionary = {}
var _party_edit := false
var _spell_ids: Array = []
var _decks: Array = []
var _idx: int = 0
var _slots: Array = []
var _tile_map: Dictionary = {}
var _tab_buttons: Array = []
var _table_grid: GridContainer
var _pool_grid: GridContainer
var _search: LineEdit
var _status: Label
var _avg: Label
var _table_count: Label
var _pool_count: Label
var _use_custom: CheckButton
var _classic_btn: Button
var _classic_menu: PopupMenu
var _action_frame
var _action_tile: DeckCardTile
var _filter_mode: String = "all"
var _owned_grid: GridContainer
var _locked_grid: GridContainer
var _pool_box: VBoxContainer
var _lock_divider: Control
var _top_info: Label
var _sort_mode: String = "level"
var _sort_menu: PopupMenu
var _filter_buttons: Dictionary = {}
var _upgrade_overlay: Control = null
var _wild_confirm_overlay: Control = null
var _tower_btns: Array = []
var _tower_preview_choice: int = 1
var _tower_tabs: Array = []
var _tower_sub: SubViewport
var _tower_model_root: Node3D
var _tower_select_btn: Button
var _tower_special_lbl: Label
var _tower_stat_grid: GridContainer
var _tower_model_frame: Control
var _data_stamp: String = ""

func _ready():
	_party_edit = bool(get_meta("party_edit", false))
	TILE.party_preview = _party_edit
	_data_stamp = _csv_stamp()
	_apply_text_theme()
	UiComponents.add_background(self)
	_load_cards()
	if _party_edit:
		_decks = [PlayerData.party_deck.duplicate()]
		while _decks.size() < 5:
			_decks.append([])
		_idx = 0
	else:
		_decks = PlayerData.custom_decks.duplicate(true)
		while _decks.size() < 5:
			_decks.append([])
		_idx = clampi(PlayerData.active_deck_index, 0, 4)
	_slots = _pad_deck(_decks[_idx])
	_sort_mode = String(PlayerData.deck_sort_mode)
	if _sort_mode not in ["level", "rarity", "arena", "default"]:
		_sort_mode = "level"
	_build_ui()
	_apply_sort()

func _csv_stamp() -> String:
	var s := ""
	for path in ["res://data/units_level11_utf8.csv", "res://data/units_level11.csv"]:
		if FileAccess.file_exists(path):
			s += "%s:%d|" % [path, FileAccess.get_modified_time(path)]
	return s

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree() and _data_stamp != "":
		if _csv_stamp() != _data_stamp:
			get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if _tower_model_root:
		_tower_model_root.rotation.y += delta * 0.35


func _apply_text_theme() -> void:
	var th := Theme.new()
	var font_res := load("res://assets/fonts/STZHONGS.TTF")
	if font_res:
		var fv := FontVariation.new()
		fv.base_font = font_res
		fv.variation_embolden = 0.72
		th.default_font = fv
	th.default_font_size = 16
	# 借鉴战场单位 Label：白字 + 深色粗描边
	th.set_color("font_color", "Label", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Label", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Button", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Button", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Button", 3)
	theme = th

func _is_available(cid: int) -> bool:
	if _party_edit:
		return true
	return PlayerData.is_card_owned(cid)


func _load_cards():
	var bm = preload("res://scripts/core/BattleManager.gd").new()
	bm.load_card_configs()
	_spell_ids = bm.SPELL_IDS.duplicate()
	for cfg in bm.configs:
		if cfg.card_id < 4:
			continue
		if not (cfg.cost > 0 or cfg.card_id == 123):
			continue
		_all_cards.append(cfg)
		_cfgs[cfg.card_id] = cfg
	bm.free()
	_all_cards.sort_custom(func(a, b): return a.card_id < b.card_id)

func _pad_deck(src: Array) -> Array:
	var out: Array = []
	for cid in src:
		var c: int = int(cid)
		if _cfgs.has(c) and _is_available(c) and not out.has(c):
			out.append(c)
		if out.size() >= 8:
			break
	while out.size() < 8:
		out.append(-1)
	return out

func _build_ui():
	# 统一顶部栏
	UiComponents.make_header(self, "派对卡组" if _party_edit else "卡组配置", _on_back, true)
	_top_info = Label.new()
	_top_info.visible = false
	_update_top_info()

	# 顶部操作
	var top := HBoxContainer.new()
	top.position = Vector2(30, 70)
	top.size = Vector2(740, 38)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var mode_lbl := Label.new()
	mode_lbl.text = "派对模式使用此卡组（全卡 · 固定 11 级）" if _party_edit else ("🧪 测试模式：随机全卡 · 固定 11 级" if PlayerData.test_mode else "对战时使用当前卡组")
	mode_lbl.add_theme_font_size_override("font_size", 16)
	mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35) if PlayerData.test_mode else ThemeHelper.COLORS.text_muted)
	top.add_child(mode_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_tool_btn("保存", _on_save, Color(0.90, 0.68, 0.24)))
	top.add_child(_tool_btn("返回", _on_back, Color(0.42, 0.50, 0.68)))

	# 1-5 卡组标签
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(30, 114)
	tabs.size = Vector2(740, 50)
	tabs.add_theme_constant_override("separation", 8)
	tabs.visible = not _party_edit
	add_child(tabs)
	_tab_buttons.clear()
	for i in range(5):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		_color_btn(b, Color(0.38, 0.56, 0.84))
		b.pressed.connect(_on_tab_pressed.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var anim_btn := Button.new()
	anim_btn.text = "🎬 配置动画"
	anim_btn.focus_mode = Control.FOCUS_NONE
	anim_btn.custom_minimum_size = Vector2(132, 50)
	anim_btn.add_theme_font_size_override("font_size", 13)
	_color_btn(anim_btn, Color(0.66, 0.46, 0.94))
	anim_btn.pressed.connect(_open_animation_studio)
	tabs.add_child(anim_btn)

	# 卡桌
	var table_panel := Panel.new()
	table_panel.position = Vector2(30, 172)
	table_panel.size = Vector2(740, 540)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.075, 0.065, 0.11, 0.94)
	psb.border_color = Color(0.52, 0.40, 0.18)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(18)
	psb.shadow_color = Color(0, 0, 0, 0.35)
	psb.shadow_size = 8
	table_panel.add_theme_stylebox_override("panel", psb)
	add_child(table_panel)
	var table_title := Label.new()
	table_title.text = "出战卡组"
	table_title.position = Vector2(16, 8)
	table_title.add_theme_font_size_override("font_size", 20)
	table_title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	table_panel.add_child(table_title)
	_table_count = Label.new()
	_table_count.position = Vector2(122, 12)
	_table_count.add_theme_font_size_override("font_size", 14)
	_table_count.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	table_panel.add_child(_table_count)
	_table_grid = GridContainer.new()
	_table_grid.position = Vector2(12, 38)
	_table_grid.size = Vector2(716, 444)
	_table_grid.columns = 4
	_table_grid.add_theme_constant_override("h_separation", 8)
	_table_grid.add_theme_constant_override("v_separation", 8)
	table_panel.add_child(_table_grid)

	# 平均圣水徽章（卡桌右下角）
	var avg_box := PanelContainer.new()
	avg_box.position = Vector2(518, 494)
	avg_box.size = Vector2(206, 32)
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.24, 0.15, 0.36, 0.95)
	asb.border_color = Color(0.62, 0.44, 0.90)
	asb.set_border_width_all(1)
	asb.set_corner_radius_all(16)
	avg_box.add_theme_stylebox_override("panel", asb)
	table_panel.add_child(avg_box)
	_avg = Label.new()
	_avg.text = "⚡ 平均圣水 0.00"
	_avg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avg.add_theme_font_size_override("font_size", 14)
	_avg.add_theme_color_override("font_color", Color(0.88, 0.76, 1.0))
	avg_box.add_child(_avg)

	_build_tower_section()

	# 工具栏
	var tools := HBoxContainer.new()
	tools.position = Vector2(30, 720)
	tools.size = Vector2(740, 42)
	tools.add_theme_constant_override("separation", 6)
	add_child(tools)
	tools.add_child(_tool_btn("📋 复制", _on_copy, Color(0.30, 0.56, 0.95)))
	tools.add_child(_tool_btn("🗑 清空", _on_clear, Color(0.88, 0.30, 0.30)))
	tools.add_child(_tool_btn("📥 粘贴", _on_paste, Color(0.24, 0.72, 0.68)))
	tools.add_child(_tool_btn("🎲 随机", _on_random, Color(0.92, 0.56, 0.20)))
	_classic_btn = _tool_btn("⭐ 经典", _on_classic_popup, Color(0.86, 0.68, 0.24))
	tools.add_child(_classic_btn)
	tools.add_child(_tool_btn("↕ 排序", _on_sort_popup, Color(0.62, 0.44, 0.92)))
	_sort_menu = PopupMenu.new()
	add_child(_sort_menu)
	_sort_menu.add_item("默认顺序", 0)
	_sort_menu.add_item("等级（高→低）", 1)
	_sort_menu.add_item("稀有度（高→低）", 2)
	_sort_menu.add_item("竞技场（低→高）", 3)
	_sort_menu.id_pressed.connect(_on_sort_selected)
	_classic_menu = PopupMenu.new()
	add_child(_classic_menu)
	var mi := 0
	for name in CLASSIC_DECKS.keys():
		_classic_menu.add_item(String(name), mi)
		mi += 1
	_classic_menu.id_pressed.connect(_on_classic_selected)

	# 搜索 + 筛选
	_search = LineEdit.new()
	_search.position = Vector2(30, 770)
	_search.size = Vector2(424, 40)
	_search.placeholder_text = "🔍 搜索卡牌名称…"
	_search.add_theme_font_size_override("font_size", 17)
	_search.text_changed.connect(_on_search)
	add_child(_search)
	var chips := HBoxContainer.new()
	chips.position = Vector2(466, 770)
	chips.size = Vector2(304, 40)
	chips.add_theme_constant_override("separation", 6)
	add_child(chips)
	var chip_colors := {"all": Color(0.86, 0.68, 0.24), "unit": Color(0.34, 0.68, 0.38), "spell": Color(0.62, 0.44, 0.92), "building": Color(0.72, 0.48, 0.24)}
	for item in [["all", "全部"], ["unit", "单位"], ["spell", "法术"], ["building", "建筑"]]:
		var cb := Button.new()
		cb.text = String(item[1])
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 38)
		cb.add_theme_font_size_override("font_size", 15)
		_color_btn(cb, chip_colors[String(item[0])])
		cb.pressed.connect(_on_filter_pressed.bind(String(item[0])))
		chips.add_child(cb)
		_filter_buttons[String(item[0])] = cb

	_pool_count = Label.new()
	# 锚定在底部卡池上方：手机长屏拉伸时不会与卡牌栏拉开固定距离
	_pool_count.anchor_left = 0.0
	_pool_count.anchor_right = 0.0
	_pool_count.anchor_top = 1.0
	_pool_count.anchor_bottom = 1.0
	_pool_count.offset_left = 30
	_pool_count.offset_right = 330
	_pool_count.offset_top = -556
	_pool_count.offset_bottom = -536
	_pool_count.add_theme_font_size_override("font_size", 14)
	_pool_count.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	add_child(_pool_count)

	# 卡池
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 30
	scroll.offset_right = -30
	scroll.offset_top = -532
	scroll.offset_bottom = -54
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.scroll_deadzone = 24
	scroll.follow_focus = true
	add_child(scroll)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): _close_actions())
	_pool_box = VBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 8)
	_pool_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_pool_box)
	_owned_grid = _make_pool_grid()
	_pool_box.add_child(_owned_grid)
	_lock_divider = PanelContainer.new()
	_lock_divider.custom_minimum_size = Vector2(0, 34)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.10, 0.08, 0.06, 0.9)
	dsb.border_color = Color(0.52, 0.40, 0.22)
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(10)
	_lock_divider.add_theme_stylebox_override("panel", dsb)
	var dlbl := Label.new()
	dlbl.text = "🔒 未获得的卡牌（获得后解锁）"
	dlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dlbl.add_theme_font_size_override("font_size", 13)
	dlbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_lock_divider.add_child(dlbl)
	_pool_box.add_child(_lock_divider)
	_locked_grid = _make_pool_grid()
	_pool_box.add_child(_locked_grid)
	for cfg in _all_cards:
		var tile = TILE.new()
		tile.setup(cfg, "pool")
		tile.clicked.connect(_on_tile_clicked)
		_tile_map[cfg.card_id] = tile
		if _is_available(cfg.card_id):
			_owned_grid.add_child(tile)
		else:
			_locked_grid.add_child(tile)

	# 状态提示
	var status_box := PanelContainer.new()
	status_box.position = Vector2(190, 1552)
	status_box.size = Vector2(420, 34)
	var stsb := StyleBoxFlat.new()
	stsb.bg_color = Color(0.08, 0.07, 0.12, 0.92)
	stsb.border_color = Color(0.48, 0.38, 0.20)
	stsb.set_border_width_all(1)
	stsb.set_corner_radius_all(16)
	status_box.add_theme_stylebox_override("panel", stsb)
	add_child(status_box)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.95, 0.78, 0.40))
	status_box.add_child(_status)

	_render_table()
	_update_avg()
	_refresh_tabs()
	_apply_filters()

func _make_pool_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

func _update_top_info() -> void:
	if _top_info == null:
		return
	_top_info.text = "👑 国王塔 Lv.%d     💰 %d 金币     💎 %d 宝石" % [PlayerData.get_tower_level(), PlayerData.gold, PlayerData.gems]

func _tool_btn(text: String, action: Callable, color: Color = Color(0.55, 0.45, 0.25)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(112, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	_color_btn(b, color)
	b.pressed.connect(action)
	return b

var _style_cache: Dictionary = {}

func _gradient_style(color: Color, state: String) -> StyleBoxTexture:
	var key: String = color.to_html() + state
	if _style_cache.has(key):
		return _style_cache[key]
	var c: Color = color
	if state == "hover":
		c = color.lightened(0.12)
	elif state == "pressed":
		c = color.darkened(0.16)
	var n: int = 48
	var r: int = 14
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(n):
		var ty: float = float(y) / float(n - 1)
		for x in range(n):
			var inside: bool = true
			if x < r and y < r:
				inside = Vector2(r - x, r - y).length() <= float(r)
			elif x >= n - r and y < r:
				inside = Vector2(x - (n - r - 1), r - y).length() <= float(r)
			elif x < r and y >= n - r:
				inside = Vector2(r - x, y - (n - r - 1)).length() <= float(r)
			elif x >= n - r and y >= n - r:
				inside = Vector2(x - (n - r - 1), y - (n - r - 1)).length() <= float(r)
			if not inside:
				continue
			var col: Color = c.lightened(0.32 * (1.0 - ty)).darkened(0.34 * ty)
			var edge: bool = x < 2 or x >= n - 2 or y < 2 or y >= n - 2
			if edge:
				col = col.lightened(0.22)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = r
	sb.texture_margin_right = r
	sb.texture_margin_top = r
	sb.texture_margin_bottom = r
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_style_cache[key] = sb
	return sb

func _color_btn(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", _gradient_style(color, "normal"))
	b.add_theme_stylebox_override("hover", _gradient_style(color, "hover"))
	b.add_theme_stylebox_override("pressed", _gradient_style(color, "pressed"))
	b.add_theme_stylebox_override("disabled", _gradient_style(Color(0.34, 0.35, 0.40), "normal"))
	b.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	b.add_theme_constant_override("outline_size", 3)

func _on_tab_pressed(i: int):
	_switch_deck(i)

func _refresh_tabs():
	for i in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[i]
		var ids: Array = _slots if i == _idx else _decks[i]
		var avg: float = _avg_of(ids)
		b.text = "卡组 %d\n%.1f ⚡" % [i + 1, avg]
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", ThemeHelper.COLORS.gold if i == _idx else Color(0.76, 0.78, 0.88))

func _avg_of(ids: Array) -> float:
	var total: float = 0.0
	var count: int = 0
	for cid in ids:
		var c: int = int(cid)
		if c <= 0 or not _cfgs.has(c) or c == 123:
			continue
		total += float(_cfgs[c].cost)
		count += 1
	return total / float(count) if count > 0 else 0.0

func _switch_deck(i: int):
	_close_actions()
	_decks[_idx] = _slots.duplicate()
	_idx = i
	PlayerData.active_deck_index = i
	_slots = _pad_deck(_decks[_idx])
	_render_table()
	_update_avg()
	_refresh_tabs()
	_set_status("已切换到卡组 %d" % (_idx + 1))

func _render_table():
	_close_actions()
	for ch in _table_grid.get_children():
		ch.queue_free()
	for i in range(8):
		var cid: int = int(_slots[i])
		if cid > 0 and _cfgs.has(cid):
			var tile = TILE.new()
			tile.setup(_cfgs[cid], "deck", true)
			tile.clicked.connect(_on_tile_clicked)
			tile.set_in_deck(true)
			_table_grid.add_child(tile)
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(150, 206)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.055, 0.045, 0.08, 0.55)
			sb.border_color = Color(0.38, 0.32, 0.22)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(12)
			empty.add_theme_stylebox_override("panel", sb)
			var l := Label.new()
			l.text = "＋"
			l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 34)
			l.add_theme_color_override("font_color", Color(0.40, 0.36, 0.28))
			empty.add_child(l)
			_table_grid.add_child(empty)
	var n: int = 0
	for cid in _slots:
		if int(cid) > 0:
			n += 1
	_table_count.text = "%d/8" % n
	for cid in _tile_map.keys():
		_tile_map[cid].set_in_deck(_slots.has(cid))
	if _search != null:
		_apply_filters()

func _on_tile_clicked(tile: DeckCardTile):
	if tile != null:
		tile.clear_new_badge()
	if _action_tile == tile and _action_frame != null:
		_close_actions()
		return
	_close_actions()
	_action_tile = tile
	var r: Rect2 = tile.get_global_rect()
	_action_frame = Panel.new()
	_action_frame.z_index = 500
	_action_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.045, 0.085, 0.35)
	sb.border_color = ThemeHelper.COLORS.gold
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	_action_frame.add_theme_stylebox_override("panel", sb)
	add_child(_action_frame)
	_action_frame.position = Vector2(r.position.x - 4, r.position.y - 4)
	_action_frame.size = Vector2(r.size.x + 8, r.size.y + 88)
	var cid: int = tile.config.card_id
	# 第一排：使用/卸下 + 详情
	var bar1 := HBoxContainer.new()
	bar1.position = Vector2(4, r.size.y + 8)
	bar1.size = Vector2(_action_frame.size.x - 8, 34)
	bar1.add_theme_constant_override("separation", 4)
	bar1.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_frame.add_child(bar1)
	if tile.mode == "pool":
		bar1.add_child(_action_btn("使用", func(): _close_actions(); _on_pool_use(cid), Color(0.32, 0.76, 0.42)))
	else:
		bar1.add_child(_action_btn("卸下", func(): _close_actions(); _on_deck_remove(cid), Color(0.90, 0.36, 0.32)))
	bar1.add_child(_action_btn("详情", func(): _close_actions(); _on_detail(cid), Color(0.34, 0.58, 0.95)))
	# 第二排：升级（单独一行，显示所需金币）
	var up := _upgrade_action_btn(cid)
	up.position = Vector2(4, r.size.y + 48)
	up.size = Vector2(_action_frame.size.x - 8, 34)
	_action_frame.add_child(up)

func _upgrade_action_btn(cid: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_btn(b, Color(0.88, 0.68, 0.26))
	if not _is_available(cid):
		b.text = "🔒 未解锁"
		b.disabled = true
		return b
	var lv: int = PlayerData.get_card_level(cid)
	if lv >= 16:
		b.text = "已满级"
		b.disabled = true
		return b
	var cost_gold: int = PlayerData.calculate_upgrade_gold(cid, lv)
	var need_cards: int = PlayerData.calculate_upgrade_cards_needed(cid, lv)
	var own_cards: int = PlayerData.get_card_quantity(cid)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := Label.new()
	t1.text = "升级"
	t1.add_theme_font_size_override("font_size", 15)
	t1.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(t1)
	var coin := Label.new()
	coin.text = "💰 %d" % cost_gold
	coin.add_theme_font_size_override("font_size", 15)
	coin.add_theme_color_override("font_color", Color(1.0, 0.36, 0.30) if PlayerData.gold < cost_gold else Color(1.0, 0.83, 0.36))
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(coin)
	b.add_child(hb)
	var wild_have: int = PlayerData.get_wildcard_for_card(cid)
	var missing: int = maxi(0, need_cards - own_cards)
	b.tooltip_text = "需要 %d 张卡（拥有 %d，万能卡 %d）" % [need_cards, own_cards, wild_have]
	b.disabled = PlayerData.gold < cost_gold or (own_cards < need_cards and wild_have < missing)
	b.pressed.connect(func(): _close_actions(); _on_upgrade(cid))
	return b

func _action_btn(text: String, action: Callable, color: Color = Color(0.55, 0.45, 0.25)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 14)
	_color_btn(b, color)
	b.pressed.connect(action)
	return b

func _close_actions():
	if _action_frame:
		_action_frame.queue_free()
		_action_frame = null
	_action_tile = null

func _on_pool_use(cid: int):
	if not _is_available(cid):
		_set_status("该卡尚未解锁，需要先获得")
		return
	if _slots.has(cid):
		_set_status("该卡已在卡组中")
		return
	for i in range(8):
		if int(_slots[i]) <= 0:
			_slots[i] = cid
			_render_table()
			_update_avg()
			_set_status("已加入卡组")
			return
	_set_status("卡组已满 8 张，请先卸下一张")

func _on_deck_remove(cid: int):
	var i := _slots.find(cid)
	if i >= 0:
		_slots[i] = -1
		_render_table()
		_update_avg()
		_set_status("已卸下该卡")

func _on_upgrade(cid: int):
	var old_lv: int = PlayerData.get_card_level(cid)
	var need: int = PlayerData.calculate_upgrade_cards_needed(cid, old_lv)
	var own: int = PlayerData.get_card_quantity(cid)
	var missing: int = maxi(0, need - own)
	var wild_have: int = PlayerData.get_wildcard_for_card(cid)
	var cost_gold: int = PlayerData.calculate_upgrade_gold(cid, old_lv)
	if missing > 0:
		if wild_have < missing:
			_set_status("万能卡不足，无法补足升级所需卡牌")
			return
		# 需要消耗万能卡时必须先弹确认窗口
		_show_wildcard_confirm(cid, old_lv, need, own, missing, wild_have, cost_gold)
		return
	_do_upgrade(cid, 0)


func _do_upgrade(cid: int, wild_use: int):
	var old_lv: int = PlayerData.get_card_level(cid)
	if wild_use > 0 and not PlayerData.use_wildcard_on_card(cid, wild_use):
		_set_status("万能卡不足，升级取消")
		return
	if PlayerData.upgrade_card(cid):
		var new_lv: int = PlayerData.get_card_level(cid)
		_set_status("升级成功！Lv.%d → Lv.%d" % [old_lv, new_lv])
		if _tile_map.has(cid):
			_tile_map[cid].refresh()
		_render_table()
		_apply_sort()
		_update_top_info()
		UiComponents.refresh_topbar()
		_show_upgrade_animation(cid, old_lv, new_lv)
	else:
		_set_status("升级失败：金币或卡牌不足")


func _show_wildcard_confirm(cid: int, level: int, need: int, own: int, missing: int, wild_have: int, cost_gold: int):
	if _wild_confirm_overlay and is_instance_valid(_wild_confirm_overlay):
		_wild_confirm_overlay.queue_free()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1100
	add_child(overlay)
	_wild_confirm_overlay = overlay
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.70)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -280
	panel.offset_bottom = 280
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.14, 0.99)
	sb.border_color = Color(0.72, 0.52, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0.55, 0.30, 0.95, 0.4)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24; v.offset_right = -24; v.offset_top = 24; v.offset_bottom = -24
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "使用万能卡升级"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.86, 0.74, 1.0))
	v.add_child(title)
	var cfg: CardData = _cfgs.get(cid, null)
	var card_name := String(cfg.card_name) if cfg else "卡牌"
	var desc := Label.new()
	desc.text = "%s  Lv.%d → Lv.%d\n普通/稀有/史诗/传奇万能卡按同稀有度消耗" % [card_name, level, level + 1]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0))
	v.add_child(desc)
	var info := Label.new()
	var remaining := wild_have - missing
	info.text = "万能卡库存：%d 张\n本次消耗：%d 张\n升级后剩余：%d 张\n金币消耗：%d（持有 %d）\n卡牌：%d/%d" % [
		wild_have, missing, remaining, cost_gold, PlayerData.gold, own, need]
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	v.add_child(info)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btns)
	var cancel := UiComponents.make_secondary_button("取消", func(): overlay.queue_free(), Vector2(0, 54))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(cancel)
	var confirm := UiComponents.make_primary_button("确认升级", func():
		overlay.queue_free()
		_do_upgrade(cid, missing), Vector2(0, 54))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(confirm)

func _show_upgrade_animation(cid: int, old_lv: int, new_lv: int):
	if _upgrade_overlay and is_instance_valid(_upgrade_overlay):
		_upgrade_overlay.queue_free()
	var cfg: CardData = _cfgs.get(cid, null)
	if cfg == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)
	_upgrade_overlay = overlay
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -210
	panel.offset_bottom = 210
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	psb.border_color = Color(1.0, 0.78, 0.28)
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(20)
	psb.shadow_color = Color(1.0, 0.72, 0.20, 0.45)
	psb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", psb)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 28
	vb.offset_right = -28
	vb.offset_top = 22
	vb.offset_bottom = -22
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "⬆ 升级成功"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	vb.add_child(title)
	var name_lbl := Label.new()
	name_lbl.text = "%s   Lv.%d → Lv.%d" % [cfg.card_name, old_lv, new_lv]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	vb.add_child(name_lbl)
	var old_mult: float = Config.level_mult(old_lv)
	var new_mult: float = Config.level_mult(new_lv)
	var has_stat := false
	if cfg.max_health > 0:
		has_stat = true
		vb.add_child(_upgrade_stat_row("❤ 生命", cfg.max_health * old_mult, cfg.max_health * new_mult))
	if cfg.damage > 0:
		has_stat = true
		vb.add_child(_upgrade_stat_row("⚔ 伤害", cfg.damage * old_mult, cfg.damage * new_mult))
	if cfg.attack_speed > 0:
		vb.add_child(_upgrade_stat_row("⏱ 攻速", cfg.attack_speed, cfg.attack_speed, true))
	if not has_stat:
		var l := Label.new()
		l.text = "卡牌属性提升"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		vb.add_child(l)
	var ok := _tool_btn("确定", func(): overlay.queue_free(), Color(0.92, 0.70, 0.24))
	ok.custom_minimum_size = Vector2(0, 48)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(ok)
	panel.pivot_offset = Vector2(270, 210)
	panel.scale = Vector2(0.75, 0.75)
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.10)
	await get_tree().create_timer(2.3).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()

func _upgrade_stat_row(label_text: String, old_v: float, new_v: float, unchanged: bool = false) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	sb.border_color = Color(0.32, 0.36, 0.46)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -10
	p.add_child(hb)
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var old_lbl := Label.new()
	old_lbl.text = "%.0f" % old_v
	old_lbl.add_theme_font_size_override("font_size", 17)
	old_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	hb.add_child(old_lbl)
	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 17)
	arrow.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	hb.add_child(arrow)
	var new_lbl := Label.new()
	if unchanged:
		new_lbl.text = "%.0f ms（不变）" % new_v
		new_lbl.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
	else:
		new_lbl.text = "%.0f" % old_v
		new_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55))
		var tw := create_tween()
		tw.tween_method(func(v: float): new_lbl.text = "%d" % int(v), old_v, new_v, 0.65)
	hb.add_child(new_lbl)
	if not unchanged and new_v > old_v:
		var pct := Label.new()
		pct.text = " +%.0f%%" % ((new_v / maxf(old_v, 0.001) - 1.0) * 100.0)
		pct.add_theme_font_size_override("font_size", 13)
		pct.add_theme_color_override("font_color", Color(0.45, 1.0, 0.60))
		hb.add_child(pct)
	return p

func _on_detail(cid: int):
	if not _cfgs.has(cid):
		return
	DETAIL.open(self, _cfgs[cid], func(_id):
		if _tile_map.has(cid):
			_tile_map[cid].refresh()
		_render_table()
		_update_top_info()
	)

func _update_avg():
	var avg: float = _avg_of(_slots)
	var has_mirror: bool = _slots.has(123)
	_avg.text = "⚡ 平均圣水 %.2f%s" % [avg, "  (镜像 ? 不计)" if has_mirror else ""]
	_refresh_tabs()

func _on_search(_text: String):
	_apply_filters()

func _apply_filters():
	var q: String = _search.text.strip_edges()
	var shown: int = 0
	for cid in _tile_map.keys():
		var tile: DeckCardTile = _tile_map[cid]
		var cfg: CardData = tile.config
		var ok: bool = q == "" or String(cfg.card_name).contains(q) or str(cid) == q
		if _slots.has(cid):
			ok = false
		if ok and _filter_mode != "all":
			var is_spell: bool = _spell_ids.has(cfg.card_id)
			var is_building: bool = cfg.type == Config.UnitType.BUILDING
			match _filter_mode:
				"spell":
					ok = is_spell
				"building":
					ok = is_building and not is_spell
				"unit":
					ok = not is_spell and not is_building
		tile.visible = ok
		if ok:
			shown += 1
	var any_locked := false
	for tile in _locked_grid.get_children():
		if tile.visible:
			any_locked = true
			break
	if _lock_divider:
		_lock_divider.visible = any_locked
	var owned_total: int = 0
	for c in _all_cards:
		if _is_available(c.card_id):
			owned_total += 1
	_pool_count.text = "卡牌库 · 已解锁 %d/%d%s" % [owned_total, _all_cards.size(), (" · 筛选 %d" % shown) if shown != _all_cards.size() else ""]
	for key in _filter_buttons.keys():
		var b: Button = _filter_buttons[key]
		b.add_theme_color_override("font_color", ThemeHelper.COLORS.gold if key == _filter_mode else Color(0.76, 0.78, 0.88))

func _on_filter_pressed(mode: String):
	_filter_mode = mode
	_apply_filters()

func _set_status(text: String):
	if _status == null:
		return
	_status.text = text

func _on_copy():
	PlayerData.deck_clipboard = _slots.duplicate()
	_set_status("已复制当前卡组")

func _on_paste():
	if PlayerData.deck_clipboard.size() < 8:
		_set_status("剪贴板没有卡组")
		return
	var out: Array = []
	for cid in PlayerData.deck_clipboard:
		var c: int = int(cid)
		if _cfgs.has(c) and not out.has(c) and c > 0:
			out.append(c)
	while out.size() < 8:
		out.append(-1)
	_slots = out.slice(0, 8)
	_render_table()
	_update_avg()
	_set_status("已粘贴卡组")

func _on_clear():
	_slots = [-1, -1, -1, -1, -1, -1, -1, -1]
	_render_table()
	_update_avg()
	_set_status("已清空当前卡组")

func _on_random():
	var pool: Array = []
	for cfg in _all_cards:
		if cfg.card_id != 123 and _is_available(cfg.card_id):
			pool.append(cfg.card_id)
	pool.shuffle()
	_slots = [-1, -1, -1, -1, -1, -1, -1, -1]
	var n: int = 0
	for cid in pool:
		if n >= 8:
			break
		_slots[n] = cid
		n += 1
	_render_table()
	_update_avg()
	_set_status("已随机生成卡组")

func _on_sort_popup():
	_sort_menu.position = Vector2i(620, 700)
	_sort_menu.popup()

func _on_sort_selected(id: int):
	_sort_mode = "default" if id == 0 else ("level" if id == 1 else ("rarity" if id == 2 else "arena"))
	PlayerData.deck_sort_mode = _sort_mode
	PlayerData.save_data()
	_apply_sort()

func _rarity_rank(cid: int) -> int:
	match CARD_RARITY.rarity_of_id(cid):
		"common": return 0
		"rare": return 1
		"epic": return 2
		"legendary": return 3
	return 0

func _apply_sort():
	var order: Array = _all_cards.duplicate()
	if _sort_mode == "level":
		order.sort_custom(func(a, b):
			var la: int = PlayerData.get_card_level(a.card_id)
			var lb: int = PlayerData.get_card_level(b.card_id)
			if la == lb:
				return a.card_id < b.card_id
			return la > lb
		)
	elif _sort_mode == "rarity":
		order.sort_custom(func(a, b):
			var ra: int = _rarity_rank(a.card_id)
			var rb: int = _rarity_rank(b.card_id)
			if ra == rb:
				return a.card_id < b.card_id
			return ra > rb
		)
	elif _sort_mode == "arena":
		order.sort_custom(func(a, b):
			var aa: int = CARD_RARITY.arena_unlock_by_id(a.card_id)
			var ab: int = CARD_RARITY.arena_unlock_by_id(b.card_id)
			if aa == ab:
				return a.card_id < b.card_id
			return aa < ab
		)
	var owned_order: Array = []
	var locked_order: Array = []
	for cfg in order:
		if _is_available(cfg.card_id):
			owned_order.append(cfg)
		else:
			locked_order.append(cfg)
	_reorder_grid(_owned_grid, owned_order)
	_reorder_grid(_locked_grid, locked_order)
	_apply_filters()

func _reorder_grid(grid: GridContainer, order: Array) -> void:
	if grid == null:
		return
	for ch in grid.get_children():
		grid.remove_child(ch)
	for cfg in order:
		if _tile_map.has(cfg.card_id):
			grid.add_child(_tile_map[cfg.card_id])

func _on_classic_popup():
	_classic_menu.position = Vector2i(30, 700)
	_classic_menu.popup()

func _on_classic_selected(id: int):
	var names: Array = CLASSIC_DECKS.keys()
	if id < 0 or id >= names.size():
		return
	var preset: Array = CLASSIC_DECKS[names[id]]
	var out: Array = []
	for cid in preset:
		var c: int = int(cid)
		if _cfgs.has(c) and _is_available(c) and not out.has(c):
			out.append(c)
	while out.size() < 8:
		out.append(-1)
	_slots = out.slice(0, 8)
	_render_table()
	_update_avg()
	_set_status("已载入经典卡组：%s" % String(names[id]))

func _on_tower_choice(choice: int):
	PlayerData.tower_choice = clampi(choice, 1, 4)
	PlayerData.save_data()
	_tower_preview_choice = PlayerData.tower_choice
	_preview_tower(_tower_preview_choice)
	_set_status("皇家塔已切换为%s" % TOWER_CATALOG.tower_name(PlayerData.tower_choice))


func _build_tower_section() -> void:
	var panel := Panel.new()
	panel.position = Vector2(30, 820)
	panel.size = Vector2(740, 220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.97)
	sb.border_color = Color(0.62, 0.48, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var title := Label.new()
	title.text = "皇家塔"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	panel.add_child(title)
	var sub := Label.new()
	sub.text = "选择出战皇家塔（4 种）"
	sub.position = Vector2(16, 36)
	sub.size = Vector2(230, 22)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.66, 0.72, 0.84))
	panel.add_child(sub)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(250, 8)
	tabs.size = Vector2(472, 36)
	tabs.add_theme_constant_override("separation", 5)
	panel.add_child(tabs)
	for choice in [1, 2, 3, 4]:
		var b := Button.new()
		b.text = TOWER_CATALOG.tower_name(choice)
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		_color_btn(b, Color(0.40, 0.52, 0.72))
		var c: int = choice
		b.pressed.connect(func(): _preview_tower(c))
		tabs.add_child(b)
		_tower_tabs.append(b)
	_tower_model_frame = Panel.new()
	_tower_model_frame.position = Vector2(12, 60)
	_tower_model_frame.size = Vector2(210, 148)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.015, 0.025, 0.06, 0.98)
	msb.set_corner_radius_all(12)
	msb.set_border_width_all(1)
	msb.border_color = Color(1, 1, 1, 0.10)
	_tower_model_frame.add_theme_stylebox_override("panel", msb)
	panel.add_child(_tower_model_frame)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	_tower_model_frame.add_child(svc)
	_tower_sub = SubViewport.new()
	_tower_sub.size = Vector2i(210, 148)
	_tower_sub.transparent_bg = true
	_tower_sub.own_world_3d = true
	_tower_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_tower_sub)
	_tower_model_root = Node3D.new()
	_tower_sub.add_child(_tower_model_root)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 2.3, 4.2)
	cam.fov = 35.0
	_tower_sub.add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 1.2
	_tower_sub.add_child(light)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.94)
	env.ambient_light_energy = 0.7
	we.environment = env
	_tower_sub.add_child(we)

	_tower_stat_grid = GridContainer.new()
	_tower_stat_grid.position = Vector2(234, 58)
	_tower_stat_grid.size = Vector2(290, 94)
	_tower_stat_grid.columns = 2
	_tower_stat_grid.add_theme_constant_override("h_separation", 5)
	_tower_stat_grid.add_theme_constant_override("v_separation", 5)
	panel.add_child(_tower_stat_grid)
	_tower_special_lbl = Label.new()
	_tower_special_lbl.position = Vector2(234, 156)
	_tower_special_lbl.size = Vector2(292, 52)
	_tower_special_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tower_special_lbl.add_theme_font_size_override("font_size", 12)
	_tower_special_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.94))
	panel.add_child(_tower_special_lbl)
	_tower_select_btn = Button.new()
	_tower_select_btn.position = Vector2(534, 166)
	_tower_select_btn.size = Vector2(188, 42)
	_tower_select_btn.add_theme_font_size_override("font_size", 15)
	_tower_select_btn.focus_mode = Control.FOCUS_NONE
	_tower_select_btn.pressed.connect(func(): _on_tower_choice(_tower_preview_choice))
	panel.add_child(_tower_select_btn)
	_tower_preview_choice = PlayerData.tower_choice if TOWER_CATALOG.has_choice(PlayerData.tower_choice) else 1
	_preview_tower(_tower_preview_choice)


func _preview_tower(choice: int) -> void:
	_tower_preview_choice = choice
	var data: Dictionary = TOWER_CATALOG.get_tower(choice)
	for i in range(_tower_tabs.size()):
		var b: Button = _tower_tabs[i]
		_color_btn(b, Color(0.90, 0.68, 0.24) if i + 1 == choice else Color(0.40, 0.52, 0.72))
	# model
	for c in _tower_model_root.get_children():
		c.queue_free()
	var model_cfg = TOWER_CATALOG.get_tower(choice)
	var spec: Dictionary = TVIEW.spec_for(String(data.name), Config.Team.PLAYER, float(data.range))
	var model: Node3D = TUMK.create_unit(spec)
	_tower_model_root.add_child(model)
	# stats
	for c in _tower_stat_grid.get_children():
		c.queue_free()
	_tower_stat_grid.add_child(_tower_stat("生命", int(data.hp), Color(0.95, 0.55, 0.55)))
	_tower_stat_grid.add_child(_tower_stat("伤害", int(data.damage), Color(1.0, 0.72, 0.38)))
	_tower_stat_grid.add_child(_tower_stat("攻速", "%.1f/秒" % (1000.0 / maxf(1.0, float(data.attack_speed))), Color(0.65, 0.82, 1.0)))
	_tower_stat_grid.add_child(_tower_stat("射程", "%.1f" % float(data.range), Color(0.76, 0.70, 1.0)))
	_tower_special_lbl.text = "%s
%s" % [String(data.desc), "特殊：%s" % String(data.special)]
	var selected: bool = choice == int(PlayerData.tower_choice)
	_tower_select_btn.text = "已选择" if selected else "选择 %s" % String(data.name)
	_tower_select_btn.disabled = selected
	_color_btn(_tower_select_btn, Color(0.90, 0.68, 0.24) if not selected else Color(0.32, 0.38, 0.48))


func _tower_stat(label: String, value, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.16, 0.95)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(color.r, color.g, color.b, 0.30)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var n := Label.new()
	n.text = label
	n.add_theme_font_size_override("font_size", 11)
	n.add_theme_color_override("font_color", Color(0.66, 0.72, 0.84))
	v.add_child(n)
	var val := Label.new()
	val.text = str(value)
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", color)
	v.add_child(val)
	return p

func _on_save():
	if _party_edit:
		var saved: Array = []
		for cid in _slots:
			if int(cid) >= 0:
				saved.append(int(cid))
		PlayerData.party_deck = saved
		PlayerData.save_data()
		LoadingScreen.change_scene("res://scenes/party_select.tscn", "正在返回派对…")
		return
	_decks[_idx] = _slots.duplicate()
	PlayerData.custom_decks = _decks.duplicate(true)
	PlayerData.active_deck_index = _idx
	PlayerData.use_custom_deck = true
	PlayerData.save_data()
	_update_top_info()
	_set_status("已保存卡组 %d（%s）" % [_idx + 1, "使用配置卡组" if PlayerData.use_custom_deck else "随机卡组"])

func _open_animation_studio() -> void:
	_on_save()
	LoadingScreen.change_scene("res://scenes/card_animation_studio.tscn", "正在进入动画配置…")


func _on_back():
	if _party_edit:
		var saved: Array = []
		for cid in _slots:
			if int(cid) >= 0:
				saved.append(int(cid))
		PlayerData.party_deck = saved
		PlayerData.save_data()
		LoadingScreen.change_scene("res://scenes/party_select.tscn", "正在返回派对…")
		return
	_decks[_idx] = _slots.duplicate()
	PlayerData.custom_decks = _decks.duplicate(true)
	PlayerData.active_deck_index = _idx
	PlayerData.use_custom_deck = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
