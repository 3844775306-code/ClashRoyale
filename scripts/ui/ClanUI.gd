# scripts/ui/ClanUI.gd
# 部落界面：分节导航（我的部落 / 搜索 / 创建）+ 空状态 + 横幅卡 + 成员/聊天 + 危险确认
extends Control
const AVATAR_ICON = preload("res://scripts/ui/AvatarIcon.gd")
const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

# 分节
var tab_buttons: Array = []
var current_tab: int = 0
var my_clan_panel: Control
var search_panel: Control
var create_panel: Control

# 我的部落
var no_clan_box: VBoxContainer
var clan_home_box: Control
var clan_name_label: Label
var clan_desc_label: Label
var clan_stat_label: Label
var leave_btn: Button
var applications_btn: Button
var member_list: VBoxContainer
var chat_list: VBoxContainer
var chat_input: LineEdit
var send_btn: Button
var request_btn: Button
var donation_label: Label

# 搜索
var search_input: LineEdit
var search_btn: Button
var clan_list: VBoxContainer

# 创建
var create_name: LineEdit
var create_desc: TextEdit
var create_min_trophies: SpinBox
var create_open_check: CheckBox
var create_btn: Button
var create_error: Label
var toast_label: Label

# 数据缓存
var my_clan_data: Dictionary = {}
var current_chat: Array = []
var _last_search_clans: Array = []
var _pending_chat: Array = []
var _chat_initial_scrolled: bool = false
var _poll_timer: Timer
var _polling: bool = false


func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "部落", _on_back_pressed, true)
	_build_tabs()
	_build_content()
	_refresh_my_clan()
	_load_all_clans()
	ClanManager.sync_my_inventory(_on_inventory_synced)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll_clan)
	add_child(_poll_timer)
	_poll_timer.start()
	toast_label = Label.new()
	toast_label.position = Vector2(70, 1540)
	toast_label.size = Vector2(660, 32)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	toast_label.z_index = 30
	toast_label.visible = false
	add_child(toast_label)
	UiComponents.fade_in(self)


# ==================== 布局骨架 ====================

func _build_tabs():
	tab_buttons = []
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_left = 24
	bar.offset_top = 112
	bar.offset_right = -24
	bar.offset_bottom = 172
	add_child(bar)
	for i in 3:
		var btn := Button.new()
		btn.text = ["我的部落", "搜索", "创建"][i]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_tab.bind(i))
		bar.add_child(btn)
		tab_buttons.append(btn)
		_style_tab(btn, i == 0)


func _build_content():
	var card := Panel.new()
	ThemeHelper.apply_panel_style(card)
	card.anchor_left = 0.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = 24
	card.offset_top = 186
	card.offset_right = -24
	card.offset_bottom = -24
	add_child(card)

	my_clan_panel = Control.new()
	my_clan_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(my_clan_panel)
	search_panel = Control.new()
	search_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	search_panel.visible = false
	card.add_child(search_panel)
	create_panel = Control.new()
	create_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_panel.visible = false
	card.add_child(create_panel)

	_build_my_clan_tab()
	_build_search_tab()
	_build_create_tab()


# ==================== 我的部落 ====================

func _build_my_clan_tab():
	# 无部落空状态
	no_clan_box = UiComponents.make_empty_state("🏰", "你还没有加入部落", "加入一个部落，与伙伴并肩作战")
	no_clan_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	no_clan_box.offset_top = 120
	my_clan_panel.add_child(no_clan_box)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.add_child(UiComponents.make_primary_button("🔍 搜索部落", func(): _switch_tab(1), Vector2(200, 56)))
	btn_row.add_child(UiComponents.make_secondary_button("🆕 新建部落", func(): _switch_tab(2), Vector2(200, 56)))
	no_clan_box.add_child(btn_row)

	# 有部落主面板
	clan_home_box = Control.new()
	clan_home_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clan_home_box.visible = false
	my_clan_panel.add_child(clan_home_box)
	_build_clan_home()


