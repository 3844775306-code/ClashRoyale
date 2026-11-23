# scripts/ui/PlayerProfileDialog.gd
# 玩家个人主页：头像/在线状态/奖杯/部落/卡组/战绩/徽章
extends Control

const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")
const BATTLE_MANAGER := preload("res://scripts/core/BattleManager.gd")
const TOWER_PREVIEW := preload("res://scripts/ui/Tower3DPreview.gd")
const TOWER_CATALOG := preload("res://scripts/data/TowerCatalog.gd")

var profile: Dictionary = {}

var _data: Dictionary = {}
var _pid := ""
var _is_self := false
var _tab := 0
var _font: Font
var _bold_font: Font
var _body: VBoxContainer
var _tab_buttons: Array = []
var _header_status: Label
var _header_battle: Label
var _header_trophies: Label
var _header_highest: Label
var _header_arena: Label
var _header_winrate: Label
var _overview_battle: Label
var _friend_btn: Button
var _invite_btn: Button
var _spectate_btn: Button
var _status: Label
var _loading := false
var _cfgs: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 220
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	if _font != null:
		var fv := FontVariation.new()
		fv.base_font = _font
		fv.variation_embolden = 1.25
		_bold_font = fv
	_pid = String(profile.get("player_id", profile.get("id", "")))
	_is_self = _pid != "" and _pid == str(ClanManager.get_player_id())
	_data = profile.duplicate(true)
	if _is_self:
		_data.merge(_self_payload(), true)
	else:
		var pr := PresenceManager.public_record(_pid)
		if not pr.is_empty():
			_data.merge(pr, true)
	_build_ui()
	if not _is_self:
		call_deferred("_load_remote")
	set_process(true)


func _process(_delta: float) -> void:
	_update_live_labels()
	_refresh_header_stats()


func _load_remote() -> void:
	if _loading or _is_self or _pid == "":
		return
	_loading = true
	var remote: Dictionary = await ProfileAPI.fetch(_pid)
	_loading = false
	if remote is Dictionary and not remote.is_empty():
		_data.merge(remote, true)
		_rebuild_tab()


func _self_payload() -> Dictionary:
	var deck: Array = []
	for cid in PlayerData.get_active_deck():
		deck.append({"id": int(cid), "level": PlayerData.get_card_level(int(cid))})
	var clan := ""
	if ClanManager.has_method("get_my_clan_name"):
		clan = String(ClanManager.get_my_clan_name())
	return {
		"player_id": _pid, "name": PlayerData.player_name,
		"avatar_seed": PlayerData.avatar_seed, "avatar_index": PlayerData.avatar_index,
		"trophies": PlayerData.trophies, "highest_trophies": PlayerData.highest_trophies,
		"arena": PlayerData.get_arena(), "clan": clan,
		"battle_wins": PlayerData.battle_wins, "battle_losses": PlayerData.battle_losses,
		"battle_draws": PlayerData.battle_draws, "three_crowns": PlayerData.three_crown_wins,
		"current_streak": PlayerData.current_streak, "best_streak": PlayerData.best_streak,
		"season_crowns": PlayerData.season_crowns, "collection_level": PlayerData.get_collection_level(),
		"honor_title": PlayerData.honor_title,
		"tower_choice": PlayerData.tower_choice, "tower_used": PlayerData.get_most_used_tower(), "bio": PlayerData.bio,
		"role": PlayerData.clan_role, "donations": PlayerData.total_donations,
		"current_deck": deck, "top_cards": PlayerData.get_most_used_cards(3),
		"recent_battles": PlayerData.recent_battles.duplicate(true),
		"trophy_badges": PlayerData.claimed_achievements.size(),
		"mastery_badges": PlayerData.get_mastery_card_count(),
		"season_badges": PlayerData.season_claimed.size(),
	}


