extends Control
# 主题赛季：每 10 个皇冠解锁一档奖励，不同月份主题奖励侧重点不同。

const SEASON = preload("res://scripts/data/SeasonCatalog.gd")
const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")

var content: VBoxContainer
var scroll: ScrollContainer

func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "主题赛季", _on_back, true)
	scroll = UiComponents.make_content_scroll(self)
	content = UiComponents.make_content_vbox()
	scroll.add_child(content)
	_build_summary()
	_build_track()
	UiComponents.fade_in(self)

func _on_back():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _build_summary():
	var theme: Dictionary = PlayerData.get_season_theme()
	var crowns: int = PlayerData.get_season_crowns()
	var pending: int = PlayerData.get_season_pending_count()
	var accent := Color.html(String(theme.get("color", "ffcc55")))
	var panel := UiComponents.make_card(accent)
	panel.custom_minimum_size = Vector2(0, 238)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 14
	vb.offset_right = -18
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "%s · 主题赛季" % String(theme.get("name", "主题赛季"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", accent.lightened(0.25))
	vb.add_child(title)
	var desc := Label.new()
	desc.text = "本月奖励侧重：%s · 每 10 个皇冠领取一档" % String(theme.get("desc", "混合奖励"))
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	var crown_lbl := Label.new()
	crown_lbl.text = "本季皇冠：%d    已领取：%d / %d" % [crowns, PlayerData.season_claimed.size(), SEASON.TIERS]
	crown_lbl.add_theme_font_size_override("font_size", 18)
	crown_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	vb.add_child(crown_lbl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 10.0
	bar.value = float(crowns % 10)
	ThemeHelper.apply_progress_gold(bar)
	vb.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var pending_lbl := Label.new()
	pending_lbl.text = "可领取：%d 档" % pending
	pending_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pending_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_lbl.add_theme_font_size_override("font_size", 16)
	pending_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if pending > 0 else Color(0.65, 0.74, 0.86))
	row.add_child(pending_lbl)
	var claim := UiComponents.make_primary_button("一键领取", _claim_all, Vector2(170, 44))
	claim.disabled = pending <= 0
	row.add_child(claim)
	content.add_child(panel)

func _build_track():
	content.add_child(UiComponents.make_section_title("赛季奖励轨道"))
	var states: Array = PlayerData.get_season_reward_state()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	for s in states:
		list.add_child(_reward_row(s))

func _reward_row(s: Dictionary) -> Panel:
	var tier: int = int(s.get("tier", 1))
	var reward: Dictionary = s.get("reward", {})
	var available: bool = bool(s.get("available", false))
	var claimed: bool = bool(s.get("claimed", false))
	var row := UiComponents.make_list_row(Color(0.96, 0.72, 0.24) if available else Color.TRANSPARENT, 82)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 14
	hb.offset_top = 8
	hb.offset_right = -14
	hb.offset_bottom = -8
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)
	var t := Label.new()
	t.text = "%d 档" % tier
	t.custom_minimum_size = Vector2(64, 0)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if available else Color(0.70, 0.78, 0.90))
	hb.add_child(t)
	if String(reward.get("type", "gold")) == "chest":
		var chest = CHEST3D.new()
		chest.custom_minimum_size = Vector2(58, 62)
		chest.size = Vector2(58, 62)
		chest.rarity = "magical"
		hb.add_child(chest)
	else:
		var icon = REWARD_ICON.new()
		icon.custom_minimum_size = Vector2(52, 58)
		if String(reward.get("type", "gold")) == "card":
			icon.setup("card", int(reward.get("amount", 0)), String(reward.get("card_name", "卡牌")), int(reward.get("card_id", 0)))
		else:
			icon.setup("gold", int(reward.get("amount", 0)))
		hb.add_child(icon)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := Label.new()
	name.text = SEASON.reward_text(reward)
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	mid.add_child(name)
	var sub := Label.new()
	sub.text = "需要 %d 皇冠" % int(s.get("crowns", tier * 10))
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.62, 0.72, 0.86))
	mid.add_child(sub)
	hb.add_child(mid)
	var btn := UiComponents.make_primary_button("领取", Callable(), Vector2(92, 40))
	btn.disabled = not available
	if claimed:
		btn.text = "已领取"
	btn.pressed.connect(_claim_one.bind(tier))
	hb.add_child(btn)
	return row

func _claim_one(tier: int):
	PlayerData.claim_season_reward(tier)
	get_tree().reload_current_scene()

func _claim_all():
	if PlayerData.claim_all_season_rewards().is_empty():
		return
	get_tree().reload_current_scene()
