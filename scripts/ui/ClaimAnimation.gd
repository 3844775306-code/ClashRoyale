extends RefCounted
# 统一领取奖励动画：皇室征程、邮箱、卡牌大师、收藏/赛季奖励共用。
# 支持一次展示多个奖励（一键领取），宝箱使用 3D 宝箱预览。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")


static func play(host: Control, title: String, subtitle: String, reward: Dictionary) -> void:
	play_many(host, title, subtitle, [reward])


static func play_many(host: Control, title: String, subtitle: String, rewards: Array) -> void:
	if host == null or not is_instance_valid(host) or rewards.is_empty():
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	host.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.60)
	overlay.add_child(dim)

	var n := rewards.size()
	var multi: bool = n > 1
	var panel_w: float = 500.0 if multi else 420.0
	var panel_h: float = 470.0 if multi else 380.0
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_w * 0.5
	panel.offset_right = panel_w * 0.5
	panel.offset_top = -panel_h * 0.5
	panel.offset_bottom = panel_h * 0.5
	panel.pivot_offset = Vector2(panel_w * 0.5, panel_h * 0.5)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.17, 0.985)
	sb.border_color = Color(1.0, 0.78, 0.28, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
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

	var grid := GridContainer.new()
	grid.columns = mini(3, n) if multi else 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(grid)
	var shown := 0
	for reward in rewards:
		if shown >= 9:
			break
		var icon = _make_icon(reward)
		if icon == null:
			continue
		icon.custom_minimum_size = Vector2(92, 100) if multi else Vector2(100, 110)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_child(icon)
		shown += 1

	var first: Dictionary = rewards[0]
	if String(first.get("kind", "")) == "card" and PlayerData.is_new_card(int(first.get("card_id", 0))):
		var nb := Label.new()
		nb.text = "新"
		nb.anchor_left = 1.0
		nb.anchor_right = 1.0
		nb.offset_left = -58
		nb.offset_top = 8
		nb.offset_right = -12
		nb.offset_bottom = 40
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nb.add_theme_font_size_override("font_size", 22)
		nb.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
		nb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		nb.add_theme_constant_override("shadow_offset_x", 2)
		nb.add_theme_constant_override("shadow_offset_y", 2)
		panel.add_child(nb)

	if n == 1 and String(first.get("kind", "")) == "wild":
		var wr := String(first.get("wild_rarity", "common"))
		var cn := "普通"
		match wr:
			"rare": cn = "稀有"
			"epic": cn = "史诗"
			"legendary": cn = "传奇"
		subtitle = "%s万能卡 ×%d" % [cn, int(first.get("amount", 1))]
	var info := Label.new()
	info.text = subtitle
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	vb.add_child(info)
	if multi:
		var count_lbl := Label.new()
		count_lbl.text = "共 %d 项奖励" % n
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color(0.66, 0.75, 0.90))
		vb.add_child(count_lbl)

	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := host.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.10)
	tw.tween_interval(0.55 if multi else 0.45)
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