func _build_clan_home():
	# ---- 部落横幅卡 ----
	var banner := UiComponents.make_card(ThemeHelper.COLORS.gold)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = 16
	banner.offset_top = 16
	banner.offset_right = -16
	banner.offset_bottom = 140
	clan_home_box.add_child(banner)

	var bv := VBoxContainer.new()
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 18
	bv.offset_top = 12
	bv.offset_right = -18
	bv.offset_bottom = -12
	bv.add_theme_constant_override("separation", 6)
	banner.add_child(bv)

	var row1 := HBoxContainer.new()
	clan_name_label = Label.new()
	clan_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clan_name_label.add_theme_font_size_override("font_size", 24)
	clan_name_label.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	clan_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(clan_name_label)
	applications_btn = UiComponents.make_secondary_button("申请", _show_applications, Vector2(100, 44))
	applications_btn.visible = false
	row1.add_child(applications_btn)
	leave_btn = UiComponents.make_danger_button("离开", _confirm_leave, Vector2(100, 44))
	row1.add_child(leave_btn)
	bv.add_child(row1)

	clan_desc_label = Label.new()
	clan_desc_label.add_theme_font_size_override("font_size", 14)
	clan_desc_label.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	clan_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(clan_desc_label)

	clan_stat_label = Label.new()
	clan_stat_label.add_theme_font_size_override("font_size", 13)
	clan_stat_label.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	bv.add_child(clan_stat_label)

	# ---- 成员列表 ----
	var member_title := Label.new()
	member_title.text = "成员"
	member_title.add_theme_font_size_override("font_size", 18)
	member_title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	member_title.anchor_left = 0.0
	member_title.anchor_right = 1.0
	member_title.offset_left = 16
	member_title.offset_top = 152
	member_title.offset_right = -16
	member_title.offset_bottom = 180
	clan_home_box.add_child(member_title)

	var member_scroll := ScrollContainer.new()
	member_scroll.anchor_left = 0.0
	member_scroll.anchor_right = 1.0
	member_scroll.offset_left = 16
	member_scroll.offset_top = 186
	member_scroll.offset_right = -16
	member_scroll.offset_bottom = 430
	member_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	member_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	member_scroll.scroll_deadzone = 24
	member_scroll.follow_focus = true
	clan_home_box.add_child(member_scroll)
	member_list = VBoxContainer.new()
	member_list.add_theme_constant_override("separation", 8)
	member_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_scroll.add_child(member_list)

	# ---- 聊天面板（现代聊天布局）----
	var chat_panel := Panel.new()
	ThemeHelper.apply_panel_style(chat_panel)
	chat_panel.anchor_left = 0.0
	chat_panel.anchor_right = 1.0
	chat_panel.offset_left = 16
	chat_panel.offset_top = 440
	chat_panel.offset_right = -16
	chat_panel.offset_bottom = 780
	clan_home_box.add_child(chat_panel)

	var chat_title := Label.new()
	chat_title.text = "部落聊天"
	chat_title.add_theme_font_size_override("font_size", 17)
	chat_title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	chat_title.position = Vector2(16, 12)
	chat_title.size = Vector2(200, 28)
	chat_panel.add_child(chat_title)
	var online := Label.new()
	online.text = "和伙伴聊聊卡组与战术"
	online.add_theme_font_size_override("font_size", 12)
	online.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	online.position = Vector2(120, 16)
	online.size = Vector2(420, 22)
	chat_panel.add_child(online)

	var chat_scroll := ScrollContainer.new()
	chat_scroll.anchor_left = 0.0
	chat_scroll.anchor_right = 1.0
	chat_scroll.offset_left = 12
	chat_scroll.offset_top = 52
	chat_scroll.offset_right = -12
	chat_scroll.offset_bottom = 248
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chat_scroll.scroll_deadzone = 24
	chat_scroll.follow_focus = true
	chat_panel.add_child(chat_scroll)
	chat_list = VBoxContainer.new()
	chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_list.add_theme_constant_override("separation", 8)
	chat_scroll.add_child(chat_list)
	set_meta("chat_scroll", chat_scroll)

	var input_row := HBoxContainer.new()
	input_row.anchor_left = 0.0
	input_row.anchor_right = 1.0
	input_row.offset_left = 12
	input_row.offset_top = 258
	input_row.offset_right = -12
	input_row.offset_bottom = 306
	input_row.add_theme_constant_override("separation", 8)
	chat_panel.add_child(input_row)
	var chat_av = AVATAR_ICON.new()
	chat_av.custom_minimum_size = Vector2(38, 38)
	chat_av.size = Vector2(38, 38)
	chat_av.setup_local()
	input_row.add_child(chat_av)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "发消息给部落…"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 42)
	chat_input.text_submitted.connect(func(_t): _on_send_chat())
	input_row.add_child(chat_input)
	send_btn = UiComponents.make_primary_button("发送", _on_send_chat, Vector2(92, 42))
	input_row.add_child(send_btn)

	# ---- 底部操作行 ----
	var bottom := HBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.offset_left = 16
	bottom.offset_top = 796
	bottom.offset_right = -16
	bottom.offset_bottom = 856
	clan_home_box.add_child(bottom)
	request_btn = UiComponents.make_primary_button("请求卡牌", _on_request_card, Vector2(180, 56))
	bottom.add_child(request_btn)
	donation_label = Label.new()
	donation_label.add_theme_font_size_override("font_size", 15)
	donation_label.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	donation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	donation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	donation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(donation_label)


# ==================== 搜索 ====================

