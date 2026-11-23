# scripts/ui/LeaderboardUI.gd
# 排行榜界面：前三名奖牌配色 + 当前玩家高亮 + 空/加载状态
extends Control
const AVATAR_ICON = preload("res://scripts/ui/AvatarIcon.gd")

var leader_list: VBoxContainer
var _scroll: ScrollContainer
var _refresh_timer: Timer
var _loading: bool = false
var _all_entries: Array = []
var _category: int = 0
var _category_names := ["最高奖杯", "本周奖杯净增", "本周胜场", "本周三冠", "收藏等级", "卡牌大师"]


func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "全球排行榜", _on_back_pressed, true)
	_scroll = UiComponents.make_content_scroll(self)
	leader_list = UiComponents.make_content_vbox()
	_scroll.add_child(leader_list)
	_show_loading_message()
	load_leaderboard()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 5.0
	_refresh_timer.timeout.connect(load_leaderboard)
	add_child(_refresh_timer)
	_refresh_timer.start()
	UiComponents.fade_in(self)


func load_leaderboard():
	if _loading or not is_inside_tree():
		return
	_loading = true
	print("[LeaderboardUI] 请求排行榜数据...")
	LeaderboardAPI.get_leaderboard(_on_leaderboard_loaded)

func _on_leaderboard_loaded(entries):
	_loading = false
	if not is_inside_tree():
		return
	var keep: int = _scroll.scroll_vertical if _scroll else 0
	var incoming: Array = entries if entries is Array else []
	# 云端短时失败/空响应时保留旧榜单，避免突然变成“云端无数据”
	if incoming.is_empty():
		if _all_entries.is_empty():
			_clear_list()
			if entries == null:
				_show_message("加载失败 (网络错误)")
			elif not AccountManager.is_supabase_authenticated():
				_show_message("当前为本机账号，请使用邮箱+密码登录 Supabase 查看云端排行榜")
			else:
				_show_message("Supabase 云端暂无排行数据")
		else:
			_populate_list(_all_entries)
			if _scroll:
				_scroll.scroll_vertical = keep
		return
	_all_entries = incoming
	_populate_list(_all_entries)
	if _scroll:
		_scroll.scroll_vertical = keep


func _highest_of(d) -> int:
	return int(d.get("highest_trophies", d.get("score", 0)))


func _clear_list():
	for child in leader_list.get_children():
		child.queue_free()


func _show_loading_message():
	_clear_list()
	var empty := UiComponents.make_empty_state("⏳", "加载中...", "正在同步全球排行榜")
	empty.custom_minimum_size = Vector2(0, 600)
	leader_list.add_child(empty)


func _show_message(text: String):
	_clear_list()
	var empty := UiComponents.make_empty_state("🏆", text, "")
	empty.custom_minimum_size = Vector2(0, 600)
	leader_list.add_child(empty)


