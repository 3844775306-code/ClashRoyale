extends Control

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const ARENA_VIEW = preload("res://scripts/ui/ArenaSideView.gd")

var scroll: ScrollContainer
var content: VBoxContainer
var achievements: Array = []
var trophy_arena: int = 1
var current_marker: Control = null
var summary_panel: Panel = null
var currency_row: HBoxContainer
var _card_names: Dictionary = {}
var _row_state: Dictionary = {}
var _teammates: Array = []
var _touch_dragging := false
var _touch_last_y := 0.0
var _mouse_dragging := false

func _ready():
	_apply_text_theme()
	UiComponents.add_background(self)
	currency_row = UiComponents.make_header(self, "皇室征程", _on_back_pressed, true)
	_load_card_names()
	achievements = PlayerData.get_achievements()
	trophy_arena = PlayerData._arena_index_for_trophies(PlayerData.highest_trophies)
	_build_summary()
	scroll = UiComponents.make_content_scroll(self, UiComponents.HEADER_H + 174)
	content = UiComponents.make_content_vbox()
	scroll.add_child(content)
	_build()
	_load_teammates()
	_make_scroll_passthrough(content)
	UiComponents.fade_in(self)
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_to_current()

func _input(event: InputEvent) -> void:
	if scroll == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and scroll.get_global_rect().has_point(st.position):
			_touch_dragging = true
			_touch_last_y = st.position.y
		elif not st.pressed:
			_touch_dragging = false
	elif event is InputEventScreenDrag:
		if _touch_dragging:
			var sd := event as InputEventScreenDrag
			scroll.scroll_vertical -= int(sd.relative.y)
			_touch_last_y = sd.position.y
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and scroll.get_global_rect().has_point(mb.position):
			_mouse_dragging = mb.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm := event as InputEventMouseMotion
		scroll.scroll_vertical -= int(mm.relative.y)
		get_viewport().set_input_as_handled()