func _build_search_tab():
	var form := VBoxContainer.new()
	form.anchor_left = 0.5
	form.anchor_right = 0.5
	form.anchor_top = 0.0
	form.anchor_bottom = 0.0
	form.offset_left = -220
	form.offset_right = 220
	form.offset_top = 36
	form.add_theme_constant_override("separation", 12)
	search_panel.add_child(form)

	var title := UiComponents.make_section_title("搜索部落")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	search_input = LineEdit.new()
	search_input.placeholder_text = "输入关键词筛选已有部落"
	search_input.custom_minimum_size = Vector2(0, 52)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_submitted.connect(func(_t): _on_search_clans())
	row.add_child(search_input)
	search_btn = UiComponents.make_primary_button("筛选", _on_search_clans, Vector2(120, 52))
	row.add_child(search_btn)
	form.add_child(row)

	var result_scroll := ScrollContainer.new()
	result_scroll.anchor_left = 0.0
	result_scroll.anchor_right = 1.0
	result_scroll.anchor_top = 0.0
	result_scroll.anchor_bottom = 1.0
	result_scroll.offset_left = 16
	result_scroll.offset_top = 240
	result_scroll.offset_right = -16
	result_scroll.offset_bottom = -16
	search_panel.add_child(result_scroll)
	clan_list = VBoxContainer.new()
	clan_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clan_list.add_theme_constant_override("separation", 8)
	result_scroll.add_child(clan_list)


# ==================== 创建 ====================

func _build_create_tab():
	var form := VBoxContainer.new()
	form.anchor_left = 0.5
	form.anchor_right = 0.5
	form.anchor_top = 0.0
	form.offset_left = -220
	form.offset_right = 220
	form.offset_top = 36
	form.add_theme_constant_override("separation", 14)
	create_panel.add_child(form)

	var title := UiComponents.make_section_title("创建部落")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(title)

	create_name = LineEdit.new()
	create_name.placeholder_text = "部落名称"
	create_name.custom_minimum_size = Vector2(0, 52)
	form.add_child(create_name)

	create_desc = TextEdit.new()
	create_desc.placeholder_text = "部落简介（可选）"
	create_desc.custom_minimum_size = Vector2(0, 110)
	form.add_child(create_desc)

	create_min_trophies = SpinBox.new()
	create_min_trophies.min_value = 0
	create_min_trophies.max_value = 5000
	create_min_trophies.step = 100
	create_min_trophies.suffix = " 奖杯"
	create_min_trophies.custom_minimum_size = Vector2(0, 46)
	form.add_child(create_min_trophies)

	create_open_check = CheckBox.new()
	create_open_check.text = "公开部落（所有人可加入）"
	form.add_child(create_open_check)

	create_btn = UiComponents.make_primary_button("创建部落", _on_create_clan, Vector2(0, 56))
	create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(create_btn)

	create_error = Label.new()
	create_error.add_theme_color_override("font_color", ThemeHelper.COLORS.danger)
	create_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(create_error)


# ==================== 分节切换 ====================

func _load_all_clans():
	if clan_list == null:
		return
	ClanManager.search_clans(func(ok, clans):
		if ok:
			_show_clan_list(clans)
		else:
			_toast("获取部落列表失败：%s" % str(clans))
	, "")

func _switch_tab(i: int):
	current_tab = i
	for b in tab_buttons.size():
		_style_tab(tab_buttons[b], b == i)
	my_clan_panel.visible = i == 0
	search_panel.visible = i == 1
	create_panel.visible = i == 2
	if i == 1 and clan_list.get_child_count() == 0:
		_load_all_clans()


func _style_tab(btn: Button, active: bool):
	if active:
		ThemeHelper.apply_tab_active(btn)
	else:
		ThemeHelper.apply_tab_idle(btn)


# ==================== 我的部落数据 ====================

func _refresh_my_clan():
	ClanManager.get_my_clan(_on_refresh_my_clan)

func _on_refresh_my_clan(success, clan) -> void:
	if not is_inside_tree():
		return
	if success and clan != null:
		_show_clan_home(clan)
	elif my_clan_data.is_empty():
		_show_no_clan()
	# 网络短时失败时保留当前部落界面


func _poll_clan() -> void:
	if not is_inside_tree() or _polling or current_tab != 0 or clan_home_box == null or not clan_home_box.visible:
		return
	_polling = true
	ClanManager.invalidate_cache()
	ClanManager.get_my_clan(_on_poll_clan)

func _on_poll_clan(success, clan) -> void:
	_polling = false
	if not is_inside_tree() or not success:
		return
	if clan == null:
		if my_clan_data.is_empty():
			_show_no_clan()
	else:
		_show_clan_home(clan)
	ClanManager.sync_my_inventory(_on_inventory_synced)

func _show_no_clan():
	no_clan_box.show()
	clan_home_box.hide()


