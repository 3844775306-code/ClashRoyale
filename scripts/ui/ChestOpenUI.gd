extends Control

const CHEST_MODEL = preload("res://scripts/visuals/ChestModel.gd")
const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")

var index: int = -1
var chest: Dictionary = {}
var model
var star_labels: Array = []
var taps_lbl: Label
var action_btn: Button
var title_lbl: Label
var sub_lbl: Label
var viewport: SubViewport
var vpc: SubViewportContainer
var tap_overlay: Button
var currency_row: HBoxContainer
var opened: bool = false

func _ready():
	_apply_text_theme()
	UiComponents.add_background(self)
	currency_row = UiComponents.make_header(self, "开启幸运宝箱", _on_back, true)
	index = PlayerData.chest_open_index
	if index < 0 or index >= PlayerData.chests.size():
		if not PlayerData.chests.is_empty():
			index = PlayerData.chests.size() - 1
			PlayerData.chest_open_index = index
		else:
			get_tree().change_scene_to_file("res://scenes/chest_ui.tscn")
			return
	chest = PlayerData.prepare_chest_opening(index)
	_build_scene()
	_build_ui()
	_update_ui()
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
	th.set_color("font_color", "Button", Color(0.99, 0.98, 0.92))
	th.set_color("font_outline_color", "Button", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Button", 3)
	theme = th

func _build_scene():
	vpc = SubViewportContainer.new()
	vpc.position = Vector2(120, 110)
	vpc.size = Vector2(560, 500)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(vpc)
	viewport = SubViewport.new()
	viewport.size = Vector2i(560, 500)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	vpc.add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.7
	env.environment = e
	viewport.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.8, 4.6)
	if cam.is_inside_tree():
		cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
	cam.fov = 35.0
	viewport.add_child(cam)
	cam.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -36, 0)
	light.light_energy = 1.25
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.72, 1.0)
	viewport.add_child(fill)
	model = CHEST_MODEL.new()
	model.position = Vector3(0, 0, 0)
	viewport.add_child(model)
	_set_model_accent()

func _set_model_accent():
	if model == null:
		return
	var r: String = String(chest.get("rarity", "silver"))
	var c := Color(0.62, 0.76, 0.90)
	if r == "gold": c = Color(1.0, 0.78, 0.28)
	elif r == "magical": c = Color(0.72, 0.44, 1.0)
	elif r == "legendary": c = Color(1.0, 0.84, 0.36)
	model.set_accent(c)

func _build_ui():
	title_lbl = Label.new()
	title_lbl.text = "幸运宝箱"
	title_lbl.position = Vector2(0, 620)
	title_lbl.size = Vector2(800, 44)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	add_child(title_lbl)
	sub_lbl = Label.new()
	sub_lbl.position = Vector2(0, 664)
	sub_lbl.size = Vector2(800, 30)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color(0.76, 0.86, 0.98))
	add_child(sub_lbl)
	var stars := HBoxContainer.new()
	stars.position = Vector2(0, 704)
	stars.size = Vector2(800, 46)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 10)
	add_child(stars)
	star_labels.clear()
	for i in range(5):
		var s := Label.new()
		s.text = "★"
		s.add_theme_font_size_override("font_size", 40)
		s.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
		stars.add_child(s)
		star_labels.append(s)
	taps_lbl = Label.new()
	taps_lbl.position = Vector2(0, 760)
	taps_lbl.size = Vector2(800, 34)
	taps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	taps_lbl.add_theme_font_size_override("font_size", 17)
	taps_lbl.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	add_child(taps_lbl)
	action_btn = _grad_button("点击宝箱", Color(0.92, 0.70, 0.24), Vector2(420, 64))
	action_btn.position = Vector2(190, 820)
	action_btn.pressed.connect(_on_action)
	add_child(action_btn)
	# 点击 3D 宝箱同样计数
	tap_overlay = Button.new()
	tap_overlay.flat = true
	tap_overlay.position = Vector2(120, 110)
	tap_overlay.size = Vector2(560, 500)
	tap_overlay.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap_overlay.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap_overlay.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap_overlay.pressed.connect(_on_action)
	add_child(tap_overlay)

