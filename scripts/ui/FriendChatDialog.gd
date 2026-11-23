# scripts/ui/FriendChatDialog.gd
# 好友私聊窗口：Supabase friend_msg:* 消息同步
extends Control

const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")

var friend: Dictionary = {}

var _pid := ""
var _scroll: ScrollContainer
var _msgs: VBoxContainer
var _input_edit: LineEdit
var _status: Label
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 240
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_pid = String(friend.get("id", friend.get("player_id", "")))
	_build()
	FriendManager.messages_changed.connect(_refresh)
	_refresh()
	set_process(false)


func _build() -> void:
	var overlay := UiComponents.make_overlay(self)
	overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -430
	panel.offset_bottom = 430
	add_child(panel)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var name := String(friend.get("name", "好友"))
	var av = AVATAR_ICON.new()
	av.custom_minimum_size = Vector2(42, 42)
	av.size = Vector2(42, 42)
	av.setup(name, int(friend.get("avatar_seed", absi(hash(name)))), int(friend.get("avatar_index", 0)))
	head.add_child(av)
	var title := _label("与 %s 聊天" % name, 18, ThemeHelper.COLORS.gold, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := UiComponents.make_secondary_button("关闭", func(): queue_free(), Vector2(76, 36))
	head.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 24
	_scroll.follow_focus = true
	root.add_child(_scroll)
	_msgs = VBoxContainer.new()
	_msgs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msgs.add_theme_constant_override("separation", 6)
	_scroll.add_child(_msgs)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	root.add_child(input_row)
	_input_edit = LineEdit.new()
	_input_edit.placeholder_text = "输入消息…"
	_input_edit.custom_minimum_size = Vector2(0, 44)
	_input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_edit.text_submitted.connect(func(_t): _send())
	input_row.add_child(_input_edit)
	var send := UiComponents.make_primary_button("发送", _send, Vector2(96, 44))
	input_row.add_child(send)
	_status = _label("", 11, ThemeHelper.COLORS.text_muted)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)


func _refresh() -> void:
	if _msgs == null:
		return
	for c in _msgs.get_children():
		c.queue_free()
	var list := FriendManager.get_messages(_pid)
	if list.is_empty():
		var empty := _label("暂无消息，开始聊天吧", 13, ThemeHelper.COLORS.text_muted)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 140)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_msgs.add_child(empty)
	else:
		var me := str(ClanManager.get_player_id())
		for m in list:
			var mine := String(m.get("from", "")) == me
			_bubble(String(m.get("text", "")), mine, int(m.get("ts", 0)))
		FriendManager.mark_messages_read(_pid)
	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _bubble(text: String, mine: bool, ts: int = 0) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	_msgs.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	row.add_child(col)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(280, 38)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.30, 0.55, 0.95) if mine else Color(0.08, 0.11, 0.20, 0.98)
	sb.border_color = Color(0.55, 0.72, 1.0, 0.35) if mine else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var lbl := _label(text, 14, Color(0.94, 0.97, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(252, 22)
	p.add_child(lbl)
	col.add_child(p)
	if ts > 0:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		var tl := _label("%02d:%02d" % [int(dt.hour), int(dt.minute)], 10, Color(0.62, 0.70, 0.84))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(tl)


func _send() -> void:
	var text := _input_edit.text.strip_edges() if _input_edit else ""
	if text == "":
		return
	if FriendManager.send_friend_message(_pid, text):
		_input_edit.text = ""
		_status.text = ""
	else:
		_status.text = "发送失败，请检查登录状态"
	_refresh()


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
