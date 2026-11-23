extends RefCounted
# ============================================================
# 法术视觉效果（程序化，多材质分层，不用单一纯色简单几何）
# 用法：var vfx = SpellVFX.build(card_id, radius, team, atk_type)
#       SpellVFX.animate(vfx, progress, elapsed) 在 _process 里调用
# ============================================================

const KIT := preload("res://scripts/visuals/UnitModelKit.gd")
const PROJ := preload("res://scripts/visuals/ProjectileKit.gd")

static func build(card_id: int, radius: float, team: int, atk_type: int) -> Node3D:
	var root := Node3D.new()
	root.name = "SpellVFX"
	match card_id:
		10:
			_arrows(root, radius)
		11:
			_fireball(root, radius)
		20, 48:
			_lightning(root, radius)
		31:
			_snow(root, radius)
		40:
			_barrel(root, radius)
		78:
			_rage(root, radius)
		80:
			_freeze(root, radius)
		104:
			_generic(root, radius, 1, team)
		110:
			_generic(root, radius, 1, team)
		112:
			_generic(root, radius, 7, team)
		113:
			_generic(root, radius, 9, team)
		116:
			# 哥布林魔咒：绿色诅咒
			_generic(root, radius, 7, team)
		107:
			_poison(root, radius)
		115:
			_earthquake(root, radius)
		_:
			_generic(root, radius, atk_type, team)
	return root

static func animate(root: Node3D, p: float, t: float) -> void:
	if root == null:
		return
	var pp: float = clampf(p, 0.0, 1.0)
	for c in root.get_children():
		if not (c is Node3D):
			continue
		var n := String(c.name)
		if n.begins_with("ring"):
			c.scale = Vector3.ONE * (0.45 + pp * 1.2)
		elif n.begins_with("flash"):
			c.scale = Vector3.ONE * (1.0 + pp * 0.7)
		elif n.begins_with("spark"):
			var f: float = fmod(t * 1.7 + float(c.get_index()) * 0.29, 1.8)
			c.position.y = 0.15 + f
			c.scale = Vector3.ONE * (1.0 - f / 1.8 * 0.65)
		elif n.begins_with("flyarrow"):
			var fp: float = clampf(pp * 1.6 - float(c.get_index()) * 0.05, 0.0, 1.0)
			c.position = (c.get_meta("from") as Vector3).lerp(c.get_meta("to") as Vector3, fp)
			c.visible = fp < 1.0 or pp < 0.85
		elif n.begins_with("bolt"):
			c.visible = fmod(t * 24.0 + float(c.get_index()), 1.0) > 0.15
		elif n.begins_with("debris"):
			var df: float = clampf(pp * 1.5 - float(c.get_index()) * 0.018, 0.0, 1.0)
			var dbase: Vector3 = c.get_meta("base_pos", c.position)
			c.position = dbase + Vector3(0.0, sin(df * PI) * 1.35, 0.0)
			c.rotation.x = df * 6.0
			c.rotation.z = df * 4.0
	_fade(root, 1.0 - pp)