func _show_clan_home(clan: Dictionary):
	my_clan_data = clan
	if current_tab == 1 and not _last_search_clans.is_empty() and clan_list != null:
		_show_clan_list(_last_search_clans)
	no_clan_box.hide()
	clan_home_box.show()

	clan_name_label.text = clan.get("name", "未知部落")
	clan_desc_label.text = clan.get("description", "")
	var members: Dictionary = clan.get("members", {})
	var open_str := "公开" if clan.get("is_open", false) else "需申请"
	clan_stat_label.text = "成员 %d/%d · 奖杯门槛 %d · %s" % [
		members.size(), ClanManager.MAX_MEMBERS, clan.get("min_trophies", 0), open_str]
	donation_label.text = "今日已捐赠 %d 次" % PlayerData.donations_used
	if PlayerData.can_request_card():
		request_btn.text = "请求卡牌"
		request_btn.disabled = false
	else:
		var secs: int = int(PlayerData.request_cooldown_left())
		request_btn.text = "请求冷却 %dh%02dm" % [secs / 3600, (secs % 3600) / 60]
		request_btn.disabled = true
	var apps: Array = clan.get("applications", [])
	var is_leader: bool = int(clan.get("leader_id", -1)) == ClanManager.get_player_id()
	applications_btn.visible = is_leader and apps.size() > 0
	applications_btn.text = "申请 %d" % apps.size()

	_refresh_members()

	ClanManager.get_chat_history(_on_chat_history)

func _on_chat_history(success, chat) -> void:
	if not is_inside_tree():
		return
	if success and chat is Array:
		var merged: Array = _merge_pending_chat(chat)
		var changed: bool = merged != current_chat
		current_chat = merged
		# 用本次真正拉取到的聊天更新部落数据，否则 my_clan_data.chat 可能是旧/空数组，
		# mark_chat_read 会把“最新已读时间”算成 0，导致下次登录未读红点再次出现。
		if my_clan_data is Dictionary:
			my_clan_data["chat"] = merged.duplicate(true)
		if changed:
			_update_chat_display()
		# 打开部落即视为已读；主菜单红点随之清除
		ClanManager.mark_chat_read(my_clan_data)


func _refresh_members():
	for child in member_list.get_children():
		child.queue_free()
	var members: Dictionary = my_clan_data.get("members", {})
	var is_leader: bool = my_clan_data.get("leader_id", -1) == ClanManager.get_player_id()
	for member_id in members:
		var m: Dictionary = members[member_id]
		var row := UiComponents.make_list_row(Color.TRANSPARENT, 56)
		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 16
		hbox.offset_right = -16
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		var role: String = str(m.get("role", ""))
		var av = AVATAR_ICON.new()
		av.custom_minimum_size = Vector2(40, 40)
		av.size = Vector2(40, 40)
		var is_me: bool = int(member_id) == ClanManager.get_player_id()
		var an := PlayerData.player_name if is_me else String(m.get("player_name", "玩家"))
		var aseed: int = int(m.get("avatar_seed", absi(hash(an))))
		var aidx: int = int(m.get("avatar_index", aseed % 12))
		if is_me:
			av.setup_local()
		else:
			av.setup(an, aseed, aidx)
			CloudAvatar.apply(av, str(member_id), an, aseed, aidx)
		var member_snapshot := {
			"player_id": str(member_id), "name": an,
			"trophies": int(m.get("trophies", 0)),
			"highest_trophies": int(m.get("highest_trophies", m.get("trophies", 0))),
			"arena": PlayerData._arena_index_for_trophies(int(m.get("trophies", 0))),
			"donations": int(m.get("donations", 0)),
			"joined": int(m.get("joined", 0)),
			"bio": String(m.get("bio", "")),
			"avatar_seed": aseed, "avatar_index": aidx,
			"role": String(m.get("role", "")),
			"clan": String(my_clan_data.get("name", "")),
		}
		hbox.add_child(av)
		av.mouse_filter = Control.MOUSE_FILTER_STOP
		av.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_open_player_profile(member_snapshot))
		row.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_open_player_profile(member_snapshot))
		var id_lbl := Label.new()
		id_lbl.text = an
		id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		id_lbl.add_theme_font_size_override("font_size", 15)
		hbox.add_child(id_lbl)

		var role_lbl := Label.new()
		role_lbl.text = _role_text(role)
		role_lbl.custom_minimum_size = Vector2(80, 0)
		role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role_lbl.add_theme_font_size_override("font_size", 13)
		role_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		hbox.add_child(role_lbl)

		var donate_lbl := Label.new()
		donate_lbl.text = "捐献 %d" % m.get("donations", 0)
		donate_lbl.custom_minimum_size = Vector2(70, 0)
		donate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		donate_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(donate_lbl)

		# 首领操作（用 bind 固定参数，避免闭包捕获循环变量）
		if is_leader and int(member_id) != ClanManager.get_player_id():
			var mid := int(member_id)
			var kick_btn := UiComponents.make_danger_button("踢出", Callable(), Vector2(64, 40))
			kick_btn.pressed.connect(_kick_member.bind(mid))
			hbox.add_child(kick_btn)
			var promote_btn := UiComponents.make_secondary_button("升首领", Callable(), Vector2(64, 40))
			promote_btn.pressed.connect(_promote_leader.bind(mid))
			hbox.add_child(promote_btn)

		member_list.add_child(row)