func _build_ui() -> void:
	UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -620
	panel.offset_bottom = 620
	add_child(panel)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := _label("玩家资料", 24, ThemeHelper.COLORS.gold, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var av_row := HBoxContainer.new()
	av_row.add_theme_constant_override("separation", 14)
	root.add_child(av_row)
	var name := String(_data.get("name", "玩家"))
	var seedv := int(_data.get("avatar_seed", absi(hash(name))))
	var idx := int(_data.get("avatar_index", seedv % 12))
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(104, 104)
	av.size = Vector2(104, 104)
	av.setup(name, seedv, idx)
	av_row.add_child(av)
	CloudAvatar.apply(av, _pid, name, seedv, idx, _is_self)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	av_row.add_child(info)
	info.add_child(_label(name, 24, ThemeHelper.COLORS.text, true))
	_header_status = _label("", 12, Color(0.58, 0.66, 0.78))
	info.add_child(_header_status)
	_header_battle = _label("", 12, Color(1.0, 0.72, 0.32))
	info.add_child(_header_battle)
	var clan := String(_data.get("clan", ""))
	var role := String(_data.get("role", ""))
	info.add_child(_label("部落：%s%s" % [clan if clan != "" else "未加入", (" · " + role) if role != "" else ""], 12, Color(0.72, 0.82, 0.95)))
	var honor := String(_data.get("honor_title", ""))
	if honor != "":
		var hl := _label("🏅 %s" % honor, 12, Color(1.0, 0.86, 0.40))
		info.add_child(hl)
	info.add_child(_label("ID %s" % (_pid if _pid != "" else "未知"), 11, ThemeHelper.COLORS.text_muted))

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 6)
	root.add_child(stat_row)
	_header_trophies = _small_stat(stat_row, "奖杯", "0")
	_header_highest = _small_stat(stat_row, "最高", "0")
	_header_arena = _small_stat(stat_row, "竞技场", "1")
	_header_winrate = _small_stat(stat_row, "胜率", "0%")

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	for i in 4:
		var names := ["概览", "卡组", "战绩", "徽章"]
		var b := Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_switch_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 24
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)

	_friend_btn = UiComponents.make_primary_button("添加好友", _on_add_friend, Vector2(0, 48))
	_friend_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_friend_btn)
	_spectate_btn = UiComponents.make_secondary_button("观战", _on_spectate, Vector2(0, 42))
	_spectate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_spectate_btn)
	_invite_btn = UiComponents.make_secondary_button("邀请入房", _on_invite, Vector2(0, 42))
	_invite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_invite_btn)
	_status = _label("", 11, ThemeHelper.COLORS.text_muted)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var copy_btn := UiComponents.make_secondary_button("复制 ID", _copy_id, Vector2(0, 38))
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(copy_btn)
	var close_btn := UiComponents.make_secondary_button("关闭", func(): queue_free(), Vector2(0, 38))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(close_btn)

	_switch_tab(0)
	_update_friend_btn()
	_refresh_spectate_btn()
	_refresh_header_stats()
	_update_live_labels()