static func _fade(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m:
			var c: Color = m.albedo_color
			c.a = float(m.get_meta("base_a", 1.0)) * alpha
			m.albedo_color = c
	for ch in node.get_children():
		_fade(ch, alpha)

static func _mat(col: Color, alpha: float = 1.0, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.set_meta("base_a", alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

static func _mesh(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material, name: String, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.name = name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

static func _disk(root: Node3D, radius: float, col: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.015
	c.radial_segments = 40
	_mesh(root, c, Vector3(0, 0.025, 0), _mat(col, 0.42, 0.6), "disk")
	var c2 := CylinderMesh.new()
	c2.top_radius = radius * 0.55
	c2.bottom_radius = radius * 0.55
	c2.height = 0.016
	c2.radial_segments = 32
	_mesh(root, c2, Vector3(0, 0.03, 0), _mat(col.lightened(0.15), 0.30, 0.5), "disk2")

static func _ring(root: Node3D, radius: float, col: Color, name: String = "ring", energy: float = 1.4) -> void:
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.90
	t.outer_radius = radius * 1.08
	t.rings = 28
	t.ring_segments = 6
	_mesh(root, t, Vector3(0, 0.06, 0), _mat(col, 0.55, energy), name)

static func _sphere(root: Node3D, radius: float, pos: Vector3, mat: Material, name: String) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 14
	s.rings = 7
	_mesh(root, s, pos, mat, name)

static func _cyl(root: Node3D, r: float, h: float, pos: Vector3, mat: Material, name: String, rot: Vector3 = Vector3.ZERO) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.05
	c.height = h
	c.radial_segments = 12
	_mesh(root, c, pos, mat, name, rot)

static func _cone(root: Node3D, r: float, h: float, pos: Vector3, mat: Material, name: String, rot: Vector3 = Vector3.ZERO) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	_mesh(root, c, pos, mat, name, rot)

static func _prism(root: Node3D, pos: Vector3, size: Vector3, mat: Material, name: String, rot: Vector3 = Vector3.ZERO) -> void:
	var p := PrismMesh.new()
	p.size = size
	_mesh(root, p, pos, mat, name, rot)

static func _box(root: Node3D, pos: Vector3, size: Vector3, mat: Material, name: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(root, b, pos, mat, name, rot)

# ---------- 万箭齐发 ----------
static func _arrows(root: Node3D, radius: float) -> void:
	_ring(root, radius, Color(0.85, 0.92, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	_ring(root, radius * 0.75, Color(0.55, 0.70, 0.55), "ring2", 0.9)
	for i in 10:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = sqrt(rng.randf()) * radius * 0.85
		var p := Vector3(cos(a) * r, 0.10, sin(a) * r)
		var rot := Vector3(-1.1 + rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
		_cyl(root, 0.018, 0.62, p, _mat(Color(0.52, 0.38, 0.22)), "arrow%d" % (i * 3), rot)
		_cone(root, 0.05, 0.14, p + Vector3(0, 0.12, 0), _mat(Color(0.72, 0.74, 0.78)), "arrow%d" % (i * 3 + 1), rot)
		_box(root, p + Vector3(0.03, 0.02, 0), Vector3(0.10, 0.05, 0.02), _mat(Color(0.88, 0.86, 0.80)), "arrow%d" % (i * 3 + 2), rot)
	# 多支箭从天而降射向目标范围
	var arrow_mesh: Mesh = PROJ.mesh_for("arrow")
	for i in 8:
		var ang: float = rng.randf_range(0.0, TAU)
		var spread: float = rng.randf_range(0.0, 1.0) * radius * 0.9
		var target_p := Vector3(cos(ang) * spread, 0.15, sin(ang) * spread)
		var start_p := target_p + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(3.2, 4.5), rng.randf_range(0.8, 1.8))
		var mi := MeshInstance3D.new()
		mi.mesh = arrow_mesh
		mi.name = "flyarrow%d" % i
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d: Vector3 = target_p - start_p
		var yaw: float = atan2(d.x, d.z)
		var pitch: float = -atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.01))
		mi.rotation = Vector3(pitch, yaw, 0.0)
		mi.position = start_p
		mi.set_meta("from", start_p)
		mi.set_meta("to", target_p)
		root.add_child(mi)
	for i in 4:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.2, 0.9) * radius
		_box(root, Vector3(cos(a2) * r2, 1.2, sin(a2) * r2), Vector3(0.02, 1.0, 0.02), _mat(Color(1.0, 1.0, 1.0), 0.25), "spark%d" % i)

# ---------- 火球 ----------
static func _fireball(root: Node3D, radius: float) -> void:
	_ring(root, radius, Color(1.0, 0.55, 0.18))
	_ring(root, radius * 0.7, Color(0.9, 0.28, 0.10), "ring2", 1.2)
	_sphere(root, radius * 0.46, Vector3(0, 0.35, 0), _mat(Color(0.75, 0.14, 0.06), 0.95, 1.4), "flash")
	_sphere(root, radius * 0.34, Vector3(0, 0.40, 0), _mat(Color(1.0, 0.42, 0.08)), "flashCore")
	_sphere(root, radius * 0.20, Vector3(0, 0.44, 0), _mat(Color(1.0, 0.86, 0.45)), "flashTip")
	_sphere(root, radius * 0.55, Vector3(0, 0.30, 0), _mat(Color(0.28, 0.26, 0.26), 0.35), "smoke")
	for i in 3:
		var a: float = TAU * float(i) / 3.0
		_cone(root, radius * 0.16, radius * 0.7, Vector3(cos(a) * radius * 0.15, radius * 0.75, sin(a) * radius * 0.15),
			_mat(Color(1.0, 0.55 - 0.12 * float(i), 0.10), 0.9), "flame%d" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 12:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.35, 1.05) * radius
		var col: Color = Color(1.0, rng.randf_range(0.45, 0.85), 0.15).lerp(Color(0.9, 0.2, 0.1), rng.randf())
		_sphere(root, rng.randf_range(0.05, 0.13), Vector3(cos(a) * r, rng.randf_range(0.25, 1.2), sin(a) * r), _mat(col, 0.95), "spark%d" % i)
	# 地面焦痕与裂纹
	_cyl(root, radius * 0.9, 0.02, Vector3(0, 0.03, 0), _mat(Color(0.16, 0.13, 0.11), 0.6), "burn")
	for i in 5:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.3, 0.95) * radius
		_box(root, Vector3(cos(a3) * r3, 0.04, sin(a3) * r3), Vector3(0.10, 0.02, 0.55 * radius), _mat(Color(0.42, 0.12, 0.06), 0.7), "crack%d" % i, Vector3(0, a3, 0))

# ---------- 闪电 ----------
static func _lightning(root: Node3D, radius: float) -> void:
	_ring(root, radius, Color(0.55, 0.85, 1.0))
	_ring(root, radius * 0.65, Color(0.30, 0.50, 1.0), "ring2", 1.8)
	_sphere(root, radius * 0.18, Vector3(0, 0.30, 0), _mat(Color(0.80, 0.94, 1.0)), "flash")
	_sphere(root, radius * 0.30, Vector3(0, 0.25, 0), _mat(Color(0.35, 0.60, 1.0), 0.5, 2.0), "flashGlow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 3:
		var x0: float = rng.randf_range(-radius * 0.4, radius * 0.4)
		var z0: float = rng.randf_range(-radius * 0.4, radius * 0.4)
		var y: float = 4.4 + float(b) * 0.5
		var seg: int = 6
		for i in seg:
			var h: float = (y / float(seg)) * 1.2
			var nx: float = x0 * (1.0 - float(i + 1) / float(seg))
			var nz: float = z0 * (1.0 - float(i + 1) / float(seg))
			var mid := Vector3(nx + rng.randf_range(-0.18, 0.18), y - (y / float(seg)) * (float(i) + 0.5), nz + rng.randf_range(-0.18, 0.18))
			var col: Color = Color(0.95, 0.99, 1.0) if i % 2 == 0 else Color(0.35, 0.55, 1.0)
			_box(root, mid, Vector3(0.09, h, 0.09), _mat(col, 0.95, 2.4), "bolt%d_%d" % [b, i], Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)))
		for f in 2:
			var fy: float = y * rng.randf_range(0.3, 0.7)
			_box(root, Vector3(x0 * 0.6 + rng.randf_range(-0.2, 0.2), fy, z0 * 0.6 + rng.randf_range(-0.2, 0.2)),
				Vector3(0.06, rng.randf_range(0.25, 0.55), 0.06), _mat(Color(0.55, 0.45, 1.0), 0.8, 2.0), "bolt%d_f%d" % [b, f], Vector3(0.6, 0, 0.4))
	for i in 7:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.35, 0.95) * radius
		_prism(root, Vector3(cos(a) * r, rng.randf_range(0.15, 0.7), sin(a) * r), Vector3(0.07, 0.18, 0.05),
			_mat(Color(0.80, 0.95, 1.0), 0.9), "spark%d" % i, Vector3(rng.randf_range(0, TAU), 0, rng.randf_range(0, TAU)))

# ---------- 大雪球 ----------
static func _snow(root: Node3D, radius: float) -> void:
	_ring(root, radius, Color(0.55, 0.85, 1.0))
	_ring(root, radius * 0.7, Color(0.80, 0.95, 1.0), "ring2", 1.2)
	_sphere(root, radius * 0.22, Vector3(0, 0.30, 0), _mat(Color(0.92, 0.98, 1.0)), "flash")
	_sphere(root, radius * 0.38, Vector3(0, 0.26, 0), _mat(Color(0.70, 0.88, 1.0), 0.45, 1.6), "flashGlow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 6:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.3, 0.95) * radius
		var col: Color = Color(0.82, 0.95, 1.0).lerp(Color(1.0, 1.0, 1.0), rng.randf())
		_prism(root, Vector3(cos(a) * r, rng.randf_range(0.15, 0.6), sin(a) * r), Vector3(0.12, 0.34, 0.07),
			_mat(col, 0.95, 1.6), "ice%d" % i, Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3)))
	for i in 5:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.35, 1.0) * radius
		_sphere(root, rng.randf_range(0.10, 0.20), Vector3(cos(a2) * r2, rng.randf_range(0.2, 0.7), sin(a2) * r2),
			_mat(Color(0.85, 0.94, 1.0), 0.30, 0.6), "spark%d" % i)
	for i in 8:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.4, 1.05) * radius
		_sphere(root, rng.randf_range(0.04, 0.08), Vector3(cos(a3) * r3, rng.randf_range(0.15, 0.8), sin(a3) * r3),
			_mat(Color(0.98, 1.0, 1.0), 0.9), "frost%d" % i)

