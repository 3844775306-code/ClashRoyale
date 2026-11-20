extends Control
const AVATAR_ICON = preload("res://scripts/ui/AvatarIcon.gd")
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
const CUSTOM_PANEL := preload("res://scripts/ui/CustomModePanel.gd")

var _status: Label
var _room_status: Label
var _initial_box: VBoxContainer
var _room_box: VBoxContainer
var _room_bg: Panel
var _host_info: Label
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _webrtc_code_edit: LineEdit
var _turn_status: Label
var _uid_label: Label
var _seats_box: VBoxContainer
var _start_btn: Button
var _room_code_label: Label
var _mode_label: Label
var _rule_buttons: Array = []
var _custom_box: VBoxContainer
var _in_room := false
var _invite_autoclaim := false

func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "联机房间", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"), true)
	_build_initial()
	_build_room()
	_update_turn_status()
	NetworkManager.lobby_status.connect(_on_status)
	NetworkManager.guest_joined.connect(_on_guest_joined)
	NetworkManager.seats_changed.connect(_refresh_seats)
	NetworkManager.joined_room.connect(func():
		_enter_room(false)
		if _invite_autoclaim:
			_invite_autoclaim = false
			call_deferred("_auto_claim"))
	NetworkManager.match_started.connect(_on_match_started)
	NetworkManager.room_closed.connect(_on_room_closed)
	# 从主菜单接受好友邀请后直接尝试加入
	if FriendManager.pending_invite.size() > 0 and NetworkManager.role == NetworkManager.Role.NONE:
		var inv := FriendManager.pending_invite
		FriendManager.pending_invite = {}
		if String(inv.get("kind", "")) == "webrtc":
			_webrtc_code_edit.text = String(inv.get("code", ""))
			_invite_autoclaim = true
			call_deferred("_webrtc_join_pressed")
		else:
			_ip_edit.text = String(inv.get("ip", ""))
			_code_edit.text = String(inv.get("code", ""))
			_invite_autoclaim = true
			call_deferred("_join_pressed")
	var env_host := OS.get_environment("CR_NET_HOST")
	if env_host != "":
		call_deferred("_host_pressed")
	var env_join := OS.get_environment("CR_NET_JOIN")
	if env_join != "":
		var parts := env_join.split(",")
		if parts.size() >= 2:
			_ip_edit.text = parts[0]
			_code_edit.text = parts[1]
			call_deferred("_join_pressed")