func _small_stat(parent: HBoxContainer, key: String, value: String) -> Label:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	p.add_child(vb)
	var k := _label(key, 10, ThemeHelper.COLORS.text_muted)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(k)
	var v := _label(value, 15, ThemeHelper.COLORS.gold, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(v)
	parent.add_child(p)
	return v


func _refresh_header_stats() -> void:
	if _header_trophies == null:
		return
	_header_trophies.text = str(int(_data.get("trophies", 0)))
	_header_highest.text = str(int(_data.get("highest_trophies", _data.get("trophies", 0))))
	var arena := int(_data.get("arena", 1))
	_header_arena.text = PlayerData.get_arena_name_at(arena)
	var total := int(_data.get("battle_wins", 0)) + int(_data.get("battle_losses", 0)) + int(_data.get("battle_draws", 0))
	var wr := 0 if total <= 0 else int(round(float(_data.get("battle_wins", 0)) * 100.0 / total))
	_header_winrate.text = "%d%%" % wr


func _refresh_spectate_btn() -> void:
	if _spectate_btn == null:
		return
	if _is_self or _pid == "":
		_spectate_btn.visible = false
		return
	var bi := PresenceManager.get_battle_info(_pid)
	var transport := String(bi.get("battle_transport", ""))
	var room := String(bi.get("battle_room", ""))
	var ip := String(bi.get("battle_ip", ""))
	_spectate_btn.visible = bool(bi.get("battle_active", false)) and room != "" and (transport == "webrtc" or ip != "")


func _update_live_labels() -> void:
	if _header_status == null:
		return
	_refresh_spectate_btn()
	var bi := PresenceManager.get_battle_info(_pid)
	var info := _battle_text(bi)
	var online := PresenceManager.is_online(_pid) if _pid != "" else false
	if info != "":
		_header_status.text = "在线"
		_header_status.add_theme_color_override("font_color", Color(0.48, 1.0, 0.62))
		_header_battle.text = info
		_header_battle.visible = true
	else:
		_header_status.text = "在线" if online else PresenceManager.last_seen_text(_pid)
		_header_status.add_theme_color_override("font_color", Color(0.48, 1.0, 0.62) if online else Color(0.58, 0.66, 0.78))
		_header_battle.visible = false
	if _overview_battle:
		_overview_battle.text = info if info != "" else ("在线" if online else "离线")


func _battle_text(bi: Dictionary) -> String:
	if not bool(bi.get("battle_active", false)):
		return ""
	var mode := String(bi.get("battle_mode", "对战中"))
	var started := int(bi.get("battle_started", 0))
	var sec := 0 if started <= 0 else maxi(0, int(Time.get_unix_time_from_system()) - started)
	var watchers := int(bi.get("battle_spectators", 0))
	var suffix := " · %d人观战" % watchers if watchers > 0 else ""
	return "⚔ 对战中 · %s · %02d:%02d%s" % [mode, sec / 60, sec % 60, suffix]


func _switch_tab(index: int) -> void:
	_tab = index
	for i in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[i]
		var active := i == index
		b.add_theme_color_override("font_color", ThemeHelper.COLORS.gold if active else Color(0.62, 0.70, 0.85))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.10, 0.05, 0.98) if active else Color(0.04, 0.065, 0.12, 0.96)
		sb.border_color = ThemeHelper.COLORS.gold if active else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(9)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
	if _body != null:
		_rebuild_tab()


func _rebuild_tab() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	_overview_battle = null
	match _tab:
		0: _build_overview()
		1: _build_deck()
		2: _build_battles()
		3: _build_badges()


func _section(title: String) -> void:
	_body.add_child(_label(title, 15, ThemeHelper.COLORS.gold, true))