# ---------- 哥布林飞桶 ----------
static func _barrel(root: Node3D, radius: float) -> void:
	_ring(root, radius, Color(0.95, 0.72, 0.34))
	_ring(root, radius * 0.75, Color(0.70, 0.48, 0.24), "ring2", 1.0)
	_cyl(root, 0.30, 0.64, Vector3(0, 0.34, 0), _mat(Color(0.60, 0.40, 0.22)), "barrel", Vector3(PI * 0.5, 0, 0))
	for i in 3:
		var b := TorusMesh.new()
		b.inner_radius = 0.30
		b.outer_radius = 0.345
		b.rings = 16
		b.ring_segments = 5
		_mesh(root, b, Vector3(0, 0.34, -0.20 + float(i) * 0.20), _mat(Color(0.38, 0.38, 0.40)), "band%d" % i, Vector3(PI * 0.5, 0, 0))
	_cyl(root, 0.31, 0.04, Vector3(0, 0.34, 0.33), _mat(Color(0.50, 0.33, 0.19)), "lid", Vector3(PI * 0.5, 0, 0))
	_cyl(root, 0.31, 0.04, Vector3(0, 0.34, -0.33), _mat(Color(0.50, 0.33, 0.19)), "lid2", Vector3(PI * 0.5, 0, 0))
	_sphere(root, radius * 0.20, Vector3(0, 0.26, 0), _mat(Color(1.0, 0.78, 0.38), 0.65, 1.6), "flash")
	var rng := RandomNumberGenerator.new()
	rng.seed = 40
	for i in 12:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.3, 1.0) * radius
		var col: Color = Color(0.62, 0.44, 0.24).lerp(Color(0.78, 0.60, 0.36), rng.randf())
		_box(root, Vector3(cos(a) * r, rng.randf_range(0.2, 0.8), sin(a) * r),
			Vector3(rng.randf_range(0.05, 0.12), rng.randf_range(0.04, 0.08), rng.randf_range(0.12, 0.30)),
			_mat(col), "splinter%d" % i, Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), 0))
	for i in 5:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.4, 1.1) * radius
		_sphere(root, rng.randf_range(0.10, 0.22), Vector3(cos(a2) * r2, rng.randf_range(0.1, 0.5), sin(a2) * r2),
			_mat(Color(0.55, 0.52, 0.48), 0.45, 0.4), "dust%d" % i)

