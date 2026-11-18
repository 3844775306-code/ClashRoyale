# assets/ui/UiComponents.gd
# 界面组件库（自动加载）：统一构建各界面共享的结构与视觉元素。
#
# 职责：
#   1. 屏幕骨架：深色氛围背景、顶部横幅（返回 + 标题 + 货币筹码）、内容滚动区
#   2. 视觉构件：货币筹码、分节标题、带强调色的卡片、列表行、空状态
#   3. 按钮工厂：主按钮（金）/ 危险按钮（红）/ 次要按钮
#   4. 轻量动效：淡入、悬停放大、呼吸脉冲
#
# 配合 ThemeHelper 使用：颜色与字体一律取 ThemeHelper 常量，不散落魔法数字。
extends Node

const HEADER_H := 72          # 统一顶部栏下方内容起始高度
const TOPBAR_H := 64          # 统一顶部栏高度
const SIDE_MARGIN := 24       # 左右留白


# ==================== 屏幕骨架 ====================

## 统一背景：与主菜单同款夜空 + 光晕 + 金尘 + 暗角（不含竞技场地板）
func add_background(owner: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.016, 0.024, 0.055, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(bg)
	var backdrop = preload("res://assets/ui/menu/MenuBackdrop.gd").new()
	backdrop.with_floor = false
	backdrop.name = "MenuBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(backdrop)
	return bg


## 程序化线描图标
func _ui_icon(kind: String, px: float, tint: Color) -> Control:
	var ic = preload("res://assets/ui/menu/MenuIcon.gd").new()
	ic.kind = kind
	ic.tint = tint
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	return ic


func _display_font():
	var f = load(ThemeHelper.DEFAULT_FONT_PATH)
	return f if f != null else null


## 统一顶部栏：返回(可选) + 玩家名(可点击改名) + 居中标题 + 货币 + 设置
## 返回货币筹码行（供 refresh_currency_row 使用；show_currency=false 时返回 null）
func make_header(owner: Control, title: String, back_action: Callable = Callable(),
		show_currency: bool = true) -> HBoxContainer:
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.030, 0.048, 0.095, 0.94)
	sb.border_color = Color(0.945, 0.765, 0.36, 0.30)
	sb.border_width_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = TOPBAR_H
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_to_group("topbar")
	owner.add_child(bar)

	var x := 12.0
	if back_action.is_valid():
		var back := Button.new()
		back.focus_mode = Control.FOCUS_NONE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.05, 0.08, 0.16, 0.9)
		bsb.set_corner_radius_all(18)
		bsb.set_border_width_all(1)
		bsb.border_color = Color(1, 1, 1, 0.18)
		back.add_theme_stylebox_override("normal", bsb)
		var bsb_h = bsb.duplicate()
		bsb_h.border_color = Color(0.945, 0.765, 0.36, 0.55)
		back.add_theme_stylebox_override("hover", bsb_h)
		back.add_theme_stylebox_override("pressed", bsb)
		back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		back.offset_left = x
		back.offset_top = 14
		back.offset_right = x + 36
		back.offset_bottom = 50
		back.pressed.connect(back_action)
		bar.add_child(back)
		var bi = _ui_icon("back", 20.0, Color(0.86, 0.88, 0.93))
		bi.position = Vector2(8, 8)
		back.add_child(bi)
		x += 50.0

	# 玩家名（点击改名）
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	var cflat := StyleBoxFlat.new()
	cflat.bg_color = Color(0, 0, 0, 0)
	cflat.set_corner_radius_all(20)
	var chover := StyleBoxFlat.new()
	chover.bg_color = Color(1, 1, 1, 0.06)
	chover.set_corner_radius_all(20)
	chover.set_border_width_all(1)
	chover.border_color = Color(0.945, 0.765, 0.36, 0.25)
	chip.add_theme_stylebox_override("normal", cflat)
	chip.add_theme_stylebox_override("hover", chover)
	chip.add_theme_stylebox_override("pressed", chover)
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip.offset_left = x
	chip.offset_top = 10
	chip.offset_right = x + 196
	chip.offset_bottom = 54
	chip.pressed.connect(func(): _open_name_dialog(owner))
	bar.add_child(chip)

	var avatar := Panel.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.08, 0.12, 0.24, 1.0)
	asb.set_corner_radius_all(17)
	asb.set_border_width_all(2)
	asb.border_color = Color(0.945, 0.765, 0.36, 0.9)
	avatar.add_theme_stylebox_override("panel", asb)
	avatar.position = Vector2(4, 7)
	avatar.size = Vector2(34, 34)
	chip.add_child(avatar)
	var crown = _ui_icon("crown", 22.0, ThemeHelper.COLORS.gold)
	crown.position = Vector2(6, 6)
	avatar.add_child(crown)

	var name_lbl := Label.new()
	name_lbl.text = PlayerData.player_name
	name_lbl.add_to_group("topbar_name")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.position = Vector2(46, 3)
	name_lbl.size = Vector2(136, 20)
	name_lbl.clip_text = true
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.93, 0.90, 0.80))
	var f = _display_font()
	if f != null:
		name_lbl.add_theme_font_override("font", f)
	chip.add_child(name_lbl)

	var tr_ic = _ui_icon("trophy", 14.0, ThemeHelper.COLORS.gold)
	tr_ic.position = Vector2(46, 22)
	chip.add_child(tr_ic)
	var tr_lbl := Label.new()
	tr_lbl.text = str(PlayerData.trophies)
	tr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_lbl.position = Vector2(63, 19)
	tr_lbl.size = Vector2(120, 16)
	tr_lbl.add_theme_font_size_override("font_size", 12)
	tr_lbl.add_theme_color_override("font_color", Color(0.945, 0.765, 0.36, 0.9))
	chip.add_child(tr_lbl)

	if title != "":
		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.anchor_left = 0.0
		title_lbl.anchor_right = 1.0
		title_lbl.offset_top = 0
		title_lbl.offset_bottom = TOPBAR_H
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.add_theme_font_size_override("font_size", 22)
		title_lbl.add_theme_color_override("font_color", Color(0.945, 0.765, 0.36))
		title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		title_lbl.add_theme_constant_override("shadow_offset_x", 1)
		title_lbl.add_theme_constant_override("shadow_offset_y", 2)
		if f != null:
			title_lbl.add_theme_font_override("font", f)
		bar.add_child(title_lbl)

	if not show_currency:
		return null
	var currency := make_currency_row()
	currency.add_to_group("topbar_currency")
	currency.anchor_left = 1.0
	currency.anchor_right = 1.0
	currency.offset_left = -236.0
	currency.offset_right = -60.0
	currency.offset_top = 15
	currency.offset_bottom = 49
	currency.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(currency)

	var gear := Button.new()
	gear.focus_mode = Control.FOCUS_NONE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.05, 0.08, 0.16, 0.9)
	gsb.set_corner_radius_all(17)
	gsb.set_border_width_all(1)
	gsb.border_color = Color(1, 1, 1, 0.18)
	gear.add_theme_stylebox_override("normal", gsb)
	var gsb_h = gsb.duplicate()
	gsb_h.border_color = Color(0.945, 0.765, 0.36, 0.55)
	gear.add_theme_stylebox_override("hover", gsb_h)
	gear.add_theme_stylebox_override("pressed", gsb)
	gear.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -50
	gear.offset_right = -14
	gear.offset_top = 15
	gear.offset_bottom = 49
	gear.tooltip_text = "设置"
	gear.pressed.connect(func(): _open_settings(owner))
	bar.add_child(gear)
	var gi = _ui_icon("gear", 20.0, Color(0.86, 0.88, 0.93))
	gi.position = Vector2(8, 7)
	gear.add_child(gi)
	return currency


