extends Node3D
# 死亡后留下的炸弹：倒计时时钟 + 到时爆炸
var delay: float = 1.0
var dmg: float = 0.0
var radius: float = 1.0
var atk_type: int = 1
var tgt_type: int = 3
var team: int = 0
var card_id: int = -1
var _t: float = 0.0
var _hand: Node3D
var _body: MeshInstance3D

func setup(p_delay: float, p_dmg: float, p_radius: float, p_atk: int, p_tgt: int, p_team: int, p_card: int) -> void:
	delay = p_delay
	dmg = p_dmg
	radius = p_radius
	atk_type = p_atk
	tgt_type = p_tgt
	team = p_team
	card_id = p_card
	_build()

func _build() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	_body = MeshInstance3D.new()
	_body.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.17, 0.20)
	m.roughness = 0.6
	_body.material_override = m
	_body.position = Vector3(0, 0.34, 0)
	add_child(_body)
	var fuse := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.03
	fm.bottom_radius = 0.03
	fm.height = 0.16
	fuse.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.62, 0.50, 0.30)
	fuse.material_override = fmat
	fuse.position = Vector3(0.06, 0.72, 0)
	fuse.rotation.z = 0.35
	add_child(fuse)
	# 表盘
	var dial := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.22
	dm.bottom_radius = 0.22
	dm.height = 0.03
	dm.radial_segments = 24
	dial.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(0.95, 0.95, 0.90)
	dial.material_override = dmat
	dial.position = Vector3(0, 1.12, 0)
	add_child(dial)
	var rim := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.20
	rt.outer_radius = 0.24
	rt.rings = 20
	rt.ring_segments = 5
	rim.mesh = rt
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.95, 0.80, 0.30)
	rim.material_override = rmat
	rim.position = Vector3(0, 1.12, 0)
	add_child(rim)
	_hand = Node3D.new()
	_hand.position = Vector3(0, 1.14, 0)
	add_child(_hand)
	for i in 2:
		var hand := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.025, 0.02, 0.16 if i == 0 else 0.12)
		hand.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hmat.albedo_color = Color(0.10, 0.10, 0.12) if i == 0 else Color(0.30, 0.30, 0.34)
		hand.material_override = hmat
		hand.position = Vector3(0, 0.01, (0.08 if i == 0 else 0.06))
		_hand.add_child(hand)

func _process(delta: float) -> void:
	_t += delta
	if _hand:
		_hand.rotation.y = TAU * clampf(_t / maxf(delay, 0.1), 0.0, 1.0)
	if _t >= delay:
		_explode()

func _explode() -> void:
	var battle = get_tree().get_first_node_in_group("battle_manager") if is_inside_tree() else null
	if battle:
		var spell = Spell.create(global_position, team, int(dmg), radius, 0, atk_type, tgt_type)
		spell.card_id = card_id
		battle.spells.add_child(spell)
		# 爆炸碎片
		for i in 10:
			var p := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = randf_range(0.06, 0.14)
			s.height = s.radius * 2.0
			p.mesh = s
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.albedo_color = Color(1.0, randf_range(0.45, 0.8), 0.15)
			p.material_override = pm
			p.position = global_position + Vector3(0, 0.4, 0)
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			battle.add_child(p)
			var tw := p.create_tween()
			tw.set_parallel(true)
			tw.tween_property(p, "position", p.position + Vector3(randf_range(-1.2, 1.2), randf_range(0.4, 1.4), randf_range(-1.2, 1.2)), 0.4)
			tw.tween_property(p, "scale", Vector3(0.2, 0.2, 0.2), 0.4)
			tw.chain().tween_callback(p.queue_free)
	queue_free()