func _make_header() -> Control:
	var top := HBoxContainer.new()
	top.position = Vector2(20, 24)
	top.size = Vector2(760, 74)
	top.add_child(UiComponents.make_secondary_button("◀", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"), Vector2(72, 60)))
	var title := Label.new()
	title.text = "🌐 联机房间"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	top.add_child(title)
	return top

func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _build_initial() -> void:
	_initial_box = VBoxContainer.new()
	_initial_box.position = Vector2(56, 130)
	_initial_box.size = Vector2(688, 1100)
	_initial_box.add_theme_constant_override("separation", 18)
	add_child(_initial_box)
	var room_list_btn := UiComponents.make_secondary_button("房间列表 / 直接加入", _show_room_list, Vector2(688, 48))
	_initial_box.add_child(room_list_btn)
	var hc := UiComponents.make_card(ThemeHelper.COLORS.gold)
	hc.custom_minimum_size = Vector2(688, 280)
	_initial_box.add_child(hc)
	var hv := VBoxContainer.new()
	hv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hv.offset_left = 22; hv.offset_top = 18; hv.offset_right = -22; hv.offset_bottom = -18
	hv.add_theme_constant_override("separation", 12)
	hc.add_child(hv)
	hv.add_child(_label("创建房间（本机权威服务器）", 22, ThemeHelper.COLORS.gold))
	hv.add_child(_label("默认 1V1；进入房间后可增加蓝/红席位，空席位默认 AI", 14, Color(0.72,0.82,0.92)))
	hv.add_child(UiComponents.make_primary_button("创建房间", _host_pressed, Vector2(644, 60)))
	hv.add_child(_label("朋友需要和你在同一个 WiFi 下", 13, Color(0.6,0.7,0.82)))
	var jc := UiComponents.make_card(Color(0.4,0.65,1.0))
	jc.custom_minimum_size = Vector2(688, 400)
	_initial_box.add_child(jc)
	var jv := VBoxContainer.new()
	jv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	jv.offset_left = 22; jv.offset_top = 18; jv.offset_right = -22; jv.offset_bottom = -18
	jv.add_theme_constant_override("separation", 10)
	jc.add_child(jv)
	jv.add_child(_label("加入朋友的房间", 22, Color(0.65,0.85,1.0)))
	jv.add_child(_label("输入房主 IP 和 4 位房间码", 14, Color(0.72,0.8,0.92)))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "房主 IP"
	_ip_edit.text = NetworkManager.get_local_ip()
	_ip_edit.custom_minimum_size = Vector2(644, 54)
	_ip_edit.add_theme_font_size_override("font_size", 20)
	jv.add_child(_ip_edit)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "4 位房间码"
	_code_edit.custom_minimum_size = Vector2(644, 54)
	_code_edit.max_length = 4
	_code_edit.add_theme_font_size_override("font_size", 20)
	jv.add_child(_code_edit)
	jv.add_child(UiComponents.make_primary_button("加入房间", _join_pressed, Vector2(644, 58)))

	# 跨网 WebRTC
	var wc := UiComponents.make_card(Color(0.55, 0.75, 1.0))
	wc.custom_minimum_size = Vector2(688, 250)
	_initial_box.add_child(wc)
	var wv := VBoxContainer.new()
	wv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wv.offset_left = 22; wv.offset_top = 16; wv.offset_right = -22; wv.offset_bottom = -16
	wv.add_theme_constant_override("separation", 8)
	wc.add_child(wv)
	wv.add_child(_label("跨网联机（WebRTC）", 22, Color(0.72,0.9,1.0)))
	wv.add_child(_label("不需要同一 WiFi。房主先创建，好友输入 6 位房间码加入。", 13, Color(0.72,0.82,0.95)))
	_webrtc_code_edit = LineEdit.new()
	_webrtc_code_edit.placeholder_text = "6 位跨网房间码"
	_webrtc_code_edit.custom_minimum_size = Vector2(644, 50)
	_webrtc_code_edit.max_length = 6
	_webrtc_code_edit.add_theme_font_size_override("font_size", 20)
	wv.add_child(_webrtc_code_edit)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	wv.add_child(wrow)
	var wh := UiComponents.make_primary_button("跨网创建", _webrtc_host_pressed, Vector2(0, 52))
	wh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(wh)
	var wj := UiComponents.make_primary_button("跨网加入", _webrtc_join_pressed, Vector2(0, 52))
	wj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(wj)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	wv.add_child(trow)
	_turn_status = _label("", 12, Color(0.72,0.82,0.95))
	_turn_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(_turn_status)
	var tbtn := UiComponents.make_secondary_button("TURN 设置", _open_turn_dialog, Vector2(130, 36))
	trow.add_child(tbtn)
	_status = _label("", 15, Color(0.9,0.95,1.0))
	_initial_box.add_child(_status)

func _build_room() -> void:
	var rbg := Panel.new()
	rbg.position = Vector2(24, 92)
	rbg.size = Vector2(752, 1240)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.035, 0.055, 0.11, 0.94)
	rsb.border_color = Color(0.72, 0.58, 0.30, 0.75)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(22)
	rsb.shadow_color = Color(0, 0, 0, 0.45)
	rsb.shadow_size = 16
	rbg.add_theme_stylebox_override("panel", rsb)
	_room_bg = rbg
	rbg.visible = false
	add_child(rbg)
	_room_box = VBoxContainer.new()
	_room_box.position = Vector2(42, 120)
	_room_box.size = Vector2(716, 1300)
	_room_box.add_theme_constant_override("separation", 10)
	_room_box.visible = false
	add_child(_room_box)
	_room_code_label = _label("", 24, Color(1.0,0.86,0.45))
	_room_box.add_child(_room_code_label)
	_mode_label = _label("", 16, Color(0.72,0.84,0.96))
	_room_box.add_child(_mode_label)
	_uid_label = _label("", 13, Color(0.6,0.72,0.86))
	_room_box.add_child(_uid_label)
	# 派对规则（房主可选，覆盖全部特殊模式；选卡类联机自动发牌）
	var rule_lbl := _label("派对规则（房主可选）", 14, Color(0.86, 0.80, 0.62))
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rule_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_lbl.custom_minimum_size = Vector2(320, 22)
	_room_box.add_child(rule_lbl)
	var rule_scroll := ScrollContainer.new()
	rule_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rule_scroll.scroll_deadzone = 8
	rule_scroll.custom_minimum_size = Vector2(716, 150)
	_room_box.add_child(rule_scroll)
	var rule_grid := GridContainer.new()
	rule_grid.columns = 4
	rule_grid.add_theme_constant_override("h_separation", 8)
	rule_grid.add_theme_constant_override("v_separation", 8)
	rule_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_scroll.add_child(rule_grid)
	var rules := [
		["standard", "标准"], ["double_elixir", "双倍圣水"], ["triple_elixir", "三倍圣水"],
		["seven_elixir", "七倍圣水"], ["sudden_death", "突然死亡"], ["touchdown", "冲线"],
		["classic_deck", "经典卡组"], ["draft", "选卡"], ["triple_draft", "三选一"],
		["swap_draft", "双向选卡"], ["mirror_deck", "镜像卡组"], ["mega_deck", "18 卡"],
		["commando", "主题特种兵"], ["custom", "自定义"],
	]
	for entry in rules:
		var b := Button.new()
		b.text = String(entry[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(166, 34)
		b.add_theme_font_size_override("font_size", 13)
		var rid := String(entry[0])
		b.pressed.connect(func():
			if NetworkManager.role == NetworkManager.Role.HOST:
				NetworkManager.party_rule = rid
				_refresh_rule_buttons()
				_refresh_custom_panel()
				_refresh_seats()
				NetworkManager.sync_room())
		_rule_buttons.append([b, rid])
		rule_grid.add_child(b)
	_custom_box = VBoxContainer.new()
	_custom_box.add_theme_constant_override("separation", 6)
	_room_box.add_child(_custom_box)
	_refresh_custom_panel()
	# 好友 / 邀请按钮
	var friend_row := HBoxContainer.new()
	friend_row.add_theme_constant_override("separation", 10)
	var friends_btn := UiComponents.make_secondary_button("好友", _show_friend_list, Vector2(150, 42))
	friends_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friend_row.add_child(friends_btn)
	var invite_btn := UiComponents.make_primary_button("邀请好友", _on_invite_friend, Vector2(0, 42))
	invite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friend_row.add_child(invite_btn)
	_room_box.add_child(friend_row)
	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 10)
	_room_box.add_child(_seats_box)
	_start_btn = UiComponents.make_primary_button("开始游戏", _start_pressed, Vector2(680, 64))
	_room_box.add_child(_start_btn)
	var destroy_btn := UiComponents.make_secondary_button("销毁房间", _destroy_room, Vector2(680, 46))
	destroy_btn.visible = false
	destroy_btn.name = "DestroyRoom"
	_room_box.add_child(destroy_btn)
	_room_status = _label("", 15, Color(0.9,0.95,1.0))
	_room_box.add_child(_room_status)

func _refresh_custom_panel() -> void:
	if _custom_box == null:
		return
	for c in _custom_box.get_children():
		c.queue_free()
	if NetworkManager.party_rule != "custom":
		return
	var panel = CUSTOM_PANEL.new()
	panel.editable = NetworkManager.role == NetworkManager.Role.HOST
	panel.changed.connect(func(cfg):
		if NetworkManager.role == NetworkManager.Role.HOST:
			BATTLE_MODES.set_custom_config(cfg)
			NetworkManager.sync_room()
			_room_status.text = "自定义规则已同步")
	_custom_box.add_child(panel)

func _update_turn_status() -> void:
	if _turn_status:
		_turn_status.text = "跨网中继：" + WebRTCNet.turn_summary()

func _open_turn_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "TURN 中继设置（可选）"
	dlg.ok_button_text = "保存"
	dlg.add_cancel_button("取消")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var hint := _label("严格 NAT 下需要 TURN。例：turn:xxx:3478?transport=udp", 12, Color(0.7,0.8,0.95))
	box.add_child(hint)
	var cfg := WebRTCNet.turn_config()
	var url := LineEdit.new(); url.placeholder_text = "TURN URL"; url.text = String(cfg.get("url", "")); box.add_child(url)
	var user := LineEdit.new(); user.placeholder_text = "TURN 用户名"; user.text = String(cfg.get("user", "")); box.add_child(user)
	var passw := LineEdit.new(); passw.placeholder_text = "TURN 密码"; passw.secret = true; passw.text = String(cfg.get("pass", "")); box.add_child(passw)
	var cf := UiComponents.make_primary_button("使用 Cloudflare 自动获取", Callable(), Vector2(0, 44))
	cf.pressed.connect(func():
		cf.disabled = true
		var r: Dictionary = await WebRTCNet.fetch_cloudflare_turn()
		cf.disabled = false
		if bool(r.get("ok", false)):
			_update_turn_status()
			dlg.hide()
		else:
			hint.text = "获取失败：%s" % String(r.get("error", "未知错误"))
	)
	box.add_child(cf)
	dlg.add_child(box)
	dlg.confirmed.connect(func():
		WebRTCNet.save_turn_config(url.text, user.text, passw.text)
		_update_turn_status())
	add_child(dlg)
	dlg.popup_centered(Vector2i(660, 420))

func _webrtc_host_pressed() -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	_status.text = "正在创建跨网房间…"
	var ok: bool = await WebRTCNet.host_room()
	if not ok:
		_status.text = "创建失败，请确认已登录 Supabase"
		return
	NetworkManager.start_host_webrtc()
	_enter_room(true)
	_room_status.text = "跨网房间码：%s（好友输入此码加入）" % WebRTCNet.room_code

func _webrtc_join_pressed() -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	var code := _webrtc_code_edit.text.strip_edges()
	if code.length() != 6:
		_status.text = "请输入 6 位跨网房间码"
		return
	_status.text = "正在连接跨网房间 %s…" % code
	var ok: bool = await WebRTCNet.join_room(code)
	if not ok:
		_status.text = "连接失败，请检查房间码/网络"
		return
	NetworkManager.join_host_webrtc()
	_status.text = "已提交加入，等待房主确认…"

func _host_pressed() -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	if not NetworkManager.start_host(24500):
		return
	_enter_room(true)

func _join_pressed() -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	var ip := _ip_edit.text.strip_edges()
	var code := _code_edit.text.strip_edges()
	if ip == "" or code.length() != 4:
		_status.text = "请输入正确的 IP 和 4 位房间码"
		return
	NetworkManager.join_host(ip, 24500, code)

func _enter_room(is_host: bool) -> void:
	_in_room = true
	_initial_box.visible = false
	_room_box.visible = true
	if _room_bg: _room_bg.visible = true
	_refresh_seats()
	if is_host:
		var env_rule := OS.get_environment("CR_NET_PARTY_RULE")
		if env_rule != "":
			NetworkManager.party_rule = env_rule
			_refresh_rule_buttons()
			_refresh_seats()
		var ai0 := OS.get_environment("CR_NET_ADD_BLUE")
		var ai1 := OS.get_environment("CR_NET_ADD_RED")
		if ai0 != "": NetworkManager.add_seat(0)
		if ai1 != "": NetworkManager.add_seat(1)
		if OS.get_environment("CR_NET_AUTO_START") != "":
			call_deferred("_try_auto_start")
	else:
		var auto_s := OS.get_environment("CR_NET_AUTO_SEAT")
		if auto_s != "":
			call_deferred("_auto_claim")

func _on_invite_friend() -> void:
	if NetworkManager.role != NetworkManager.Role.HOST:
		_room_status.text = "只有房主可以发送房间邀请"
		return
	if NetworkManager.room_code == "":
		return
	if NetworkManager.webrtc_mode:
		_show_friend_list()
		return
	var ok := FriendManager.send_room_invite(NetworkManager.room_code, NetworkManager.get_local_ip(), PlayerData.player_name)
	_room_status.text = "已发送房间邀请：%s" % NetworkManager.room_code if ok else "邀请发送失败"


func _on_friend_invite(invite: Dictionary) -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	var dlg := AcceptDialog.new()
	dlg.title = "联机邀请"
	var is_web := String(invite.get("kind", "")) == "webrtc"
	dlg.dialog_text = "好友 %s 邀请你加入房间 %s\n%s\n\n确定后将进入联机房间。" % [
		String(invite.get("from", "好友")), String(invite.get("code", "")),
		"跨网房间码，可直接加入" if is_web else "IP：%s" % String(invite.get("ip", ""))]
	dlg.confirmed.connect(func():
		get_tree().change_scene_to_file("res://scenes/network_lobby.tscn"))
	add_child(dlg)
	dlg.popup_centered(Vector2i(680, 320))


func _show_room_list() -> void:
	if NetworkManager.role != NetworkManager.Role.NONE:
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 215
	add_child(layer)
	var overlay := UiComponents.make_overlay(layer)
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -430
	panel.offset_bottom = 430
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20; v.offset_right = -20; v.offset_top = 18; v.offset_bottom = -18
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := _label("房间列表", 24, ThemeHelper.COLORS.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var hint := _label("局域网房间和跨网房间；点击直接加入", 12, ThemeHelper.COLORS.text_muted)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var loading := _label("正在读取房间…", 13, ThemeHelper.COLORS.text_muted)
	list.add_child(loading)
	var refresh := UiComponents.make_secondary_button("刷新", func(): layer.queue_free(); _show_room_list(), Vector2(0, 40))
	v.add_child(refresh)
	v.add_child(UiComponents.make_secondary_button("关闭", func(): layer.queue_free(), Vector2(0, 40)))
	var rows: Array = await SupabaseAPI.list_prefix("room_list:", 80)
	loading.queue_free()
	var now := int(Time.get_unix_time_from_system())
	var count := 0
	for row in rows:
		if not (row is Dictionary): continue
		var d = row.get("value", {})
		if not (d is Dictionary): continue
		if now - int(d.get("updated", 0)) > 300: continue
		var code := String(d.get("code", ""))
		if code == "" or code == NetworkManager.room_code: continue
		count += 1
		var rp := Panel.new()
		rp.custom_minimum_size = Vector2(0, 58)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.05, 0.08, 0.15, 0.98)
		rsb.border_color = Color(1,1,1,0.12)
		rsb.set_border_width_all(1)
		rsb.set_corner_radius_all(10)
		rp.add_theme_stylebox_override("panel", rsb)
		var rh := HBoxContainer.new()
		rh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rh.offset_left = 10; rh.offset_right = -10
		rp.add_child(rh)
		var info := _label("房间 %s   房主 %s   玩家 %d   %s" % [code, String(d.get("host", "玩家")), int(d.get("players", 0)), "跨网" if String(d.get("transport", "")) == "webrtc" else "局域网"], 13, Color(0.86,0.9,1.0))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rh.add_child(info)
		var join := UiComponents.make_primary_button("加入", Callable(), Vector2(82, 40))
		join.pressed.connect(func():
			layer.queue_free()
			if String(d.get("transport", "")) == "webrtc":
				_webrtc_code_edit.text = code
				_webrtc_join_pressed()
			else:
				NetworkManager.join_host(String(d.get("ip", "")), 24500, code))
		rh.add_child(join)
		list.add_child(rp)
	if count == 0:
		list.add_child(_label("暂无可用房间", 13, ThemeHelper.COLORS.text_muted))

func _show_friend_list() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 210
	add_child(layer)
	var overlay := UiComponents.make_overlay(layer)
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free())
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -300
	panel.offset_bottom = 300
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Label.new()
	title.text = "好友列表"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var fl := FriendManager.all()
	if fl.is_empty():
		var empty := Label.new()
		empty.text = "暂无好友\n在排行榜或部落点击玩家头像即可添加"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		list.add_child(empty)
	for f in fl:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var nm := Label.new()
		nm.text = "%s  %d杯" % [String(f.get("name", "玩家")), int(f.get("trophies", 0))]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 15)
		row.add_child(nm)
		var ib := UiComponents.make_primary_button("邀请", Callable(), Vector2(88, 36))
		ib.pressed.connect(func():
			if NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.room_code != "":
				var ok := false
				if NetworkManager.webrtc_mode:
					ok = FriendManager.send_cloud_room_invite(NetworkManager.room_code, PlayerData.player_name, String(f.get("id", "")))
				else:
					ok = FriendManager.send_room_invite(NetworkManager.room_code, NetworkManager.get_local_ip(), PlayerData.player_name, String(f.get("id", "")))
				_room_status.text = "已发送邀请给 %s" % String(f.get("name", "好友")) if ok else "邀请失败"
			else:
				_room_status.text = "请先创建房间再邀请好友")
		row.add_child(ib)
	var search_btn := UiComponents.make_secondary_button("搜索添加好友", Callable(), Vector2(0, 44))
	search_btn.pressed.connect(func():
		layer.queue_free()
		add_child(preload("res://assets/ui/FriendCenter.gd").new()))
	v.add_child(search_btn)
	v.add_child(UiComponents.make_secondary_button("关闭", func(): layer.queue_free(), Vector2(0, 44)))