func _open_player_profile(profile: Dictionary) -> void:
	call_deferred("_open_player_profile_deferred", profile)

func _open_player_profile_deferred(profile: Dictionary) -> void:
	if not is_inside_tree():
		return
	var dlg = preload("res://scripts/ui/PlayerProfileDialog.gd").new()
	dlg.profile = profile
	add_child(dlg)


func _role_emoji(role: String) -> String:
	var r := role.to_lower()
	if r.contains("leader") or r.contains("首领"):
		return "👑"
	if r.contains("co") or r.contains("副"):
		return "⭐"
	return "🗡️"


func _role_text(role: String) -> String:
	var r := role.to_lower()
	if r.contains("leader") or r.contains("首领"):
		return "首领"
	if r.contains("co") or r.contains("副"):
		return "副手"
	return "成员"


# ==================== 聊天 ====================

func _update_chat_display():
	var sc = get_meta("chat_scroll", null)
	var old_scroll: int = 0
	var was_bottom: bool = true
	if sc is ScrollContainer:
		old_scroll = int(sc.scroll_vertical)
		was_bottom = old_scroll >= int(sc.get_v_scroll_bar().max_value) - 4
	for child in chat_list.get_children():
		child.queue_free()
	var ordered: Array = current_chat.duplicate()
	ordered.sort_custom(func(a, b): return float(a.get("timestamp", 0.0)) < float(b.get("timestamp", 0.0)))
	for msg in ordered:
		chat_list.add_child(_create_chat_node(msg))
	if not _chat_initial_scrolled and not ordered.is_empty():
		_chat_initial_scrolled = true
		_scroll_chat_to_latest()
	elif was_bottom:
		_scroll_chat_to_latest()
	elif old_scroll > 0 and sc is ScrollContainer:
		_restore_chat_scroll(old_scroll)

func _merge_pending_chat(server_chat: Array) -> Array:
	var merged: Array = server_chat.duplicate()
	var keep: Array = []
	for p in _pending_chat:
		var found := false
		for m in server_chat:
			if int(m.get("player_id", -2)) == int(p.get("player_id", -3)) and String(m.get("message", "")) == String(p.get("message", "")):
				found = true
				break
		if not found:
			keep.append(p)
			merged.push_front(p)
	_pending_chat = keep
	return merged

func _format_chat_time(ts: float) -> String:
	if ts <= 0.0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(int(ts))
	return "%d月%d日 %02d:%02d" % [int(d.month), int(d.day), int(d.hour), int(d.minute)]

func _card_name_for_id(card_id: int) -> String:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if bm == null:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	var cfg = bm.get_config(card_id) if bm else null
	return String(cfg.card_name) if cfg else "卡牌"

func _restore_chat_scroll(value: int) -> void:
	var sc = get_meta("chat_scroll", null)
	if not (sc is ScrollContainer):
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(sc):
		return
	sc.scroll_vertical = value


func _scroll_chat_to_latest() -> void:
	var sc = get_meta("chat_scroll", null)
	if not (sc is ScrollContainer):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	if not is_inside_tree() or not is_instance_valid(sc):
		return
	sc.scroll_vertical = 1000000
	# 文字自动换行会让内容高度在随后几帧才稳定，再补一次滚动到底
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree() and is_instance_valid(sc):
		sc.scroll_vertical = 1000000