func _apply_text_theme():
	var th := Theme.new()
	var f := load("res://assets/fonts/STZHONGS.TTF")
	if f:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_embolden = 0.7
		th.default_font = fv
	th.default_font_size = 15
	th.set_color("font_color", "Label", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Label", Color(0.04, 0.06, 0.10))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Button", Color(0.99, 0.98, 0.92))
	th.set_color("font_outline_color", "Button", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Button", 3)
	theme = th

func _load_card_names():
	var f := FileAccess.open("res://data/units_level11_utf8.csv", FileAccess.READ)
	if f == null:
		var bm = preload("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
		for cfg in bm.configs:
			_card_names[cfg.card_id] = cfg.card_name
		bm.free()
		return
	var header: PackedStringArray = f.get_csv_line()
	var id_i: int = -1
	var name_i: int = -1
	for i in range(header.size()):
		if header[i] == "id": id_i = i
		elif header[i] == "name": name_i = i
	if id_i < 0 or name_i < 0:
		return
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() <= max(id_i, name_i):
			continue
		_card_names[int(row[id_i])] = row[name_i]

func _build_summary():
	if summary_panel and is_instance_valid(summary_panel):
		summary_panel.queue_free()
	summary_panel = Panel.new()
	summary_panel.position = Vector2(30, UiComponents.HEADER_H + 6)
	summary_panel.size = Vector2(740, 156)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.10, 0.18, 0.97)
	sb.border_color = Color(0.30, 0.62, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	summary_panel.add_theme_stylebox_override("panel", sb)
	add_child(summary_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 10
	vb.offset_right = -16
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 5)
	summary_panel.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var cur := Label.new()
	cur.text = "当前 %d 杯" % PlayerData.trophies
	cur.add_theme_font_size_override("font_size", 25)
	cur.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	top.add_child(cur)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var best := Label.new()
	best.text = "历史最高 %d" % PlayerData.highest_trophies
	best.add_theme_font_size_override("font_size", 15)
	best.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	top.add_child(best)
	var next: Dictionary = {}
	var best_t: int = 999999
	for a in achievements:
		if PlayerData.claimed_achievements.has(String(a.id)):
			continue
		var at: int = int(a.get("trophies", 0))
		if at >= PlayerData.highest_trophies and at < best_t:
			best_t = at
			next = a
	if next.is_empty() and not achievements.is_empty():
		next = achievements[achievements.size() - 1]
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(int(next.get("trophies", 1))))
	bar.value = clampf(float(PlayerData.highest_trophies), 0.0, float(int(next.get("trophies", 1))))
	ThemeHelper.apply_progress_gold(bar)
	vb.add_child(bar)
	var info := Label.new()
	if PlayerData.highest_trophies >= 8900:
		info.text = "已抵达官方公开奖励表末端（8900杯）"
	else:
		info.text = "下一里程碑：%d 杯 · 还差 %d 杯" % [int(next.get("trophies", 0)), maxi(0, int(next.get("trophies", 0)) - PlayerData.highest_trophies)]
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	vb.add_child(info)
	var claimed := 0
	for a in achievements:
		if a.get("claimed", false):
			claimed += 1
	var cnt := Label.new()
	cnt.text = "已领取 %d / %d 个官方里程碑" % [claimed, achievements.size()]
	cnt.add_theme_font_size_override("font_size", 13)
	cnt.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
	vb.add_child(cnt)
	var emo := Label.new()
	emo.text = "已收集表情 %d" % PlayerData.get_emote_count()
	emo.add_theme_font_size_override("font_size", 12)
	emo.add_theme_color_override("font_color", Color(0.70, 0.82, 0.96))
	vb.add_child(emo)

func _make_scroll_passthrough(n: Node) -> void:
	for c in n.get_children():
		if c is Control and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
		_make_scroll_passthrough(c)

func _vgrad(top: Color, bottom: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([top, bottom])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 128
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return t


func _build():
	for ch in content.get_children():
		ch.queue_free()
	current_marker = null
	_row_state.clear()
	var by_arena: Dictionary = {}
	for a in achievements:
		var idx: int = int(a.get("arena_index", 1))
		if not by_arena.has(idx):
			by_arena[idx] = []
		by_arena[idx].append(a)
	for i in range(32, 0, -1):
		var rows: Array = by_arena.get(i, [])
		if rows.is_empty():
			continue
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 0)
		content.add_child(body)
		var ordered: Array = rows.duplicate()
		ordered.sort_custom(func(a, b): return int(a.trophies) > int(b.trophies))
		var marker_done := false
		for a in ordered:
			if i == trophy_arena and not marker_done and int(a.get("trophies", 0)) <= PlayerData.highest_trophies:
				current_marker = _current_marker()
				body.add_child(current_marker)
				marker_done = true
			body.add_child(_milestone_row(a))
		if i == trophy_arena and not marker_done:
			current_marker = _current_marker()
			body.add_child(current_marker)
		# 队友位置：按奖杯插入当前竞技场
		var team_rows: Array = []
		for tm in _teammates:
			if int(tm.get("arena", 0)) == i:
				team_rows.append(tm)
		team_rows.sort_custom(func(a, b): return int(a.get("trophies", 0)) > int(b.get("trophies", 0)))
		for tm in team_rows:
			body.add_child(_teammate_marker(tm))
		# 竞技场图像放在里程碑下面，1 阶竞技场位于最底部
		content.add_child(_arena_divider(i, rows))

func _load_teammates() -> void:
	if ClanManager == null:
		return
	ClanManager.get_my_clan(func(success, clan):
		if not success or not (clan is Dictionary):
			return
		var members: Dictionary = clan.get("members", {})
		var my_id := str(ClanManager.get_player_id())
		var out: Array = []
		for key in members.keys():
			if str(key) == my_id:
				continue
			var m: Dictionary = Dictionary(members[key])
			var nm := String(m.get("player_name", m.get("name", "队友")))
			var tr := int(m.get("trophies", 0))
			out.append({
				"player_id": str(key), "name": nm, "trophies": tr,
				"avatar_seed": int(m.get("avatar_seed", absi(hash(nm)))),
				"avatar_index": int(m.get("avatar_index", 0)),
				"arena": PlayerData._arena_index_for_trophies(tr),
			})
		_teammates = out
		if not _teammates.is_empty() and content != null:
			_build()
	)

func _teammate_marker(tm: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.11, 0.20, 0.95)
	sb.border_color = Color(0.36, 0.72, 1.0, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.offset_left = 14
	h.offset_right = -14
	row.add_child(h)
	var av = preload("res://scripts/ui/AvatarIcon.gd").new()
	av.custom_minimum_size = Vector2(42, 42)
	av.size = Vector2(42, 42)
	var nm := String(tm.get("name", "队友"))
	var seedv := int(tm.get("avatar_seed", absi(hash(nm))))
	var idx := int(tm.get("avatar_index", 0))
	av.setup(nm, seedv, idx)
	h.add_child(av)
	CloudAvatar.apply(av, String(tm.get("player_id", "")), nm, seedv, idx)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	info.add_child(_label(String(tm.get("name", "队友")), 15, Color(0.82, 0.92, 1.0)))
	info.add_child(_label("队友 · 🏆 %d" % int(tm.get("trophies", 0)), 12, Color(1.0, 0.86, 0.42)))
	return row

func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	return l


func _arena_divider(idx: int, rows: Array) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 420)
	p.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.12, 1.0)
	sb.border_color = Color(0.34, 0.62, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel", sb)
	var shot := TextureRect.new()
	shot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shot_path := "res://assets/ui/arena_portraits/arena_%02d.png" % idx
	if ResourceLoader.exists(shot_path):
		shot.texture = load(shot_path)
	else:
		var view = ARENA_VIEW.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.set_arena(idx)
		p.add_child(view)
	p.add_child(shot)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.06, 0.10)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(shade)
	var top_grad := TextureRect.new()
	top_grad.texture = _vgrad(Color(0.012, 0.02, 0.045, 0.62), Color(0.012, 0.02, 0.045, 0.0))
	top_grad.anchor_right = 1.0
	top_grad.offset_bottom = 150
	top_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_grad.stretch_mode = TextureRect.STRETCH_SCALE
	top_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(top_grad)
	var bottom_grad := TextureRect.new()
	bottom_grad.texture = _vgrad(Color(0.012, 0.02, 0.045, 0.0), Color(0.012, 0.02, 0.045, 0.72))
	bottom_grad.anchor_right = 1.0
	bottom_grad.anchor_top = 1.0
	bottom_grad.anchor_bottom = 1.0
	bottom_grad.offset_top = -150
	bottom_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_grad.stretch_mode = TextureRect.STRETCH_SCALE
	bottom_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bottom_grad)
	var name_lbl := Label.new()
	name_lbl.text = PlayerData.get_arena_name_at(idx)
	name_lbl.position = Vector2(24, 16)
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	name_lbl.add_theme_constant_override("outline_size", 8)
	p.add_child(name_lbl)
	var sub := Label.new()
	sub.text = "竞技场 %d · %d 杯" % [idx, PlayerData.get_arena_trophies_at(idx)]
	sub.position = Vector2(26, 68)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	p.add_child(sub)
	var got := 0
	for a in rows:
		if a.get("claimed", false):
			got += 1
	var cnt := Label.new()
	cnt.text = "%d/%d" % [got, rows.size()]
	cnt.anchor_left = 1.0
	cnt.anchor_right = 1.0
	cnt.offset_left = -140
	cnt.offset_right = -24
	cnt.offset_top = 24
	cnt.offset_bottom = 60
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 20)
	cnt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44))
	p.add_child(cnt)
	# 4 张一排、居中放大：最多 3 张解锁卡 + 宝箱
	var center := CenterContainer.new()
	center.position = Vector2(0, 282)
	center.size = Vector2(740, 126)
	p.add_child(center)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(grid)
	var ids: Array = PlayerData.get_cards_unlocked_at(idx)
	var icon_size := Vector2(72, 94) if ids.size() >= 5 else Vector2(84, 108)
	var shown := 0
	for cid in ids:
		var nm: String = String(_card_names.get(int(cid), ""))
		if nm == "":
			continue
		var ic = REWARD_ICON.new()
		ic.custom_minimum_size = icon_size
		ic.setup("card", 1, nm, int(cid))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(ic)
		shown += 1
	var chest = _make_chest_preview(icon_size, "silver")
	grid.add_child(chest)
	return p