func _build_overview() -> void:
	_section("当前状态")
	var status_card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(0.35, 0.55, 0.85, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	status_card.add_theme_stylebox_override("panel", sb)
	_body.add_child(status_card)
	_overview_battle = _label("", 14, Color(1.0, 0.78, 0.40), true)
	_overview_battle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview_battle.custom_minimum_size = Vector2(0, 44)
	_overview_battle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_card.add_child(_overview_battle)
	_update_live_labels()

	_section("数据")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	var wins := int(_data.get("battle_wins", 0))
	var losses := int(_data.get("battle_losses", 0))
	var draws := int(_data.get("battle_draws", 0))
	var total := wins + losses + draws
	grid.add_child(_stat_card("总场次", str(total)))
	grid.add_child(_stat_card("胜率", "%d%%" % (0 if total <= 0 else int(round(float(wins) * 100.0 / total)))))
	grid.add_child(_stat_card("三冠次数", str(int(_data.get("three_crowns", 0)))))
	grid.add_child(_stat_card("当前连胜", str(int(_data.get("current_streak", 0)))))
	grid.add_child(_stat_card("最高连胜", str(int(_data.get("best_streak", 0)))))
	grid.add_child(_stat_card("赛季皇冠", str(int(_data.get("season_crowns", 0)))))
	grid.add_child(_stat_card("收藏等级", str(int(_data.get("collection_level", 1)))))
	grid.add_child(_stat_card("部落捐赠", str(int(_data.get("donations", 0)))))

	_section("简介")
	var bio := String(_data.get("bio", ""))
	if bio == "":
		bio = "热爱皇室战争的玩家，欢迎一起交流卡组与战术。"
	var bio_lbl := _label(bio, 13, Color(0.72, 0.78, 0.90))
	bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(bio_lbl)


func _stat_card(key: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 58)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	p.add_child(vb)
	var k := _label(key, 11, ThemeHelper.COLORS.text_muted)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(k)
	var v := _label(value, 17, ThemeHelper.COLORS.gold, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _deck_cards() -> Array:
	var deck: Array = Array(_data.get("current_deck", []))
	if deck.is_empty() and _is_self:
		for cid in PlayerData.get_active_deck():
			deck.append({"id": int(cid), "level": PlayerData.get_card_level(int(cid))})
	return deck


func _build_deck() -> void:
	var current_tower := clampi(int(_data.get("tower_choice", 1)), 1, 4)
	var most_tower := clampi(int(_data.get("tower_used", current_tower)), 1, 4)
	_section("皇家塔")
	var tower_row := HBoxContainer.new()
	tower_row.add_theme_constant_override("separation", 8)
	_body.add_child(tower_row)
	tower_row.add_child(_tower_card("当前使用", current_tower))
	tower_row.add_child(_tower_card("最常使用", most_tower))

	var top_cards: Array = Array(_data.get("top_cards", []))
	if top_cards.is_empty() and _is_self:
		top_cards = PlayerData.get_most_used_cards(3)
	if not top_cards.is_empty():
		_section("最常使用")
		var top_grid := GridContainer.new()
		top_grid.columns = 3
		top_grid.add_theme_constant_override("h_separation", 6)
		top_grid.add_theme_constant_override("v_separation", 6)
		_body.add_child(top_grid)
		for item in top_cards.slice(0, 3):
			var cid := int(item.get("id", 0)) if item is Dictionary else int(item)
			var lv := int(item.get("level", 1)) if item is Dictionary else 1
			top_grid.add_child(_mini_card(cid, lv))
		_body.add_child(_label("按历史使用次数排序", 12, ThemeHelper.COLORS.text_muted))
	_section("当前卡组")
	var deck := _deck_cards()
	if deck.is_empty():
		_body.add_child(_label("暂无公开卡组", 13, ThemeHelper.COLORS.text_muted))
		return
	var avg := 0.0
	for item in deck:
		var cid := int(item.get("id", 0)) if item is Dictionary else int(item)
		var cfg = _card_cfg(cid)
		if cfg:
			avg += float(cfg.cost)
	_body.add_child(_label("平均圣水 %.1f · %d 张" % [avg / maxf(1.0, float(deck.size())), deck.size()], 12, Color(0.72, 0.82, 0.95)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for item in deck:
		var cid := int(item.get("id", 0)) if item is Dictionary else int(item)
		var lv := int(item.get("level", 1)) if item is Dictionary else 1
		grid.add_child(_mini_card(cid, lv))


func _tower_card(caption: String, choice: int) -> Control:
	var data: Dictionary = TOWER_CATALOG.get_tower(choice)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 205)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(0.62, 0.48, 0.22, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.offset_top = 8
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var preview = TOWER_PREVIEW.new()
	preview.custom_minimum_size = Vector2(128, 170)
	preview.size = Vector2(128, 170)
	preview.choice = choice
	h.add_child(preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	info.add_child(_label(caption, 11, Color(0.68, 0.78, 0.92)))
	info.add_child(_label(String(data.name), 20, ThemeHelper.COLORS.gold, true))
	info.add_child(_label("生命 %d" % int(data.hp), 12, Color(0.95, 0.72, 0.55)))
	info.add_child(_label("伤害 %d" % int(data.damage), 12, Color(1.0, 0.78, 0.45)))
	info.add_child(_label("攻速 %.1f/秒" % (1000.0 / maxf(1.0, float(data.attack_speed))), 12, Color(0.72, 0.84, 1.0)))
	info.add_child(_label("特殊：%s" % String(data.special), 11, Color(0.72, 0.82, 0.96)))
	return p


func _mini_card(cid: int, level: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(130, 152)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	sb.border_color = Color(0.45, 0.55, 0.75, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", sb)
	var cfg = _card_cfg(cid)
	var nm := String(cfg.card_name) if cfg else "卡牌 %d" % cid
	var path := "res://assets/cards_web/%s.png" % nm
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % nm
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4
		tr.offset_right = -4
		tr.offset_top = 4
		tr.offset_bottom = -42
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
	var lv_lbl := _label("Lv.%d" % level, 11, ThemeHelper.COLORS.gold)
	lv_lbl.position = Vector2(7, 118)
	lv_lbl.size = Vector2(46, 18)
	lv_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lv_lbl.clip_text = true
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lv_lbl)
	var n_lbl := _label(nm, 10, Color(0.92, 0.95, 1.0))
	n_lbl.position = Vector2(56, 118)
	n_lbl.size = Vector2(66, 18)
	n_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	n_lbl.clip_text = true
	n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(n_lbl)
	return p


func _build_battles() -> void:
	var wins := int(_data.get("battle_wins", 0))
	var losses := int(_data.get("battle_losses", 0))
	var draws := int(_data.get("battle_draws", 0))
	var total := wins + losses + draws
	_section("历史战绩")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	row.add_child(_stat_card("胜利", str(wins)))
	row.add_child(_stat_card("失败", str(losses)))
	row.add_child(_stat_card("平局", str(draws)))

	var rate := 0 if total <= 0 else int(round(float(wins) * 100.0 / float(total)))
	var rate_panel := PanelContainer.new()
	rate_panel.custom_minimum_size = Vector2(0, 70)
	var rp_sb := StyleBoxFlat.new()
	rp_sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	rp_sb.border_color = Color(0.35, 0.55, 0.85, 0.45)
	rp_sb.set_border_width_all(1)
	rp_sb.set_corner_radius_all(10)
	rate_panel.add_theme_stylebox_override("panel", rp_sb)
	_body.add_child(rate_panel)
	var rate_v := VBoxContainer.new()
	rate_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rate_v.offset_left = 14
	rate_v.offset_right = -14
	rate_v.offset_top = 10
	rate_v.offset_bottom = -10
	rate_v.add_theme_constant_override("separation", 6)
	rate_panel.add_child(rate_v)
	rate_v.add_child(_label("胜率 %d%%    ·    三冠 %d 次    ·    当前连胜 %d" % [
		rate, int(_data.get("three_crowns", 0)), int(_data.get("current_streak", 0))],
		14, ThemeHelper.COLORS.gold, true))
	var rate_bar := ProgressBar.new()
	rate_bar.custom_minimum_size = Vector2(0, 14)
	rate_bar.show_percentage = false
	rate_bar.max_value = 100.0
	rate_bar.value = float(rate)
	var rb_bg := StyleBoxFlat.new()
	rb_bg.bg_color = Color(0.025, 0.04, 0.08, 0.95)
	rb_bg.set_corner_radius_all(7)
	rate_bar.add_theme_stylebox_override("background", rb_bg)
	var rb_fill := StyleBoxFlat.new()
	rb_fill.bg_color = Color(0.42, 0.82, 0.56)
	rb_fill.set_corner_radius_all(7)
	rate_bar.add_theme_stylebox_override("fill", rb_fill)
	rate_v.add_child(rate_bar)

	_section("最近对战")
	var recent: Array = Array(_data.get("recent_battles", []))
	if recent.is_empty():
		_body.add_child(_label("暂无最近对战记录", 14, ThemeHelper.COLORS.text_muted))
		return
	for i in range(mini(recent.size(), 5)):
		var b: Dictionary = Dictionary(recent[i])
		_body.add_child(_battle_history_row(b))


func _battle_history_row(b: Dictionary) -> Control:
	var result := "平" if bool(b.get("draw", false)) else ("胜" if bool(b.get("win", false)) else "负")
	var col := Color(0.80, 0.82, 0.95) if result == "平" else (Color(0.52, 1.0, 0.62) if result == "胜" else Color(1.0, 0.55, 0.52))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(col.r, col.g, col.b, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	row.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var ts := int(b.get("ts", 0))
	var time_text := "--"
	if ts > 0:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		time_text = "%02d-%02d %02d:%02d" % [int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]
	var tl := _label(time_text, 11, ThemeHelper.COLORS.text_muted)
	tl.custom_minimum_size = Vector2(112, 0)
	head.add_child(tl)
	var mode := _label(String(b.get("mode", "对战")), 13, Color(0.82, 0.90, 1.0))
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(mode)
	var res := _label("  %s  " % result, 16, col, true)
	head.add_child(res)

	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 8)
	v.add_child(hud_row)
	var p_hud: Dictionary = Dictionary(b.get("player_hud", {}))
	var e_hud: Dictionary = Dictionary(b.get("enemy_hud", {}))
	var player_name := String(p_hud.get("name", _data.get("name", PlayerData.player_name if _is_self else "玩家")))
	var enemy_name := String(e_hud.get("name", b.get("opponent", "对手")))
	var left_hud := _history_hud("我方", player_name, p_hud, int(b.get("crowns_for", 0)), _data if _is_self else {}, true)
	left_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(left_hud)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(110, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 1)
	hud_row.add_child(mid)
	var score := _label("%d : %d" % [int(b.get("crowns_for", 0)), int(b.get("crowns_against", 0))], 22, col, true)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(score)
	var dur := int(float(b.get("duration", 0.0)))
	var dur_lbl := _label("%d:%02d" % [dur / 60, dur % 60], 12, Color(0.76, 0.84, 1.0))
	dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(dur_lbl)
	var right_hud := _history_hud("敌方", enemy_name, e_hud, int(b.get("crowns_against", 0)), {}, false)
	right_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(right_hud)

	var decks := HBoxContainer.new()
	decks.add_theme_constant_override("separation", 8)
	v.add_child(decks)
	var p_deck: Array = Array(b.get("player_deck", []))
	if p_deck.is_empty():
		p_deck = _deck_cards()
	var e_deck: Array = Array(b.get("enemy_deck", []))
	decks.add_child(_history_deck_strip("我方卡组", p_deck))
	decks.add_child(_history_deck_strip("敌方卡组", e_deck))
	return row


func _history_hud(caption: String, name: String, block: Dictionary, crowns: int, fallback: Dictionary, is_left: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.045, 0.09, 0.95)
	sb.border_color = Color(0.35, 0.58, 0.95, 0.28) if is_left else Color(0.95, 0.38, 0.35, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", 7)
	p.add_child(h)
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(38, 38)
	av.size = Vector2(38, 38)
	var seed := int(block.get("avatar_seed", fallback.get("avatar_seed", absi(hash(name)))))
	var aidx := int(block.get("avatar_index", fallback.get("avatar_index", 0)))
	av.setup(name, seed, aidx)
	h.add_child(av)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	var nm := _label(("%s · %s" % [caption, name]), 12, Color(0.90, 0.95, 1.0), true)
	nm.clip_text = true
	info.add_child(nm)
	var trophies := int(block.get("trophies", fallback.get("trophies", 0)))
	var king_hp := int(block.get("king_hp", -1))
	var elixir := int(block.get("elixir_spent", -1))
	var parts: Array = ["🏆 %d" % trophies]
	if king_hp >= 0:
		parts.append("国王塔 %d" % king_hp)
	if elixir >= 0:
		parts.append("圣水 %d" % elixir)
	var sub := _label(" · ".join(parts), 10, ThemeHelper.COLORS.text_muted)
	sub.clip_text = true
	info.add_child(sub)
	var crown := _label("👑%d" % crowns, 17, ThemeHelper.COLORS.gold, true)
	crown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(crown)
	return p


func _history_deck_strip(title: String, deck: Array) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(title, 10, ThemeHelper.COLORS.text_muted))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	box.add_child(h)
	if deck.is_empty():
		h.add_child(_label("无卡组记录", 10, Color(0.55, 0.62, 0.74)))
		return box
	for item in deck.slice(0, 8):
		var cid := int(item.get("id", 0)) if item is Dictionary else int(item)
		var lv := int(item.get("level", 1)) if item is Dictionary else 1
		h.add_child(_history_card_icon(cid, lv))
	return box


func _history_card_icon(cid: int, level: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(26, 34)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	sb.border_color = Color(0.55, 0.62, 0.78, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfg = _card_cfg(cid)
	if cfg:
		var path := "res://assets/cards_web/%s.png" % String(cfg.card_name)
		if not ResourceLoader.exists(path):
			path = "res://assets/cards_rendered/%s.png" % String(cfg.card_name)
		if ResourceLoader.exists(path):
			tr.texture = load(path)
	p.add_child(tr)
	var lv_lbl := _label(str(level), 8, Color(1, 0.88, 0.55))
	lv_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lv_lbl.position = Vector2(-15, -12)
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lv_lbl)
	return p


func _build_badges() -> void:
	_section("徽章")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	grid.add_child(_stat_card("奖杯之路", str(int(_data.get("trophy_badges", 0)))))
	grid.add_child(_stat_card("卡牌大师", str(int(_data.get("mastery_badges", 0)))))
	grid.add_child(_stat_card("主题赛季", str(int(_data.get("season_badges", 0)))))
	grid.add_child(_stat_card("最高奖杯", str(int(_data.get("highest_trophies", 0)))))
	_body.add_child(_label("已获得徽章会在后续版本显示为独立图标。", 12, ThemeHelper.COLORS.text_muted))


func _card_cfg(cid: int):
	if _cfgs.is_empty():
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if bm == null:
			bm = BATTLE_MANAGER.new()
			bm.load_card_configs()
		for cfg in bm.configs:
			if cfg:
				_cfgs[int(cfg.card_id)] = cfg
	return _cfgs.get(cid, null)


func _copy_id() -> void:
	if _pid != "":
		DisplayServer.clipboard_set(_pid)
		_status.text = "ID 已复制"


func _update_friend_btn() -> void:
	if _friend_btn == null:
		return
	_friend_btn.disabled = false
	if bool(_data.get("ai", false)):
		_friend_btn.text = "AI 对手"
		_friend_btn.disabled = true
	elif _is_self:
		_friend_btn.text = "这是你"
		_friend_btn.disabled = true
	elif FriendManager.is_friend(_pid):
		_friend_btn.text = "已是好友"
		_friend_btn.disabled = true
	elif FriendManager.has_incoming(_pid):
		_friend_btn.text = "同意好友请求"
	elif FriendManager.has_outgoing(_pid):
		_friend_btn.text = "再次申请好友"
	else:
		_friend_btn.text = "发送好友请求"
	if _invite_btn:
		if bool(_data.get("ai", false)):
			_invite_btn.text = "AI 对手"
			_invite_btn.disabled = true
		elif NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.room_code != "":
			_invite_btn.text = "邀请入房（跨网）" if NetworkManager.webrtc_mode else "邀请入房（局域网）"
			_invite_btn.disabled = false
		else:
			_invite_btn.text = "邀请入房（需先创建房间）"
			_invite_btn.disabled = true


func _on_add_friend() -> void:
	if _pid == "":
		return
	if FriendManager.has_incoming(_pid):
		FriendManager.accept_request(_pid)
		_status.text = "已同意好友请求"
	elif FriendManager.send_friend_request(_data):
		_status.text = "好友请求已发送"
	else:
		_status.text = "已是好友或请求已发送"
	_update_friend_btn()


func _on_spectate() -> void:
	var bi := PresenceManager.get_battle_info(_pid)
	var code := String(bi.get("battle_room", ""))
	var transport := String(bi.get("battle_transport", ""))
	var ip := String(bi.get("battle_ip", ""))
	if code == "":
		_status.text = "对方当前没有可观的对局"
		return
	LoadingScreen.show_loading("正在连接观战…")
	var ok := false
	if transport == "webrtc":
		ok = await NetworkManager.join_spectator_webrtc(code)
		if not ok:
			await get_tree().create_timer(0.8).timeout
			ok = await NetworkManager.join_spectator_webrtc(code)
	elif ip != "":
		ok = NetworkManager.join_spectator_lan(ip, 24500, code)
	if ok:
		LoadingScreen.change_scene("res://scenes/network_guest.tscn", "正在进入观战…")
	else:
		LoadingScreen.hide_loading()
		_status.text = "观战连接失败，请稍后重试"


func _on_invite() -> void:
	if NetworkManager.role != NetworkManager.Role.HOST or NetworkManager.room_code == "":
		_status.text = "请先创建联机房间"
		return
	if NetworkManager.webrtc_mode:
		FriendManager.send_cloud_room_invite(NetworkManager.room_code, PlayerData.player_name, _pid)
		_status.text = "已发送跨网邀请"
	else:
		FriendManager.send_room_invite(NetworkManager.room_code, NetworkManager.get_local_ip(), PlayerData.player_name, _pid)
		_status.text = "已发送局域网邀请"


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(14, int(round(float(fs) * 1.36))))
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", _bold_font if _bold_font != null else _font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
