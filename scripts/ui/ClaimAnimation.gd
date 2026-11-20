extends RefCounted
# 统一领取奖励动画：皇室征程、邮箱、卡牌大师、收藏/赛季奖励共用。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")

static func play(host: Control, title: String, subtitle: String, reward: Dictionary) -> void:
	if host == null or not is_instance_valid(host):
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	host.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -190
	panel.offset_bottom = 190
	panel.pivot_offset = Vector2(210, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.18, 0.98)
	sb.border_color = Color(1.0, 0.78, 0.28, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 18
	vb.offset_right = -20
	vb.offset_bottom = -18
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	vb.add_child(t)
	var icon = _make_icon(reward)
	if icon:
		icon.custom_minimum_size = Vector2(100, 110)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(icon)
	var info := Label.new()
	info.text = subtitle
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	vb.add_child(info)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.10)
	tw.tween_interval(0.55)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): overlay.queue_free())

static func _make_icon(reward: Dictionary):
	var kind := String(reward.get("kind", "gold"))
	if kind == "chest":
		var c = CHEST3D.new()
		c.rarity = String(reward.get("chest_rarity", "magical"))
		return c
	if kind == "emote":
		var e = EMOTE_ICON.new()
		e.emote_id = String(reward.get("emote_id", ""))
		return e
	var ic = REWARD_ICON.new()
	if kind == "card":
		ic.setup("card", int(reward.get("amount", 1)), String(reward.get("card_name", "卡牌")), int(reward.get("card_id", 0)))
	elif kind == "gems":
		ic.setup("gems", int(reward.get("amount", 1)))
	elif kind == "wild":
		ic.setup("wild", int(reward.get("amount", 1)))
	else:
		ic.setup("gold", int(reward.get("amount", 1)))
	return ic
