extends CanvasLayer
# 金币/钻石获得与花费特效：
# - 3D 金币/钻石模型在独立 SubViewport 中飞行
# - 金币花费：顶部金币栏 -> 最近点击的位置
# - 金币获得：最近位置/屏幕中央 -> 顶部金币栏
# - 钻石花费：顶部钻石栏 -> 最近点击的位置
# - 钻石获得：屏幕中央 -> 顶部钻石栏
# - 顶部数字渐变滚动，不再瞬间跳变

const PA := preload("res://scripts/core/ProceduralAudio.gd")

const MAX_ACTIVE := 56
const VIEW_SIZE := Vector2(400, 800)
const GOLD_TINT := Color(1.0, 0.79, 0.28)
const GOLD_DEEP := Color(0.42, 0.23, 0.04)
const GEM_TINT := Color(0.55, 0.84, 1.0)
const GEM_DEEP := Color(0.10, 0.28, 0.56)
const COUNT_DUR := 0.62

var _root: Control
var _sub: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _active := 0

var _last_gold := 0
var _last_gems := 0
var _shown_gold := 0
var _shown_gems := 0
var _target_gold := 0
var _target_gems := 0
var _anim_gold := false
var _anim_gems := false
var _count_t := 0.0
var _armed := false

var _last_press_pos := Vector2.ZERO
var _last_target_pos := Vector2.ZERO
var _last_target_id := 0
var _has_press := false
var _startup_until: int = 0
var _user_interacted := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_sub = SubViewportContainer.new()
	_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.stretch = true
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sub)
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sub.add_child(_vp)
	_vp.own_world_3d = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.85
	env.environment = e
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = VIEW_SIZE.y
	_cam.near = 1.0
	_cam.far = 3000.0
	_cam.position = Vector3(VIEW_SIZE.x * 0.5, VIEW_SIZE.y * 0.5, 1000.0)
	_cam.look_at_from_position(Vector3(VIEW_SIZE.x * 0.5, VIEW_SIZE.y * 0.5, 1000.0), Vector3(VIEW_SIZE.x * 0.5, VIEW_SIZE.y * 0.5, 0.0), Vector3.UP)
	_vp.add_child(_cam)
	_cam.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -28, 0)
	light.light_energy = 1.5
	_vp.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.55, 0.72, 1.0)
	_vp.add_child(fill)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed = true
			pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pressed = true
			pos = st.position
	if not pressed:
		return
	_user_interacted = true
	_has_press = true
	_last_press_pos = pos
	var hovered := get_viewport().gui_get_hovered_control() if get_viewport() != null else null
	if hovered is Control and not (hovered as Control).is_in_group("currency_chip_coin") and not (hovered as Control).is_in_group("currency_chip_gem"):
		_last_target_id = hovered.get_instance_id()
		_last_target_pos = (hovered as Control).get_global_rect().get_center()


func _process(delta: float) -> void:
	if PlayerData == null:
		return
	if not _armed:
		_last_gold = int(PlayerData.gold)
		_last_gems = int(PlayerData.gems)
		_shown_gold = _last_gold
		_shown_gems = _last_gems
		_target_gold = _last_gold
		_target_gems = _last_gems
		_armed = true
		_startup_until = Time.get_ticks_msec() + 8000
		return
	var gold_now: int = int(PlayerData.gold)
	var gems_now: int = int(PlayerData.gems)
	# 启动阶段账号/云存档回填会改变货币值；玩家第一次操作前全部只同步、不播放特效
	if not _user_interacted or (AccountManager != null and AccountManager.is_syncing_cloud()):
		_last_gold = gold_now
		_last_gems = gems_now
		_shown_gold = gold_now
		_shown_gems = gems_now
		_target_gold = gold_now
		_target_gems = gems_now
		return
	if Time.get_ticks_msec() < _startup_until:
		_last_gold = gold_now
		_last_gems = gems_now
		_shown_gold = gold_now
		_shown_gems = gems_now
		_target_gold = gold_now
		_target_gems = gems_now
		return
	if gold_now != _last_gold:
		_start_count("coin", gold_now)
		_handle_change("coin", gold_now - _last_gold)
		_last_gold = gold_now
	if gems_now != _last_gems:
		_start_count("gem", gems_now)
		_handle_change("gem", gems_now - _last_gems)
		_last_gems = gems_now
	_animate_counts(delta)


# ---------------- 顶部数字渐变 ----------------
func display_gold() -> int:
	return _shown_gold if _anim_gold else int(PlayerData.gold)


func display_gems() -> int:
	return _shown_gems if _anim_gems else int(PlayerData.gems)


func _start_count(kind: String, target: int) -> void:
	if kind == "coin":
		_target_gold = target
		_anim_gold = true
	else:
		_target_gems = target
		_anim_gems = true
	_count_t = 0.0


func _animate_counts(delta: float) -> void:
	if not _anim_gold and not _anim_gems:
		return
	_count_t = minf(COUNT_DUR, _count_t + delta)
	var k := _count_t / COUNT_DUR
	var e := 1.0 - pow(1.0 - k, 3.0)
	if _anim_gold:
		_shown_gold = int(round(lerpf(float(_shown_gold), float(_target_gold), e)))
		_set_chip_text("coin", str(_shown_gold))
		if k >= 1.0:
			_shown_gold = _target_gold
			_set_chip_text("coin", str(_shown_gold))
			_anim_gold = false
	if _anim_gems:
		_shown_gems = int(round(lerpf(float(_shown_gems), float(_target_gems), e)))
		_set_chip_text("gem", str(_shown_gems))
		if k >= 1.0:
			_shown_gems = _target_gems
			_set_chip_text("gem", str(_shown_gems))
			_anim_gems = false