func _update_ui():
	var stars: int = int(chest.get("stars", 1))
	for i in range(star_labels.size()):
		star_labels[i].add_theme_color_override("font_color", Color(1.0, 0.78, 0.28) if i < stars else Color(0.22, 0.26, 0.34))
	var taps: int = int(chest.get("taps_left", 0))
	var total: int = int(chest.get("total_taps", 3))
	title_lbl.text = _chest_name(chest)
	sub_lbl.text = "宝箱等级 Lv.%d · 点击宝箱有机会升星" % int(chest.get("level", PlayerData.get_chest_level()))
	taps_lbl.text = "剩余点击 %d / %d" % [taps, total]
	if opened:
		action_btn.text = "已开启"
		action_btn.disabled = true
	elif taps <= 0:
		action_btn.text = "打开宝箱"
		action_btn.disabled = false
	else:
		action_btn.text = "点击宝箱"
		action_btn.disabled = false

func _chest_name(c) -> String:
	var r: String = String(c.get("rarity", "silver"))
	var s: int = int(c.get("stars", 1))
	if r == "magical": return "魔法幸运宝箱  " + "★".repeat(s)
	if r == "legendary": return "传奇幸运宝箱  " + "★".repeat(s)
	return "标准幸运宝箱  " + "★".repeat(s)

func _on_action():
	if opened:
		return
	var taps: int = int(chest.get("taps_left", 0))
	if taps <= 0:
		_open_chest()
		return
	var res: Dictionary = PlayerData.tap_chest(index)
	if res.is_empty():
		return
	chest = PlayerData.chests[index] if index < PlayerData.chests.size() else chest
	model.shake(0.10)
	if bool(res.get("upgraded", false)):
		_float_star()
	_update_ui()

func _float_star():
	var lbl := Label.new()
	lbl.text = "+1★"
	lbl.position = Vector2(340, 360)
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", 300, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(func(): lbl.queue_free())

func _open_chest():
	opened = true
	action_btn.disabled = true
	model.open_lid()
	await get_tree().create_timer(0.65).timeout
	var rewards: Dictionary = PlayerData.finish_chest_opening(index)
	if currency_row:
		UiComponents.refresh_currency_row(currency_row)
	_show_rewards(rewards)

func _show_rewards(rewards: Dictionary):
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 900
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.78)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -360
	panel.offset_bottom = 360
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.98)
	sb.border_color = Color(1.0, 0.78, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_right = -20
	vb.offset_top = 18
	vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "✨ 开箱结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 24
	scroll.follow_focus = true
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var delay := 0.0
	var items: Array = []
	if int(rewards.get("gold", 0)) > 0:
		items.append(["gold", int(rewards.gold), "", 0])
	if int(rewards.get("gems", 0)) > 0:
		items.append(["gems", int(rewards.gems), "", 0])
	var cards: Dictionary = rewards.get("cards", {})
	for cid in cards.keys():
		items.append(["card", int(cards[cid]), _card_name(int(cid)), int(cid)])
	for item in items:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(136, 158)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.08, 0.11, 0.18, 0.95)
		bs.border_color = Color(0.38, 0.42, 0.52)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(12)
		box.add_theme_stylebox_override("panel", bs)
		grid.add_child(box)
		var ic = REWARD_ICON.new()
		ic.position = Vector2(18, 10)
		ic.size = Vector2(100, 120)
		ic.setup(String(item[0]), int(item[1]), String(item[2]), int(item[3]))
		box.add_child(ic)
		var nm := Label.new()
		nm.text = "×%d" % int(item[1])
		nm.position = Vector2(0, 130)
		nm.size = Vector2(136, 22)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
		box.add_child(nm)
		if String(item[0]) == "card" and PlayerData.is_new_card(int(item[3])):
			var nb := Label.new()
			nb.text = "新"
			nb.position = Vector2(6, 6)
			nb.size = Vector2(34, 26)
			nb.add_theme_font_size_override("font_size", 18)
			nb.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
			nb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			nb.add_theme_constant_override("shadow_offset_x", 1)
			nb.add_theme_constant_override("shadow_offset_y", 1)
			box.add_child(nb)
		box.scale = Vector2(0.2, 0.2)
		box.pivot_offset = Vector2(68, 79)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.07
	var ok := _grad_button("收下奖励", Color(0.92, 0.70, 0.24), Vector2(0, 56))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		PlayerData.chest_open_index = -1
		get_tree().change_scene_to_file("res://scenes/chest_ui.tscn")
	)
	vb.add_child(ok)

func _card_name(cid: int) -> String:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not bm:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	var cfg = bm.get_config(cid)
	return cfg.card_name if cfg else "卡牌"

func _grad_button(text: String, color: Color, size_px: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size_px
	b.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.30)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.35)
	sb.shadow_size = 6
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = color.darkened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = color.darkened(0.40)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	b.add_theme_constant_override("outline_size", 3)
	return b

func _on_back():
	PlayerData.chest_open_index = -1
	get_tree().change_scene_to_file("res://scenes/chest_ui.tscn")
