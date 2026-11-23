extends Control
# 个人主页皇家塔 3D 预览：复用 DeckBuilder 的塔模型与相机设置。

const TOWER_CATALOG = preload("res://scripts/data/TowerCatalog.gd")
const CARD_VISUAL = preload("res://scripts/visuals/CardVisualCatalog.gd")
const UNIT_KIT = preload("res://scripts/visuals/UnitModelKit.gd")

var choice: int = 1
var _sub: SubViewport
var _root: Node3D
var _model: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size = Vector2(180, 168)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(220, 200)
	_sub.transparent_bg = true
	_sub.own_world_3d = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)
	_root = Node3D.new()
	_sub.add_child(_root)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 2.3, 4.2)
	cam.fov = 35.0
	_sub.add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 1.2
	_sub.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.4
	_sub.add_child(fill)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.84, 0.94)
	env.ambient_light_energy = 0.7
	env_node.environment = env
	_sub.add_child(env_node)
	set_tower(choice)


func set_tower(c: int) -> void:
	choice = clampi(c, 1, 4)
	if _root == null:
		return
	for ch in _root.get_children():
		ch.queue_free()
	var data: Dictionary = TOWER_CATALOG.get_tower(choice)
	var spec: Dictionary = CARD_VISUAL.spec_for(String(data.name), Config.Team.PLAYER, float(data.range))
	_model = UNIT_KIT.create_unit(spec)
	_root.add_child(_model)
	_model.rotation.y = 0.35
	_animate_idle()


func _animate_idle() -> void:
	if _model == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_model, "rotation:y", 0.55, 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_model, "rotation:y", 0.15, 2.4).set_trans(Tween.TRANS_SINE)