func _set_chip_text(kind: String, text: String) -> void:
	for n in get_tree().get_nodes_in_group("currency_chip_" + kind):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var chip := n as Control
		if chip.get_child_count() < 1:
			continue
		var h := chip.get_child(0)
		if h is HBoxContainer and h.get_child_count() >= 2:
			(h.get_child(1) as Label).text = text
			return


# ---------------- 3D 粒子 ----------------
func _handle_change(kind: String, delta: int) -> void:
	if delta == 0 or _active >= MAX_ACTIVE:
		return
	var amount: int = absi(delta)
	var spend := delta < 0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var top := _chip_center(kind)
	var target := _target_pos(center)
	var from := top
	var to := target
	if kind == "gem" and not spend:
		from = center
		to = top
	elif kind == "coin" and not spend:
		from = target
		to = top
	elif spend:
		from = top
		to = target
	_spawn_burst(kind, _count_for(kind, amount), from, to, spend)
	_pulse_chip(kind)
	_play_sound(kind, spend)


func _count_for(kind: String, amount: int) -> int:
	if kind == "coin":
		return clampi(4 + int(amount / 50), 6, 30)
	return clampi(2 + int(amount / 10), 3, 16)


func _chip_center(kind: String) -> Vector2:
	var group := "currency_chip_" + kind
	for n in get_tree().get_nodes_in_group(group):
		if n is Control and (n as Control).is_visible_in_tree():
			return (n as Control).get_global_rect().get_center()
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - 76.0, 32.0)


func _target_pos(center: Vector2) -> Vector2:
	if _last_target_id != 0:
		var n := instance_from_id(_last_target_id)
		if n is Control and is_instance_valid(n) and (n as Control).is_visible_in_tree():
			return (n as Control).get_global_rect().get_center()
	if _has_press:
		return _last_press_pos
	return center


func _spawn_burst(kind: String, count: int, from: Vector2, to: Vector2, spend: bool) -> void:
	for i in count:
		if _active >= MAX_ACTIVE:
			break
		_spawn_one(kind, from, to, i, spend)


func _spawn_one(kind: String, from: Vector2, to: Vector2, index: int, spend: bool) -> void:
	var node := Node3D.new()
	node.add_child(_make_model(kind))
	_stage.add_child(node)
	var spread := 24.0 if kind == "coin" else 30.0
	var start := from + Vector2(randf_range(-spread, spread), randf_range(-10.0, 10.0))
	var end := to + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
	var lift := randf_range(70.0, 170.0)
	if spend:
		lift = -lift
	var mid := (start + end) * 0.5 + Vector2(randf_range(-60.0, 60.0), lift)
	var delay := float(index) * (0.028 if kind == "coin" else 0.045)
	var dur := randf_range(0.48, 0.76) if kind == "coin" else randf_range(0.55, 0.85)
	var spin := randf_range(-4.0, 4.0)
	node.position = _screen_to_world(start)
	node.scale = Vector3(0.25, 0.25, 0.25)
	node.rotation = Vector3(0, 0, randf_range(-0.5, 0.5))
	_active += 1
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var move := func(t: float) -> void:
		if is_instance_valid(node):
			node.position = _screen_to_world(_bezier(start, mid, end, t))
	var done := func() -> void:
		if is_instance_valid(node):
			node.queue_free()
		_active = maxi(0, _active - 1)
		if _active == 0:
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var tw := _vp.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector3(1.15, 1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(move, 0.0, 1.0, dur)
	tw.parallel().tween_property(node, "rotation:y", spin, dur)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.10)
	tw.tween_callback(done)


func _make_model(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if kind == "coin":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 6.0
		cyl.bottom_radius = 6.0
		cyl.height = 2.0
		cyl.radial_segments = 24
		cyl.rings = 1
		mi.mesh = cyl
		mi.rotation_degrees = Vector3(90, 0, 0)
		mi.material_override = _material(true)
	else:
		var sph := SphereMesh.new()
		sph.radius = 5.0
		sph.height = 12.0
		sph.radial_segments = 4
		sph.rings = 2
		mi.mesh = sph
		mi.rotation_degrees = Vector3(0, 45, 0)
		mi.material_override = _material(false)
	return mi


func _material(gold: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD_TINT if gold else GEM_TINT
	m.metallic = 0.8
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = (GOLD_DEEP if gold else GEM_DEEP) * 0.9
	return m


func _screen_to_world(p: Vector2) -> Vector3:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return Vector3.ZERO
	var sx := VIEW_SIZE.x / vp.x
	var sy := VIEW_SIZE.y / vp.y
	return Vector3(p.x * sx, VIEW_SIZE.y - p.y * sy, 0.0)


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


func _pulse_chip(kind: String) -> void:
	for n in get_tree().get_nodes_in_group("currency_chip_" + kind):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var chip := n as Control
		chip.pivot_offset = chip.size * 0.5
		var tw := chip.create_tween()
		tw.tween_property(chip, "scale", Vector2(1.12, 1.12), 0.08)
		tw.tween_property(chip, "scale", Vector2.ONE, 0.16)
		return


func _play_sound(kind: String, spend: bool) -> void:
	if AudioManager == null:
		return
	var snd := "coin" if kind == "coin" else "gem"
	var stream := PA.get_sound(snd)
	if stream:
		AudioManager.play_sfx(stream)
