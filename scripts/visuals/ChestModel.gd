extends Node3D

var lid_pivot: Node3D
var accent: Color = Color(1.0, 0.78, 0.26)
var _band_mat: StandardMaterial3D
var _lock_mat: StandardMaterial3D
var _glow: OmniLight3D

func _ready():
	_build()
	shake(0.01)

func _mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
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

func _build():
	var wood := Color(0.45, 0.25, 0.12)
	var wood_dark := Color(0.30, 0.16, 0.08)
	_box(self, Vector3(0, 0.55, 0), Vector3(2.1, 1.1, 1.4), wood)
	_box(self, Vector3(0, 0.08, 0), Vector3(2.2, 0.16, 1.5), wood_dark)
	for z in [-0.55, 0.0, 0.55]:
		var band := _box(self, Vector3(0, 0.56, z), Vector3(2.16, 1.14, 0.10), accent, 0.35)
		band.material_override = _mat(accent, 0.35)
	_band_mat = _mat(accent, 0.35)
	# 锁扣
	var lock := _box(self, Vector3(0, 0.55, 0.73), Vector3(0.34, 0.40, 0.08), Color(1.0, 0.88, 0.42), 0.5)
	_lock_mat = lock.material_override
	# 盖子
	lid_pivot = Node3D.new()
	lid_pivot.position = Vector3(0, 1.10, -0.70)
	add_child(lid_pivot)
	_box(lid_pivot, Vector3(0, 0.05, 0.70), Vector3(2.14, 0.32, 1.40), wood)
	_box(lid_pivot, Vector3(0, 0.22, 0.70), Vector3(2.16, 0.08, 1.42), accent, 0.35)
	for z in [-0.50, 0.0, 0.50]:
		_box(lid_pivot, Vector3(0, 0.06, 0.70 + z), Vector3(2.18, 0.34, 0.10), accent, 0.35)
	_glow = OmniLight3D.new()
	_glow.light_color = accent
	_glow.light_energy = 0.6
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.2, 0.4)
	add_child(_glow)

func set_accent(c: Color) -> void:
	accent = c
	if _band_mat:
		_band_mat.albedo_color = c
	if _lock_mat:
		_lock_mat.albedo_color = Color(1.0, 0.88, 0.42).lerp(c, 0.4)
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
