# scripts/ui/PlayerProfileDialog.gd
# 玩家个人主页：头像/名字/奖杯/部落 + 加好友
extends Control

const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")

var profile: Dictionary = {}
var _friend_btn: Button
var _status: Label
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	battle_setup()


func battle_setup() -> void:
	z_index = 220
	UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -430
	panel.offset_bottom = 430
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_right = -26
	v.offset_top = 22
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := _label("玩家资料", 26, ThemeHelper.COLORS.gold, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var av_row := HBoxContainer.new()
	av_row.alignment = BoxContainer.ALIGNMENT_CENTER
	av_row.add_theme_constant_override("separation", 18)
	v.add_child(av_row)
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(112, 112)
	av.size = Vector2(112, 112)
	var name := String(profile.get("name", profile.get("player_name", "玩家")))
	var seedv := int(profile.get("avatar_seed", absi(hash(name))))
	var idx := int(profile.get("avatar_index", seedv % 12))
	av.setup(name, seedv, idx)
	av_row.add_child(av)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	av_row.add_child(info)
	info.add_child(_label(name, 25, ThemeHelper.COLORS.text, true))
	var pid := String(profile.get("player_id", profile.get("id", "")))
	var is_self := pid != "" and pid == str(ClanManager.get_player_id())
	var online := FriendManager.is_online(pid) if pid != "" else false
	info.add_child(_label("在线" if online else "离线", 12, Color(0.48, 1.0, 0.62) if online else Color(0.58, 0.66, 0.78)))
	info.add_child(_label("ID %s" % (pid if pid != "" else "未知"), 12, ThemeHelper.COLORS.text_muted))
	var role := String(profile.get("role", ""))
	if role != "":
		info.add_child(_label("职位：%s" % role, 14, Color(0.82, 0.88, 1.0)))

	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	v.add_child(cards)
	cards.add_child(_stat_card("奖杯", str(int(profile.get("trophies", profile.get("score", 0))))))
	cards.add_child(_stat_card("最高奖杯", str(int(profile.get("highest_trophies", profile.get("trophies", 0))))))
	var arena_i := int(profile.get("arena", 1))
	cards.add_child(_stat_card("竞技场", PlayerData.get_arena_name_at(arena_i)))
	cards.add_child(_stat_card("捐赠", str(int(profile.get("donations", 0)))))
	var clan := String(profile.get("clan", profile.get("clan_name", "")))
	var joined := int(profile.get("joined", 0))
	var meta_row := VBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 2)
	v.add_child(meta_row)
	meta_row.add_child(_label("部落：%s" % (clan if clan != "" else "未加入"), 14, Color(0.72, 0.82, 0.95)))
	if joined > 0:
		var d := Time.get_datetime_dict_from_unix_time(joined)
		meta_row.add_child(_label("加入时间：%d/%02d/%02d" % [int(d.year), int(d.month), int(d.day)], 12, ThemeHelper.COLORS.text_muted))
	var bio := String(profile.get("bio", ""))
	if bio == "":
		bio = "热爱皇室战争的部落成员，欢迎一起交流卡组与战术。"
	meta_row.add_child(_label(bio, 13, Color(0.72, 0.78, 0.90)))

	_friend_btn = UiComponents.make_primary_button("添加好友", _on_add_friend, Vector2(0, 54))
	_friend_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_friend_btn)
	var invite_btn := UiComponents.make_secondary_button("邀请入房（同局域网）", _on_invite, Vector2(0, 46))
	invite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(invite_btn)
	_status = _label("", 12, ThemeHelper.COLORS.text_muted)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var close_btn := UiComponents.make_secondary_button("关闭", func(): queue_free(), Vector2(0, 46))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(close_btn)
	_update_friend_btn(is_self, pid)

func _stat_card(k: String, v: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 74)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.075, 0.13, 0.96)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var key := _label(k, 11, ThemeHelper.COLORS.text_muted)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(key)
	var val := _label(v, 18, ThemeHelper.COLORS.gold, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(val)
	return p

func _update_friend_btn(is_self: bool, pid: String) -> void:
	if _friend_btn == null:
		return
	_friend_btn.disabled = false
	if is_self:
		_friend_btn.text = "这是你"
		_friend_btn.disabled = true
	elif FriendManager.is_friend(pid):
		_friend_btn.text = "已是好友"
		_friend_btn.disabled = true
	elif FriendManager.has_incoming(pid):
		_friend_btn.text = "同意好友请求"
	elif FriendManager.has_outgoing(pid):
		_friend_btn.text = "再次申请好友"
		_friend_btn.disabled = false
	else:
		_friend_btn.text = "发送好友请求"


func _on_add_friend() -> void:
	var pid := String(profile.get("player_id", profile.get("id", "")))
	if FriendManager.has_incoming(pid):
		FriendManager.accept_request(pid)
		_status.text = "已同意好友请求"
		_update_friend_btn(false, pid)
	elif FriendManager.send_friend_request(profile):
		_status.text = "好友请求已发送，等待对方同意"
		_update_friend_btn(false, pid)
	else:
		_status.text = "已在好友列表或请求已发送"


func _on_invite() -> void:
	# 如果当前在联机房间，直接广播房间码；否则提示先开房
	if NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.room_code != "":
		FriendManager.send_room_invite(NetworkManager.room_code, NetworkManager.get_local_ip(), PlayerData.player_name)
		_status.text = "已广播邀请（好友需在同一局域网）"
	else:
		_status.text = "请先创建联机房间，再邀请好友"


func _stat(k: String, v: String) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_label(k, 12, ThemeHelper.COLORS.text_muted))
	var val := _label(v, 22, ThemeHelper.COLORS.text, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(val)
	return box


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
