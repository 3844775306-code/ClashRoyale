# scripts/ui/LeaderboardUI.gd
# 排行榜界面：前三名奖牌配色 + 当前玩家高亮 + 空/加载状态
extends Control

var leader_list: VBoxContainer


func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "全球排行榜", _on_back_pressed, true)
	var scroll := UiComponents.make_content_scroll(self)
	leader_list = UiComponents.make_content_vbox()
	scroll.add_child(leader_list)
	_show_loading_message()
	load_leaderboard()
	UiComponents.fade_in(self)


func load_leaderboard():
	print("[LeaderboardUI] 请求排行榜数据...")
	LeaderboardAPI.get_leaderboard(func(entries):
		print("[LeaderboardUI] 收到回调, 条目数: ", entries.size() if entries else 0)
		_clear_list()
		if entries == null:
			_show_message("加载失败 (网络错误)")
			return
		if entries.is_empty():
			_show_message("加载失败：%s" % LeaderboardAPI.last_error if LeaderboardAPI.last_error != "" else "暂无数据")
			return
		_populate_list(entries)
	)


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
	for data in entries:
		var rank: int = data.rank
		var pid := str(data.get("player_id", ""))
		var is_self := false
		if pid != "" and str(ClanManager.get_player_id()) == pid:
			is_self = true
		elif str(data.name) == str(PlayerData.player_name):
			is_self = true
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
				rank_lbl.text = "🥇"
			2:
				rank_lbl.text = "🥈"
			3:
				rank_lbl.text = "🥉"
			_:
				rank_lbl.text = str(rank)
		hbox.add_child(rank_lbl)

		# 玩家名
		var name_lbl := Label.new()
		name_lbl.text = data.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		if is_self:
			name_lbl.text += "（我）"
			name_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		hbox.add_child(name_lbl)

		# 奖杯数
		var score_lbl := Label.new()
		score_lbl.text = "🏆 %d" % data.score
		score_lbl.add_theme_font_size_override("font_size", 18)
		score_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(score_lbl)

		leader_list.add_child(row)


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
