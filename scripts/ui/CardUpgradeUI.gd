# scripts/ui/CardUpgradeUI.gd
# 卡牌升级界面：等级徽章 + 稀有度色 + 升级进度条 + 花费 + 升级按钮
extends Control
const CLAIM_ANIM = preload("res://scripts/ui/ClaimAnimation.gd")

const MAX_LEVEL := 16   # 与 Config.LEVEL_MAX 一致

var currency_row: HBoxContainer
var card_list: VBoxContainer
var card_configs: Array = []
var info_panel: Control = null


func _ready():
	card_configs = _get_all_card_configs()
	UiComponents.add_background(self)
	currency_row = UiComponents.make_header(self, "卡牌升级", _on_return_pressed, true)
	var scroll := UiComponents.make_content_scroll(self)
	card_list = UiComponents.make_content_vbox()
	scroll.add_child(card_list)
	_refresh_ui()
	UiComponents.fade_in(self)


func _get_all_card_configs() -> Array:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not bm:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	return bm.configs


func _refresh_ui():
	UiComponents.refresh_currency_row(currency_row)
	for child in card_list.get_children():
		child.queue_free()
	var lv: int = PlayerData.get_collection_level()
	var pending: int = PlayerData.get_collection_reward_pending_count()
	var reward_panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	reward_panel.custom_minimum_size = Vector2(0, 84)
	var rh := HBoxContainer.new()
	rh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rh.offset_left = 16
	rh.offset_right = -16
	rh.add_theme_constant_override("separation", 12)
	reward_panel.add_child(rh)
	var info := Label.new()
	info.text = "收藏等级 Lv.%d    待领 %d · 大师 %d" % [lv, pending, PlayerData.get_mastery_claimable_count()]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	rh.add_child(info)
	var btn := UiComponents.make_primary_button("收藏奖励", func(): get_tree().change_scene_to_file("res://scenes/collection_rewards.tscn"), Vector2(150, 44))
	rh.add_child(btn)
	var mbtn := UiComponents.make_secondary_button("卡牌大师", func(): get_tree().change_scene_to_file("res://scenes/card_mastery.tscn"), Vector2(150, 44))
	rh.add_child(mbtn)
	card_list.add_child(reward_panel)
	for cfg in card_configs:
		if cfg.card_id <= 3:
			continue
		card_list.add_child(_make_upgrade_row(cfg))


func _make_upgrade_row(cfg) -> Panel:
	var card_id: int = cfg.card_id
	var level: int = PlayerData.get_card_level(card_id)
	var own: int = PlayerData.get_card_quantity(card_id)
	var need: int = PlayerData.calculate_upgrade_cards_needed(card_id, level)
	var cost_gold: int = PlayerData.calculate_upgrade_gold(card_id, level)
	var at_max := level >= MAX_LEVEL

	var row := UiComponents.make_list_row(ThemeHelper.cost_rarity(cfg.cost), 96)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_top = 10
	hbox.offset_right = -16
	hbox.offset_bottom = -10
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	# 等级徽章
	var badge := UiComponents.make_badge("Lv.%d" % level)
	badge.custom_minimum_size = Vector2(62, 0)
	hbox.add_child(badge)

	# 中间列：名称 + 进度
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	var name_row := HBoxContainer.new()
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 14)
	dot.add_theme_color_override("font_color", ThemeHelper.cost_rarity(cfg.cost))
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(dot)
	var name_lbl := Label.new()
	name_lbl.text = cfg.card_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_lbl)
	mid.add_child(name_row)

	var progress_row := HBoxContainer.new()
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max(1, need)
	bar.value = min(own, need)
	ThemeHelper.apply_progress_gold(bar)
	progress_row.add_child(bar)
	var count_lbl := Label.new()
	count_lbl.text = "%d/%d" % [own, need] if not at_max else "MAX"
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_row.add_child(count_lbl)
	mid.add_child(progress_row)
	hbox.add_child(mid)

	# 花费
	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if at_max:
		cost_lbl.text = "已满级"
		cost_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.success)
	else:
		cost_lbl.text = "%d 🪙" % cost_gold
		cost_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	hbox.add_child(cost_lbl)

	# 升级按钮
	var up_btn := UiComponents.make_primary_button("升级", func(): _on_upgrade_pressed(card_id), Vector2(96, 48))
	up_btn.disabled = not (PlayerData.gold >= cost_gold and own >= need and not at_max)
	hbox.add_child(up_btn)

	# 详情按钮
	var info_btn := UiComponents.make_secondary_button("ℹ", func(): _on_info_pressed(card_id), Vector2(56, 48))
	hbox.add_child(info_btn)

	return row


func _on_info_pressed(card_id: int):
	_show_card_info(card_id)