# ---------- 通用（治疗/狂暴/毒药/冰冻等） ----------
static func _generic(root: Node3D, radius: float, atk_type: int, team: int) -> void:
	var col: Color = Color(0.40, 0.85, 1.0)
	match atk_type:
		8:
			col = Color(0.45, 0.95, 0.50)
		9:
			col = Color(0.75, 0.40, 1.0)
		7:
			col = Color(0.50, 0.85, 0.25)
		3:
			col = Color(0.55, 0.90, 1.0)
		_:
			col = Color(0.45, 0.75, 1.0) if team == 0 else Color(1.0, 0.45, 0.35)
	_ring(root, radius, col)
	_ring(root, radius * 0.72, col.darkened(0.25), "ring2", 1.0)
	_sphere(root, radius * 0.24, Vector3(0, 0.30, 0), _mat(col.lightened(0.35), 0.9), "flash")
	_sphere(root, radius * 0.34, Vector3(0, 0.25, 0), _mat(col, 0.35, 1.6), "flashGlow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 10:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.25, 1.05) * radius
		var c: Color = col.lightened(rng.randf_range(-0.05, 0.35))
		_sphere(root, rng.randf_range(0.035, 0.085), Vector3(cos(a) * r, rng.randf_range(0.1, 0.5), sin(a) * r), _mat(c, 0.9), "spark%d" % i)
	for i in 6:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.3, 1.0) * radius
		_box(root, Vector3(cos(a2) * r2, 0.04, sin(a2) * r2), Vector3(0.06, 0.02, 0.40 * radius),
			_mat(col.darkened(0.35), 0.6), "crack%d" % i, Vector3(0, a2, 0))
	for i in 4:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.4, 1.0) * radius
		_prism(root, Vector3(cos(a3) * r3, rng.randf_range(0.4, 0.9), sin(a3) * r3), Vector3(0.10, 0.22, 0.05),
			_mat(col.lightened(0.25), 0.85), "rune%d" % i, Vector3(0, rng.randf_range(0, TAU), 0))