func _populate_list(entries: Array):
	_clear_list()
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	leader_list.add_child(tab_bar)
	for i in range(_category_names.size()):
		var tb := Button.new()
		tb.text = _category_names[i]
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(0, 42)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 12)
		var active := i == _category
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.10, 0.04, 0.98) if active else Color(0.04, 0.06, 0.12, 0.96)
		sb.border_color = ThemeHelper.COLORS.gold if active else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(9)
		tb.add_theme_stylebox_override("normal", sb)
		tb.add_theme_stylebox_override("hover", sb)
		tb.add_theme_stylebox_override("pressed", sb)
		var cat := i
		tb.pressed.connect(func():
			_category = cat
			_populate_list(_all_entries))
		tab_bar.add_child(tb)
	var rows: Array = []
	var wk := PlayerData.current_week_key()
	for d in entries:
		if not (d is Dictionary):
			continue
		if _category in [1, 2, 3] and String(d.get("week_key", "")) != wk:
			continue
		rows.append(d)
	if _category == 0:
		rows.sort_custom(func(a, b): return _highest_of(a) > _highest_of(b))
	elif _category == 1:
		rows.sort_custom(func(a, b): return int(a.get("weekly_score", 0)) > int(b.get("weekly_score", 0)))
	elif _category == 2:
		rows.sort_custom(func(a, b): return int(a.get("weekly_wins", 0)) > int(b.get("weekly_wins", 0)))
	elif _category == 3:
		rows.sort_custom(func(a, b): return int(a.get("weekly_three_crowns", 0)) > int(b.get("weekly_three_crowns", 0)))
	elif _category == 4:
		rows.sort_custom(func(a, b): return int(a.get("collection_level", 1)) > int(b.get("collection_level", 1)))
	else:
		rows.sort_custom(func(a, b): return int(a.get("mastery_count", 0)) > int(b.get("mastery_count", 0)))
	if rows.is_empty():
		var e := UiComponents.make_empty_state("🏆", "暂无排行数据", "完成对战后会自动上榜")
		e.custom_minimum_size = Vector2(0, 420)
		leader_list.add_child(e)
		return
	for idx in range(rows.size()):
		var data: Dictionary = rows[idx]
		var rank: int = idx + 1
		var pid := str(data.get("player_id", ""))
		var is_self := false
		var scoped := String(data.get("scoped_id", ""))
		if scoped != "" and scoped == str(ClanManager.get_player_id()):
			is_self = true
		elif pid != "" and str(ClanManager.get_player_id()) == pid:
			is_self = true
		elif str(data.name) == str(PlayerData.player_name):
			is_self = true
		var display_name: String = PlayerData.player_name if is_self else String(data.name)
		if display_name.strip_edges() == "":
			display_name = "玩家"
		var accent := ThemeHelper.COLORS.gold if is_self else Color.TRANSPARENT
		var row := UiComponents.make_list_row(accent, 60)
		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 16
		hbox.offset_top = 6
		hbox.offset_right = -16
		hbox.offset_bottom = -6
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		# 排名（前三名奖牌配色）
		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(70, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_size_override("font_size", 22)
		match rank:
			1:
				rank_lbl.text = "1"
				rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
			2:
				rank_lbl.text = "2"
				rank_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
			3:
				rank_lbl.text = "3"
				rank_lbl.add_theme_color_override("font_color", Color(0.86, 0.58, 0.30))
			_:
				rank_lbl.text = str(rank)
		hbox.add_child(rank_lbl)
		var av = AVATAR_ICON.new()
		av.custom_minimum_size = Vector2(46, 46)
		av.size = Vector2(46, 46)
		var hs: int = int(data.get("avatar_seed", absi(hash(display_name))))
		var ai: int = int(data.get("avatar_index", hs % 12))
		if is_self:
			av.setup_local()
		else:
			av.setup(display_name, hs, ai)
		hbox.add_child(av)
		if not is_self:
			CloudAvatar.apply(av, str(scoped if scoped != "" else data.get("player_id", "")), display_name, hs, ai)
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		var prof := {
			"player_id": scoped if scoped != "" else String(data.get("player_id", "")),
			"name": display_name,
			"trophies": int(data.get("score", 0)),
			"rank": int(data.get("rank", 0)),
			"avatar_seed": int(data.get("avatar_seed", absi(hash(display_name)))),
			"avatar_index": int(data.get("avatar_index", 0)),
			"clan": String(data.get("clan", "")),
		}
		av.clicked.connect(func(): UiComponents.open_player_profile(self, prof))

		# 玩家名
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		if is_self:
			name_lbl.text += "（我）"
			name_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		var honor := String(data.get("honor_title", ""))
		if honor != "":
			name_lbl.text = "%s  🏅%s" % [name_lbl.text, honor]
		hbox.add_child(name_lbl)

		# 奖杯数
		var score_lbl := Label.new()
		var display_score: int = int(data.get("highest_trophies", data.get("score", 0)))
		var score_suffix := "杯"
		if _category == 1:
			display_score = int(data.get("weekly_score", 0))
			score_suffix = "杯"
			score_lbl.text = "%+d %s" % [display_score, score_suffix]
		else:
			if _category == 2:
				display_score = int(data.get("weekly_wins", 0))
				score_suffix = "胜"
			elif _category == 3:
				display_score = int(data.get("weekly_three_crowns", 0))
				score_suffix = "次"
			elif _category == 4:
				display_score = int(data.get("collection_level", 1))
				score_suffix = "级"
			elif _category == 5:
				display_score = int(data.get("mastery_count", 0))
				score_suffix = "个"
			score_lbl.text = "%d %s" % [display_score, score_suffix]
		score_lbl.add_theme_font_size_override("font_size", 18)
		score_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(score_lbl)

		leader_list.add_child(row)


func _open_profile(data: Dictionary, display_name: String) -> void:
	var dlg = preload("res://scripts/ui/PlayerProfileDialog.gd").new()
	dlg.profile = {
		"player_id": String(data.get("player_id", "")),
		"name": display_name,
		"trophies": int(data.get("score", 0)),
		"rank": int(data.get("rank", 0)),
		"avatar_seed": int(data.get("avatar_seed", absi(hash(display_name)))),
		"avatar_index": int(data.get("avatar_index", 0)),
		"clan": String(data.get("clan", "")),
	}
	add_child(dlg)


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
