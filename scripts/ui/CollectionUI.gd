extends Control

const EMOTES = preload("res://scripts/data/EmoteCatalog.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")

func _ready():
	_apply_text_theme()
	UiComponents.add_background(self)
	UiComponents.make_header(self, "收藏", _on_back, true)
	var scroll := UiComponents.make_content_scroll(self)
	var vbox := UiComponents.make_content_vbox()
	scroll.add_child(vbox)
	# 顶部概览
	var summary := Label.new()
	summary.text = "🎭 表情 %d / %d     🃏 万能卡 %d" % [
		PlayerData.get_emote_count(), EMOTES.all().size(), _wildcard_total()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	summary.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	vbox.add_child(summary)
	# 收藏等级奖励入口
	var lv: int = PlayerData.get_collection_level()
	var pending: int = PlayerData.get_collection_reward_pending_count()
	var reward_panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	reward_panel.custom_minimum_size = Vector2(0, 94)
	var rh := HBoxContainer.new()
	rh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rh.offset_left = 16
	rh.offset_right = -16
	rh.add_theme_constant_override("separation", 12)
	reward_panel.add_child(rh)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	var rl := Label.new()
	rl.text = "收藏等级 Lv.%d" % lv
	rl.add_theme_font_size_override("font_size", 22)
	rl.add_theme_color_override("font_color", Color(1.0, 0.87, 0.46))
	rv.add_child(rl)
	var rs := Label.new()
	rs.text = "收藏奖励待领 %d · 大师奖励待领 %d" % [pending, PlayerData.get_mastery_claimable_count()]
	rs.add_theme_font_size_override("font_size", 14)
	rs.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	rv.add_child(rs)
	rh.add_child(rv)
	var rb := UiComponents.make_primary_button("收藏奖励", func(): get_tree().change_scene_to_file("res://scenes/collection_rewards.tscn"), Vector2(156, 48))
	rh.add_child(rb)
	var mb := UiComponents.make_secondary_button("卡牌大师", func(): get_tree().change_scene_to_file("res://scenes/card_mastery.tscn"), Vector2(156, 48))
	rh.add_child(mb)
	vbox.add_child(reward_panel)
	# 表情
	vbox.add_child(UiComponents.make_section_title("😀 表情收藏"))
	var ec := CenterContainer.new()
	vbox.add_child(ec)
	var eg := GridContainer.new()
	eg.columns = 4
	eg.add_theme_constant_override("h_separation", 10)
	eg.add_theme_constant_override("v_separation", 10)
	ec.add_child(eg)
	for item in EMOTES.all():
		eg.add_child(_emote_card(item))
	# 万能卡
	vbox.add_child(UiComponents.make_section_title("🃏 万能卡库存"))
	var wc := CenterContainer.new()
	vbox.add_child(wc)
	var wg := GridContainer.new()
	wg.columns = 4
	wg.add_theme_constant_override("h_separation", 10)
	wg.add_theme_constant_override("v_separation", 10)
	wc.add_child(wg)
	for rar in ["common", "rare", "epic", "legendary"]:
		wg.add_child(_wildcard_card(rar))
	var tip := Label.new()
	tip.text = "万能卡用于在卡牌详情中提升同稀有度卡牌数量；表情可在对战 HUD 发送。"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.68, 0.78, 0.90))
	vbox.add_child(tip)
	UiComponents.fade_in(self)

func _apply_text_theme():
	var th := Theme.new()
	var f := load("res://assets/fonts/STZHONGS.TTF")
	if f:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_embolden = 0.7
		th.default_font = fv
	th.default_font_size = 16
	th.set_color("font_color", "Label", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Label", Color(0.04, 0.06, 0.10))
	th.set_constant("outline_size", "Label", 5)
	theme = th

func _emote_card(item: Dictionary) -> Panel:
	var owned: bool = PlayerData.owned_emotes.has(String(item.id))
	var accent: Color = Color(String(item.color))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(168, 196)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.14, 0.97) if owned else Color(0.06, 0.06, 0.08, 0.92)
	sb.border_color = accent if owned else Color(0.32, 0.34, 0.40)
	sb.set_border_width_all(3 if owned else 1)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	if owned:
		var glyph = EMOTE_ICON.new()
		glyph.emote_id = String(item.id)
		glyph.custom_minimum_size = Vector2(120, 120)
		glyph.size = Vector2(120, 120)
		v.add_child(glyph)
	else:
		var lock := Label.new()
		lock.text = "未解锁"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 22)
		lock.add_theme_color_override("font_color", Color(0.40, 0.44, 0.52))
		v.add_child(lock)
	var name := Label.new()
	name.text = String(item.name) if owned else "未解锁"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", accent if owned else Color(0.56, 0.60, 0.68))
	v.add_child(name)
	var desc := Label.new()
	desc.text = String(item.desc) if owned else "皇室征程获取"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.66, 0.74, 0.86))
	v.add_child(desc)
	return p

func _wildcard_card(rar: String) -> Panel:
	var col: Color = PlayerData.wildcard_color(rar)
	var count: int = PlayerData.get_wildcard_count(rar)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(168, 196)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.14, 0.97)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var icon = REWARD_ICON.new()
	icon.custom_minimum_size = Vector2(0, 90)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.setup("wild", count)
	v.add_child(icon)
	var name := Label.new()
	name.text = "%s万能卡" % _rarity_cn(rar)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", col)
	v.add_child(name)
	var cnt := Label.new()
	cnt.text = "×%d" % count
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 20)
	cnt.add_theme_color_override("font_color", Color(1, 0.96, 0.84))
	v.add_child(cnt)
	var desc := Label.new()
	desc.text = "提升同稀有度卡牌数量"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.66, 0.74, 0.86))
	v.add_child(desc)
	return p

func _rarity_cn(rar: String) -> String:
	match rar:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传奇"
	return "普通"

func _wildcard_total() -> int:
	var n := 0
	for rar in ["common", "rare", "epic", "legendary"]:
		n += PlayerData.get_wildcard_count(rar)
	return n

func _on_back():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
