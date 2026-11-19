extends Control
# 官方收藏等级奖励：20 级起每 10 级一个奖励（1500 级后每 5 级）。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const WILD_CN := {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇", "champion": "冠军"}

var content: VBoxContainer
var scroll: ScrollContainer

func _ready():
	print("COLLREW READY")
	UiComponents.add_background(self)
	UiComponents.make_header(self, "收藏等级奖励", _on_back, true)
	scroll = UiComponents.make_content_scroll(self)
	content = UiComponents.make_content_vbox()
	scroll.add_child(content)
	_build_summary()
	_build_track()
	UiComponents.fade_in(self)

func _on_back():
	get_tree().change_scene_to_file("res://scenes/collection.tscn")

func _build_summary():
	var lv: int = PlayerData.get_collection_level()
	var next: Dictionary = PlayerData.get_next_collection_reward()
	var pending: int = PlayerData.get_collection_reward_pending_count()
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.custom_minimum_size = Vector2(0, 230)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 14
	vb.offset_right = -18
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "收藏等级  Lv.%d" % lv
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	vb.add_child(title)
	var info := Label.new()
	if next.is_empty():
		info.text = "已领取全部收藏奖励"
	else:
		info.text = "下一奖励：Lv.%d · %s（还需 %d 级，1500 级前每 10 级一个）" % [int(next.level), _reward_text(next), maxi(0, int(next.level) - lv)]
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	var prev_level: int = 20
	var next_level: int = int(next.get("level", lv)) if not next.is_empty() else lv
	if next_level > 20:
		prev_level = next_level - (5 if next_level > 1500 else 10)
	bar.max_value = maxf(1.0, float(next_level - prev_level))
	bar.value = clampf(float(lv - prev_level), 0.0, bar.max_value)
	ThemeHelper.apply_progress_gold(bar)
	vb.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var pending_lbl := Label.new()
	pending_lbl.text = "待领取：%d 个奖励" % pending
	pending_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pending_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_lbl.add_theme_font_size_override("font_size", 16)
	pending_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if pending > 0 else Color(0.65, 0.74, 0.86))
	row.add_child(pending_lbl)
	var claim := UiComponents.make_primary_button("一键领取", _claim_all, Vector2(180, 46))
	claim.disabled = pending <= 0
	row.add_child(claim)
	content.add_child(panel)

func _build_track():
	var lv: int = PlayerData.get_collection_level()
	var rewards: Array = PlayerData.get_collection_rewards()
	var pending: Array = PlayerData.get_collection_reward_pending()
	var shown: Array = pending.duplicate()
	if shown.size() > 24:
		shown = shown.slice(0, 24)
	for r in rewards:
		if int(r.get("level", 0)) > lv and shown.size() < 34:
			shown.append(r)
	content.add_child(UiComponents.make_section_title("奖励轨道"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	if shown.is_empty():
		var empty := Label.new()
		empty.text = "升级卡牌提升收藏等级，20 级开始每 10 级获得奖励。"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
		list.add_child(empty)
		return
	for r in shown:
		list.add_child(_reward_row(r, lv))

func _reward_row(r: Dictionary, lv: int) -> Panel:
	var level: int = int(r.get("level", 0))
	var claimed: bool = PlayerData.collection_rewards_claimed.has(level)
	var available: bool = level <= lv and not claimed
	var row := UiComponents.make_list_row(Color(0.96, 0.72, 0.24) if available else Color.TRANSPARENT, 86)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 12
	hb.offset_top = 9
	hb.offset_right = -12
	hb.offset_bottom = -9
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % level
	lv_lbl.custom_minimum_size = Vector2(86, 0)
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 18)
	lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if available else Color(0.72, 0.78, 0.90))
	hb.add_child(lv_lbl)
	if String(r.get("type", "")) == "chest":
		var chest = CHEST3D.new()
		chest.custom_minimum_size = Vector2(64, 64)
		chest.size = Vector2(64, 64)
		chest.rarity = "magical"
		hb.add_child(chest)
	else:
		var ic = REWARD_ICON.new()
		ic.custom_minimum_size = Vector2(58, 64)
		if String(r.get("type", "")) == "gems":
			ic.setup("gems", int(r.get("amount", 0)))
		else:
			ic.setup("wild", int(r.get("amount", 0)))
		hb.add_child(ic)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := Label.new()
	name.text = _reward_text(r)
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	txt.add_child(name)
	var sub := Label.new()
	if claimed:
		sub.text = "已领取"
	elif available:
		sub.text = "可领取"
	else:
		sub.text = "还需 %d 级" % maxi(0, level - lv)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.55, 0.85, 0.62) if available else Color(0.62, 0.70, 0.82))
	txt.add_child(sub)
	hb.add_child(txt)
	var btn := UiComponents.make_primary_button("领取", Callable(), Vector2(96, 42))
	btn.disabled = not available
	btn.pressed.connect(_claim_one.bind(level))
	hb.add_child(btn)
	return row

func _reward_text(r: Dictionary) -> String:
	var typ := String(r.get("type", "gems"))
	if typ == "gems":
		return "%d 宝石" % int(r.get("amount", 0))
	if typ == "wild":
		var rar := String(r.get("rarity", "common"))
		return "%d 张%s万能卡" % [int(r.get("amount", 0)), String(WILD_CN.get(rar, "普通"))]
	if typ == "chest":
		if String(r.get("label", "")) != "":
			return String(r.get("label"))
		return "%d 星魔法幸运宝箱" % int(r.get("stars", 5))
	return "奖励"

func _claim_one(level: int):
	PlayerData.claim_collection_reward(level)
	get_tree().reload_current_scene()

func _claim_all():
	var got: Array = PlayerData.claim_all_collection_rewards()
	if got.is_empty():
		return
	get_tree().reload_current_scene()