func _scroll_to_current():
	if OS.has_environment("CR_ACH_TOP"):
		return
	if current_marker == null or not is_instance_valid(current_marker):
		return
	var y: float = current_marker.get_global_position().y - content.get_global_position().y
	scroll.scroll_vertical = maxi(0, int(y - scroll.size.y * 0.40))

func _current_marker() -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 76)
	var rail := ColorRect.new()
	rail.color = Color(1.0, 0.78, 0.26)
	rail.position = Vector2(6, 0)
	rail.size = Vector2(18, 76)
	row.add_child(rail)
	var bubble := Panel.new()
	bubble.position = Vector2(34, 10)
	bubble.size = Vector2(330, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.98, 1.0, 0.97)
	sb.border_color = Color(0.24, 0.58, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	bubble.add_theme_stylebox_override("panel", sb)
	row.add_child(bubble)
	var lbl := Label.new()
	lbl.text = "当前 %d 杯" % PlayerData.trophies
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.04, 0.10, 0.18))
	bubble.add_child(lbl)
	return row

func _reward_title(a: Dictionary) -> String:
	if String(a.get("emote_id", "")) != "": return "表情收藏"
	if int(a.get("gold", 0)) > 0: return "金币 ×%d" % int(a.gold)
	if int(a.get("gems", 0)) > 0: return "宝石 ×%d" % int(a.gems)
	if int(a.get("card_amount", 0)) > 0: return "%s ×%d" % [String(a.get("card_name", "卡牌")), int(a.card_amount)]
	if int(a.get("wild_amount", 0)) > 0:
		return "%s万能卡 ×%d" % [String(a.get("wild_rarity_cn", "")), int(a.wild_amount)]
	if String(a.get("chest", "")) != "": return "幸运宝箱"
	if int(a.get("emote", 0)) > 0: return "表情"
	return "里程碑奖励"

