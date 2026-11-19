extends Control
# 邮箱：版本通知、官方福利、部落赠卡，手动领取。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")

var content: VBoxContainer

func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "邮箱", _on_back, true)
	var scroll := UiComponents.make_content_scroll(self)
	content = UiComponents.make_content_vbox()
	scroll.add_child(content)
	_build_summary()
	_build_list()
	UiComponents.fade_in(self)

func _on_back():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _build_summary():
	var pending: int = PlayerData.get_mail_pending_count()
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.custom_minimum_size = Vector2(0, 112)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 14
	vb.offset_right = -18
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "邮箱"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "版本通知 · 官方福利 · 部落赠卡   |   待领取 %d" % pending
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	vb.add_child(sub)
	content.add_child(panel)

func _build_list():
	content.add_child(UiComponents.make_section_title("邮件列表"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	content.add_child(list)
	if PlayerData.mailbox.is_empty():
		list.add_child(UiComponents.make_empty_state("📪", "暂无邮件", "版本通知与赠卡会出现在这里"))
		return
	for m in PlayerData.mailbox:
		list.add_child(_mail_row(m))

func _mail_row(m: Dictionary) -> Panel:
	var claimed: bool = bool(m.get("claimed", false))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.075, 0.13, 0.98) if not claimed else Color(0.055, 0.065, 0.09, 0.85)
	sb.border_color = Color(1.0, 0.78, 0.30, 0.75) if not claimed else Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 12
	vb.offset_right = -16
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 5)
	p.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var title := Label.new()
	title.text = String(m.get("title", "邮件"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	top.add_child(title)
	var sender := Label.new()
	sender.text = String(m.get("sender", "官方"))
	sender.add_theme_font_size_override("font_size", 12)
	sender.add_theme_color_override("font_color", Color(0.62, 0.80, 1.0))
	top.add_child(sender)
	var time := Label.new()
	var d := Time.get_datetime_dict_from_unix_time(int(m.get("time", 0)))
	time.text = "%d/%02d/%02d %02d:%02d" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute)]
	time.add_theme_font_size_override("font_size", 11)
	time.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80))
	top.add_child(time)
	var body := Label.new()
	body.text = String(m.get("body", ""))
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.80, 0.88, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 82)
	vb.add_child(body)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vb.add_child(bottom)
	var rewards: Dictionary = m.get("reward", {})
	if int(rewards.get("gold", 0)) > 0:
		bottom.add_child(_reward_icon("gold", int(rewards.gold)))
	if int(rewards.get("gems", 0)) > 0:
		bottom.add_child(_reward_icon("gems", int(rewards.gems)))
	if not (rewards.get("cards", {}) as Dictionary).is_empty():
		for cid in rewards.cards.keys():
			var amount := int(rewards.cards[cid])
			var ic = REWARD_ICON.new()
			ic.custom_minimum_size = Vector2(40, 50)
			ic.setup("card", amount, _card_name(int(cid)), int(cid))
			bottom.add_child(ic)
	if not (rewards.get("wildcards", {}) as Dictionary).is_empty():
		for rar in rewards.wildcards.keys():
			bottom.add_child(_reward_icon("wild", int(rewards.wildcards[rar])))
	if String(rewards.get("chest", "")) != "":
		var ch = CHEST3D.new()
		ch.custom_minimum_size = Vector2(48, 48)
		ch.size = Vector2(48, 48)
		ch.rarity = String(rewards.chest)
		bottom.add_child(ch)
	if String(rewards.get("emote", "")) != "":
		var em = EMOTE_ICON.new()
		em.custom_minimum_size = Vector2(40, 40)
		em.size = Vector2(40, 40)
		em.emote_id = String(rewards.emote)
		bottom.add_child(em)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	if String(m.get("url", "")) != "":
		var open_btn := UiComponents.make_secondary_button("更新页面", func(): OS.shell_open(String(m.get("url", ""))), Vector2(108, 38))
		bottom.add_child(open_btn)
	var claim := UiComponents.make_primary_button("已领取" if claimed else "领取", func(): _claim(String(m.get("id", ""))), Vector2(100, 40))
	claim.disabled = claimed
	bottom.add_child(claim)
	return p

func _reward_icon(kind: String, amount: int):
	var ic = REWARD_ICON.new()
	ic.custom_minimum_size = Vector2(40, 46)
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
	_show_claim_anim(String(m.get("title", "邮件")))
	await get_tree().create_timer(0.9).timeout
	get_tree().reload_current_scene()

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
