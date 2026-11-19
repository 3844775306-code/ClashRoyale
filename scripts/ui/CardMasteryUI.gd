extends Control
# 卡牌大师：每张卡累计使用次数，解锁三档奖励。

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const RARITY_CN := {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇", "champion": "冠军"}

var content: VBoxContainer
var scroll: ScrollContainer

func _ready():
	UiComponents.add_background(self)
	UiComponents.make_header(self, "卡牌大师", _on_back, true)
	scroll = UiComponents.make_content_scroll(self)
	content = UiComponents.make_content_vbox()
	scroll.add_child(content)
	_build_summary()
	_build_list()
	UiComponents.fade_in(self)

func _on_back():
	get_tree().change_scene_to_file("res://scenes/collection.tscn")

func _build_summary():
	var pending: int = PlayerData.get_mastery_claimable_count()
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.custom_minimum_size = Vector2(0, 160)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 14
	vb.offset_right = -18
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "卡牌大师"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	vb.add_child(title)
	var info := Label.new()
	info.text = "使用卡牌积累大师进度：10 / 50 / 150 次解锁三档奖励。"
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var lbl := Label.new()
	lbl.text = "可领取奖励：%d" % pending
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if pending > 0 else Color(0.65, 0.74, 0.86))
	row.add_child(lbl)
	var btn := UiComponents.make_primary_button("一键领取", _claim_all, Vector2(170, 44))
	btn.disabled = pending <= 0
	row.add_child(btn)
	content.add_child(panel)

func _build_list():
	content.add_child(UiComponents.make_section_title("卡牌大师进度"))
	var cards: Array = _card_configs()
	var rows: Array = []
	for cfg in cards:
		if cfg.card_id <= 3:
			continue
		var uses := PlayerData.get_mastery_uses(int(cfg.card_id))
		if not PlayerData.is_card_owned(int(cfg.card_id)) and uses <= 0:
			continue
		rows.append(cfg)
	rows.sort_custom(func(a, b):
		var ac := PlayerData.get_mastery_claimable_count_for(int(a.card_id)) if PlayerData.has_method("get_mastery_claimable_count_for") else 0
		var bc := PlayerData.get_mastery_claimable_count_for(int(b.card_id)) if PlayerData.has_method("get_mastery_claimable_count_for") else 0
		if ac != bc:
			return ac > bc
		return PlayerData.get_mastery_uses(int(a.card_id)) > PlayerData.get_mastery_uses(int(b.card_id))
	)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "还没有可展示的卡牌。"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
		content.add_child(empty)
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	for cfg in rows:
		list.add_child(_card_row(cfg))

func _card_configs() -> Array:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not bm:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	return bm.configs

func _card_row(cfg) -> Panel:
	var cid: int = int(cfg.card_id)
	var uses := PlayerData.get_mastery_uses(cid)
	var next_tier := PlayerData.get_mastery_next_tier(cid)
	var row := UiComponents.make_list_row(Color(0.96, 0.72, 0.24) if next_tier > 0 else Color.TRANSPARENT, 92)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_top = 8
	hb.offset_right = -10
	hb.offset_bottom = -8
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var icon = REWARD_ICON.new()
	icon.custom_minimum_size = Vector2(48, 62)
	icon.setup("card", 1, cfg.card_name, cid)
	hb.add_child(icon)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := Label.new()
	name.text = cfg.card_name
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	mid.add_child(name)
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	var claimed: Array = Array(PlayerData._mastery_entry(cid).get("claimed", []))
	for i in range(3):
		var chip := Label.new()
		var need: int = int(PlayerData.MASTERY_USES[i])
		chip.text = "%s %d" % ["青铜/白银/黄金".split("/")[i], need]
		chip.add_theme_font_size_override("font_size", 11)
		if claimed.has(i + 1):
			chip.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
		elif uses >= need:
			chip.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
		else:
			chip.add_theme_color_override("font_color", Color(0.55, 0.64, 0.78))
		tier_row.add_child(chip)
	mid.add_child(tier_row)
	var prog := ProgressBar.new()
	prog.custom_minimum_size = Vector2(0, 10)
	prog.show_percentage = false
	var next_need: int = 150
	for i in range(3):
		if not claimed.has(i + 1):
			next_need = int(PlayerData.MASTERY_USES[i])
			break
	prog.max_value = maxf(1.0, float(next_need))
	prog.value = minf(float(uses), prog.max_value)
	ThemeHelper.apply_progress_gold(prog)
	mid.add_child(prog)
	hb.add_child(mid)
	var uses_lbl := Label.new()
	uses_lbl.text = "%d 次" % uses
	uses_lbl.custom_minimum_size = Vector2(64, 0)
	uses_lbl.add_theme_font_size_override("font_size", 14)
	uses_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.96))
	uses_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(uses_lbl)
	var btn := UiComponents.make_primary_button("领取", Callable(), Vector2(92, 40))
	btn.disabled = next_tier <= 0
	btn.pressed.connect(_claim_one.bind(cid))
	hb.add_child(btn)
	return row

func _claim_one(cid: int):
	PlayerData.claim_mastery(cid)
	get_tree().reload_current_scene()

func _claim_all():
	if PlayerData.claim_all_mastery().is_empty():
		return
	get_tree().reload_current_scene()
