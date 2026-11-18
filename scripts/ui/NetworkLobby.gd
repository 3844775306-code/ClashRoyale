extends Control
const AVATAR_ICON = preload("res://scripts/ui/AvatarIcon.gd")

var _status: Label
var _room_status: Label
var _initial_box: VBoxContainer
var _room_box: VBoxContainer
var _room_bg: Panel
var _host_info: Label
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _uid_label: Label
var _seats_box: VBoxContainer
var _start_btn: Button
var _room_code_label: Label
var _mode_label: Label
var _in_room := false

func _ready():
	UiComponents.add_background(self)
	add_child(_make_header())
	_build_initial()
	_build_room()
	NetworkManager.lobby_status.connect(_on_status)
	NetworkManager.guest_joined.connect(_on_guest_joined)
	NetworkManager.seats_changed.connect(_refresh_seats)
	NetworkManager.joined_room.connect(func(): _enter_room(false))
	NetworkManager.match_started.connect(_on_match_started)
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
	_status = _label("", 15, Color(0.9,0.95,1.0))
	_initial_box.add_child(_status)

func _build_room() -> void:
	var rbg := Panel.new()
	rbg.position = Vector2(24, 92)
	rbg.size = Vector2(752, 1050)
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
	_room_box.size = Vector2(716, 1400)
	_room_box.add_theme_constant_override("separation", 10)
	_room_box.visible = false
	add_child(_room_box)
	_room_code_label = _label("", 24, Color(1.0,0.86,0.45))
	_room_box.add_child(_room_code_label)
	_mode_label = _label("", 16, Color(0.72,0.84,0.96))
	_room_box.add_child(_mode_label)
	_uid_label = _label("", 13, Color(0.6,0.72,0.86))
	_room_box.add_child(_uid_label)
	_seats_box = VBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 10)
	_room_box.add_child(_seats_box)
	_start_btn = UiComponents.make_primary_button("开始游戏", _start_pressed, Vector2(680, 64))
	_room_box.add_child(_start_btn)
	_room_status = _label("", 15, Color(0.9,0.95,1.0))
	_room_box.add_child(_room_status)

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

func _refresh_seats() -> void:
	if not _in_room:
		return
	_room_code_label.text = "房间码 %s    IP %s" % [NetworkManager.room_code, NetworkManager.get_local_ip()]
	_mode_label.text = "模式 %s    蓝 %d 席 / 红 %d 席" % [NetworkManager.mode_name(), NetworkManager.seats_in_team(0).size(), NetworkManager.seats_in_team(1).size()]
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
			var addb := UiComponents.make_secondary_button("+ 席位", func(): NetworkManager.add_seat(team), Vector2(120, 38))
			addb.disabled = NetworkManager.seats_in_team(team).size() >= 2
			head.add_child(addb)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 10)
		row.add_child(cards)
		for s in NetworkManager.seats_in_team(team):
			cards.add_child(_make_seat_card(s, team))
	_start_btn.visible = NetworkManager.role == NetworkManager.Role.HOST
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
	NetworkManager.start_match()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_guest_joined() -> void:
	if NetworkManager.role == NetworkManager.Role.HOST:
		_refresh_seats()
	else:
		_enter_room(false)

func _on_status(text: String) -> void:
	if _status:
		_status.text = text
	if _room_status:
		_room_status.text = text

func _on_match_started(_info: Dictionary) -> void:
	if NetworkManager.role == NetworkManager.Role.HOST:
		return
	LoadingScreen.show_loading("正在进入战场…")
	get_tree().change_scene_to_file("res://scenes/network_guest.tscn")
