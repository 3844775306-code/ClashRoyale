extends Control

const TILE = preload("res://scripts/ui/DeckCardTile.gd")
const DETAIL = preload("res://scripts/ui/CardDetailDialog.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

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
var _tower_btns: Array = []
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
	if _sort_mode not in ["level", "rarity", "default"]:
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
	var tlabel := Label.new()
	tlabel.text = "皇家塔"
	tlabel.add_theme_font_size_override("font_size", 14)
	tlabel.add_theme_color_override("font_color", Color(0.86, 0.78, 0.58))
	top.add_child(tlabel)
	_tower_btns.clear()
	for choice in [1, 2]:
		var tb := Button.new()
		tb.text = "👸 公主" if choice == 1 else "🤴 王子"
		tb.custom_minimum_size = Vector2(84, 38)
		tb.add_theme_font_size_override("font_size", 13)
		_color_btn(tb, Color(0.90, 0.68, 0.24) if PlayerData.tower_choice == choice else Color(0.40, 0.52, 0.72))
		var c: int = choice
		tb.pressed.connect(func(): _on_tower_choice(c))
		top.add_child(tb)
		_tower_btns.append(tb)
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
	_pool_count.position = Vector2(30, 816)
	_pool_count.size = Vector2(300, 20)
	_pool_count.add_theme_font_size_override("font_size", 14)
	_pool_count.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	add_child(_pool_count)

	# 卡池
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 838)
	scroll.size = Vector2(740, 708)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
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
	b.tooltip_text = "需要 %d 张卡（拥有 %d）" % [need_cards, own_cards]
	b.disabled = PlayerData.gold < cost_gold or own_cards < need_cards
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
	_sort_mode = "default" if id == 0 else ("level" if id == 1 else "rarity")
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
	PlayerData.tower_choice = clampi(choice, 1, 2)
	PlayerData.save_data()
	for i in range(_tower_btns.size()):
		var b: Button = _tower_btns[i]
		_color_btn(b, Color(0.90, 0.68, 0.24) if i + 1 == PlayerData.tower_choice else Color(0.40, 0.52, 0.72))
	_set_status("皇家塔已切换为%s" % ("公主塔" if PlayerData.tower_choice == 1 else "王子塔"))

func _on_save():
	if _party_edit:
		var saved: Array = []
		for cid in _slots:
			if int(cid) >= 0:
				saved.append(int(cid))
		PlayerData.party_deck = saved
		PlayerData.save_data()
		get_tree().change_scene_to_file("res://scenes/party_select.tscn")
		return
	_decks[_idx] = _slots.duplicate()
	PlayerData.custom_decks = _decks.duplicate(true)
	PlayerData.active_deck_index = _idx
	PlayerData.use_custom_deck = true
	PlayerData.save_data()
	_update_top_info()
	_set_status("已保存卡组 %d（%s）" % [_idx + 1, "使用配置卡组" if PlayerData.use_custom_deck else "随机卡组"])

func _on_back():
	if _party_edit:
		var saved: Array = []
		for cid in _slots:
			if int(cid) >= 0:
				saved.append(int(cid))
		PlayerData.party_deck = saved
		PlayerData.save_data()
		get_tree().change_scene_to_file("res://scenes/party_select.tscn")
		return
	_decks[_idx] = _slots.duplicate()
	PlayerData.custom_decks = _decks.duplicate(true)
	PlayerData.active_deck_index = _idx
	PlayerData.use_custom_deck = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
