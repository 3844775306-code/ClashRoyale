extends Control
# 邮箱：列表只显示摘要，点击邮件查看全文；移动端大字号 + 触屏滚动。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const CLAIM_ANIM = preload("res://scripts/ui/ClaimAnimation.gd")
const MAIL_FONT := 36
const MAIL_META_FONT := 36

var content: VBoxContainer
var _scroll: ScrollContainer
var _detail: Control
var _detail_scroll: ScrollContainer
var _touch_dragging := false
var _mouse_dragging := false


func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "邮箱", _on_back, true)
	var topbar := get_tree().get_first_node_in_group("topbar")
	if topbar:
		for n in topbar.find_children("*", "Label", true, false):
			n.add_theme_font_size_override("font_size", MAIL_FONT)
	_scroll = UiComponents.make_content_scroll(self, UiComponents.HEADER_H + 16)
	content = UiComponents.make_content_vbox()
	_scroll.add_child(content)
	PlayerData.sync_global_mail()
	_build_summary()
	_build_list()
	UiComponents.fade_in(self)


func _on_back():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _input(event: InputEvent) -> void:
	var target: ScrollContainer = _detail_scroll if _detail != null else _scroll
	if target == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and target.get_global_rect().has_point(st.position):
			_touch_dragging = true
		elif not st.pressed:
			_touch_dragging = false
	elif event is InputEventScreenDrag:
		if _touch_dragging:
			var sd := event as InputEventScreenDrag
			target.scroll_vertical -= int(sd.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and target.get_global_rect().has_point(mb.position):
			_mouse_dragging = mb.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm := event as InputEventMouseMotion
		target.scroll_vertical -= int(mm.relative.y)
		get_viewport().set_input_as_handled()


func _build_summary():
	var pending: int = PlayerData.get_mail_pending_count()
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.custom_minimum_size = Vector2(0, 240)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 16
	vb.offset_right = -18
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "邮件概览"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "版本通知 · 官方福利 · 部落赠卡\n待领取：%d 封" % pending
	sub.add_theme_font_size_override("font_size", MAIL_FONT)
	sub.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	content.add_child(panel)


func _build_list():
	var section := Label.new()
	section.text = "邮件列表"
	section.add_theme_font_size_override("font_size", MAIL_FONT)
	section.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	content.add_child(section)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	content.add_child(list)
	if PlayerData.mailbox.is_empty():
		list.add_child(UiComponents.make_empty_state("📪", "暂无邮件", "版本通知与赠卡会出现在这里"))
		return
	for m in PlayerData.mailbox:
		list.add_child(_mail_row(m))


func _mail_row(m: Dictionary) -> Control:
	var claimed: bool = bool(m.get("claimed", false))
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 320)
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.075, 0.13, 0.98) if not claimed else Color(0.055, 0.065, 0.09, 0.85)
	sb.border_color = Color(1.0, 0.78, 0.30, 0.75) if not claimed else Color(1, 1, 1, 0.10)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.pressed.connect(_open_mail.bind(m))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 12
	vb.offset_right = -18
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 5)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var title := Label.new()
	title.text = String(m.get("title", "邮件"))
	title.add_theme_font_size_override("font_size", MAIL_FONT)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	var meta := Label.new()
	var d := Time.get_datetime_dict_from_unix_time(int(m.get("time", 0)))
	meta.text = "%s · %d/%02d/%02d %02d:%02d · %s" % [
		String(m.get("sender", "官方")), int(d.year), int(d.month), int(d.day),
		int(d.hour), int(d.minute), "已领取" if claimed else "未领取"]
	meta.add_theme_font_size_override("font_size", MAIL_META_FONT)
	meta.add_theme_color_override("font_color", Color(0.64, 0.80, 1.0))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(meta)

	var preview := Label.new()
	preview.text = _mail_preview(m)
	preview.add_theme_font_size_override("font_size", MAIL_FONT)
	preview.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.max_lines_visible = 2
	preview.clip_text = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(preview)

	var hint := Label.new()
	hint.text = "点击查看详细内容 ▶"
	hint.add_theme_font_size_override("font_size", MAIL_META_FONT)
	hint.add_theme_color_override("font_color", Color(1.0, 0.76, 0.34))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hint)
	return btn


func _mail_preview(m: Dictionary) -> String:
	var body := String(m.get("body", "")).replace("\n", " ").replace("\r", " ")
	while body.contains("  "):
		body = body.replace("  ", " ")
	body = body.strip_edges()
	if body.length() > 58:
		body = body.left(58) + "…"
	return "奖励：" + _reward_summary(Dictionary(m.get("reward", {}))) + "\n" + body