# ---------- 狂暴法术 ----------
static func _rage(root: Node3D, radius: float) -> void:
	_disk(root, radius, Color(0.38, 0.16, 0.62))
	_ring(root, radius, Color(0.72, 0.35, 1.0))
	_ring(root, radius * 0.72, Color(0.90, 0.66, 1.0), "ring2", 1.8)
	_sphere(root, radius * 0.22, Vector3(0, 0.30, 0), _mat(Color(0.88, 0.70, 1.0)), "flash")
	_sphere(root, radius * 0.34, Vector3(0, 0.25, 0), _mat(Color(0.55, 0.25, 0.95), 0.4, 2.0), "flashGlow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	for i in 10:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.25, 1.0) * radius
		_sphere(root, rng.randf_range(0.04, 0.09), Vector3(cos(a) * r, rng.randf_range(0.1, 0.5), sin(a) * r),
			_mat(Color(rng.randf_range(0.60, 0.90), 0.30, 1.0), 0.95), "spark%d" % i)
	for i in 5:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.3, 0.95) * radius
		_box(root, Vector3(cos(a2) * r2, 0.04, sin(a2) * r2), Vector3(0.05, 0.02, 0.45 * radius),
			_mat(Color(0.30, 0.12, 0.52), 0.65), "crack%d" % i, Vector3(0, a2, 0))
	for i in 5:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.4, 1.0) * radius
		_prism(root, Vector3(cos(a3) * r3, rng.randf_range(0.35, 0.85), sin(a3) * r3), Vector3(0.09, 0.26, 0.05),
			_mat(Color(0.82, 0.60, 1.0), 0.9), "rune%d" % i, Vector3(0, rng.randf_range(0, TAU), 0))
# ---------- 冰冻法术 ----------
static func _freeze(root: Node3D, radius: float) -> void:
	_disk(root, radius, Color(0.40, 0.62, 0.85))
	_ring(root, radius, Color(0.55, 0.85, 1.0))
	_ring(root, radius * 0.7, Color(0.85, 0.97, 1.0), "ring2", 1.4)
	_sphere(root, radius * 0.22, Vector3(0, 0.30, 0), _mat(Color(0.85, 0.97, 1.0)), "flash")
	_sphere(root, radius * 0.36, Vector3(0, 0.26, 0), _mat(Color(0.55, 0.82, 1.0), 0.40, 1.6), "flashGlow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	for i in 8:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.25, 0.95) * radius
		_prism(root, Vector3(cos(a) * r, rng.randf_range(0.15, 0.65), sin(a) * r), Vector3(0.13, 0.40, 0.08),
			_mat(Color(0.75, 0.92, 1.0).lerp(Color(1.0, 1.0, 1.0), rng.randf()), 0.95, 1.6), "ice%d" % i,
			Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3)))
	for i in 6:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.35, 1.05) * radius
		_sphere(root, rng.randf_range(0.10, 0.20), Vector3(cos(a2) * r2, rng.randf_range(0.15, 0.6), sin(a2) * r2),
			_mat(Color(0.90, 0.97, 1.0), 0.28, 0.5), "spark%d" % i)
	for i in 8:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.4, 1.05) * radius
		_sphere(root, rng.randf_range(0.035, 0.07), Vector3(cos(a3) * r3, rng.randf_range(0.2, 0.9), sin(a3) * r3),
			_mat(Color(0.98, 1.0, 1.0), 0.9), "frost%d" % i)