func _make_chest_preview(size: Vector2, chest_name: String = ""):
	var c = CHEST3D.new()
	c.custom_minimum_size = size
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var low := String(chest_name).to_lower()
	if low.contains("legendary"): c.rarity = "legendary"
	elif low.contains("magic"): c.rarity = "magical"
	elif low.contains("gold") or low.contains("giant") or low.contains("epic"): c.rarity = "gold"
	else: c.rarity = "silver"
	return c

func _setup_reward_icon(icon, a: Dictionary) -> void:
	if String(a.get("emote_id", "")) != "":
		icon.setup("emote", 1)
		return
	if int(a.get("gold", 0)) > 0:
		icon.setup("gold", int(a.gold))
	elif int(a.get("gems", 0)) > 0:
		icon.setup("gems", int(a.gems))
	elif int(a.get("card_amount", 0)) > 0:
		icon.setup("card", int(a.card_amount), String(a.get("card_name", "")), int(a.get("card_id", 0)))
	elif int(a.get("wild_amount", 0)) > 0:
		icon.setup("wild", int(a.wild_amount))
	elif String(a.get("chest", "")) != "":
		icon.setup("chest", 1)
	elif int(a.get("emote", 0)) > 0:
		icon.setup("emote", 1)

func _milestone_row(a: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 168)
	var claimed: bool = a.get("claimed", false)
	var claimable: bool = a.get("claimable", false)
	var rail_col: Color = Color(0.12, 0.30, 0.52)
	if claimed:
		rail_col = Color(0.40, 0.76, 0.48)
	elif claimable:
		rail_col = Color(1.0, 0.78, 0.26)
	var rail := ColorRect.new()
	rail.color = rail_col
	rail.position = Vector2(6, 0)
	rail.size = Vector2(18, 168)
	row.add_child(rail)
	var trophy := Label.new()
	trophy.text = "%d" % int(a.get("trophies", 0))
	trophy.position = Vector2(28, 50)
	trophy.size = Vector2(128, 42)
	trophy.add_theme_font_size_override("font_size", 23)
	trophy.add_theme_color_override("font_color", Color(1, 0.95, 0.82) if not claimable else Color(1, 0.86, 0.38))
	row.add_child(trophy)
	var st := Label.new()
	st.text = "已领取" if claimed else ("可领取" if claimable else "未达成")
	st.position = Vector2(30, 96)
	st.size = Vector2(120, 26)
	st.add_theme_font_size_override("font_size", 12)
	st.add_theme_color_override("font_color", Color(0.48, 0.92, 0.60) if claimed else (Color(1.0, 0.82, 0.35) if claimable else Color(0.56, 0.64, 0.76)))
	row.add_child(st)
	var card := PanelContainer.new()
	card.position = Vector2(168, 12)
	card.size = Vector2(560, 144)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.055, 0.09, 0.14, 0.97)
	csb.border_color = rail_col
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(13)
	card.add_theme_stylebox_override("panel", csb)
	row.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)
	var icon
	if String(a.get("chest", "")) != "":
		icon = _make_chest_preview(Vector2(112, 124), String(a.get("chest", "")))
	else:
		icon = REWARD_ICON.new()
		icon.custom_minimum_size = Vector2(112, 124)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_setup_reward_icon(icon, a)
	hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	var title := Label.new()
	title.text = _reward_title(a)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "官方里程碑奖励"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.62, 0.74, 0.88))
	vb.add_child(sub)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 38)
	btn.add_theme_font_size_override("font_size", 15)
	ThemeHelper.apply_card_button_style(btn)
	var aid: String = String(a.get("id", ""))
	if claimed:
		btn.text = "已领取"
		btn.disabled = true
	elif claimable:
		btn.text = "领取奖励"
		ThemeHelper.apply_primary_button(btn)
		btn.pressed.connect(func(): _on_claim(aid))
	else:
		btn.text = "未达成"
		btn.disabled = true
	vb.add_child(btn)
	_row_state[aid] = {"row": row, "rail": rail, "trophy": trophy, "status": st, "btn": btn}
	return row