func _refresh_rule_buttons() -> void:
	for item in _rule_buttons:
		var b: Button = item[0]
		var active: bool = String(item[1]) == NetworkManager.party_rule
		b.disabled = NetworkManager.role != NetworkManager.Role.HOST
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2 if active else 1)
		sb.bg_color = Color(0.16, 0.11, 0.05, 0.95) if active else Color(0.05, 0.07, 0.13, 0.9)
		sb.border_color = Color(0.95, 0.76, 0.36, 0.95) if active else Color(1, 1, 1, 0.16)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72) if active else Color(0.72, 0.78, 0.88))
	_refresh_custom_panel()


func _refresh_seats() -> void:
	if not _in_room:
		return
	_room_code_label.text = "房间码 %s    IP %s" % [NetworkManager.room_code, NetworkManager.get_local_ip()]
	var rule_name := String(BATTLE_MODES.get_by_id(NetworkManager.party_rule).get("name", "标准"))
	_mode_label.text = "模式 %s · %s    蓝 %d 席 / 红 %d 席" % [NetworkManager.mode_name(), rule_name, NetworkManager.seats_in_team(0).size(), NetworkManager.seats_in_team(1).size()]
	_refresh_rule_buttons()
	_uid_label.text = "你是 %s" % ("房主" if NetworkManager.role == NetworkManager.Role.HOST else "玩家")
	for ch in _seats_box.get_children():
		ch.queue_free()
	for team in [0, 1]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_seats_box.add_child(row)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		row.add_child(head)
		var team_lbl := _label("蓝方" if team == 0 else "红方", 24, Color(0.55,0.8,1.0) if team == 0 else Color(1.0,0.6,0.55))
		team_lbl.custom_minimum_size = Vector2(180, 40)
		team_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(team_lbl)
		if NetworkManager.role == NetworkManager.Role.HOST:
			var addb := UiComponents.make_secondary_button("+ 席位", func(): NetworkManager.add_seat(team), Vector2(96, 38))
			addb.disabled = NetworkManager.seats_in_team(team).size() >= 2
			head.add_child(addb)
			var delb := UiComponents.make_secondary_button("- 席位", func(): NetworkManager.remove_seat(team, NetworkManager.seats_in_team(team).size() - 1), Vector2(96, 38))
			delb.disabled = NetworkManager.seats_in_team(team).size() <= 0
			head.add_child(delb)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 10)
		row.add_child(cards)
		for s in NetworkManager.seats_in_team(team):
			cards.add_child(_make_seat_card(s, team))
	_start_btn.visible = NetworkManager.role == NetworkManager.Role.HOST
	var dr := _room_box.get_node_or_null("DestroyRoom")
	if dr:
		dr.visible = NetworkManager.role == NetworkManager.Role.HOST
	_start_btn.disabled = not NetworkManager.can_start()
	if NetworkManager.role == NetworkManager.Role.HOST:
		_start_btn.text = "开始游戏" if NetworkManager.can_start() else "等待玩家入驻…"
	var seated := 0
	for s in NetworkManager.seats:
		if int(s.peer) > 0: seated += 1
	_room_status.text = "已入驻 %d 席 · 空席位 AI 托管" % seated