func _show_card_info(card_id: int):
	# 关闭旧面板
	if info_panel:
		info_panel.queue_free()
		info_panel = null

	var cfg = _get_card_config(card_id)
	if not cfg:
		return
	var level = PlayerData.get_card_level(card_id)
	var accent: Color = ThemeHelper.cost_rarity(cfg.cost)
	var at_max: bool = level >= MAX_LEVEL

	# 当前 / 下一级属性
	var cur_hp = cfg.max_health * Config.level_mult(level)
	var cur_dmg = cfg.damage * Config.level_mult(level)
	var cur_shield = cfg.shield * Config.level_mult(level)
	var next_hp = cfg.max_health * Config.level_mult(level + 1)
	var next_dmg = cfg.damage * Config.level_mult(level + 1)

	# ---- 全屏遮罩（点击关闭）----
	info_panel = Control.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_info_panel())
	info_panel.add_child(bg)

	# ---- 居中卡片 ----
	var panel := UiComponents.make_card(accent)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_right = 270
	panel.offset_top = -430
	panel.offset_bottom = 430
	info_panel.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_top = 16
	scroll.offset_right = -18
	scroll.offset_bottom = -16
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	# ---- 名片头：emoji + 名称 + 等级 + 费用/类型/目标芯片 ----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	content.add_child(head)

	var emoji_holder := Panel.new()
	emoji_holder.custom_minimum_size = Vector2(120, 120)
	var emoji_sb := StyleBoxFlat.new()
	emoji_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	emoji_sb.set_corner_radius_all(60)
	emoji_sb.set_border_width_all(2)
	emoji_sb.border_color = accent
	emoji_holder.add_theme_stylebox_override("panel", emoji_sb)
	var emoji_lbl := UiComponents.make_emoji_icon(ThemeHelper.card_emoji(cfg), 52)
	emoji_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emoji_holder.add_child(emoji_lbl)
	head.add_child(emoji_holder)

	var head_info := VBoxContainer.new()
	head_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_info.alignment = BoxContainer.ALIGNMENT_CENTER
	head_info.add_theme_constant_override("separation", 8)
	head.add_child(head_info)

	var name_lbl := Label.new()
	name_lbl.text = cfg.card_name
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", accent)
	head_info.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % level
	lv_lbl.add_theme_font_size_override("font_size", 15)
	lv_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	head_info.add_child(lv_lbl)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	if cfg.cost > 0:
		chip_row.add_child(_make_chip("💎 %d" % cfg.cost, Color(0.55, 0.4, 0.95)))
	var type_str = ["", "🏰 建筑", "⚔️ 地面", "🕊️ 空军"][cfg.type] if cfg.type >= 1 and cfg.type <= 3 else "❓"
	chip_row.add_child(_make_chip(type_str, accent))
	var target_str = ["", "🏯 仅建筑", "🛡️ 仅地面", "🎯 所有"][cfg.target_type] if cfg.target_type >= 1 and cfg.target_type <= 3 else "🎯 所有"
	chip_row.add_child(_make_chip(target_str, ThemeHelper.COLORS.text_muted))
	head_info.add_child(chip_row)

	content.add_child(HSeparator.new())

	# ---- 属性两栏网格 ----
	var stats: Array = []
	stats.append(["❤️", "生命", "%.0f" % cur_hp, true])
	stats.append(["⚔️", "伤害/次", "%.0f" % cur_dmg, true])
	if cfg.attack_speed > 0:
		var dps = cur_dmg / (cfg.attack_speed / 1000.0)
		stats.append(["📈", "DPS", "%.1f" % dps, true])
	if cfg.shield > 0:
		stats.append(["🛡️", "护盾", "%.0f" % cur_shield, true])
	elif cfg.shield == -1:
		stats.append(["💥", "护盾", "自爆", false])
	stats.append(["⏱", "攻速", "%.1f秒" % (cfg.attack_speed / 1000.0), false])
	if cfg.attack_range > 0:
		stats.append(["🎯", "射程", "%.1f米" % cfg.attack_range, false])
	if cfg.damage_range > 0:
		stats.append(["💫", "溅射半径", "%.1f米" % cfg.damage_range, false])
	if cfg.num > 1:
		stats.append(["👥", "数量", "×%d" % cfg.num, false])
	if cfg.move_speed > 0:
		stats.append(["👣", "移速", "%.1f米/秒" % (cfg.move_speed * 0.05), false])
	if cfg.horizon > 0:
		stats.append(["🔍", "视野", "%.1f米" % cfg.horizon, false])
	stats.append(["🏷️", "碰撞", "%.1f米" % cfg.size, false])
	if cfg.move_type != 1:
		var move_str = ["", "普通", "冲锋", "跳跃"][cfg.move_type] if cfg.move_type >= 1 and cfg.move_type <= 3 else "普通"
		stats.append(["🚀", "移动类型", move_str, false])
	if cfg.attack_type != 1:
		var atk_str = ["", "普通", "电击", "冰冻", "灼烧", "充能"][cfg.attack_type] if cfg.attack_type >= 1 and cfg.attack_type <= 5 else "特殊"
		stats.append(["⚡", "攻击特效", atk_str, false])
	if cfg.spawn_unit.size() >= 3:
		var spawn_cfg = _get_card_config(cfg.spawn_unit[0])
		var spawn_name = spawn_cfg.card_name if spawn_cfg else "?"
		stats.append(["🏭", "生成", "%.1f秒×%d %s" % [cfg.spawn_unit[2] / 1000.0, cfg.spawn_unit[1], spawn_name], false])
	if cfg.extra_spell.size() > 0:
		stats.append(["🌀", "附加法术", "有", false])
	if cfg.multiple_targets.size() >= 2:
		stats.append(["🎇", "多目标", "最多%d个" % cfg.multiple_targets[0], false])
	if cfg.multiple_process.size() >= 5:
		stats.append(["🔫", "多段攻击", "子弹%d发" % cfg.multiple_process[1], false])

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for s in stats:
		var row := UiComponents.make_stat_row(s[0], s[1], s[2],
			ThemeHelper.COLORS.gold if s[3] else Color.WHITE)
		row.custom_minimum_size.y = 30
		grid.add_child(row)

	content.add_child(HSeparator.new())

	# ---- 下一级预览 ----
	var next_title := UiComponents.make_section_title("下一级  Lv.%d" % (level + 1))
	content.add_child(next_title)

	if at_max:
		var max_lbl := Label.new()
		max_lbl.text = "🎉 已达到最高等级！"
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_lbl.add_theme_font_size_override("font_size", 16)
		max_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.success)
		content.add_child(max_lbl)
	else:
		content.add_child(UiComponents.make_stat_row("❤️", "生命", "%.0f → %.0f  (+5%%)" % [cur_hp, next_hp], ThemeHelper.COLORS.success))
		content.add_child(UiComponents.make_stat_row("⚔️", "伤害", "%.0f → %.0f  (+5%%)" % [cur_dmg, next_dmg], ThemeHelper.COLORS.success))

		# 升级需求
		var need = PlayerData.calculate_upgrade_cards_needed(card_id, level)
		var own = PlayerData.get_card_quantity(card_id)
		var cost_gold = PlayerData.calculate_upgrade_gold(card_id, level)

		var prog_row := HBoxContainer.new()
		prog_row.add_theme_constant_override("separation", 10)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = max(1, need)
		bar.value = min(own, need)
		ThemeHelper.apply_progress_gold(bar)
		prog_row.add_child(bar)
		var need_lbl := Label.new()
		need_lbl.text = "%d/%d 张" % [own, need]
		need_lbl.add_theme_font_size_override("font_size", 13)
		need_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		need_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prog_row.add_child(need_lbl)
		content.add_child(prog_row)

		var upgrade_row := HBoxContainer.new()
		upgrade_row.alignment = BoxContainer.ALIGNMENT_CENTER
		upgrade_row.add_theme_constant_override("separation", 14)
		var cost_lbl := Label.new()
		cost_lbl.text = "%d 🪙" % cost_gold
		cost_lbl.add_theme_font_size_override("font_size", 18)
		cost_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		upgrade_row.add_child(cost_lbl)
		var up_btn := UiComponents.make_primary_button("升级", func():
			_on_upgrade_pressed(card_id)
			_close_info_panel(), Vector2(150, 52))
		up_btn.disabled = not (PlayerData.gold >= cost_gold and own >= need)
		upgrade_row.add_child(up_btn)
		content.add_child(upgrade_row)

	# ---- 关闭 ----
	var close_btn := UiComponents.make_secondary_button("关闭", _close_info_panel, Vector2(0, 52))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(close_btn)

	add_child(info_panel)
	UiComponents.fade_in(info_panel)


## 小芯片（圆角 + 强调色描边），用于名片头的费用/类型/目标
## 用 PanelContainer：容器会按内容自动撑宽，文字居中，不会与相邻芯片重叠
func _make_chip(text: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = accent
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	return chip


func _close_info_panel():
	if info_panel:
		info_panel.queue_free()
		info_panel = null


func _get_card_config(card_id: int) -> CardData:
	for cfg in card_configs:
		if cfg.card_id == card_id:
			return cfg
	return null


func _on_upgrade_pressed(card_id: int):
	var old_lv := PlayerData.get_card_level(card_id)
	if PlayerData.upgrade_card(card_id):
		var new_lv := PlayerData.get_card_level(card_id)
		_refresh_ui()
		UiComponents.refresh_topbar()
		CLAIM_ANIM.play(self, "升级成功", "卡牌等级 Lv.%d → Lv.%d" % [old_lv, new_lv], {
			"kind": "card", "card_id": card_id, "card_name": "卡牌", "amount": 1,
		})


func _on_return_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