func refresh_topbar_currency() -> void:
	for row in get_tree().get_nodes_in_group("topbar_currency"):
		refresh_currency_row(row)


func refresh_topbar_name() -> void:
	for lbl in get_tree().get_nodes_in_group("topbar_name"):
		if is_instance_valid(lbl) and lbl is Label:
			lbl.text = PlayerData.player_name


func refresh_topbar() -> void:
	refresh_topbar_name()
	refresh_topbar_currency()


func _open_name_dialog(host: Control) -> void:
	prompt_player_name(host)


func prompt_player_name(host: Node) -> void:
	if host == null:
		return
	var scene := host.get_tree().current_scene
	if scene == null:
		return
	for c in scene.get_children():
		if c.is_in_group("name_dialog"):
			return
	var dlg = (load("res://assets/ui/NameDialog.gd") as GDScript).new()
	if dlg != null:
		scene.add_child(dlg)


func _open_settings(host: Control) -> void:
	var scene := host.get_tree().current_scene
	if scene == null:
		return
	for c in scene.get_children():
		if c.is_in_group("settings_menu"):
			return
	var ps := "res://scenes/settings_menu.tscn"
	if ResourceLoader.exists(ps):
		var sm = load(ps).instantiate()
		scene.add_child(sm)


func ensure_player_name(host: Node) -> void:
	if OS.has_environment("CR_SKIP_NAME_PROMPT"):
		return
	if PlayerData.name_chosen and PlayerData.player_name.strip_edges() != "":
		return
	prompt_player_name(host)


## 内容滚动区（横幅下方开始）
func make_content_scroll(owner: Control, top: int = HEADER_H + 16) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.anchor_left = 0.0
	sc.anchor_right = 1.0
	sc.anchor_top = 0.0
	sc.anchor_bottom = 1.0
	sc.offset_top = top
	sc.scroll_deadzone = 12
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	owner.add_child(sc)
	return sc


## 内容竖向容器（给 ScrollContainer 用，撑满宽度）
func make_content_vbox() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	return vbox


# ==================== 视觉构件 ====================

## 分节标题（金色小标题）
func make_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


## 货币筹码行（金币 + 宝石），实时刷新用 refresh_currency_row
func make_currency_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_chip("coin", str(PlayerData.gold), ThemeHelper.COLORS.gold))
	row.add_child(_make_chip("gem", str(PlayerData.gems), Color(0.55, 0.8, 1.0)))
	return row


