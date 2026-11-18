# scripts/ui/ChestUI.gd
# 宝箱界面：当前宝箱聚焦 + 宝箱队列 + 官方幸运宝箱星级/开启次数
extends Control

const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")

var currency_row: HBoxContainer
var content_vbox: VBoxContainer
var _style_cache: Dictionary = {}

func _ready():
	_apply_text_theme()
	UiComponents.add_background(self)
	currency_row = UiComponents.make_header(self, "我的宝箱", _on_return_pressed, true)
	var scroll := UiComponents.make_content_scroll(self)
	content_vbox = UiComponents.make_content_vbox()
	scroll.add_child(content_vbox)
	_refresh()
	UiComponents.fade_in(self)

func _apply_text_theme():
	var th := Theme.new()
	var f := load("res://assets/fonts/STZHONGS.TTF")
	if f:
		var fv := FontVariation.new()
		fv.base_font = f
	ThemeHelper.apply_emoji_fallback(fv)
		fv.variation_embolden = 0.7
		th.default_font = fv
	th.default_font_size = 15
	th.set_color("font_color", "Label", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Label", Color(0.04, 0.06, 0.10))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Button", Color(0.99, 0.98, 0.92))
	th.set_color("font_outline_color", "Button", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Button", 3)
	theme = th

func _refresh():
	for child in content_vbox.get_children():
		child.queue_free()
	if PlayerData.chests.is_empty():
		_build_empty_state()
		return
	# 当前宝箱聚焦
	content_vbox.add_child(_hero_chest(PlayerData.chests[0]))
	# 队列
	var rest: int = PlayerData.chests.size() - 1
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = "📦 宝箱队列"
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(0.66, 0.84, 1.0))
	head.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var n := Label.new()
	n.text = "共 %d 个" % PlayerData.chests.size()
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90))
	head.add_child(n)
	content_vbox.add_child(head)
	if rest <= 0:
		var none := Label.new()
		none.text = "暂无其它宝箱，去商店补充幸运宝箱吧"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
		content_vbox.add_child(none)
		return
	for i in range(1, PlayerData.chests.size()):
		content_vbox.add_child(_queue_row(i))

func _hero_chest(chest: Dictionary) -> Panel:
	var accent: Color = _chest_accent(chest)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 356)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.10, 0.17, 0.98)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.40)
	sb.shadow_size = 12
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 22
	vb.offset_top = 16
	vb.offset_right = -22
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var tag := Label.new()
	tag.text = "当前幸运宝箱"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	vb.add_child(tag)
	var glow := Panel.new()
	glow.custom_minimum_size = Vector2(0, 128)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.85)
	gsb.set_corner_radius_all(18)
	gsb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	gsb.set_border_width_all(2)
	glow.add_theme_stylebox_override("panel", gsb)
	vb.add_child(glow)
	var icon = REWARD_ICON.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 90
	icon.offset_right = -90
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.setup("chest", 1)
	glow.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = _chest_name(chest)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", accent.lightened(0.25))
	vb.add_child(name_lbl)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 5)
	vb.add_child(stars)
	var s: int = int(chest.get("stars", 1))
	for i in range(5):
		var st := Label.new()
		st.text = "★"
		st.add_theme_font_size_override("font_size", 22)
		st.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28) if i < s else Color(0.24, 0.28, 0.36))
		stars.add_child(st)
	var lv := Label.new()
	lv.text = "宝箱等级 Lv.%d · 剩余开启 %d 次" % [int(chest.get("level", PlayerData.get_chest_level())), int(chest.get("taps_left", 1))]
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_theme_font_size_override("font_size", 15)
	lv.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
	vb.add_child(lv)
	var btn := _grad_button("开启宝箱", accent, Vector2(0, 58))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _enter_chest_open(0))
	vb.add_child(btn)
	UiComponents.pulse(glow)
	return p

func _queue_row(idx: int) -> Panel:
	var chest: Dictionary = PlayerData.chests[idx]
	var accent: Color = _chest_accent(chest)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 116)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.085, 0.13, 0.96)
	sb.border_color = accent.darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 12
	hb.offset_right = -12
	hb.offset_top = 8
	hb.offset_bottom = -8
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var icon_box := Panel.new()
	icon_box.custom_minimum_size = Vector2(90, 0)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(accent.r * 0.20, accent.g * 0.20, accent.b * 0.20, 0.9)
	isb.set_corner_radius_all(12)
	icon_box.add_theme_stylebox_override("panel", isb)
	hb.add_child(icon_box)
	var icon = REWARD_ICON.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_right = -10
	icon.offset_top = 8
	icon.offset_bottom = -8
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.setup("chest", 1)
	icon_box.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)
	var nm := Label.new()
	nm.text = _chest_name(chest)
	nm.add_theme_font_size_override("font_size", 17)
	nm.add_theme_color_override("font_color", accent.lightened(0.25))
	vb.add_child(nm)
	var meta := Label.new()
	meta.text = "Lv.%d · 剩余 %d 次" % [int(chest.get("level", PlayerData.get_chest_level())), int(chest.get("taps_left", 1))]
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color(0.70, 0.78, 0.88))
	vb.add_child(meta)
	var btn := _grad_button("开启", accent, Vector2(104, 52))
	btn.pressed.connect(func(): _enter_chest_open(idx))
	hb.add_child(btn)
	return p

func _chest_accent(chest: Dictionary) -> Color:
	var r: String = String(chest.get("rarity", "silver")).to_lower()
	if r == "magical": return Color(0.72, 0.42, 0.98)
	if r == "gold": return Color(0.96, 0.72, 0.24)
	if r == "legendary": return Color(1.0, 0.82, 0.34)
	return Color(0.62, 0.76, 0.90)

