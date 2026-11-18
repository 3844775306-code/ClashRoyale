extends Control
# 可复用 3D 宝箱预览：宝箱开箱界面同款 ChestModel，用于皇室征程/主菜单飞入动画。

const CHEST_MODEL = preload("res://scripts/visuals/ChestModel.gd")
var rarity: String = "silver"
var model
var _viewport: SubViewport

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size = Vector2(112, 112)
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.75
	env.environment = e
	_viewport.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.8, 4.6)
	cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
	cam.fov = 35.0
	_viewport.add_child(cam)
	cam.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -36, 0)
	light.light_energy = 1.25
	_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.72, 1.0)
	_viewport.add_child(fill)
	model = CHEST_MODEL.new()
	_viewport.add_child(model)
	_apply_accent()

func set_rarity(r: String) -> void:
	rarity = r
	_apply_accent()

func _apply_accent() -> void:
	if model == null:
		return
	var c := Color(0.62, 0.76, 0.90)
	if rarity == "gold": c = Color(1.0, 0.78, 0.28)
	elif rarity == "magical": c = Color(0.72, 0.44, 1.0)
	elif rarity == "legendary": c = Color(1.0, 0.84, 0.36)
	model.set_accent(c)

func play_idle() -> void:
	if model:
		model.shake(0.015)