## 刷新货币筹码行文本
func refresh_currency_row(row: HBoxContainer):
	if row == null:
		return
	var kids := row.get_children()
	if kids.size() >= 1 and kids[0] is PanelContainer:
		_set_chip_amount(kids[0], str(PlayerData.gold))
	if kids.size() >= 2 and kids[1] is PanelContainer:
		_set_chip_amount(kids[1], str(PlayerData.gems))


func _set_chip_amount(chip: PanelContainer, amount: String):
	var hbox := chip.get_child(0) as HBoxContainer
	if hbox and hbox.get_child_count() >= 2:
		(hbox.get_child(1) as Label).text = amount


func _make_chip(kind: String, amount: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.042, 0.085, 0.88)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	var icon_ctl = _ui_icon(kind, 18.0, accent.darkened(0.05))
	icon_ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_ctl)
	var amt_lbl := Label.new()
	amt_lbl.text = amount
	amt_lbl.add_theme_font_size_override("font_size", 14)
	amt_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(amt_lbl)
	chip.add_child(hbox)
	return chip


## 带顶部强调色描边的卡片面板（title/subtitle 可选，返回 Panel 供继续加子节点）
func make_card(accent: Color, title: String = "", subtitle: String = "") -> Panel:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _card_style(accent))
	if title != "":
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 16
		vbox.offset_top = 12
		vbox.offset_right = -16
		vbox.offset_bottom = -12
		vbox.add_theme_constant_override("separation", 4)
		var t := Label.new()
		t.text = title
		t.add_theme_font_size_override("font_size", 20)
		t.add_theme_color_override("font_color", accent)
		vbox.add_child(t)
		if subtitle != "":
			var s := Label.new()
			s.text = subtitle
			s.add_theme_font_size_override("font_size", 13)
			s.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(s)
		card.add_child(vbox)
	return card


## 列表行（左侧 3px 强调色描边）
func make_list_row(accent: Color = Color.TRANSPARENT, height: int = 64) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeHelper.COLORS.row_bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.set_border_width_all(1)
	if accent.a > 0:
		# 强调色描边：左侧加粗，其余 1px
		sb.border_width_left = 3
		sb.border_color = accent
	else:
		sb.border_color = Color(1, 1, 1, 0.08)
	row.add_theme_stylebox_override("panel", sb)
	return row


func _card_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeHelper.COLORS.card_bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	# Godot 4 的 StyleBoxFlat 只有统一边框色：用强调色描边（顶部 3px，其余 1px）
	sb.set_border_width_all(1)
	sb.border_width_top = 3
	sb.border_color = accent
	sb.shadow_color = ThemeHelper.COLORS.shadow
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


## 空状态（居中大图标 + 标题 + 副标题），返回 VBox 供追加按钮
func make_empty_state(icon: String, title: String, subtitle: String = "") -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 64)
	vbox.add_child(icon_lbl)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	vbox.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 15)
		s.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		vbox.add_child(s)
	return vbox


## 居中大 emoji 图标（卡牌名片 / 空状态图标复用）
func make_emoji_icon(emoji: String, font_size: int = 56) -> Label:
	var lbl := Label.new()
	lbl.text = emoji
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## 属性行（图标 + 键名 + 金色数值），用于卡牌详情
func make_stat_row(icon: String, key: String, value: String,
		value_color: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.custom_minimum_size = Vector2(30, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 15)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_lbl)
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	row.add_child(key_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", value_color)
	row.add_child(val_lbl)
	return row


## 等级徽章（小圆角面板 + 文字）
func make_badge(text: String) -> Panel:
	var badge := Panel.new()
	ThemeHelper.apply_badge_style(badge)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge


# ==================== 按钮工厂 ====================

func make_primary_button(text: String, action: Callable = Callable(),
		min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_primary_button(btn)
	if action.is_valid():
		btn.pressed.connect(action)
	return btn


func make_danger_button(text: String, action: Callable = Callable(),
		min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_danger_button(btn)
	if action.is_valid():
		btn.pressed.connect(action)
	return btn


func make_secondary_button(text: String, action: Callable = Callable(),
		min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_muted_button(btn)
	if action.is_valid():
		btn.pressed.connect(action)
	return btn


# ==================== 轻量动效 ====================

func fade_in(node: CanvasItem, dur: float = 0.3):
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 悬停放大反馈（按钮/卡片）
func hover_scale(node: Control, scale := 1.04):
	node.mouse_entered.connect(func():
		node.pivot_offset = node.size * 0.5
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector2.ONE * scale, 0.12))
	node.mouse_exited.connect(func():
		node.pivot_offset = node.size * 0.5
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector2.ONE, 0.12))


## 呼吸脉冲（可开启宝箱等醒目元素）
func pulse(node: Control):
	# 布局完成后才更新 pivot，避免刚加入树时 size 为 0
	var tw := node.create_tween().set_loops()
	tw.tween_callback(func(): node.pivot_offset = node.size * 0.5)
	tw.tween_property(node, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 全屏暗色遮罩（模态弹窗底层）
func make_overlay(owner: Control, color := Color(0, 0, 0, 0.6)) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(bg)
	return bg