func _open_mail(m: Dictionary):
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	_detail = Control.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.z_index = 260
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_detail)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail.add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370
	panel.offset_right = 370
	panel.offset_top = -680
	panel.offset_bottom = 680
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.075, 0.13, 0.99)
	sb.border_color = Color(1.0, 0.78, 0.30, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	_detail.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22; v.offset_right = -22; v.offset_top = 18; v.offset_bottom = -18
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var title := Label.new()
	title.text = String(m.get("title", "邮件"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var close := UiComponents.make_secondary_button("返回", func(): _detail.queue_free(), Vector2(120, 58))
	close.add_theme_font_size_override("font_size", MAIL_FONT)
	top.add_child(close)

	var meta := Label.new()
	var d := Time.get_datetime_dict_from_unix_time(int(m.get("time", 0)))
	meta.text = "%s · %d/%02d/%02d %02d:%02d · %s" % [
		String(m.get("sender", "官方")), int(d.year), int(d.month), int(d.day),
		int(d.hour), int(d.minute), "已领取" if bool(m.get("claimed", false)) else "未领取"]
	meta.add_theme_font_size_override("font_size", MAIL_META_FONT)
	meta.add_theme_color_override("font_color", Color(0.64, 0.80, 1.0))
	v.add_child(meta)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.scroll_deadzone = 16
	v.add_child(_detail_scroll)
	var body_vb := VBoxContainer.new()
	body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vb.add_theme_constant_override("separation", 16)
	_detail_scroll.add_child(body_vb)

	var body := Label.new()
	body.text = String(m.get("body", "")).replace("\n", "\n")
	body.add_theme_font_size_override("font_size", MAIL_FONT)
	body.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_vb.add_child(body)

	var reward_title := Label.new()
	reward_title.text = "邮件奖励"
	reward_title.add_theme_font_size_override("font_size", MAIL_FONT)
	reward_title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	body_vb.add_child(reward_title)
	var rewards: Dictionary = m.get("reward", {})
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	body_vb.add_child(reward_row)
	_add_reward_icons(reward_row, rewards)
	if reward_row.get_child_count() == 0:
		reward_row.add_child(_make_label("无附加奖励", MAIL_FONT, Color(0.65, 0.74, 0.88)))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	var claimed: bool = bool(m.get("claimed", false))
	var claim := UiComponents.make_primary_button("已领取" if claimed else "领取奖励", func(): _claim(String(m.get("id", ""))), Vector2(0, 64))
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim.add_theme_font_size_override("font_size", MAIL_FONT)
	claim.disabled = claimed
	bottom.add_child(claim)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _add_reward_icons(parent: HBoxContainer, rewards: Dictionary) -> void:
	if int(rewards.get("gold", 0)) > 0:
		parent.add_child(_reward_icon("gold", int(rewards.gold)))
	if int(rewards.get("gems", 0)) > 0:
		parent.add_child(_reward_icon("gems", int(rewards.gems)))
	if not (rewards.get("cards", {}) as Dictionary).is_empty():
		for cid in rewards.cards.keys():
			var ic = REWARD_ICON.new()
			ic.custom_minimum_size = Vector2(54, 66)
			ic.setup("card", int(rewards.cards[cid]), _card_name(int(cid)), int(cid))
			parent.add_child(ic)
	if not (rewards.get("wildcards", {}) as Dictionary).is_empty():
		for rar in rewards.wildcards.keys():
			parent.add_child(_reward_icon("wild", int(rewards.wildcards[rar])))
	if String(rewards.get("chest", "")) != "":
		var ch = CHEST3D.new()
		ch.custom_minimum_size = Vector2(68, 68)
		ch.size = Vector2(68, 68)
		ch.rarity = String(rewards.chest)
		parent.add_child(ch)
	if String(rewards.get("emote", "")) != "":
		var em = EMOTE_ICON.new()
		em.custom_minimum_size = Vector2(58, 58)
		em.size = Vector2(58, 58)
		em.emote_id = String(rewards.emote)
		parent.add_child(em)



func _reward_icon(kind: String, amount: int):
	var ic = REWARD_ICON.new()
	ic.custom_minimum_size = Vector2(54, 66)
	ic.setup(kind, amount)
	return ic


func _card_name(cid: int) -> String:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if bm == null:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	var cfg = bm.get_config(cid) if bm else null
	return String(cfg.card_name) if cfg else "卡牌"


func _claim(mail_id: String):
	var m: Dictionary = PlayerData.claim_mail(mail_id)
	if m.is_empty():
		return
	var r: Dictionary = m.get("reward", {})
	CLAIM_ANIM.play(self, "领取成功", _reward_summary(r), _claim_spec(r))
	await get_tree().create_timer(1.1).timeout
	get_tree().reload_current_scene()

func _claim_spec(r: Dictionary) -> Dictionary:
	if not (r.get("cards", {}) as Dictionary).is_empty():
		for cid in r.cards.keys():
			return {"kind": "card", "card_id": int(cid), "card_name": _card_name(int(cid)), "amount": int(r.cards[cid])}
	if String(r.get("chest", "")) != "":
		return {"kind": "chest", "chest_rarity": String(r.chest)}
	if String(r.get("emote", "")) != "":
		return {"kind": "emote", "emote_id": String(r.emote)}
	if int(r.get("gems", 0)) > 0:
		return {"kind": "gems", "amount": int(r.gems)}
	if not (r.get("wildcards", {}) as Dictionary).is_empty():
		return {"kind": "wild", "amount": int((r.wildcards as Dictionary).values()[0])}
	return {"kind": "gold", "amount": int(r.get("gold", 0))}

func _reward_summary(r: Dictionary) -> String:
	var parts: Array = []
	if int(r.get("gold", 0)) > 0: parts.append("+%d 金币" % int(r.gold))
	if int(r.get("gems", 0)) > 0: parts.append("+%d 宝石" % int(r.gems))
	if not (r.get("cards", {}) as Dictionary).is_empty():
		for cid in r.cards.keys(): parts.append("%s ×%d" % [_card_name(int(cid)), int(r.cards[cid])])
	if not (r.get("wildcards", {}) as Dictionary).is_empty():
		for k in r.wildcards.keys(): parts.append("%s万能卡 ×%d" % [String(k), int(r.wildcards[k])])
	if String(r.get("chest", "")) != "": parts.append("宝箱")
	return "   ".join(parts) if not parts.is_empty() else "奖励已领取"

func _show_claim_anim(title: String):
	var lbl := Label.new()
	lbl.text = "领取成功：" + title
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-180, -24)
	lbl.size = Vector2(360, 48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 0.9)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free)