func _create_chat_node(msg: Dictionary) -> Control:
	var sender_name := String(msg.get("player_name", "玩家"))
	var pid := int(msg.get("player_id", 0))
	var is_me: bool = pid == ClanManager.get_player_id() or sender_name == PlayerData.player_name
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.custom_minimum_size = Vector2(0, 52)

	var seed_value: int = int(msg.get("avatar_seed", absi(hash(sender_name))))
	var avatar_index: int = int(msg.get("avatar_index", seed_value % 12))
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(36, 36)
	av.size = Vector2(36, 36)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_me:
		av.setup_local()
	else:
		av.setup(sender_name, seed_value, avatar_index)
		CloudAvatar.apply(av, str(pid), sender_name, seed_value, avatar_index)
	row.add_child(av)
	av.mouse_filter = Control.MOUSE_FILTER_STOP
	var chat_profile := {"player_id": str(pid), "name": sender_name, "avatar_seed": seed_value, "avatar_index": avatar_index, "clan": String(my_clan_data.get("name", "")), "trophies": 0, "role": ""}
	for mid in my_clan_data.get("members", {}).keys():
		if str(mid) == str(pid):
			var mm: Dictionary = my_clan_data.members[mid]
			chat_profile["trophies"] = int(mm.get("trophies", 0))
			chat_profile["highest_trophies"] = int(mm.get("highest_trophies", mm.get("trophies", 0)))
			chat_profile["arena"] = PlayerData._arena_index_for_trophies(int(mm.get("trophies", 0)))
			chat_profile["donations"] = int(mm.get("donations", 0))
			chat_profile["joined"] = int(mm.get("joined", 0))
			chat_profile["role"] = String(mm.get("role", ""))
			break
	av.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_open_player_profile(chat_profile))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var meta := HBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_END if is_me else BoxContainer.ALIGNMENT_BEGIN
	meta.add_theme_constant_override("separation", 7)
	col.add_child(meta)
	var name_lbl := Label.new()
	name_lbl.text = "你" if is_me else sender_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.57, 0.82, 1.0) if is_me else Color(0.78, 0.84, 0.94))
	meta.add_child(name_lbl)
	var time_lbl := Label.new()
	time_lbl.text = _format_chat_time(float(msg.get("timestamp", 0.0)))
	time_lbl.add_theme_font_size_override("font_size", 10)
	time_lbl.add_theme_color_override("font_color", Color(0.48, 0.57, 0.70))
	meta.add_child(time_lbl)

	var bubble_row := HBoxContainer.new()
	bubble_row.alignment = BoxContainer.ALIGNMENT_END if is_me else BoxContainer.ALIGNMENT_BEGIN
	bubble_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bubble_row)
	var bubble := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.16, 0.38, 0.66, 0.98) if is_me else Color(0.075, 0.105, 0.18, 0.98)
	bs.border_color = Color(0.46, 0.80, 1.0, 0.45) if is_me else Color(1, 1, 1, 0.10)
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(16)
	bs.content_margin_left = 13
	bs.content_margin_right = 13
	bs.content_margin_top = 9
	bs.content_margin_bottom = 9
	bs.shadow_color = Color(0, 0, 0, 0.22)
	bs.shadow_size = 5
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_me else Control.SIZE_SHRINK_BEGIN
	bubble_row.add_child(bubble)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	bubble.add_child(body)
	var msg_type := String(msg.get("type", "chat"))
	if msg_type == "request":
		var cid := int(msg.get("card_id", 0))
		var cname := String(msg.get("card_name", ""))
		if cname == "" or cname == "卡牌":
			cname = _card_name_for_id(cid)
		var amt := int(msg.get("amount", 1))
		var donated := int(msg.get("donated", 0))
		var donors: Array = Array(msg.get("donors", []))
		var key := String(msg.get("request_key", ""))
		var local_id := ClanManager.get_player_id()
		var is_mine_request: bool = pid == local_id or pid <= 0 or sender_name == PlayerData.player_name
		var already: bool = donors.has(local_id) or donors.has(str(local_id))
		var completed: bool = donated >= amt
		var rarity: String = CARD_RARITY.rarity_of_id(cid)
		var sunday: bool = int(Time.get_date_dict_from_system().weekday) == 0
		var step: int = 10 if rarity == "common" else 1
		var card_icon = REWARD_ICON.new()
		card_icon.custom_minimum_size = Vector2(46, 60)
		card_icon.setup("card", amt, cname, cid)
		body.add_child(card_icon)
		var req_col := VBoxContainer.new()
		req_col.add_theme_constant_override("separation", 4)
		body.add_child(req_col)
		var req_text := Label.new()
		req_text.text = "请求 %s ×%d" % [cname, amt]
		req_text.add_theme_font_size_override("font_size", 13)
		req_text.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
		req_col.add_child(req_text)
		var prog_row := HBoxContainer.new()
		prog_row.add_theme_constant_override("separation", 6)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(128, 10)
		bar.show_percentage = false
		bar.max_value = maxf(1.0, float(amt))
		bar.value = minf(float(donated), float(amt))
		ThemeHelper.apply_progress_gold(bar)
		prog_row.add_child(bar)
		var prog_lbl := Label.new()
		prog_lbl.text = "%d/%d" % [donated, amt]
		prog_lbl.add_theme_font_size_override("font_size", 11)
		prog_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
		prog_row.add_child(prog_lbl)
		req_col.add_child(prog_row)
		var donate_btn := UiComponents.make_primary_button("捐赠", Callable(), Vector2(82, 34))
		if is_mine_request:
			donate_btn.text = "自己的请求"
			donate_btn.disabled = true
		elif completed:
			donate_btn.text = "已完成"
			donate_btn.disabled = true
		elif already:
			donate_btn.text = "已捐赠"
			donate_btn.disabled = true
		elif rarity == "epic" and not sunday:
			donate_btn.text = "周日可捐"
			donate_btn.disabled = true
		else:
			donate_btn.disabled = PlayerData.get_card_quantity(cid) < step
			donate_btn.pressed.connect(_donate_card.bind(pid, cid, key))
		req_col.add_child(donate_btn)
	else:
		var content := Label.new()
		content.text = String(msg.get("message", ""))
		content.add_theme_font_size_override("font_size", 13)
		content.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.custom_minimum_size = Vector2(200, 0)
		body.add_child(content)
	return row


