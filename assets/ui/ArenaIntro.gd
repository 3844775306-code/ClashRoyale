# assets/ui/ArenaIntro.gd
# 进入新竞技场的入场动画：暗场 + 旋转金色辉光 + 竞技场徽章 + 名称揭晓 + 星尘粒子
extends Control

signal finished

const GOLD := Color(0.96, 0.78, 0.38)
const GOLD_LIGHT := Color(1.0, 0.94, 0.74)
const INK := Color(0.012, 0.020, 0.055)
const MUTED := Color(0.67, 0.73, 0.86)
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const BATTLEFIELD := preload("res://scenes/Battlefield.gd")

var arena_idx: int = 1
var arena_name: String = ""
var _font: Font
var _t := 0.0
var _done := false
var _content: Control
var _badge: Panel
var _dim: ColorRect
var _particles: Array = []
var _unlock_row: Control = null


func setup(idx: int, name: String) -> void:
	arena_idx = idx
	arena_name = name


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.40)
	for i in range(40):
		_particles.append({
			"a": randf() * TAU,
			"r": randf_range(120.0, 420.0),
			"sp": randf_range(0.18, 0.55),
			"sz": randf_range(1.5, 4.5),
			"ph": randf() * TAU,
		})
	_build(vp, center)
	_play()


func _build(vp: Vector2, center: Vector2) -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.005, 0.008, 0.025, 1.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.z_index = -10
	add_child(_dim)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.z_index = 10
	add_child(_content)

	# 皇室征程竞技场模型
	var arena_frame := Panel.new()
	arena_frame.position = Vector2(40, vp.y * 0.045)
	arena_frame.size = Vector2(vp.x - 80, vp.y * 0.205)
	var afsb := StyleBoxFlat.new()
	afsb.bg_color = Color(0.015, 0.022, 0.055, 0.92)
	afsb.set_corner_radius_all(18)
	afsb.set_border_width_all(2)
	afsb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	arena_frame.add_theme_stylebox_override("panel", afsb)
	arena_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(arena_frame)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.offset_left = 8
	svc.offset_right = -8
	svc.offset_top = 8
	svc.offset_bottom = -8
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_frame.add_child(svc)
	var av := SubViewport.new()
	av.size = Vector2i(680, 300)
	av.transparent_bg = false
	av.own_world_3d = true
	av.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(av)
	var arena = BATTLEFIELD.new()
	arena.forced_arena = arena_idx
	av.add_child(arena)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.10, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.80, 0.92)
	env.ambient_light_energy = 0.85
	we.environment = env
	av.add_child(we)
	var acam := Camera3D.new()
	acam.projection = Camera3D.PROJECTION_ORTHOGONAL
	acam.size = 36.5
	acam.position = Vector3(0, 30, 18)
	acam.look_at(Vector3(0, 0, 0), Vector3.UP)
	acam.current = true
	av.add_child(acam)
	var alight := DirectionalLight3D.new()
	alight.rotation_degrees = Vector3(-48, -35, 0)
	alight.light_energy = 1.1
	av.add_child(alight)

	# 中央徽章
	_badge = Panel.new()
	_badge.size = Vector2(180, 180)
	_badge.position = Vector2(vp.x * 0.5 - 90, vp.y * 0.245)
	_badge.pivot_offset = _badge.size * 0.5
	_badge.scale = Vector2(0.15, 0.15)
	_badge.modulate.a = 0.0
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.045, 0.060, 0.120, 0.96)
	bs.set_corner_radius_all(90)
	bs.set_border_width_all(3)
	bs.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95)
	bs.shadow_color = Color(1.0, 0.75, 0.24, 0.30)
	bs.shadow_size = 24
	_badge.add_theme_stylebox_override("panel", bs)
	_content.add_child(_badge)
	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 12
	inner.offset_top = 12
	inner.offset_right = -12
	inner.offset_bottom = -12
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.10, 0.075, 0.025, 0.90)
	isb.set_corner_radius_all(80)
	isb.set_border_width_all(1)
	isb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	inner.add_theme_stylebox_override("panel", isb)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(inner)
	var ic = ICON.new()
	ic.kind = "crown"
	ic.tint = GOLD_LIGHT
	ic.custom_minimum_size = Vector2(94, 94)
	ic.size = Vector2(94, 94)
	ic.position = Vector2(43, 48)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(ic)
	var num := _label(str(arena_idx), 20, Color(0.15, 0.10, 0.03), true)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.position = Vector2(0, 130)
	num.size = Vector2(180, 28)
	num.add_theme_constant_override("outline_size", 0)
	num.add_theme_color_override("font_color", GOLD_LIGHT)
	_badge.add_child(num)

	var eyebrow := _label("NEW ARENA", 16, GOLD, true)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(0, vp.y * 0.345)
	eyebrow.size = Vector2(vp.x, 30)
	eyebrow.modulate.a = 0.0
	eyebrow.name = "Eyebrow"
	_content.add_child(eyebrow)

	var title := _label(arena_name, 40, GOLD_LIGHT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(30, vp.y * 0.385)
	title.size = Vector2(vp.x - 60, 64)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.modulate.a = 0.0
	title.name = "ArenaName"
	_content.add_child(title)

	var index_lbl := _label("竞技场 %d" % arena_idx, 19, Color(0.78, 0.68, 0.42))
	index_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_lbl.position = Vector2(0, vp.y * 0.435)
	index_lbl.size = Vector2(vp.x, 30)
	index_lbl.modulate.a = 0.0
	index_lbl.name = "ArenaIndex"
	_content.add_child(index_lbl)

	var unlocked := PlayerData.get_cards_unlocked_at(arena_idx).size()
	var reward_text := "新卡牌已解锁 · %d 张" % unlocked if unlocked > 0 else "新的战场已开启"
	var reward := _label(reward_text, 15, Color(0.72, 0.78, 0.90))
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.position = Vector2(0, vp.y * 0.485)
	reward.size = Vector2(vp.x, 28)
	reward.modulate.a = 0.0
	reward.name = "Reward"
	_content.add_child(reward)

	_build_unlock_cards(vp)

	var hint := _label("点击任意处跳过", 12, Color(0.55, 0.62, 0.76))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, vp.y - 170)
	hint.size = Vector2(vp.x, 24)
	hint.modulate.a = 0.0
	hint.name = "Hint"
	_content.add_child(hint)