func _make_seat_card(s: Dictionary, team: int) -> Button:
	var peer := int(s.peer)
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 112)
	b.add_theme_font_size_override("font_size", 16)
	var peer0 := int(s.get("peer", 0))
	var av = AVATAR_ICON.new()
	av.position = Vector2(12, 34)
	av.size = Vector2(44, 44)
	av.custom_minimum_size = Vector2(44, 44)
	if peer0 == multiplayer.get_unique_id() or (NetworkManager.role == NetworkManager.Role.HOST and peer0 == 1):
		av.setup_local()
	else:
		av.setup(String(s.get("name", "玩家")), int(s.get("avatar_seed", 0)), int(s.get("avatar_index", 0)))
	b.add_child(av)
	av.mouse_filter = Control.MOUSE_FILTER_STOP
	av.clicked.connect(func():
		UiComponents.open_player_profile(self, {"player_id": str(peer0), "name": String(s.get("name", "玩家")), "avatar_seed": int(s.get("avatar_seed", 0)), "avatar_index": int(s.get("avatar_index", 0)), "trophies": 0, "clan": ""}))
	var team_col := Color(0.36, 0.66, 1.0) if team == 0 else Color(1.0, 0.45, 0.40)
	var bg := Color(0.055, 0.09, 0.16, 0.98)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = team_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.10, 0.16, 0.26, 1.0)
	hover.border_color = team_col.lightened(0.25)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", sb)
	var role_txt := ""
	if peer == 1:
		role_txt = "👑 房主"
	elif peer > 0:
		role_txt = "👤 玩家"
	elif bool(s.ai):
		role_txt = "🤖 AI 托管"
	else:
		role_txt = "＋ 点击进驻"
	b.text = "       席位 %d    %s\n       %s" % [int(s.idx) + 1, role_txt, String(s.name) if peer > 0 else ("点击此席位进驻" if peer == 0 and not bool(s.ai) else "空席位")]
	if peer > 0:
		b.text = "       席位 %d    %s\n       %s" % [int(s.idx) + 1, role_txt, String(s.name)]
	elif bool(s.ai):
		b.text = "       席位 %d    AI 托管\n       点击可进驻" % [int(s.idx) + 1]
	else:
		b.text = "       席位 %d    空席位\n       点击进驻" % [int(s.idx) + 1]
	var mine := (peer == multiplayer.get_unique_id()) or (NetworkManager.role == NetworkManager.Role.HOST and peer == 1)
	b.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if mine else Color(0.82, 0.88, 0.98))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
	if NetworkManager.role == NetworkManager.Role.GUEST and peer == 0:
		b.pressed.connect(func(): NetworkManager.claim_seat(team, int(s.idx)))
	return b