# ---------- 毒药法术 ----------
static func _poison(root: Node3D, radius: float) -> void:
	_disk(root, radius, Color(0.22, 0.55, 0.18))
	_ring(root, radius, Color(0.45, 0.90, 0.30))
	_ring(root, radius * 0.7, Color(0.70, 0.95, 0.45), "ring2", 1.0)
	_sphere(root, radius * 0.20, Vector3(0, 0.35, 0), _mat(Color(0.72, 0.95, 0.55)), "flash")
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	for i in 12:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.2, 1.0) * radius
		_sphere(root, rng.randf_range(0.06, 0.16), Vector3(cos(a) * r, rng.randf_range(0.15, 0.9), sin(a) * r),
			_mat(Color(0.30, 0.75, 0.25).lerp(Color(0.65, 0.95, 0.35), rng.randf()), 0.55, 0.7), "spark%d" % i)
	for i in 6:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.4, 1.0) * radius
		_sphere(root, rng.randf_range(0.02, 0.05), Vector3(cos(a2) * r2, rng.randf_range(0.8, 1.6), sin(a2) * r2),
			_mat(Color(0.75, 1.0, 0.55), 0.85), "bubble%d" % i)
	for i in 5:
		var a3: float = rng.randf_range(0.0, TAU)
		_prism(root, Vector3(cos(a3) * radius * 0.7, 0.1, sin(a3) * radius * 0.7), Vector3(0.10, 0.20, 0.06),
			_mat(Color(0.30, 0.70, 0.25), 0.85), "rune%d" % i, Vector3(0, rng.randf_range(0, TAU), 0))

# ---------- 地震法术 ----------
static func _earthquake(root: Node3D, radius: float) -> void:
	_disk(root, radius, Color(0.50, 0.38, 0.24))
	_ring(root, radius, Color(0.80, 0.62, 0.38))
	_ring(root, radius * 0.72, Color(0.45, 0.33, 0.20), "ring2", 1.2)
	_sphere(root, radius * 0.24, Vector3(0, 0.25, 0), _mat(Color(0.85, 0.70, 0.45), 0.7), "flash")
	var rng := RandomNumberGenerator.new()
	rng.seed = 115
	for i in 14:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.25, 1.0) * radius
		var sz: float = rng.randf_range(0.08, 0.20)
		_box(root, Vector3(cos(a) * r, rng.randf_range(0.1, 0.5), sin(a) * r), Vector3(sz, sz * 0.7, sz),
			_mat(Color(0.48, 0.38, 0.26).lerp(Color(0.70, 0.58, 0.40), rng.randf())), "rock%d" % i,
			Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), 0))
	for i in 7:
		var a2: float = rng.randf_range(0.0, TAU)
		var r2: float = rng.randf_range(0.3, 1.0) * radius
		_box(root, Vector3(cos(a2) * r2, 0.045, sin(a2) * r2), Vector3(0.06, 0.02, 0.7 * radius),
			_mat(Color(0.25, 0.18, 0.12), 0.8), "crack%d" % i, Vector3(0, a2, 0))
	for i in 6:
		var a3: float = rng.randf_range(0.0, TAU)
		var r3: float = rng.randf_range(0.3, 1.0) * radius
		_sphere(root, rng.randf_range(0.15, 0.30), Vector3(cos(a3) * r3, rng.randf_range(0.2, 0.7), sin(a3) * r3),
			_mat(Color(0.58, 0.50, 0.40), 0.35, 0.4), "dust%d" % i)
	# 飞散碎石：提升地震的爆发感
	for i in 16:
		var a4: float = rng.randf_range(0.0, TAU)
		var r4: float = rng.randf_range(0.15, 0.9) * radius
		var sz4: float = rng.randf_range(0.06, 0.16)
		var pos4 := Vector3(cos(a4) * r4, rng.randf_range(0.12, 0.30), sin(a4) * r4)
		_box(root, pos4, Vector3(sz4, sz4 * 0.8, sz4),
			_mat(Color(0.46, 0.36, 0.24).lerp(Color(0.76, 0.60, 0.38), rng.randf()), 0.95), "debris%d" % i,
			Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU)))
		var rock = root.get_child(root.get_child_count() - 1)
		rock.set_meta("base_pos", pos4)
	# 外层扬尘
	for i in 10:
		var a5: float = rng.randf_range(0.0, TAU)
		var r5: float = rng.randf_range(0.5, 1.1) * radius
		_sphere(root, rng.randf_range(0.18, 0.36), Vector3(cos(a5) * r5, rng.randf_range(0.1, 0.5), sin(a5) * r5),
			_mat(Color(0.54, 0.44, 0.32), 0.25, 0.3), "dust%d" % (i + 6))