# assets/ui/FriendCenter.gd
# 好友中心：好友请求、搜索添加、在线状态、邀请入房
extends Control

const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const PANEL_BG := Color(0.030, 0.048, 0.098, 0.985)
const ROW_BG := Color(0.055, 0.080, 0.150, 0.94)
const GREEN := Color(0.35, 0.95, 0.48)

var _search_edit: LineEdit
var _results: VBoxContainer
var _friends_box: VBoxContainer
var _requests_box: VBoxContainer
var _nearby_box: VBoxContainer
var _online_box: VBoxContainer
var _status: Label
var _font: Font
var _online_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	z_index = 230
	_build()
	_refresh_all()
	FriendManager.friends_changed.connect(_refresh_friends)
	FriendManager.presence_changed.connect(_refresh_friends)
	FriendManager.presence_changed.connect(_refresh_nearby)
	FriendManager.requests_changed.connect(_refresh_all)
	if PresenceManager and not PresenceManager.presence_changed.is_connected(_refresh_online_players):
		PresenceManager.presence_changed.connect(_refresh_online_players)


func _build() -> void:
	var overlay := UiComponents.make_overlay(self)
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free())

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -356
	panel.offset_right = 356
	panel.offset_top = -700
	panel.offset_bottom = 700
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_right = -26
	v.offset_top = 22
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# 标题行
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var close := Button.new()
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(46, 46)
	close.add_theme_stylebox_override("normal", _round_style(Color(0.06, 0.09, 0.17, 0.95), 1, Color(1, 1, 1, 0.16)))
	close.add_theme_stylebox_override("hover", _round_style(Color(0.10, 0.14, 0.25, 0.98), 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.6)))
	close.add_theme_stylebox_override("pressed", _round_style(Color(0.05, 0.07, 0.13, 0.95), 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.5)))
	close.pressed.connect(func(): queue_free())
	head.add_child(close)
	var back_icon = ICON.new()
	back_icon.kind = "back"
	back_icon.tint = PARCHMENT
	back_icon.size = Vector2(22, 22)
	back_icon.position = Vector2(12, 12)
	close.add_child(back_icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	head.add_child(title_box)
	var title := _label("好友中心", 27, GOLD_LIGHT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(title)
	var sub := _label("连接你的皇室战友", 12, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(sub)
	_online_lbl = _label("", 12, GREEN)
	_online_lbl.custom_minimum_size = Vector2(100, 0)
	_online_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_online_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_online_lbl)

	# 搜索
	var search_card := Panel.new()
	search_card.custom_minimum_size = Vector2(0, 128)
	search_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_card.add_theme_stylebox_override("panel", _round_style(Color(0.045, 0.065, 0.125, 0.9), 1, Color(1, 1, 1, 0.08), 16))
	v.add_child(search_card)
	var search_m := MarginContainer.new()
	search_m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	search_m.add_theme_constant_override("margin_left", 14)
	search_m.add_theme_constant_override("margin_right", 14)
	search_m.add_theme_constant_override("margin_top", 12)
	search_m.add_theme_constant_override("margin_bottom", 12)
	search_card.add_child(search_m)
	var search_col := VBoxContainer.new()
	search_col.add_theme_constant_override("separation", 8)
	search_m.add_child(search_col)
	var search_head := _label("搜索玩家", 14, GOLD)
	search_col.add_child(search_head)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	search_col.add_child(search_row)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "输入玩家 ID 或名字"
	_search_edit.custom_minimum_size = Vector2(0, 48)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_search_edit)
	_search_edit.text_submitted.connect(func(_t): _on_search())
	search_row.add_child(_search_edit)
	var search_btn := UiComponents.make_primary_button("搜索", _on_search, Vector2(112, 48))
	search_row.add_child(search_btn)

	# 滚动内容
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	v.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	content.add_child(_section("搜索结果", "搜索后可直接发送好友请求"))
	_results = VBoxContainer.new()
	_results.add_theme_constant_override("separation", 6)
	content.add_child(_results)

	content.add_child(_section("好友请求", "同意后才会成为好友"))
	_requests_box = VBoxContainer.new()
	_requests_box.add_theme_constant_override("separation", 6)
	content.add_child(_requests_box)

	content.add_child(_section("我的好友", "绿点表示在线"))
	_friends_box = VBoxContainer.new()
	_friends_box.add_theme_constant_override("separation", 6)
	content.add_child(_friends_box)

	content.add_child(_section("附近的玩家", "同一局域网内正在运行游戏的玩家"))
	_nearby_box = VBoxContainer.new()
	_nearby_box.add_theme_constant_override("separation", 6)
	content.add_child(_nearby_box)

	content.add_child(_section("在线玩家", "所有通过 Supabase 在线的玩家"))
	_online_box = VBoxContainer.new()
	_online_box.add_theme_constant_override("separation", 6)
	content.add_child(_online_box)

	# 底部
	_status = _label("", 12, MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	v.add_child(bottom)
	var close2 := UiComponents.make_secondary_button("关闭", func(): queue_free(), Vector2(0, 44))
	close2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(close2)


func _section(title: String, hint: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	row.add_child(head)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(3, 20)
	line.color = GOLD
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	head.add_child(_label(title, 16, GOLD_LIGHT, true))
	var hint_lbl := _label(hint, 11, MUTED)
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(hint_lbl)
	return row


func _refresh_all() -> void:
	_refresh_requests()
	_refresh_online_players()
	_refresh_friends()
	_refresh_nearby()
	if _search_edit != null and _search_edit.text.strip_edges() != "" and _results.get_child_count() > 0:
		_on_search()


func _refresh_online_players() -> void:
	if _online_box == null:
		return
	for c in _online_box.get_children():
		c.queue_free()
	var players: Array = PresenceManager.online_players() if PresenceManager else []
	if players.is_empty():
		_online_box.add_child(_empty_row("暂无在线玩家", "玩家登录后会自动出现在这里"))
		return
	for p in players:
		_online_box.add_child(_result_row(p))

func _on_search() -> void:
	var q := _search_edit.text.strip_edges()
	if q == "":
		_status.text = "请输入玩家 ID 或名字"
		return
	_status.text = "正在搜索玩家…"
	for c in _results.get_children():
		c.queue_free()
	FriendManager.search_players(q, func(list):
		for e in list:
			_results.add_child(_result_row(e))
		if list.is_empty():
			_status.text = "没有找到玩家（搜索依赖排行榜/部落/局域网数据）"
		else:
			_status.text = "找到 %d 位玩家，发送请求后需对方同意" % list.size())


func _result_row(e: Dictionary) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 68)
	card.add_theme_stylebox_override("panel", _row_style(Color(0.04, 0.06, 0.12, 0.9)))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var name := String(e.get("name", "玩家"))
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(44, 44)
	av.size = Vector2(44, 44)
	av.setup(name, int(e.get("avatar_seed", absi(hash(name)))), int(e.get("avatar_index", 0)))
	h.add_child(av)
	av.mouse_filter = Control.MOUSE_FILTER_STOP
	av.clicked.connect(func(): UiComponents.open_player_profile(self, e))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	info.add_child(_label(name, 16, PARCHMENT, true))
	info.add_child(_label("ID %s · %d 杯" % [String(e.get("player_id", "")), int(e.get("trophies", e.get("score", 0)))], 11, MUTED))
	var pid := String(e.get("player_id", ""))
	var add := UiComponents.make_primary_button("发送请求", Callable(), Vector2(104, 38))
	if FriendManager.is_friend(pid):
		add.text = "已是好友"
		add.disabled = true
	elif FriendManager.has_outgoing(pid):
		add.text = "再次申请"
		add.disabled = false
	elif FriendManager.has_incoming(pid):
		add.text = "同意"
	add.pressed.connect(func():
		if FriendManager.has_incoming(pid):
			FriendManager.accept_request(pid)
			_status.text = "已同意 %s 的好友请求" % name
			add.text = "已是好友"
			add.disabled = true
			_refresh_all()
		elif FriendManager.send_friend_request(e):
			_status.text = "好友请求已再次发送，等待 %s 同意" % name
			add.text = "再次申请"
			add.disabled = false
		else:
			_status.text = "已在好友列表或请求已发送" if not FriendManager.has_outgoing(pid) else "已发送过申请，等待对方同意"
			if FriendManager.has_outgoing(pid) or FriendManager.is_friend(pid):
				add.text = "等待同意" if FriendManager.has_outgoing(pid) else "已是好友"
				add.disabled = true)
	h.add_child(add)
	return card


func _refresh_nearby() -> void:
	if _nearby_box == null:
		return
	for c in _nearby_box.get_children():
		c.queue_free()
	var list: Array = FriendManager.nearby_players()
	if list.is_empty():
		_nearby_box.add_child(_empty_row("暂无附近玩家", "同一局域网内的玩家会自动出现"))
		return
	for p in list:
		_nearby_box.add_child(_result_row(p))

func _refresh_requests() -> void:
	if _requests_box == null:
		return
	for c in _requests_box.get_children():
		c.queue_free()
	var reqs := FriendManager.incoming_list()
	if reqs.is_empty():
		var empty := _empty_row("暂无新的好友请求", "添加好友需要对方同意")
		_requests_box.add_child(empty)
		return
	for req in reqs:
		var prof: Dictionary = Dictionary(req.get("profile", {})).duplicate(true)
		var pid := String(prof.get("player_id", req.get("id", "")))
		var name := String(prof.get("name", prof.get("player_name", "玩家")))
		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 86)
		card.add_theme_stylebox_override("panel", _row_style(Color(0.045, 0.075, 0.13, 0.98)))
		var rail := ColorRect.new()
		rail.color = GOLD
		rail.position = Vector2(0, 8)
		rail.size = Vector2(5, 70)
		card.add_child(rail)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -12
		h.offset_top = 8
		h.offset_bottom = -8
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var av = AVATAR_ICON.new()
		av.custom_minimum_size = Vector2(48, 48)
		av.size = Vector2(48, 48)
		av.setup(name, int(prof.get("avatar_seed", 0)), int(prof.get("avatar_index", 0)))
		h.add_child(av)
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		av.clicked.connect(func(): UiComponents.open_player_profile(self, prof))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(info)
		var title := _label("好友申请", 11, GOLD)
		info.add_child(title)
		info.add_child(_label(name, 16, PARCHMENT, true))
		info.add_child(_label("奖杯 %d · 请求添加你为好友" % int(prof.get("trophies", 0)), 11, MUTED))
		var ok := UiComponents.make_primary_button("同意", Callable(), Vector2(78, 38))
		ok.pressed.connect(func():
			FriendManager.accept_request(pid)
			_refresh_all()
			_status.text = "已同意 %s 的好友请求" % name)
		h.add_child(ok)
		var no := UiComponents.make_secondary_button("拒绝", Callable(), Vector2(72, 38))
		no.pressed.connect(func():
			FriendManager.reject_request(pid)
			_refresh_all()
			_status.text = "已拒绝 %s 的好友请求" % name)
		h.add_child(no)
		_requests_box.add_child(card)


func _refresh_friends() -> void:
	if _friends_box == null:
		return
	for c in _friends_box.get_children():
		c.queue_free()
	var fl := FriendManager.all()
	var online := 0
	for f in fl:
		if FriendManager.is_online(String(f.get("id", ""))):
			online += 1
	if _online_lbl != null:
		_online_lbl.text = "● %d 人在线" % online
	if fl.is_empty():
		_friends_box.add_child(_empty_row("还没有好友", "通过 ID/名字搜索，对方同意后加入"))
		return
	for f in fl:
		var pid := String(f.get("id", ""))
		var name := String(f.get("name", "玩家"))
		var is_online := FriendManager.is_online(pid)
		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 64)
		card.add_theme_stylebox_override("panel", _row_style(Color(0.045, 0.07, 0.13, 0.94)))
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var dot := Label.new()
		dot.text = "●"
		dot.custom_minimum_size = Vector2(16, 0)
		dot.add_theme_font_size_override("font_size", 18)
		dot.add_theme_color_override("font_color", GREEN if is_online else Color(0.38, 0.42, 0.50))
		h.add_child(dot)
		var av = AVATAR_ICON.new()
		av.custom_minimum_size = Vector2(44, 44)
		av.size = Vector2(44, 44)
		av.setup(name, int(f.get("avatar_seed", 0)), int(f.get("avatar_index", 0)))
		h.add_child(av)
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		av.clicked.connect(func(): UiComponents.open_player_profile(self, f))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		h.add_child(info)
		info.add_child(_label(name, 15, PARCHMENT, true))
		info.add_child(_label(("● 在线" if is_online else "○ 离线") + ((" · %d 杯" % int(f.get("trophies", 0))) if int(f.get("trophies", 0)) > 0 else ""), 11, GREEN if is_online else MUTED))
		var invite := UiComponents.make_secondary_button("邀请入房", Callable(), Vector2(104, 36))
		invite.pressed.connect(func():
			if NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.room_code != "":
				var ok := FriendManager.send_room_invite(NetworkManager.room_code, NetworkManager.get_local_ip(), PlayerData.player_name, pid)
				_status.text = "已向 %s 发出邀请（同一局域网）" % name if ok else "邀请发送失败"
			else:
				_status.text = "请先创建联机房间")
		h.add_child(invite)
		_friends_box.add_child(card)


func _empty_row(title: String, hint: String) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.add_theme_stylebox_override("panel", _row_style(Color(0.035, 0.05, 0.09, 0.7)))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var t := _label(title, 13, MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := _label(hint, 10, Color(0.45, 0.50, 0.60))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	return card


func _style_input(le: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.020, 0.035, 0.075, 0.96)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	le.add_theme_stylebox_override("normal", sb)
	var focus := sb.duplicate()
	focus.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", PARCHMENT)
	le.add_theme_color_override("font_placeholder_color", Color(0.45, 0.50, 0.60))
	if _font != null:
		le.add_theme_font_override("font", _font)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	return sb


func _row_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.10)
	return sb


func _round_style(bg: Color, border := 1, border_col := Color.WHITE, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	return sb


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