func _on_send_chat():
	var msg := chat_input.text
	if msg == "":
		return
	ClanManager.send_chat_message(msg, func(success, _data):
		if not success:
			_toast("发送失败：%s" % str(_data))
			return
		var local_msg := {
			"player_id": ClanManager.get_player_id(),
			"player_name": ClanManager.get_player_name(),
			"message": msg,
			"timestamp": Time.get_unix_time_from_system(),
			"type": "chat",
			"avatar_seed": PlayerData.avatar_seed,
			"avatar_index": PlayerData.avatar_index,
			"client_id": "local_%d" % Time.get_ticks_usec(),
		}
		current_chat.push_front(local_msg)
		_pending_chat.append(local_msg)
		_update_chat_display()
		chat_input.clear()
	)


# ==================== 操作 ====================

func _on_request_card():
	var card_select = preload("res://scenes/card_select_ui.tscn").instantiate()
	card_select.callback = func(card_id, amount):
		ClanManager.request_card(card_id, amount, func(succ, data):
			if succ:
				_toast("卡牌请求已发送")
				ClanManager.invalidate_cache()
				_refresh_my_clan()
				ClanManager.get_chat_history(_on_chat_history)
			else:
				_toast("请求失败：%s" % str(data))
		)
	add_child(card_select)


func _donate_card(target_id: int, card_id: int, request_key: String):
	ClanManager.donate_card(target_id, card_id, 0, request_key, _on_donate_result)

func _on_donate_result(succ, data) -> void:
	if not is_inside_tree():
		return
	if succ:
		ClanManager.invalidate_cache()
		_refresh_my_clan()
		PlayerData.save_data()
		UiComponents.refresh_topbar()
		var gold := int(Dictionary(data).get("gold", 0)) if data is Dictionary else 0
		if gold > 0:
			_toast("捐赠成功，获得 %d 金币补贴" % gold)
		else:
			_toast("捐赠成功")
	else:
		_toast("捐赠失败：%s" % str(data))


func _on_search_clans():
	var keyword: String = search_input.text if search_input else ""
	ClanManager.search_clans(func(success, clans):
		if success:
			_show_clan_list(clans)
		else:
			_toast("搜索失败：%s" % str(clans))
	, keyword)


func _show_clan_list(clans: Array):
	_last_search_clans = clans.duplicate()
	for child in clan_list.get_children():
		child.queue_free()
	if clans.is_empty():
		clan_list.add_child(UiComponents.make_empty_state("🔍", "没有找到部落", ""))
		return
	var keyword := search_input.text.strip_edges()
	var my_clan_id := str(my_clan_data.get("clan_id", ""))
	var my_clan_name := String(my_clan_data.get("name", ""))
	for clan in clans:
		var name: String = clan.get("name", "")
		var cid := str(clan.get("clan_id", ""))
		var already_joined: bool = (my_clan_id != "" and cid == my_clan_id) or (my_clan_name != "" and name == my_clan_name)
		if keyword != "" and not name.contains(keyword):
			continue
		var row := UiComponents.make_list_row(ThemeHelper.COLORS.gold, 68)
		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 16
		hbox.offset_top = 8
		hbox.offset_right = -16
		hbox.offset_bottom = -8
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n_lbl := Label.new()
		n_lbl.text = name
		n_lbl.add_theme_font_size_override("font_size", 17)
		info.add_child(n_lbl)
		var sub_lbl := Label.new()
		var members: Dictionary = clan.get("members", {})
		sub_lbl.text = "成员 %d/%d · 奖杯门槛 %d" % [members.size(), ClanManager.MAX_MEMBERS, clan.get("min_trophies", 0)]
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		info.add_child(sub_lbl)
		hbox.add_child(info)

		var join_btn := UiComponents.make_primary_button("加入" if clan.get("is_open", false) else "申请", Callable(), Vector2(96, 44))
		if already_joined:
			join_btn.text = "已加入"
			join_btn.disabled = true
		else:
			join_btn.pressed.connect(_join_clan.bind(cid))
		hbox.add_child(join_btn)

		clan_list.add_child(row)


