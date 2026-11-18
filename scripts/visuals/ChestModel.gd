extends Node3D
# 玩具沙盘风格宝箱：木箱 + 拱形盖 + 金属包边/铆钉/锁扣/侧把手。

var lid_pivot: Node3D
var accent: Color = Color(1.0, 0.78, 0.26)
var _band_mat: StandardMaterial3D
var _lock_mat: StandardMaterial3D
var _accent_mats: Array = []
var _glow: OmniLight3D

const WOOD := Color(0.48, 0.27, 0.13)
const WOOD_LIGHT := Color(0.60, 0.36, 0.19)
const WOOD_DARK := Color(0.31, 0.17, 0.09)
const IRON := Color(0.22, 0.24, 0.29)

func _ready():
	_build()
	shake(0.01)

func _mat(color: Color, metallic: float = 0.0, rough: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color, metallic)
	parent.add_child(mi)
	return mi

func _accent_box(parent: Node3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var m := _mat(accent, 0.45, 0.34)
	_accent_mats.append(m)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 24
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _mat(color, 0.3, 0.4)
	parent.add_child(mi)
	return mi

func _rivet(parent: Node3D, pos: Vector3, s: float = 0.045) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s
	sm.height = s * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(accent.lightened(0.25), 0.7, 0.3)
	parent.add_child(mi)

func _build():
	# 底座/脚
	for x in [-0.78, 0.78]:
		for z in [-0.52, 0.52]:
			_box(self, Vector3(x, 0.08, z), Vector3(0.28, 0.16, 0.28), WOOD_DARK)
	_box(self, Vector3(0, 0.17, 0), Vector3(2.10, 0.16, 1.42), WOOD_DARK)
	# 箱体
	_box(self, Vector3(0, 0.62, 0), Vector3(2.02, 1.00, 1.32), WOOD)
	# 正面/背面木板
	for side in [-1.0, 1.0]:
		for i in range(5):
			var x: float = -0.80 + float(i) * 0.40
			var col: Color = WOOD_LIGHT if i % 2 == 0 else WOOD
			_box(self, Vector3(x, 0.62, side * 0.69), Vector3(0.34, 0.98, 0.055), col)
	# 侧面木板
	for side in [-1.0, 1.0]:
		for i in range(4):
			var z: float = -0.46 + float(i) * 0.31
			_box(self, Vector3(side * 1.03, 0.62, z), Vector3(0.055, 0.96, 0.24), WOOD_LIGHT if i % 2 == 0 else WOOD)
	# 底部/顶部金属包边
	_accent_box(self, Vector3(0, 0.20, 0), Vector3(2.16, 0.07, 1.46))
	_accent_box(self, Vector3(0, 1.05, 0), Vector3(2.14, 0.07, 1.44))
	# 中部立包边
	for x in [-0.86, 0.0, 0.86]:
		_accent_box(self, Vector3(x, 0.62, 0.705), Vector3(0.075, 1.0, 0.06))
		_accent_box(self, Vector3(x, 0.62, -0.705), Vector3(0.075, 1.0, 0.06))
	# 角包边
	for x in [-1.02, 1.02]:
		for z in [-0.68, 0.68]:
			_accent_box(self, Vector3(x, 0.62, z), Vector3(0.09, 1.02, 0.09),)
	# 侧把手
	for side in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.10
		tm.outer_radius = 0.145
		tm.rings = 18
		tm.ring_segments = 8
		ring.mesh = tm
		ring.position = Vector3(side * 1.10, 0.67, 0)
		ring.rotation = Vector3(0, 0, PI * 0.5)
		ring.material_override = _mat(accent, 0.45, 0.34)
		add_child(ring)
	# 锁扣
	var lock := _accent_box(self, Vector3(0, 0.55, 0.75), Vector3(0.34, 0.42, 0.10))
	_lock_mat = lock.material_override
	_box(self, Vector3(0, 0.55, 0.81), Vector3(0.13, 0.10, 0.04), Color(0.10, 0.08, 0.06))
	# 铆钉
	for x in [-0.86, 0.0, 0.86]:
		_rivet(self, Vector3(x, 0.32, 0.735))
		_rivet(self, Vector3(x, 0.88, 0.735))
	# 盖子
	lid_pivot = Node3D.new()
	lid_pivot.position = Vector3(0, 1.10, -0.70)
	add_child(lid_pivot)
	_box(lid_pivot, Vector3(0, 0.02, 0.70), Vector3(2.14, 0.18, 1.40), WOOD_DARK)
	_box(lid_pivot, Vector3(0, 0.13, 0.70), Vector3(2.10, 0.20, 1.36), WOOD)
	# 拱形盖：圆柱沿 X 轴
	var arch := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.66
	cm.bottom_radius = 0.66
	cm.height = 2.10
	cm.radial_segments = 28
	arch.mesh = cm
	arch.position = Vector3(0, 0.22, 0.70)
	arch.rotation = Vector3(0, 0, PI * 0.5)
	arch.material_override = _mat(WOOD_LIGHT, 0.0, 0.5)
	lid_pivot.add_child(arch)
	# 盖顶金条 + 两端金箍
	_accent_box(lid_pivot, Vector3(0, 0.90, 0.70), Vector3(2.12, 0.07, 0.18))
	for x in [-0.94, 0.0, 0.94]:
		_accent_box(lid_pivot, Vector3(x, 0.20, 0.70), Vector3(0.075, 0.34, 1.38))
	for x in [-0.98, 0.98]:
		_accent_box(lid_pivot, Vector3(x, 0.20, 0.70), Vector3(0.08, 0.24, 1.40))
		_rivet(lid_pivot, Vector3(x, 0.42, 0.72))
	# 盖锁扣
	_accent_box(lid_pivot, Vector3(0, 0.15, 1.40), Vector3(0.26, 0.20, 0.08))
	# 光
	_glow = OmniLight3D.new()
	_glow.light_color = accent
	_glow.light_energy = 0.7
	_glow.omni_range = 4.5
	_glow.position = Vector3(0, 1.25, 0.45)
	add_child(_glow)

func set_accent(c: Color) -> void:
	accent = c
	if _band_mat:
		_band_mat.albedo_color = c
	if _lock_mat:
		_lock_mat.albedo_color = Color(1.0, 0.88, 0.42).lerp(c, 0.4)
	for m in _accent_mats:
		if m:
			m.albedo_color = c
	if _glow:
		_glow.light_color = c

func shake(strength: float = 0.08) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", strength, 0.05)
	tw.tween_property(self, "position:x", -strength, 0.06)
	tw.tween_property(self, "position:x", strength * 0.5, 0.05)
	tw.tween_property(self, "position:x", 0.0, 0.06)

func open_lid() -> void:
	var tw := create_tween()
	tw.tween_property(lid_pivot, "rotation:x", -1.45, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3(1.08, 1.08, 1.08), 0.15)
	tw.tween_property(self, "scale", Vector3.ONE, 0.20)
	if _glow:
		var gt := create_tween()
		gt.tween_property(_glow, "light_energy", 3.2, 0.25)
		gt.tween_property(_glow, "light_energy", 1.0, 0.8)