func _on_claim(id: String):
	var keep_scroll: int = scroll.scroll_vertical
	var r: Dictionary = PlayerData.claim_achievement(id)
	if r.is_empty():
		return
	_play_claim_animation(r)
	if _row_state.has(id):
		var d: Dictionary = _row_state[id]
		d.rail.color = Color(0.40, 0.76, 0.48)
		d.status.text = "已领取"
		d.status.add_theme_color_override("font_color", Color(0.48, 0.92, 0.60))
		d.btn.text = "已领取"
		d.btn.disabled = true
	achievements = PlayerData.get_achievements()
	_build_summary()
	if currency_row:
		UiComponents.refresh_currency_row(currency_row)
	await get_tree().process_frame
	scroll.scroll_vertical = keep_scroll

func _play_claim_animation(r: Dictionary):
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -190
	panel.offset_bottom = 190
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	sb.border_color = Color(1.0, 0.78, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24
	vb.offset_right = -24
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "领取成功"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	vb.add_child(title)
	var icon = REWARD_ICON.new()
	icon.custom_minimum_size = Vector2(110, 120)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if String(r.get("emote_id", "")) != "":
		icon.setup("emote", 1)
	elif not (r.get("wildcards", {}) as Dictionary).is_empty():
		var wc: Dictionary = r.get("wildcards", {})
		var wn := 0
		for k in wc.keys(): wn += int(wc[k])
		icon.setup("wild", maxi(1, wn))
	elif int(r.get("gold", 0)) > 0:
		icon.setup("gold", int(r.gold))
	elif int(r.get("gems", 0)) > 0:
		icon.setup("gems", int(r.gems))
	elif int(r.get("card", 0)) > 0:
		icon.setup("card", int(r.get("card_amount", 1)), String(r.get("card_name", "")), int(r.card))
	elif String(r.get("chest", "")) != "":
		icon.setup("chest", 1)
	else:
		icon.setup("gold", 1)
	vb.add_child(icon)
	var info := Label.new()
	var parts: Array = []
	if int(r.get("gold", 0)) > 0: parts.append("+%d 金币" % int(r.gold))
	if int(r.get("gems", 0)) > 0: parts.append("+%d 宝石" % int(r.gems))
	if int(r.get("card", 0)) > 0: parts.append("卡牌 ×%d" % int(r.get("card_amount", 1)))
	if String(r.get("chest", "")) != "": parts.append("+幸运宝箱")
	if String(r.get("emote_id", "")) != "": parts.append("+表情")
	var wcd: Dictionary = r.get("wildcards", {})
	for k in wcd.keys():
		parts.append("+%s万能卡 ×%d" % [PlayerData._wildcard_cn(String(k)), int(wcd[k])])
	info.text = "   ".join(parts) if not parts.is_empty() else "奖励已加入账户"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	vb.add_child(info)
	panel.pivot_offset = Vector2(230, 190)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.10)
	tw.tween_interval(0.55)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): overlay.queue_free())

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