func _join_clan(clan_id: String):
	ClanManager.join_clan(clan_id, func(success, data):
		if success:
			if str(data) == "applied":
				_toast("已提交入部申请，等待首领审批")
				ClanManager.invalidate_cache()
				_refresh_my_clan()
			else:
				ClanManager.invalidate_cache()
				_switch_tab(0)
				_refresh_my_clan()
		else:
			_toast("加入失败：%s" % str(data))
	)


func _on_create_clan():
	var name := create_name.text
	var desc := create_desc.text
	var min_trophies := int(create_min_trophies.value)
	var is_open := create_open_check.button_pressed
	if name.strip_edges() == "":
		create_error.text = "请输入部落名称"
		return
	create_error.text = ""
	ClanManager.create_clan(name, desc, min_trophies, is_open, func(success, clan_id):
		if success:
			ClanManager.invalidate_cache()
			_switch_tab(0)
			_refresh_my_clan()
		else:
			create_error.text = "创建失败: %s" % clan_id
	)


func _confirm_leave():
	var overlay := UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.danger)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -120
	panel.offset_bottom = 120
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 20
	vbox.offset_right = -24
	vbox.offset_bottom = -20
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var t := Label.new()
	t.text = "确定要离开「%s」吗？" % my_clan_data.get("name", "部落")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(t)

	var sub := Label.new()
	sub.text = "离开后将无法参与部落捐赠与聊天。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	vbox.add_child(sub)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	btns.add_child(UiComponents.make_secondary_button("取消", func(): panel.queue_free(); overlay.queue_free(), Vector2(160, 52)))
	btns.add_child(UiComponents.make_danger_button("离开", func():
		panel.queue_free()
		overlay.queue_free()
		_on_leave_clan(), Vector2(160, 52)))
	vbox.add_child(btns)
	UiComponents.fade_in(panel)


func _on_leave_clan():
	ClanManager.leave_clan(func(success, data):
		if success:
			_refresh_my_clan()
		else:
			_toast("离开失败：%s" % str(data))
	)


func _kick_member(member_id: int):
	ClanManager.kick_member(member_id, func(success, data):
		if success:
			_refresh_my_clan()
		else:
			_toast("操作失败：%s" % str(data))
	)


func _promote_leader(member_id: int):
	ClanManager.promote_to_leader(member_id, func(success, data):
		if success:
			_refresh_my_clan()
		else:
			_toast("操作失败：%s" % str(data))
	)


func _show_applications():
	var apps: Array = my_clan_data.get("applications", [])
	var overlay := UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_right = -18
	vb.offset_top = 16
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "入部申请"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	vb.add_child(title)
	if apps.is_empty():
		var empty := Label.new()
		empty.text = "暂无申请"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		vb.add_child(empty)
	for app in apps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var nl := Label.new()
		nl.text = "%s · %d杯" % [String(app.get("player_name", "玩家")), int(app.get("trophies", 0))]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 15)
		row.add_child(nl)
		var pid: int = int(app.get("player_id", -1))
		var approve := UiComponents.make_primary_button("通过", func(): _approve_app(pid), Vector2(80, 38))
		row.add_child(approve)
		var reject := UiComponents.make_danger_button("拒绝", func(): _reject_app(pid), Vector2(80, 38))
		row.add_child(reject)
	var close := UiComponents.make_secondary_button("关闭", func(): panel.queue_free(); overlay.queue_free(), Vector2(0, 48))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(close)
	UiComponents.fade_in(panel)

func _approve_app(pid: int):
	ClanManager.approve_application(pid, func(ok, err):
		if ok:
			_refresh_my_clan()
			_toast("已通过申请")
		else:
			_toast("审批失败：%s" % str(err))
	)

func _reject_app(pid: int):
	ClanManager.reject_application(pid, func(ok, err):
		if ok:
			_refresh_my_clan()
			_toast("已拒绝申请")
		else:
			_toast("审批失败：%s" % str(err))
	)

func _on_inventory_synced(_ok) -> void:
	if is_inside_tree():
		_show_mail_alert_if_any()

func _show_mail_alert_if_any() -> void:
	var msg := PlayerData.mail_alert_pending
	if msg == "":
		return
	PlayerData.mail_alert_pending = ""
	PlayerData.save_data()
	_show_mail_alert(msg)

func _show_mail_alert(text: String) -> void:
	if text == "" or not is_inside_tree():
		return
	var panel := Panel.new()
	panel.position = Vector2(90, 700)
	panel.size = Vector2(620, 86)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.12, 0.20, 0.98)
	sb.border_color = Color(1.0, 0.80, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 16
	lbl.offset_right = -16
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = "📬 " + text
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	panel.add_child(lbl)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree():
		return
	var tw2 := create_tween()
	tw2.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tw2.finished
	panel.queue_free()

func _toast(text: String):
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): toast_label.visible = false)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