func _build_unlock_cards(vp: Vector2) -> void:
	var ids: Array = PlayerData.get_cards_unlocked_at(arena_idx)
	if ids.is_empty():
		return
	var bm = load("res://scripts/core/BattleManager.gd").new()
	bm.load_card_configs()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, vp.y * 0.505)
	scroll.size = Vector2(vp.x - 60, vp.y * 0.30)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.modulate.a = 0.0
	_content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_unlock_row = scroll
	for cid in ids:
		var cfg = bm.get_config(int(cid))
		if cfg == null:
			continue
		grid.add_child(_unlock_card_tile(String(cfg.card_name)))
	bm.free()


func _unlock_card_tile(card_name: String) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(112, 154)
	card.size = Vector2(112, 154)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.062, 0.120, 0.96)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.945, 0.765, 0.360, 0.65)
	card.add_theme_stylebox_override("panel", sb)
	var img := TextureRect.new()
	img.position = Vector2(5, 5)
	img.size = Vector2(102, 118)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/cards_web/%s.png" % card_name
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % card_name
	if ResourceLoader.exists(path):
		img.texture = load(path)
	card.add_child(img)
	var nl := _label(card_name, 10, Color(0.94, 0.91, 0.82))
	nl.position = Vector2(2, 128)
	nl.size = Vector2(108, 22)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	card.add_child(nl)
	return card


func _play() -> void:
	var vp := get_viewport_rect().size
	var dim_tw := create_tween()
	dim_tw.tween_property(_dim, "modulate:a", 0.94, 0.35)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_badge, "scale", Vector2.ONE, 0.75).set_delay(0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_badge, "modulate:a", 1.0, 0.30).set_delay(0.18)
	for n in ["Eyebrow", "ArenaName", "ArenaIndex", "Reward"]:
		var node := _content.get_node_or_null(n) as Control
		if node == null:
			continue
		var delay: float = 0.45 + (0.10 if n == "ArenaName" else (0.18 if n == "ArenaIndex" else (0.26 if n == "Reward" else 0.0)))
		tw.tween_property(node, "modulate:a", 1.0, 0.35).set_delay(delay)
		tw.tween_property(node, "position:y", node.position.y, 0.35).set_delay(delay).from(node.position.y + 14)
	if _unlock_row:
		tw.tween_property(_unlock_row, "modulate:a", 1.0, 0.35).set_delay(0.95)
		var ci := 0
		for child in _unlock_row.get_children():
			if child is Control:
				child.pivot_offset = (child as Control).size * 0.5
				tw.tween_property(child, "scale", Vector2.ONE, 0.30).set_delay(0.98 + ci * 0.07).from(Vector2(0.80, 0.80)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				ci += 1
	var hint := _content.get_node_or_null("Hint") as Control
	if hint:
		tw.tween_property(hint, "modulate:a", 0.85, 0.4).set_delay(1.0)
	# 停留后淡出
	var end_tw := create_tween()
	end_tw.tween_interval(4.2)
	end_tw.tween_callback(_fade_out)


func _fade_out() -> void:
	if _done:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.40)
	tw.tween_property(_content, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(_finish)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_finish()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var c := Vector2(vp.x * 0.5, vp.y * 0.38)
	# 旋转金色光束
	for i in range(28):
		var ang: float = _t * 0.16 + TAU * float(i) / 28.0
		var dir := Vector2(cos(ang), sin(ang))
		var inner := c + dir * 120.0
		var outer := c + dir * (760.0 + sin(_t * 1.3 + i) * 40.0)
		var a: float = 0.035 + 0.035 * (0.5 + 0.5 * sin(_t * 2.0 + i * 0.7))
		draw_line(inner, outer, Color(1.0, 0.78, 0.34, a), 2.0)
	# 扩散圆环
	for k in range(3):
		var rr: float = 205.0 + k * 34.0 + sin(_t * 1.8 - k * 0.8) * 8.0
		draw_arc(c, rr, 0, TAU, 80, Color(0.96, 0.76, 0.34, 0.26 - k * 0.06), 2.0)
	# 星尘
	for p in _particles:
		var ang: float = float(p.a) + _t * float(p.sp)
		var rad: float = float(p.r) + sin(_t * 0.8 + float(p.ph)) * 18.0
		var pos := c + Vector2(cos(ang), sin(ang) * 0.8) * rad
		var alpha: float = 0.25 + 0.55 * (0.5 + 0.5 * sin(_t * 2.2 + float(p.ph)))
		draw_circle(pos, float(p.sz), Color(1.0, 0.86, 0.52, alpha))


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