func _auto_claim() -> void:
	var myid := multiplayer.get_unique_id()
	for s in NetworkManager.seats:
		if int(s.peer) == 0:
			NetworkManager.claim_seat(int(s.team), int(s.idx))
			return

func _try_auto_start() -> void:
	var env := OS.get_environment("CR_NET_AUTO_START")
	print("NET auto start env=", env, " players=", NetworkManager.players.size(), " can=", NetworkManager.can_start())
	if env == "wait" and NetworkManager.players.size() < 2:
		await get_tree().create_timer(0.5).timeout
		_try_auto_start()
		return
	if NetworkManager.can_start():
		_start_pressed()
	else:
		await get_tree().create_timer(0.5).timeout
		_try_auto_start()

func _start_pressed() -> void:
	if NetworkManager.role != NetworkManager.Role.HOST or not NetworkManager.can_start():
		return
	LoadingScreen.show_loading("正在进入 %s 战场…" % NetworkManager.mode_name())
	BATTLE_MODES.set_mode(BATTLE_MODES.get_by_id(NetworkManager.party_rule))
	NetworkManager.start_match()
	await get_tree().create_timer(0.15).timeout
	var rule_mode := BATTLE_MODES.current() if NetworkManager.party_rule == "custom" else BATTLE_MODES.get_by_id(NetworkManager.party_rule)
	var deck := String(rule_mode.get("deck", ""))
	if deck == "draft" or deck == "swap_draft":
		get_tree().change_scene_to_file("res://scenes/network_draft.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_guest_joined() -> void:
	if NetworkManager.role == NetworkManager.Role.HOST:
		_refresh_seats()
	else:
		_enter_room(false)

func _destroy_room() -> void:
	if NetworkManager.role != NetworkManager.Role.HOST:
		return
	NetworkManager.destroy_room()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_room_closed() -> void:
	get_tree().change_scene_to_file("res://scenes/network_lobby.tscn")

func _on_status(text: String) -> void:
	if _status:
		_status.text = text
	if _room_status:
		_room_status.text = text

func _on_match_started(info: Dictionary) -> void:
	if NetworkManager.role == NetworkManager.Role.HOST:
		return
	BATTLE_MODES.set_mode(BATTLE_MODES.get_by_id(String(info.get("party_rule", "standard"))))
	var rule_mode := BATTLE_MODES.current() if NetworkManager.party_rule == "custom" else BATTLE_MODES.get_by_id(NetworkManager.party_rule)
	var deck := String(rule_mode.get("deck", ""))
	LoadingScreen.show_loading("正在进入战场…")
	if deck == "draft" or deck == "swap_draft":
		get_tree().change_scene_to_file("res://scenes/network_draft.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/network_guest.tscn")