func _chest_name(chest) -> String:
	var rarity: String = String(chest.get("rarity", "silver")).to_lower()
	var stars: int = int(chest.get("stars", 1))
	var star_txt: String = "★".repeat(clampi(stars, 1, 5))
	match rarity:
		"silver", "gold":
			return "标准幸运宝箱 " + star_txt
		"magical":
			return "魔法幸运宝箱 " + star_txt
		"legendary":
			return "传奇幸运宝箱 " + star_txt
	return "幸运宝箱 " + star_txt

func _build_empty_state():
	var empty := UiComponents.make_empty_state("📦", "暂无宝箱", "去商店购买幸运宝箱，或通过皇室征程获得")
	empty.custom_minimum_size = Vector2(0, 700)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.add_child(_grad_button("去商店购买", Color(0.90, 0.68, 0.24), Vector2(240, 58), func(): get_tree().change_scene_to_file("res://scenes/shop_ui.tscn")))
	empty.add_child(btn_row)
	content_vbox.add_child(empty)

func _enter_chest_open(idx: int):
	PlayerData.chest_open_index = idx
	get_tree().change_scene_to_file("res://scenes/chest_open.tscn")

func _on_open_chest(idx: int):
	var rewards = PlayerData.open_chest(idx)
	if rewards.is_empty():
		return
	_show_reward_popup(rewards)
	_refresh()

func _show_reward_popup(rewards: Dictionary):
	var overlay := UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -310
	panel.offset_bottom = 310
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 20
	vbox.offset_right = -24
	vbox.offset_bottom = -20
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 9)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "🎁 幸运宝箱奖励"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	vbox.add_child(title)
	if int(rewards.get("taps_left", 0)) > 0:
		var left := Label.new()
		left.text = "还可继续开启 %d 次" % int(rewards.taps_left)
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_theme_font_size_override("font_size", 14)
		left.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
		vbox.add_child(left)
	var rscroll := ScrollContainer.new()
	rscroll.custom_minimum_size = Vector2(0, 360)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(rscroll)
	var reward_rows := VBoxContainer.new()
	reward_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_rows.add_theme_constant_override("separation", 6)
	rscroll.add_child(reward_rows)
	if int(rewards.get("gold", 0)) > 0:
		reward_rows.add_child(_reward_line("gold", "金币", int(rewards.gold), 0))
	if int(rewards.get("gems", 0)) > 0:
		reward_rows.add_child(_reward_line("gems", "宝石", int(rewards.gems), 0))
	if not rewards.get("cards", {}).is_empty():
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if not bm:
			bm = load("res://scripts/core/BattleManager.gd").new()
			bm.load_card_configs()
		for cid in rewards.cards:
			var cfg = bm.get_config(cid)
			var nm: String = cfg.card_name if cfg else "未知卡牌"
			reward_rows.add_child(_reward_line("card", nm, int(rewards.cards[cid]), cid))
	var ok_btn := _grad_button("收下", ThemeHelper.COLORS.gold, Vector2(230, 56))
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(func(): panel.queue_free(); overlay.queue_free())
	vbox.add_child(ok_btn)
	UiComponents.fade_in(panel)

func _reward_line(kind: String, name: String, amount: int, card_id: int = 0) -> Panel:
	var color: Color = Color(0.96, 0.72, 0.24)
	if kind == "gems": color = Color(0.28, 0.82, 0.98)
	elif kind == "card": color = Color(0.70, 0.54, 1.0)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.95)
	sb.border_color = color.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -12
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	var icon = REWARD_ICON.new()
	icon.custom_minimum_size = Vector2(46, 56)
	icon.setup(kind, amount, name, card_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)
	var nl := Label.new()
	nl.text = name
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.add_theme_font_size_override("font_size", 16)
	nl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	hb.add_child(nl)
	var al := Label.new()
	al.text = "+%d" % amount if kind != "card" else "×%d" % amount
	al.add_theme_font_size_override("font_size", 17)
	al.add_theme_color_override("font_color", color)
	hb.add_child(al)
	return p

func _grad_button(text: String, color: Color, size_px: Vector2, action: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size_px
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _gradient_style(color, "normal"))
	b.add_theme_stylebox_override("hover", _gradient_style(color, "hover"))
	b.add_theme_stylebox_override("pressed", _gradient_style(color, "pressed"))
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	b.add_theme_constant_override("outline_size", 3)
	if action.is_valid():
		b.pressed.connect(action)
	return b

func _gradient_style(color: Color, state: String) -> StyleBoxTexture:
	var key: String = color.to_html() + state
	if _style_cache.has(key):
		return _style_cache[key]
	var c: Color = color
	if state == "hover": c = color.lightened(0.12)
	elif state == "pressed": c = color.darkened(0.16)
	var n: int = 48
	var r: int = 14
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(n):
		var ty: float = float(y) / float(n - 1)
		for x in range(n):
			var inside: bool = true
			if x < r and y < r:
				inside = Vector2(r - x, r - y).length() <= float(r)
			elif x >= n - r and y < r:
				inside = Vector2(x - (n - r - 1), r - y).length() <= float(r)
			elif x < r and y >= n - r:
				inside = Vector2(r - x, y - (n - r - 1)).length() <= float(r)
			elif x >= n - r and y >= n - r:
				inside = Vector2(x - (n - r - 1), y - (n - r - 1)).length() <= float(r)
			if not inside:
				continue
			var col: Color = c.lightened(0.32 * (1.0 - ty)).darkened(0.34 * ty)
			if x < 2 or x >= n - 2 or y < 2 or y >= n - 2:
				col = col.lightened(0.22)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = r
	sb.texture_margin_right = r
	sb.texture_margin_top = r
	sb.texture_margin_bottom = r
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_style_cache[key] = sb
	return sb

func _on_return_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
