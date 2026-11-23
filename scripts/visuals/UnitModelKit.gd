extends RefCounted
# ============================================================
# 程序化单位模型套件（玩具沙盘风格）
# 所有单位由基础几何体拼装，顶点色 + 卡通着色，统一风格、零外部资源
# 使用方式：UnitModelKit.create_unit(spec) -> Node3D
# ============================================================

const VISUAL_SCALE := 1.5
const TOON_SHADER := "res://assets/shaders/toon_unit.gdshader"
const OUTLINE_SHADER := "res://assets/shaders/toon_outline.gdshader"

# ---------------- 基础色板 ----------------
const COL_SKIN := Color(0.93, 0.74, 0.58)
const COL_SKIN_DARK := Color(0.80, 0.60, 0.44)
const COL_STEEL := Color(0.72, 0.77, 0.85)
const COL_STEEL_DARK := Color(0.42, 0.46, 0.55)
const COL_IRON := Color(0.33, 0.36, 0.43)
const COL_GOLD := Color(0.93, 0.70, 0.26)
const COL_LEATHER := Color(0.42, 0.28, 0.19)
const COL_LEATHER_LIGHT := Color(0.60, 0.42, 0.28)
const COL_WOOD := Color(0.62, 0.42, 0.25)
const COL_WOOD_DARK := Color(0.45, 0.30, 0.19)
const COL_STONE := Color(0.68, 0.65, 0.59)
const COL_STONE_DARK := Color(0.50, 0.48, 0.44)
const COL_BONE := Color(0.90, 0.87, 0.77)
const COL_CLOTH := Color(0.88, 0.83, 0.72)
const COL_DARK := Color(0.13, 0.14, 0.19)

const COL_TEAM_PLAYER := Color(0.16, 0.45, 0.90)
const COL_TEAM_ENEMY := Color(0.88, 0.20, 0.22)

static var _cache: Dictionary = {}
static var _toon_mat: ShaderMaterial
static var _shadow_tex: GradientTexture2D
static var _shadow_mat: StandardMaterial3D

# ============================================================
# Geo：把各种基础几何变换后累积成单个 ArrayMesh（顶点色）
# ============================================================
class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func add_prim(m: Mesh, xf: Transform3D, col: Color) -> void:
		var arrays: Array = m.surface_get_arrays(0)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var inds: Variant = arrays[Mesh.ARRAY_INDEX]
		var base: int = v.size()
		var nb: Basis = xf.basis.inverse().transposed()
		for i in vs.size():
			var p: Vector3 = xf * vs[i]
			v.append(p)
			if i < ns.size():
				n.append((nb * ns[i]).normalized())
			else:
				n.append(Vector3.UP)
			# 假 AO：越靠地面越暗一点，增加体积感
			var ao: float = 0.84 + 0.16 * clampf(p.y / 1.15, 0.0, 1.0)
			c.append(Color(col.r * ao, col.g * ao, col.b * ao, 1.0))
		if inds is PackedInt32Array and (inds as PackedInt32Array).size() > 0:
			for i in (inds as PackedInt32Array):
				idx.append(base + i)
		else:
			for i in vs.size():
				idx.append(base + i)

	func box(pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
		var m := BoxMesh.new()
		m.size = size
		add_prim(m, Transform3D(Basis.from_euler(rot), pos), col)

	func sphere(pos: Vector3, radius: float, col: Color, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> void:
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = 16
		m.rings = 8
		var b := Basis.from_euler(rot) * Basis.from_scale(Vector3(scl.x, scl.y, scl.z))
		add_prim(m, Transform3D(b, pos), col)

	func capsule(pos: Vector3, radius: float, height: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(height, radius * 2.0 + 0.001)
		m.radial_segments = 12
		m.rings = 5
		add_prim(m, Transform3D(Basis.from_euler(rot), pos), col)

	func cyl(pos: Vector3, r_top: float, r_bottom: float, height: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bottom
		m.height = height
		m.radial_segments = 14
		m.rings = 1
		add_prim(m, Transform3D(Basis.from_euler(rot), pos), col)

	func cone(pos: Vector3, radius: float, height: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
		cyl(pos, 0.0, radius, height, col, rot)

	func torus(pos: Vector3, inner: float, outer: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 18
		m.ring_segments = 8
		add_prim(m, Transform3D(Basis.from_euler(rot), pos), col)

	func prism(pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, left_to_right: float = 0.5) -> void:
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left_to_right
		add_prim(m, Transform3D(Basis.from_euler(rot), pos), col)

	# 两点之间的圆柱（用于手臂/腿/武器杆）
	func limb(a: Vector3, b: Vector3, radius: float, col: Color) -> void:
		var d: Vector3 = b - a
		var l: float = d.length()
		if l < 0.001:
			return
		var up: Vector3 = d.normalized()
		var rot: Basis = Basis(Quaternion(Vector3.UP, up))
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(l, radius * 2.0 + 0.001)
		m.radial_segments = 12
		m.rings = 5
		add_prim(m, Transform3D(rot, (a + b) * 0.5), col)

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return am

# ============================================================
# 材质
# ============================================================
static func toon_material() -> ShaderMaterial:
	if _toon_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load(TOON_SHADER)
		var o := ShaderMaterial.new()
		o.shader = load(OUTLINE_SHADER)
		o.set_shader_parameter("width", 0.020)
		m.next_pass = o
		# 兼容渲染器(OpenGL)会自动把顶点色转成线性，避免二次转换变黑
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			m.set_shader_parameter("vertex_srgb", 0.0)
		_toon_mat = m
	return _toon_mat

static func contact_shadow(radius: float) -> MeshInstance3D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.60))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_shadow_tex = t
	if _shadow_mat == null:
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = _shadow_tex
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_shadow_mat = mm
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.6)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position.y = 0.02
	mi.material_override = _shadow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ============================================================
# 对外入口
# ============================================================
static func create_unit(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "UnitVisual"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh_for(spec, "body")
	body.material_override = toon_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(body)
	# 双腿独立节点（走路摆动）
	if has_legs(spec):
		var ts: float = spec.get("torso_scale", 1.0)
		var y0: float = spec.get("lift", 0.0)
		var leg_mesh := mesh_for(spec, "legs")
		for side in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			leg.name = "LegL" if side < 0.0 else "LegR"
			leg.mesh = leg_mesh
			leg.material_override = toon_material()
			leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			leg.position = Vector3(side * 0.105 * ts, 0.30 + y0, 0.0)
			body.add_child(leg)
	# 武器单独成节点，方便程序化动画挥动（枢轴在手上）
	if has_weapon(spec):
		var w := MeshInstance3D.new()
		w.name = "Weapon"
		w.mesh = mesh_for(spec, "weapon")
		w.material_override = toon_material()
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		w.position = hand_position(spec)
		body.add_child(w)
	# 塔顶炮台：独立节点，由 Unit 转向攻击目标
	if bool(spec.get("turret", false)):
		var t := MeshInstance3D.new()
		t.name = "Turret"
		t.mesh = mesh_for(spec, "turret")
		t.material_override = toon_material()
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		t.position = Vector3(0, float(spec.get("turret_y", 1.2)), 0) + Vector3(float(spec.get("turret_off_x", 0.0)), 0.0, float(spec.get("turret_off_z", 0.0)))
		body.add_child(t)
	var h: float = spec.get("height", 1.0)
	var mul: float = spec.get("scale_mul", 1.0)
	root.scale = Vector3.ONE * h * VISUAL_SCALE * mul
	return root

static func _add_held_boulder(g: Geo) -> void:
	# 手里石头与实际石头子弹同尺寸（子弹 boulder 世界半径约 0.88，模型 root scale≈3.3 → 本地半径≈0.267）
	g.sphere(Vector3(0, 0.66, 0.36), 0.267, Color(0.52, 0.52, 0.50))
	g.sphere(Vector3(-0.13, 0.63, 0.39), 0.157, Color(0.44, 0.44, 0.42))
	g.sphere(Vector3(0.12, 0.60, 0.34), 0.149, Color(0.60, 0.59, 0.56))
	g.sphere(Vector3(0.02, 0.79, 0.30), 0.126, Color(0.48, 0.48, 0.46))
	g.box(Vector3(-0.05, 0.48, 0.39), Vector3(0.13, 0.08, 0.10), Color(0.40, 0.40, 0.38))

static func has_legs(spec: Dictionary) -> bool:
	if String(spec.get("archetype", "humanoid")) != "humanoid":
		return false
	return not bool(spec.get("robe", false))

static func _build_legs(g: Geo, p: Dictionary) -> void:
	var ls: float = p.get("limb_scale", 1.0)
	var pants: Color = p.get("pants", Color(0.26, 0.29, 0.38))
	var boot: Color = p.get("boot", COL_LEATHER_LIGHT)
	g.limb(Vector3.ZERO, Vector3(0, -0.20, 0), 0.078 * ls, pants)
	g.box(Vector3(0, -0.235, 0.05), Vector3(0.19, 0.13, 0.30), boot)
	g.box(Vector3(0, -0.16, 0.06), Vector3(0.18, 0.035, 0.235), COL_LEATHER)

static func has_weapon(spec: Dictionary) -> bool:
	if String(spec.get("archetype", "humanoid")) != "humanoid":
		return false
	return String(spec.get("weapon", "none")) not in ["none", ""]

static func hand_position(spec: Dictionary) -> Vector3:
	var ts: float = spec.get("torso_scale", 1.0)
	var y0: float = spec.get("lift", 0.0)
	return Vector3(0.235 * ts, 0.35 + y0, 0.065)

static func mesh_for(spec: Dictionary, part: String = "body") -> ArrayMesh:
	var key: String = str(spec) + "|" + part
	if _cache.has(key):
		return _cache[key]
	var g := Geo.new()
	var arch: String = String(spec.get("archetype", "humanoid"))
	if part == "weapon":
		_build_weapon(g, String(spec.get("weapon", "none")), Vector3.ZERO,
			Color(spec.get("accent", COL_TEAM_PLAYER)),
			Color(spec.get("metal", COL_STEEL)),
			Color(spec.get("leather", COL_LEATHER)),
			Color(spec.get("glow", Color(1.0, 0.62, 0.25))),
			float(spec.get("limb_scale", 1.0)))
	elif part == "legs":
		_build_legs(g, spec)
	elif part == "turret":
		_build_turret(g, spec)
	else:
		match arch:
			"humanoid":
				build_humanoid(g, spec)
				if bool(spec.get("held_boulder", false)):
					_add_held_boulder(g)
			"dragon":
				build_dragon(g, spec)
			"building":
				build_building(g, spec)
			"barrel":
				build_barrel(g, spec)
			"spirit":
				build_spirit(g, spec)
			"balloon":
				build_balloon(g, spec)
			"bush":
				build_bush(g, spec)
			"cannon_cart":
				build_cannon_cart(g, spec)
			"crossbow":
				build_crossbow(g, spec)
			"sparky":
				build_sparky(g, spec)
			"ram":
				build_ram(g, spec)
			"winged":
				build_winged(g, spec)
			"egg":
				build_egg(g, spec)
			"flying_machine":
				build_flying_machine(g, spec)
			"boar_rider":
				build_boar(g, spec, true)
			"boar":
				build_boar(g, spec, false)
			"ram_rider":
				build_ram_mount(g, spec, true)
			"zappy":
				build_zappy(g, spec)
			_:
				build_humanoid(g, spec)

	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m

# ============================================================
# 人形（战士/弓手/法师/骷髅/巨人）
# ============================================================
static func build_humanoid(g: Geo, p: Dictionary) -> void:
	var body: Color = p.get("body", COL_TEAM_PLAYER)
	var pants: Color = p.get("pants", body.darkened(0.42))
	var skin: Color = p.get("skin", COL_SKIN)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var metal: Color = p.get("metal", COL_STEEL)
	var leather: Color = p.get("leather", COL_LEATHER)
	var cloth: Color = p.get("cloth", COL_CLOTH)
	var hs: float = p.get("head_scale", 1.0)
	var ls: float = p.get("limb_scale", 1.0)
	var ts: float = p.get("torso_scale", 1.0)
	var bare_arms: bool = p.get("bare_arms", false)
	var armor: bool = p.get("armor", false)
	var pauldrons: bool = p.get("pauldrons", false)
	var robe: bool = p.get("robe", false)
	var y0: float = p.get("lift", 0.0)

	# ---- 下肢：长袍直接画在身体上；裤子/靴子拆成独立 LegL/LegR 节点（走路动画用） ----
	if robe:
		g.cyl(Vector3(0, 0.20 + y0, 0), 0.18 * ts, 0.31 * ts, 0.40, body)
		g.torus(Vector3(0, 0.045 + y0, 0), 0.30, 0.325, accent)

	# ---- 髋 / 腰带 ----
	g.box(Vector3(0, 0.345 + y0, 0), Vector3(0.30 * ts, 0.14, 0.20 * ts), pants)
	g.box(Vector3(0, 0.375 + y0, 0), Vector3(0.32 * ts, 0.055, 0.22 * ts), leather)
	g.box(Vector3(0, 0.375 + y0, 0.115 * ts), Vector3(0.08, 0.05, 0.025), accent)

	# ---- 躯干（短而圆） ----
	g.capsule(Vector3(0, 0.49 + y0, 0), 0.158 * ts, 0.26 * ts, body)
	if not armor:
		g.box(Vector3(0, 0.525 + y0, 0.130 * ts), Vector3(0.22 * ts, 0.04, 0.02), accent)
	if armor:
		g.box(Vector3(0, 0.520 + y0, 0.005), Vector3(0.285 * ts, 0.155, 0.24 * ts), metal)
		g.box(Vector3(0, 0.520 + y0, 0.125 * ts), Vector3(0.29 * ts, 0.045, 0.02), accent)
		g.cyl(Vector3(0, 0.618 + y0, 0), 0.082, 0.092, 0.035, metal)
	if p.get("tabard", false):
		g.box(Vector3(0, 0.40 + y0, 0.163 * ts), Vector3(0.14, 0.34, 0.02), accent)
		g.box(Vector3(0, 0.245 + y0, 0.163 * ts), Vector3(0.14, 0.05, 0.02), COL_GOLD)
	if p.get("fur_collar", false):
		g.torus(Vector3(0, 0.598 + y0, 0), 0.082, 0.125, cloth)

	# ---- 披风 ----
	if p.get("cape_on", false):
		g.prism(Vector3(0, 0.45 + y0, -0.20 * ts), Vector3(0.44 * ts, 0.50, 0.028), accent, Vector3(-0.10, 0, 0), 0.5)

	# ---- 肩 / 臂（短臂 + 大手掌） ----
	var sh_x: float = 0.185 * ts
	if pauldrons:
		g.sphere(Vector3(-sh_x, 0.60 + y0, 0), 0.105 * ls, metal, Vector3(1.0, 0.78, 1.0))
		g.sphere(Vector3(sh_x, 0.60 + y0, 0), 0.105 * ls, metal, Vector3(1.0, 0.78, 1.0))
	var sleeve: Color = skin if bare_arms else body
	var hand_l := Vector3(-0.235 * ts, 0.35 + y0, 0.065)
	var hand_r := Vector3(0.235 * ts, 0.35 + y0, 0.065)
	g.limb(Vector3(-sh_x, 0.575 + y0, 0), hand_l, 0.058 * ls, sleeve)
	g.limb(Vector3(sh_x, 0.575 + y0, 0), hand_r, 0.058 * ls, sleeve)
	if armor:
		g.cyl(Vector3(-0.212 * ts, 0.44 + y0, 0.045), 0.065, 0.060, 0.10, metal)
		g.cyl(Vector3(0.212 * ts, 0.44 + y0, 0.045), 0.065, 0.060, 0.10, metal)
	g.sphere(hand_l, 0.070 * ls, leather, Vector3(1.0, 0.9, 1.0))
	g.sphere(hand_r, 0.070 * ls, leather, Vector3(1.0, 0.9, 1.0))

	# ---- 颈 / 头（大头 Q 版） ----
	g.cyl(Vector3(0, 0.615 + y0, 0), 0.05, 0.06, 0.06, skin)
	var hy: float = 0.755 + y0
	g.sphere(Vector3(0, hy, 0), 0.145 * hs, skin, Vector3(1.0, 1.04, 0.98))
	# 大眼（眼白 + 瞳孔 + 高光）
	g.sphere(Vector3(-0.055 * hs, hy + 0.020, 0.135 * hs), 0.040 * hs, Color(0.98, 0.98, 0.95), Vector3(1.0, 1.18, 0.50))
	g.sphere(Vector3(0.055 * hs, hy + 0.020, 0.135 * hs), 0.040 * hs, Color(0.98, 0.98, 0.95), Vector3(1.0, 1.18, 0.50))
	g.sphere(Vector3(-0.055 * hs, hy + 0.015, 0.152 * hs), 0.020 * hs, COL_DARK, Vector3(1.0, 1.15, 0.50))
	g.sphere(Vector3(0.055 * hs, hy + 0.015, 0.152 * hs), 0.020 * hs, COL_DARK, Vector3(1.0, 1.15, 0.50))
	g.sphere(Vector3(-0.055 * hs, hy + 0.032, 0.158 * hs), 0.008 * hs, Color(1, 1, 1), Vector3(1.0, 1.0, 0.5))
	g.sphere(Vector3(0.055 * hs, hy + 0.032, 0.158 * hs), 0.008 * hs, Color(1, 1, 1), Vector3(1.0, 1.0, 0.5))
	# 腮红
	g.sphere(Vector3(-0.105 * hs, hy - 0.030, 0.105 * hs), 0.032 * hs, Color(0.96, 0.56, 0.52), Vector3(1.0, 0.70, 0.35))
	g.sphere(Vector3(0.105 * hs, hy - 0.030, 0.105 * hs), 0.032 * hs, Color(0.96, 0.56, 0.52), Vector3(1.0, 0.70, 0.35))
	# 眉毛
	g.box(Vector3(-0.058 * hs, hy + 0.080, 0.128 * hs), Vector3(0.052, 0.014, 0.014), Color(0.25, 0.19, 0.16), Vector3(0, 0, 0.10))
	g.box(Vector3(0.058 * hs, hy + 0.080, 0.128 * hs), Vector3(0.052, 0.014, 0.014), Color(0.25, 0.19, 0.16), Vector3(0, 0, -0.10))
	# 鼻子 / 嘴
	g.sphere(Vector3(0, hy - 0.022, 0.142 * hs), 0.019 * hs, skin.darkened(0.10), Vector3(1.0, 0.9, 1.0))
	g.box(Vector3(0, hy - 0.078, 0.132 * hs), Vector3(0.048, 0.013, 0.014), Color(0.42, 0.24, 0.22))

	_build_headgear(g, p, hy, hs * 1.38, accent, metal, cloth, skin)

	if p.get("beard", false):
		g.sphere(Vector3(0, hy - 0.105, 0.090 * hs), 0.078 * hs, p.get("beard_color", Color(0.92, 0.90, 0.86)), Vector3(1.15, 1.20, 0.85))

	# ---- 翅膀 ----
	if p.get("wings", false):
		g.prism(Vector3(-0.37, 0.60 + y0, -0.05), Vector3(0.52, 0.30, 0.035), accent, Vector3(0.10, 0.42, 0.62), 0.0)
		g.prism(Vector3(0.37, 0.60 + y0, -0.05), Vector3(0.52, 0.30, 0.035), accent, Vector3(0.10, -0.42, -0.62), 0.0)

	# ---- 盾牌（左手）----
	if p.get("shield", false):
		var sc: Color = p.get("shield_color", accent)
		g.cyl(Vector3(-0.30 * ts, 0.42 + y0, 0.13), 0.195, 0.195, 0.045, sc, Vector3(PI * 0.5, 0, 0))
		g.torus(Vector3(-0.30 * ts, 0.42 + y0, 0.145), 0.160, 0.205, metal, Vector3(PI * 0.5, 0, 0))
		g.sphere(Vector3(-0.30 * ts, 0.42 + y0, 0.165), 0.055, metal, Vector3(1.0, 0.55, 1.0))
		g.box(Vector3(-0.30 * ts, 0.42 + y0, 0.157), Vector3(0.055, 0.34, 0.012), metal, Vector3(0, 0, 0.62))

static func _build_headgear(g: Geo, p: Dictionary, head_y: float, hs: float, accent: Color, metal: Color, cloth: Color, skin: Color) -> void:
	var hair_col: Color = p.get("hair_color", Color(0.30, 0.22, 0.17))
	match String(p.get("helmet", "none")):
		"helm":
			g.sphere(Vector3(0, head_y + 0.040, -0.006), 0.112 * hs, metal, Vector3(1.05, 0.72, 1.05))
			g.torus(Vector3(0, head_y + 0.015, -0.004), 0.098, 0.118, COL_STEEL_DARK, Vector3(0.06, 0, 0))
			g.box(Vector3(-0.096 * hs, head_y - 0.030, 0.045), Vector3(0.030, 0.090, 0.085), metal)
			g.box(Vector3(0.096 * hs, head_y - 0.030, 0.045), Vector3(0.030, 0.090, 0.085), metal)
			g.box(Vector3(0, head_y - 0.008, 0.108 * hs), Vector3(0.026, 0.095, 0.022), metal)
			g.box(Vector3(0, head_y + 0.135, -0.020), Vector3(0.032, 0.150, 0.090), accent, Vector3(0.25, 0, 0))
		"horns":
			g.sphere(Vector3(0, head_y + 0.038, -0.004), 0.110 * hs, metal, Vector3(1.04, 0.66, 1.04))
			g.cone(Vector3(-0.105 * hs, head_y + 0.095, 0.005), 0.050, 0.24, COL_BONE, Vector3(0, 0, 0.85))
			g.cone(Vector3(0.105 * hs, head_y + 0.095, 0.005), 0.050, 0.24, COL_BONE, Vector3(0, 0, -0.85))
		"crown":
			g.cyl(Vector3(0, head_y + 0.080, 0), 0.098 * hs, 0.108 * hs, 0.055, COL_GOLD)
			for i in 5:
				var a: float = TAU * float(i) / 5.0
				g.cone(Vector3(cos(a) * 0.082 * hs, head_y + 0.140, sin(a) * 0.082 * hs), 0.030, 0.095, COL_GOLD)
			g.sphere(Vector3(0, head_y + 0.088, 0.098 * hs), 0.022, accent)
		"hood":
			g.sphere(Vector3(0, head_y + 0.030, -0.030), 0.122 * hs, cloth, Vector3(1.06, 0.98, 0.98))
			g.cone(Vector3(0, head_y + 0.140, -0.080), 0.062, 0.18, cloth, Vector3(-0.45, 0, 0))
			g.torus(Vector3(0, head_y - 0.10, 0), 0.06, 0.095, accent)
		"wizard":
			g.cyl(Vector3(0, head_y + 0.062, 0), 0.170 * hs, 0.175 * hs, 0.025, cloth)
			g.cyl(Vector3(0, head_y + 0.080, 0), 0.108 * hs, 0.112 * hs, 0.030, accent)
			g.cone(Vector3(0, head_y + 0.235, -0.005), 0.108 * hs, 0.31, cloth, Vector3(0.10, 0, 0))
			g.sphere(Vector3(0, head_y + 0.390, -0.030), 0.030, COL_GOLD)
		"skull":
			g.sphere(Vector3(0, head_y + 0.010, 0.005), 0.106 * hs, COL_BONE, Vector3(1.0, 1.08, 0.96))
			g.box(Vector3(0, head_y - 0.078, 0.045), Vector3(0.115 * hs, 0.055, 0.095), COL_BONE)
			for i in 3:
				g.box(Vector3(-0.030 + float(i) * 0.030, head_y - 0.062, 0.092), Vector3(0.017, 0.024, 0.012), COL_DARK)
			g.sphere(Vector3(-0.040 * hs, head_y + 0.015, 0.096 * hs), 0.027 * hs, COL_DARK, Vector3(1.0, 1.25, 0.6))
			g.sphere(Vector3(0.040 * hs, head_y + 0.015, 0.096 * hs), 0.027 * hs, COL_DARK, Vector3(1.0, 1.25, 0.6))
			g.box(Vector3(0, head_y - 0.012, 0.104 * hs), Vector3(0.018, 0.024, 0.012), COL_DARK)
			g.sphere(Vector3(0, head_y + 0.075, 0.0), 0.085 * hs, COL_BONE, Vector3(1.05, 0.55, 1.0))
		"hair":
			g.sphere(Vector3(0, head_y + 0.032, -0.012), 0.108 * hs, hair_col, Vector3(1.05, 0.62, 1.05))
			g.box(Vector3(-0.088 * hs, head_y + 0.005, 0.02), Vector3(0.035, 0.10, 0.10), hair_col)
			g.box(Vector3(0.088 * hs, head_y + 0.005, 0.02), Vector3(0.035, 0.10, 0.10), hair_col)
		"cap":
			g.sphere(Vector3(0, head_y + 0.045, -0.004), 0.108 * hs, accent, Vector3(1.03, 0.66, 1.03))
			g.box(Vector3(0, head_y + 0.055, 0.10 * hs), Vector3(0.11, 0.018, 0.07), accent)
		_:
			pass

static func _build_weapon(g: Geo, weapon: String, hand: Vector3, accent: Color, metal: Color, leather: Color, glow: Color, ls: float) -> void:
	var hx: float = hand.x
	var hy: float = hand.y
	var hz: float = hand.z
	match weapon:
		"sword":
			g.box(Vector3(hx + 0.02, hy + 0.31, hz + 0.05), Vector3(0.055, 0.54, 0.085), metal, Vector3(-0.10, 0, 0.05))
			g.cone(Vector3(hx + 0.02, hy + 0.60, hz + 0.05), 0.038, 0.10, metal)
			g.box(Vector3(hx + 0.02, hy + 0.030, hz + 0.05), Vector3(0.19, 0.038, 0.075), COL_GOLD)
			g.cyl(Vector3(hx + 0.02, hy - 0.055, hz + 0.05), 0.024, 0.024, 0.13, leather)
			g.sphere(Vector3(hx + 0.02, hy - 0.125, hz + 0.05), 0.035, COL_GOLD)
		"big_sword":
			g.box(Vector3(hx + 0.03, hy + 0.40, hz + 0.06), Vector3(0.105, 0.78, 0.15), metal, Vector3(-0.08, 0, 0.04))
			g.cone(Vector3(hx + 0.03, hy + 0.83, hz + 0.06), 0.072, 0.16, metal)
			g.box(Vector3(hx + 0.03, hy + 0.020, hz + 0.06), Vector3(0.28, 0.055, 0.10), COL_GOLD)
			g.cyl(Vector3(hx + 0.03, hy - 0.085, hz + 0.06), 0.030, 0.030, 0.16, leather)
			g.sphere(Vector3(hx + 0.03, hy - 0.175, hz + 0.06), 0.045, COL_GOLD)
		"axe":
			g.cyl(Vector3(hx + 0.02, hy + 0.22, hz + 0.045), 0.022, 0.024, 0.72, leather)
			g.box(Vector3(hx + 0.12, hy + 0.42, hz + 0.045), Vector3(0.20, 0.17, 0.05), COL_STEEL, Vector3(0, 0, 0.18))
			g.box(Vector3(hx - 0.08, hy + 0.42, hz + 0.045), Vector3(0.14, 0.15, 0.05), COL_STEEL, Vector3(0, 0, -0.18))
		"bow":
			g.torus(Vector3(hx + 0.05, hy + 0.10, hz + 0.14), 0.155, 0.185, COL_WOOD, Vector3(0, 0, 0.30))
			g.box(Vector3(hx + 0.02, hy + 0.10, hz + 0.14), Vector3(0.008, 0.34, 0.008), COL_CLOTH, Vector3(0, 0, 0.30))
			g.cyl(Vector3(hx + 0.02, hy + 0.10, hz + 0.30), 0.009, 0.009, 0.34, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(hx + 0.02, hy + 0.10, hz + 0.49), 0.022, 0.06, metal, Vector3(PI * 0.5, 0, 0))
		"staff":
			g.cyl(Vector3(hx + 0.02, hy + 0.18, hz + 0.075), 0.025, 0.027, 0.80, leather)
			g.sphere(Vector3(hx + 0.02, hy + 0.60, hz + 0.075), 0.088, glow, Vector3(1, 1, 1))
			g.torus(Vector3(hx + 0.02, hy + 0.60, hz + 0.075), 0.088, 0.112, COL_GOLD, Vector3(PI * 0.5, 0, 0))
			g.sphere(Vector3(hx + 0.13, hy + 0.70, hz + 0.075), 0.030, glow)
			g.sphere(Vector3(hx - 0.09, hy + 0.72, hz + 0.075), 0.024, glow)
		"spear":
			g.cyl(Vector3(hx + 0.02, hy + 0.22, hz + 0.05), 0.019, 0.021, 0.98, leather)
			g.cone(Vector3(hx + 0.02, hy + 0.78, hz + 0.05), 0.055, 0.26, metal)
			g.torus(Vector3(hx + 0.02, hy + 0.63, hz + 0.05), 0.030, 0.048, accent, Vector3(PI * 0.5, 0, 0))
		"musket":
			g.box(Vector3(hx + 0.02, hy + 0.01, hz + 0.10), Vector3(0.07, 0.11, 0.34), COL_WOOD, Vector3(0.10, 0, 0))
			g.cyl(Vector3(hx + 0.02, hy + 0.075, hz + 0.34), 0.028, 0.032, 0.44, COL_IRON, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(hx + 0.02, hy + 0.075, hz + 0.55), 0.040, 0.040, 0.05, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(hx + 0.02, hy + 0.10, hz + 0.16), Vector3(0.05, 0.03, 0.08), COL_STEEL_DARK)
		"hammer":
			g.cyl(Vector3(hx + 0.02, hy + 0.16, hz + 0.05), 0.023, 0.025, 0.54, leather)
			g.box(Vector3(hx + 0.02, hy + 0.40, hz + 0.05), Vector3(0.25, 0.16, 0.19), COL_IRON)
			g.box(Vector3(hx + 0.02, hy + 0.40, hz + 0.05), Vector3(0.27, 0.035, 0.21), accent)
		"club":
			g.cyl(Vector3(hx + 0.03, hy + 0.16, hz + 0.05), 0.055, 0.038, 0.52, COL_WOOD_DARK, Vector3(0, 0, -0.14))
			g.sphere(Vector3(hx + 0.06, hy + 0.45, hz + 0.07), 0.095, COL_WOOD_DARK, Vector3(1.0, 1.15, 1.0))
			g.sphere(Vector3(hx + 0.06, hy + 0.52, hz + 0.07), 0.045, COL_IRON, Vector3(1, 1, 1))
		"cannon":
			g.cyl(Vector3(hx + 0.10, hy + 0.12, hz + 0.16), 0.080, 0.100, 0.46, COL_IRON, Vector3(PI * 0.5, 0, 0.20))
			g.cyl(Vector3(hx + 0.10, hy + 0.12, hz + 0.40), 0.115, 0.115, 0.06, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0.20))
		"flask":
			g.sphere(Vector3(hx + 0.04, hy + 0.02, hz + 0.10), 0.080, glow, Vector3(0.85, 1.0, 0.85))
			g.cyl(Vector3(hx + 0.04, hy + 0.10, hz + 0.10), 0.024, 0.032, 0.07, COL_CLOTH)
		_:
			pass

# ============================================================
# 飞龙 / 蝙蝠 / 飞行单位
# ============================================================
static func build_dragon(g: Geo, p: Dictionary) -> void:
	var body: Color = p.get("body", Color(0.36, 0.58, 0.34))
	var belly: Color = p.get("belly", body.lightened(0.35))
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var horn: Color = p.get("horn", COL_BONE)
	var eye: Color = p.get("eye", Color(1.0, 0.82, 0.25))
	var y0: float = p.get("lift", 0.0)
	var ts: float = p.get("torso_scale", 1.0)
	var dark: Color = body.darkened(0.20)

	# 身体（更圆更短）
	g.sphere(Vector3(0, 0.80 + y0, -0.02), 0.275 * ts, body, Vector3(1.0, 0.92, 1.15))
	# 肚皮
	g.sphere(Vector3(0, 0.73 + y0, 0.085), 0.195 * ts, belly, Vector3(1.0, 0.72, 0.95))
	# 脖子
	g.limb(Vector3(0, 0.88 + y0, 0.09), Vector3(0, 0.96 + y0, 0.26), 0.11, body)
	# 头（大头 Q 版）
	g.sphere(Vector3(0, 0.98 + y0, 0.30), 0.185, body, Vector3(1.06, 1.0, 1.04))
	g.box(Vector3(0, 0.945 + y0, 0.46), Vector3(0.19, 0.115, 0.21), body, Vector3(0.10, 0, 0))
	g.box(Vector3(0, 0.898 + y0, 0.465), Vector3(0.155, 0.045, 0.19), dark, Vector3(0.10, 0, 0))
	g.sphere(Vector3(0, 0.975 + y0, 0.485), 0.055, belly, Vector3(1.2, 0.55, 0.6))
	# 大眼（眼白 + 瞳孔 + 高光）
	g.sphere(Vector3(-0.085, 1.02 + y0, 0.455), 0.055, Color(0.98, 0.98, 0.95), Vector3(1.0, 1.15, 0.55))
	g.sphere(Vector3(0.085, 1.02 + y0, 0.455), 0.055, Color(0.98, 0.98, 0.95), Vector3(1.0, 1.15, 0.55))
	g.sphere(Vector3(-0.085, 1.015 + y0, 0.492), 0.028, COL_DARK, Vector3(1.0, 1.15, 0.55))
	g.sphere(Vector3(0.085, 1.015 + y0, 0.492), 0.028, COL_DARK, Vector3(1.0, 1.15, 0.55))
	g.sphere(Vector3(-0.085, 1.033 + y0, 0.503), 0.011, Color(1, 1, 1), Vector3(1.0, 1.0, 0.5))
	g.sphere(Vector3(0.085, 1.033 + y0, 0.503), 0.011, Color(1, 1, 1), Vector3(1.0, 1.0, 0.5))
	# 角 + 头冠
	g.cone(Vector3(-0.105, 1.15 + y0, 0.25), 0.045, 0.20, horn, Vector3(0.45, 0, 0.35))
	g.cone(Vector3(0.105, 1.15 + y0, 0.25), 0.045, 0.20, horn, Vector3(0.45, 0, -0.35))
	g.prism(Vector3(0, 1.13 + y0, 0.26), Vector3(0.055, 0.11, 0.16), accent, Vector3(0, 0, 0), 0.0)
	# 背刺
	for i in 3:
		g.cone(Vector3(0, 1.05 + y0 + float(i) * 0.012, 0.10 - float(i) * 0.16), 0.032, 0.10, horn, Vector3(-0.55, 0, 0))
	# 翅膀（两层，增加剪影）
	g.prism(Vector3(-0.42, 0.92 + y0, -0.03), Vector3(0.56, 0.28, 0.030), body.lightened(0.22), Vector3(0.08, 0.50, 0.70), 0.0)
	g.prism(Vector3(0.42, 0.92 + y0, -0.03), Vector3(0.56, 0.28, 0.030), body.lightened(0.22), Vector3(0.08, -0.50, -0.70), 0.0)
	g.prism(Vector3(-0.32, 0.87 + y0, -0.10), Vector3(0.44, 0.22, 0.026), accent, Vector3(0.05, 0.40, 0.55), 0.0)
	g.prism(Vector3(0.32, 0.87 + y0, -0.10), Vector3(0.44, 0.22, 0.026), accent, Vector3(0.05, -0.40, -0.55), 0.0)
	# 尾巴
	g.cyl(Vector3(0, 0.74 + y0, -0.36), 0.095, 0.040, 0.36, body, Vector3(PI * 0.5 + 0.20, 0, 0))
	g.prism(Vector3(0, 0.685 + y0, -0.55), Vector3(0.20, 0.18, 0.025), accent, Vector3(0, 0, 0), 0.0)
	# 小短腿
	g.capsule(Vector3(-0.15, 0.58 + y0, 0.075), 0.068, 0.20, body)
	g.capsule(Vector3(0.15, 0.58 + y0, 0.075), 0.068, 0.20, body)
	g.sphere(Vector3(-0.15, 0.485 + y0, 0.11), 0.062, dark, Vector3(1.2, 0.7, 1.3))
	g.sphere(Vector3(0.15, 0.485 + y0, 0.11), 0.062, dark, Vector3(1.2, 0.7, 1.3))

# ============================================================
# 建筑（塔 / 炮 / 生成屋 / 墓碑）
# ============================================================
static func build_building(g: Geo, p: Dictionary) -> void:
	var kind: String = p.get("kind", "tower")
	var stone: Color = p.get("body", COL_STONE)
	var stone_dark: Color = p.get("stone_dark", COL_STONE_DARK)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var roof: Color = p.get("roof", accent.darkened(0.25))
	var wood: Color = p.get("wood", COL_WOOD)
	var metal: Color = p.get("metal", COL_IRON)

	match kind:
		"cannon":
			g.box(Vector3(0, 0.12, 0), Vector3(0.74, 0.24, 0.62), stone_dark)
			g.box(Vector3(0, 0.265, 0), Vector3(0.64, 0.10, 0.52), wood)
			g.cyl(Vector3(-0.34, 0.22, 0), 0.20, 0.20, 0.10, wood, Vector3(0, 0, PI * 0.5))
			g.cyl(Vector3(0.34, 0.22, 0), 0.20, 0.20, 0.10, wood, Vector3(0, 0, PI * 0.5))
			g.cyl(Vector3(-0.34, 0.22, 0), 0.10, 0.10, 0.11, COL_STEEL_DARK, Vector3(0, 0, PI * 0.5))
			g.cyl(Vector3(0.34, 0.22, 0), 0.10, 0.10, 0.11, COL_STEEL_DARK, Vector3(0, 0, PI * 0.5))

		"spawner":
			g.box(Vector3(0, 0.10, 0), Vector3(0.86, 0.20, 0.74), stone_dark)
			g.box(Vector3(0, 0.42, 0), Vector3(0.64, 0.44, 0.54), wood)
			g.box(Vector3(0, 0.32, 0), Vector3(0.68, 0.07, 0.58), COL_WOOD_DARK)
			g.box(Vector3(0, 0.62, 0.18), Vector3(0.62, 0.06, 0.20), COL_WOOD_DARK)
			g.prism(Vector3(0, 0.80, 0), Vector3(0.84, 0.44, 0.76), roof, Vector3(0, 0, 0), 0.5)
			g.box(Vector3(0, 0.34, 0.28), Vector3(0.20, 0.32, 0.02), COL_LEATHER)
			g.cyl(Vector3(-0.30, 0.72, -0.20), 0.014, 0.014, 0.32, COL_STEEL_DARK)
			g.box(Vector3(-0.22, 0.86, -0.20), Vector3(0.20, 0.12, 0.012), accent)
			g.torus(Vector3(0, 0.10, 0), 0.34, 0.38, accent)
		"tomb":
			g.sphere(Vector3(0, 0.06, 0), 0.44, Color(0.30, 0.34, 0.28), Vector3(1.0, 0.26, 0.85))
			g.box(Vector3(0, 0.36, 0), Vector3(0.36, 0.64, 0.17), stone)
			g.sphere(Vector3(0, 0.67, 0), 0.18, stone, Vector3(1.0, 0.72, 0.5))
			g.box(Vector3(0, 0.54, 0.095), Vector3(0.065, 0.36, 0.02), stone_dark)
			g.box(Vector3(0, 0.62, 0.095), Vector3(0.24, 0.065, 0.02), stone_dark)
			g.torus(Vector3(0, 0.10, 0), 0.34, 0.38, accent)
			g.box(Vector3(0.20, 0.16, 0.16), Vector3(0.10, 0.24, 0.08), stone_dark, Vector3(0.2, 0, 0.3))
		"furnace":
			g.cyl(Vector3(0, 0.10, 0), 0.44, 0.50, 0.20, stone_dark)
			g.box(Vector3(0, 0.38, 0), Vector3(0.72, 0.42, 0.72), stone)
			g.box(Vector3(0, 0.60, 0), Vector3(0.78, 0.08, 0.78), stone_dark)
			g.box(Vector3(0, 0.36, 0.37), Vector3(0.34, 0.24, 0.04), Color(0.16, 0.12, 0.10))
			g.sphere(Vector3(0, 0.38, 0.40), 0.13, Color(1.0, 0.55, 0.12))
			g.sphere(Vector3(0, 0.46, 0.41), 0.08, Color(1.0, 0.85, 0.35))
			g.cyl(Vector3(0.20, 0.86, -0.16), 0.09, 0.11, 0.36, metal)
			g.cyl(Vector3(0.20, 1.02, -0.16), 0.13, 0.13, 0.05, COL_STEEL_DARK)
			g.sphere(Vector3(-0.12, 0.78, 0), 0.12, Color(1.0, 0.50, 0.10))
			g.cone(Vector3(-0.12, 0.92, 0), 0.09, 0.22, Color(1.0, 0.70, 0.20))
			g.box(Vector3(-0.12, 0.70, 0.24), Vector3(0.26, 0.02, 0.02), COL_STEEL_DARK)
			g.torus(Vector3(0, 0.10, 0), 0.40, 0.44, accent)
		"drill":
			# 木头底座 + 支架 + 中央钻头
			g.box(Vector3(0, 0.10, 0), Vector3(0.92, 0.20, 0.92), COL_WOOD_DARK)
			g.box(Vector3(0, 0.24, 0), Vector3(0.78, 0.08, 0.78), wood)
			g.box(Vector3(-0.34, 0.66, -0.30), Vector3(0.08, 0.86, 0.08), metal)
			g.box(Vector3(0.34, 0.66, -0.30), Vector3(0.08, 0.86, 0.08), metal)
			g.box(Vector3(0, 1.06, -0.30), Vector3(0.78, 0.08, 0.08), metal)
			g.cyl(Vector3(0, 0.62, 0.02), 0.10, 0.10, 0.90, COL_STEEL_DARK)
			# 钻头（向下锥形 + 螺旋环）
			g.cone(Vector3(0, 0.16, 0.02), 0.26, 0.46, metal)
			g.cyl(Vector3(0, 0.42, 0.02), 0.22, 0.22, 0.10, COL_STEEL)
			for i in range(4):
				var yy: float = 0.26 + float(i) * 0.13
				g.cyl(Vector3(0, yy, 0.02), 0.20 - float(i) * 0.025, 0.20 - float(i) * 0.025, 0.035, Color(0.56, 0.48, 0.32))
			g.cyl(Vector3(0, 0.72, 0.02), 0.16, 0.16, 0.16, accent)
			g.sphere(Vector3(0, 0.86, 0.02), 0.10, Color(0.72, 0.58, 0.32))
		"elixir_pump":
			g.cyl(Vector3(0, 0.10, 0), 0.44, 0.50, 0.20, stone_dark)
			g.box(Vector3(0, 0.22, 0), Vector3(0.72, 0.10, 0.72), wood)
			# 紫色储液罐
			g.cyl(Vector3(-0.12, 0.66, 0), 0.30, 0.34, 0.78, Color(0.42, 0.22, 0.58))
			g.cyl(Vector3(-0.12, 0.66, 0), 0.24, 0.24, 0.62, Color(0.62, 0.34, 0.92))
			g.sphere(Vector3(-0.12, 0.66, 0.0), 0.22, Color(0.74, 0.44, 1.0), Vector3(1.0, 1.6, 1.0))
			g.torus(Vector3(-0.12, 1.03, 0), 0.26, 0.31, metal, Vector3(PI * 0.5, 0, 0))
			# 管道 + 出液口
			g.cyl(Vector3(0.24, 0.80, 0), 0.06, 0.06, 0.34, metal, Vector3(0, 0, PI * 0.5))
			g.cyl(Vector3(0.40, 0.62, 0), 0.055, 0.055, 0.40, metal)
			g.sphere(Vector3(0.40, 0.40, 0), 0.10, Color(0.74, 0.44, 1.0))
			# 提灯/阀门
			g.cyl(Vector3(0.24, 0.25, 0.22), 0.08, 0.10, 0.22, COL_STEEL_DARK)
			g.box(Vector3(0.24, 0.40, 0.22), Vector3(0.18, 0.04, 0.04), Color(0.72, 0.58, 0.32))
			g.torus(Vector3(0, 0.10, 0), 0.44, 0.48, accent)
		"cage":
			# 木头底座 + 金属栏杆笼
			g.box(Vector3(0, 0.10, 0), Vector3(0.86, 0.20, 0.86), COL_WOOD_DARK)
			g.box(Vector3(0, 0.22, 0), Vector3(0.78, 0.10, 0.78), wood)
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				var bx: float = cos(a) * 0.40
				var bz: float = sin(a) * 0.40
				g.box(Vector3(bx, 0.78, bz), Vector3(0.055, 1.05, 0.055), metal)
			g.torus(Vector3(0, 1.30, 0), 0.40, 0.46, metal, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0.26, 0), 0.40, 0.46, metal, Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(0, 1.31, 0), Vector3(0.86, 0.055, 0.86), COL_WOOD_DARK)
			g.torus(Vector3(0, 0.10, 0), 0.44, 0.48, accent)
		"tesla":
			g.cyl(Vector3(0, 0.15, 0), 0.46, 0.52, 0.30, stone_dark)
			g.cyl(Vector3(0, 0.18, 0), 0.50, 0.50, 0.05, stone)
			g.cyl(Vector3(0, 0.55, 0), 0.17, 0.22, 0.52, COL_STEEL_DARK)
			g.sphere(Vector3(0, 0.86, 0), 0.21, Color(0.45, 0.78, 1.0), Vector3(1, 1, 1))
			g.torus(Vector3(0, 0.86, 0), 0.20, 0.27, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0.62, 0), 0.27, 0.33, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0.115, 0), 0.40, 0.44, accent)
		"tower_princess":
			_tower_with_platform(g, p)
			_seated_figure(g, 1.19, "princess", p)
		"tower_cannon":
			_tower_with_platform(g, p)
			_seated_figure(g, 1.19, "prince", p)
		"tower_king":
			_tower_with_platform(g, p, 1.35)
			_seated_figure(g, 1.59, "king", p)
		"tower_chef":
			_tower_with_platform(g, p)
			_seated_figure(g, 1.19, "king", p)
			# 煎饼堆、厨师帽和专属平底锅
			for i in range(3):
				g.cyl(Vector3(0, 1.02 + i * 0.08, 0), 0.30 - i * 0.03, 0.30 - i * 0.03, 0.07, Color(0.98, 0.76, 0.32), Vector3.ZERO)
			g.cyl(Vector3(0, 1.48, 0), 0.20, 0.24, 0.10, Color(0.96, 0.94, 0.88), Vector3.ZERO)
			g.cyl(Vector3(-0.55, 1.18, 0.10), 0.23, 0.23, 0.05, Color(0.28, 0.30, 0.34), Vector3(0.25, 0, 0.15))
			g.box(Vector3(-0.55, 1.18, 0.42), Vector3(0.05, 0.05, 0.42), Color(0.44, 0.28, 0.16), Vector3(0.25, 0, 0.15))
		"tower_knife":
			_tower_with_platform(g, p)
			_seated_figure(g, 1.19, "prince", p)
			# 专属飞刀架与环形刀盘
			for i in range(4):
				var a: float = TAU * float(i) / 4.0
				g.box(Vector3(cos(a) * 0.42, 1.12 + i * 0.09, sin(a) * 0.42), Vector3(0.035, 0.28, 0.035), Color(0.78, 0.82, 0.88))
				g.cyl(Vector3(cos(a) * 0.42, 1.28 + i * 0.09, sin(a) * 0.42), 0.018, 0.018, 0.36, Color(0.86, 0.90, 0.96), Vector3(PI * 0.5, a, 0))
			g.torus(Vector3(0, 1.16, 0), 0.38, 0.44, Color(0.84, 0.88, 0.94), Vector3(PI * 0.5, 0, 0))
		"bomb_tower":
			_build_special_tower(g, p, "bomb")
		"inferno_tower":
			_build_special_tower(g, p, "inferno")
		"mortar":
			_build_mortar(g, p)
		_:
			# 通用塔
			g.cyl(Vector3(0, 0.10, 0), 0.48, 0.55, 0.20, stone_dark)
			g.cyl(Vector3(0, 0.50, 0), 0.41, 0.45, 0.62, stone)
			g.cyl(Vector3(0, 0.34, 0), 0.46, 0.46, 0.045, stone_dark)
			g.cyl(Vector3(0, 0.66, 0), 0.46, 0.46, 0.045, stone_dark)
			g.cyl(Vector3(0, 0.85, 0), 0.49, 0.43, 0.09, stone_dark)
			for i in 6:
				var a: float = TAU * float(i) / 6.0
				g.box(Vector3(cos(a) * 0.41, 0.95, sin(a) * 0.41), Vector3(0.17, 0.15, 0.13), stone)
			g.cone(Vector3(0, 1.24, 0), 0.44, 0.54, roof)
			g.sphere(Vector3(0, 1.52, 0), 0.06, COL_GOLD)
			g.cyl(Vector3(0, 1.76, 0), 0.014, 0.014, 0.44, COL_STEEL_DARK)
			g.box(Vector3(0.14, 1.88, 0), Vector3(0.26, 0.15, 0.014), accent)
			g.box(Vector3(0, 0.39, 0.43), Vector3(0.21, 0.32, 0.03), COL_LEATHER)
			g.box(Vector3(-0.27, 0.58, 0.42), Vector3(0.10, 0.14, 0.03), Color(0.30, 0.26, 0.22))
			g.box(Vector3(0.27, 0.58, 0.42), Vector3(0.10, 0.14, 0.03), Color(0.30, 0.26, 0.22))
			g.torus(Vector3(0, 0.10, 0), 0.46, 0.50, accent)

# ============================================================
# 滚动木桶 / 炸药桶 / 飞桶
# ============================================================
static func build_barrel(g: Geo, p: Dictionary) -> void:
	var wood: Color = p.get("body", COL_WOOD)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var band: Color = p.get("metal", COL_IRON)
	g.cyl(Vector3(0, 0.30, 0), 0.22, 0.25, 0.52, wood, Vector3(PI * 0.5, 0, 0))
	g.torus(Vector3(0, 0.30, -0.15), 0.20, 0.255, band, Vector3(PI * 0.5, 0, 0))
	g.torus(Vector3(0, 0.30, 0.15), 0.20, 0.255, band, Vector3(PI * 0.5, 0, 0))
	g.cyl(Vector3(0, 0.30, 0.27), 0.245, 0.245, 0.025, wood, Vector3(PI * 0.5, 0, 0))
	g.box(Vector3(0, 0.30, 0.285), Vector3(0.28, 0.11, 0.02), accent)
	g.box(Vector3(0, 0.43, 0.10), Vector3(0.10, 0.07, 0.10), COL_LEATHER_LIGHT)
	g.torus(Vector3(0, 0.05, 0), 0.28, 0.32, accent)

# ============================================================
# 元素精灵
# ============================================================
static func build_spirit(g: Geo, p: Dictionary) -> void:
	var glow: Color = p.get("glow", Color(0.5, 0.9, 1.0))
	var body: Color = p.get("body", glow)
	g.sphere(Vector3(0, 0.28, 0), 0.175, body, Vector3(1.05, 1.10, 1.05))
	g.sphere(Vector3(0, 0.22, 0.02), 0.145, glow, Vector3(1.0, 0.82, 1.0))
	g.cone(Vector3(0, 0.46, 0), 0.105, 0.17, body)
	g.cone(Vector3(-0.11, 0.42, 0), 0.062, 0.15, body, Vector3(0, 0, 0.5))
	g.cone(Vector3(0.11, 0.42, 0), 0.062, 0.15, body, Vector3(0, 0, -0.5))
	g.sphere(Vector3(-0.062, 0.30, 0.140), 0.044, Color(0.98, 0.98, 0.95), Vector3(1, 1.20, 0.5))
	g.sphere(Vector3(0.062, 0.30, 0.140), 0.044, Color(0.98, 0.98, 0.95), Vector3(1, 1.20, 0.5))
	g.sphere(Vector3(-0.062, 0.297, 0.168), 0.022, COL_DARK, Vector3(1, 1.15, 0.5))
	g.sphere(Vector3(0.062, 0.297, 0.168), 0.022, COL_DARK, Vector3(1, 1.15, 0.5))

# ============================================================
# 气球兵 / 骷髅气球
# ============================================================
static func build_balloon(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var skin: Color = p.get("skin", COL_SKIN)
	var y0: float = p.get("lift", 0.0)
	g.sphere(Vector3(0, 1.34 + y0, 0), 0.42, accent, Vector3(1.0, 1.15, 1.0))
	g.cyl(Vector3(0, 1.80 + y0, 0), 0.09, 0.12, 0.09, accent)
	g.cone(Vector3(0, 1.87 + y0, 0), 0.09, 0.09, accent.darkened(0.25))
	g.box(Vector3(0, 0.38 + y0, 0), Vector3(0.40, 0.30, 0.38), COL_WOOD)
	g.box(Vector3(0, 0.54 + y0, 0), Vector3(0.42, 0.045, 0.40), COL_WOOD_DARK)
	g.box(Vector3(-0.19, 0.97 + y0, 0.0), Vector3(0.012, 0.90, 0.012), COL_CLOTH, Vector3(0, 0, 0.06))
	g.box(Vector3(0.19, 0.97 + y0, 0.0), Vector3(0.012, 0.90, 0.012), COL_CLOTH, Vector3(0, 0, -0.06))
	g.sphere(Vector3(0, 0.66 + y0, 0.02), 0.078, COL_BONE, Vector3(1.0, 1.05, 0.95))
	g.box(Vector3(0, 0.55 + y0, 0.02), Vector3(0.10, 0.09, 0.08), COL_BONE)
	g.sphere(Vector3(-0.030, 0.665 + y0, 0.077), 0.018, COL_DARK)
	g.sphere(Vector3(0.030, 0.665 + y0, 0.077), 0.018, COL_DARK)
	g.box(Vector3(0, 0.445 + y0, 0), Vector3(0.26, 0.22, 0.02), skin)

# ============================================================
# 塔楼 + 塔顶人物 + 炮台
# ============================================================
static func _tower_with_platform(g: Geo, p: Dictionary, top_y: float = 0.95) -> void:
	var stone: Color = p.get("body", COL_STONE)
	var stone_dark: Color = p.get("stone_dark", COL_STONE_DARK)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var h: float = top_y
	var w: float = float(p.get("tower_w", 0.86))
	# 立方体塔身
	g.box(Vector3(0, 0.10, 0), Vector3(w + 0.16, 0.20, w + 0.16), stone_dark)
	g.box(Vector3(0, 0.10 + (h - 0.10) * 0.5, 0), Vector3(w, h - 0.10, w), stone)
	g.box(Vector3(0, 0.10 + (h - 0.10) * 0.35, 0), Vector3(w + 0.06, 0.045, w + 0.06), stone_dark)
	g.box(Vector3(0, 0.10 + (h - 0.10) * 0.70, 0), Vector3(w + 0.06, 0.045, w + 0.06), stone_dark)
	# 顶部石檐
	g.box(Vector3(0, h + 0.05, 0), Vector3(w + 0.14, 0.08, w + 0.14), stone_dark)
	var pw: float = (w + 0.18) * 0.5
	# 木地板：底板 + 逐条木板纹理（深浅交错）+ 边缘压条
	g.box(Vector3(0, h + 0.20, 0), Vector3(w + 0.18, 0.07, w + 0.18), Color(0.36, 0.24, 0.14))
	var planks: int = 6
	for i in planks:
		var t: float = (float(i) + 0.5) / float(planks)
		var pz: float = -pw + (w + 0.18) * t
		var wood_col: Color = COL_WOOD.lerp(Color(0.52, 0.36, 0.20), float(i % 2))
		g.box(Vector3(0, h + 0.238, pz), Vector3(w + 0.14, 0.018, (w + 0.14) / float(planks) - 0.015), wood_col)
	g.box(Vector3(0, h + 0.25, pw - 0.02), Vector3(w + 0.18, 0.03, 0.06), Color(0.44, 0.30, 0.17))
	g.box(Vector3(0, h + 0.25, -pw + 0.02), Vector3(w + 0.18, 0.03, 0.06), Color(0.44, 0.30, 0.17))
	g.box(Vector3(pw - 0.02, h + 0.25, 0), Vector3(0.06, 0.03, w + 0.14), Color(0.44, 0.30, 0.17))
	g.box(Vector3(-pw + 0.02, h + 0.25, 0), Vector3(0.06, 0.03, w + 0.14), Color(0.44, 0.30, 0.17))
	# 四角 L 型白色围栏
	var fence_col := Color(0.94, 0.93, 0.87)
	var inset: float = 0.05
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var fx: float = sx * (pw - inset)
			var fz: float = sz * (pw - inset)
			var arm: float = 0.34
			g.box(Vector3(fx - sx * arm * 0.5, h + 0.33, fz), Vector3(arm, 0.17, 0.055), fence_col)
			g.box(Vector3(fx, h + 0.33, fz - sz * arm * 0.5), Vector3(0.055, 0.17, arm), fence_col)
			# 栏柱帽
			g.box(Vector3(fx, h + 0.43, fz), Vector3(0.09, 0.05, 0.09), Color(0.86, 0.85, 0.80))
	# 前方围栏缺口处的炮台基座
	g.box(Vector3(0, h + 0.30, pw - 0.03), Vector3(0.46, 0.06, 0.30), stone_dark)
	g.box(Vector3(0, h + 0.34, pw - 0.03), Vector3(0.38, 0.03, 0.24), Color(0.52, 0.40, 0.26))
	# 门 / 窗 / 队旗
	g.box(Vector3(0, 0.34, w * 0.5 + 0.02), Vector3(0.22, 0.32, 0.03), COL_LEATHER)
	g.box(Vector3(-w * 0.28, 0.62, w * 0.5 + 0.02), Vector3(0.12, 0.16, 0.03), Color(0.30, 0.26, 0.22))
	g.box(Vector3(w * 0.28, 0.62, w * 0.5 + 0.02), Vector3(0.12, 0.16, 0.03), Color(0.30, 0.26, 0.22))
	g.box(Vector3(0, h + 0.30, -w * 0.5 - 0.06), Vector3(0.30, 0.44, 0.02), accent)

static func seated_king_mesh(accent: Color) -> ArrayMesh:
	var g := Geo.new()
	_seated_figure(g, 0.0, "king", {"accent": accent})
	return g.commit()

static func _seated_figure(g: Geo, y: float, kind: String, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var skin: Color = COL_SKIN
	var cloth: Color = Color(0.62, 0.46, 0.66) if kind == "princess" else (Color(0.34, 0.40, 0.62) if kind == "prince" else Color(0.62, 0.42, 0.24))
	var metal: Color = COL_GOLD if kind == "king" else COL_STEEL
	var zoff: float = 0.22 if kind == "princess" else -0.18
	var yy: float = y + (0.06 if kind == "princess" else 0.16)
	# 坐姿：腿、身体、头
	g.box(Vector3(0, yy + 0.04, zoff + 0.12), Vector3(0.18, 0.10, 0.24), cloth)
	g.capsule(Vector3(0, yy + 0.22, zoff), 0.095, 0.20, cloth)
	g.sphere(Vector3(0, yy + 0.38, zoff + 0.01), 0.09, skin, Vector3(1.0, 1.05, 0.98))
	g.sphere(Vector3(-0.033, yy + 0.395, zoff + 0.078), 0.016, COL_DARK, Vector3(1.0, 1.25, 0.6))
	g.sphere(Vector3(0.033, yy + 0.395, zoff + 0.078), 0.016, COL_DARK, Vector3(1.0, 1.25, 0.6))
	# 手臂
	g.box(Vector3(-0.10, yy + 0.24, zoff + 0.05), Vector3(0.06, 0.16, 0.06), cloth, Vector3(0.3, 0, 0))
	g.box(Vector3(0.10, yy + 0.24, zoff + 0.05), Vector3(0.06, 0.16, 0.06), cloth, Vector3(0.3, 0, 0))
	if kind == "princess":
		g.sphere(Vector3(0, yy + 0.42, zoff - 0.02), 0.092, Color(0.72, 0.55, 0.30), Vector3(1.05, 0.52, 1.05))
		g.cyl(Vector3(0, yy + 0.46, zoff), 0.055, 0.06, 0.05, COL_GOLD)
		# 竖直的弓 + 搭在弦上的箭
		g.torus(Vector3(-0.17, yy + 0.30, zoff + 0.06), 0.15, 0.185, COL_WOOD, Vector3(PI * 0.5, 0.35, 0))
		g.box(Vector3(-0.17, yy + 0.30, zoff + 0.06), Vector3(0.008, 0.40, 0.008), COL_CLOTH, Vector3(0, 0, 0.35))
		g.cyl(Vector3(-0.17, yy + 0.30, zoff + 0.13), 0.010, 0.010, 0.34, COL_WOOD, Vector3(PI * 0.5, 0, 0))
		g.cone(Vector3(-0.17, yy + 0.30, zoff + 0.31), 0.025, 0.08, COL_STEEL, Vector3(PI * 0.5, 0, 0))
	elif kind == "prince":
		g.cyl(Vector3(0, yy + 0.455, zoff), 0.070, 0.078, 0.045, COL_GOLD)
		for i in 5:
			var a: float = TAU * float(i) / 5.0
			g.cone(Vector3(cos(a) * 0.058, yy + 0.495, zoff + sin(a) * 0.058), 0.022, 0.06, COL_GOLD)
		g.box(Vector3(0, yy + 0.24, zoff - 0.10), Vector3(0.26, 0.30, 0.02), accent, Vector3(-0.12, 0, 0))
	else:
		g.cyl(Vector3(0, yy + 0.46, zoff), 0.075, 0.085, 0.05, COL_GOLD)
		for i in 5:
			var a2: float = TAU * float(i) / 5.0
			g.cone(Vector3(cos(a2) * 0.062, yy + 0.51, zoff + sin(a2) * 0.062), 0.026, 0.075, COL_GOLD)
		g.sphere(Vector3(0, yy + 0.31, zoff + 0.06), 0.048, Color(0.92, 0.90, 0.86), Vector3(1.1, 1.15, 0.8))
		g.box(Vector3(0, yy + 0.24, zoff - 0.10), Vector3(0.30, 0.34, 0.02), Color(0.70, 0.20, 0.24), Vector3(-0.12, 0, 0))
	# 权杖（王子/国王）
	if kind != "princess":
		g.cyl(Vector3(0.17, yy + 0.18, zoff + 0.08), 0.014, 0.016, 0.30, metal, Vector3(0, 0, -0.2))
		g.sphere(Vector3(0.21, yy + 0.33, zoff + 0.08), 0.030, COL_GOLD)

static func _build_turret(g: Geo, p: Dictionary) -> void:
	var metal: Color = p.get("metal", COL_IRON)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var steel: Color = COL_STEEL_DARK
	var kind := String(p.get("kind", "tower"))
	match kind:
		"cannon":
			g.cyl(Vector3(0, 0, -0.10), 0.19, 0.21, 0.22, metal, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.14), 0.105, 0.155, 0.56, metal, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.43), 0.130, 0.130, 0.06, steel, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.30), 0.13, 0.16, accent, Vector3(PI * 0.5, 0, 0))
		"crossbow":
			g.box(Vector3(0, 0.0, 0.02), Vector3(0.16, 0.10, 0.70), COL_WOOD_DARK)
			g.prism(Vector3(-0.34, 0.04, 0.14), Vector3(0.62, 0.13, 0.07), COL_WOOD, Vector3(0, 0, 0.32), 0.0)
			g.prism(Vector3(0.34, 0.04, 0.14), Vector3(0.62, 0.13, 0.07), COL_WOOD, Vector3(0, 0, PI - 0.32), 0.0)
			g.box(Vector3(0, 0.04, -0.16), Vector3(1.06, 0.012, 0.012), COL_CLOTH)
			g.cyl(Vector3(0, 0.06, 0.28), 0.015, 0.015, 0.50, COL_WOOD, Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0.06, 0.56), 0.035, 0.12, COL_STEEL, Vector3(PI * 0.5, 0, 0))
		"mortar":
			g.cyl(Vector3(0, 0.05, -0.04), 0.085, 0.11, 0.62, metal, Vector3(-0.62, 0, 0))
			g.cyl(Vector3(0, 0.23, 0.20), 0.115, 0.115, 0.08, steel, Vector3(-0.62, 0, 0))
			g.torus(Vector3(0, -0.01, -0.10), 0.11, 0.14, accent, Vector3(0.95, 0, 0))
			g.box(Vector3(-0.16, 0.08, 0.02), Vector3(0.06, 0.24, 0.24), metal, Vector3(0.2, 0, 0.15))
			g.box(Vector3(0.16, 0.08, 0.02), Vector3(0.06, 0.24, 0.24), metal, Vector3(0.2, 0, -0.15))
		_:
			g.cyl(Vector3(0, 0.02, 0), 0.13, 0.15, 0.06, COL_STONE_DARK)
			g.box(Vector3(0, 0.09, 0.02), Vector3(0.18, 0.11, 0.24), metal)
			g.sphere(Vector3(0, 0.15, -0.06), 0.085, metal, Vector3(1.0, 0.9, 1.0))
			g.cyl(Vector3(0, 0.15, 0.20), 0.052, 0.070, 0.38, metal, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0.15, 0.40), 0.080, 0.080, 0.055, steel, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0.15, 0.30), 0.065, 0.085, accent, Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(-0.15, 0.26, 0.0), Vector3(0.045, 0.18, 0.26), steel, Vector3(0, 0, 0.1))
			g.box(Vector3(0.15, 0.26, 0.0), Vector3(0.045, 0.18, 0.26), steel, Vector3(0, 0, -0.1))
			g.sphere(Vector3(0, 0.34, 0.42), 0.030, Color(0.85, 0.90, 1.0))
static func build_cannon_cart(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var metal: Color = COL_IRON
	# 车身
	g.box(Vector3(0, 0.30, 0), Vector3(0.52, 0.24, 0.86), COL_WOOD)
	g.box(Vector3(0, 0.45, 0), Vector3(0.44, 0.10, 0.74), COL_WOOD_DARK)
	g.box(Vector3(0, 0.44, 0.16), Vector3(0.50, 0.06, 0.30), accent)
	# 车轮
	for sx in [-0.30, 0.30]:
		for sz in [-0.26, 0.26]:
			g.cyl(Vector3(sx, 0.19, sz), 0.17, 0.17, 0.09, COL_WOOD_DARK, Vector3(0, 0, PI * 0.5))
			g.cyl(Vector3(sx, 0.19, sz), 0.06, 0.06, 0.11, COL_IRON, Vector3(0, 0, PI * 0.5))
	# 炮
	g.sphere(Vector3(0, 0.56, -0.06), 0.12, metal, Vector3(1.0, 0.9, 1.0))
	g.cyl(Vector3(0, 0.56, 0.24), 0.075, 0.095, 0.52, metal, Vector3(PI * 0.5, 0, 0))
	g.cyl(Vector3(0, 0.56, 0.51), 0.11, 0.11, 0.06, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
	g.torus(Vector3(0, 0.56, 0.38), 0.09, 0.115, accent, Vector3(PI * 0.5, 0, 0))

static func build_crossbow(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	# 底座 + 立柱（弩臂在 Turret 节点上，可转向目标）
	g.box(Vector3(0, 0.14, 0), Vector3(0.62, 0.14, 0.62), COL_WOOD_DARK)
	g.cyl(Vector3(0, 0.42, 0), 0.07, 0.09, 0.46, COL_WOOD)
	g.box(Vector3(0.22, 0.16, 0.22), Vector3(0.14, 0.10, 0.14), accent)
	g.box(Vector3(-0.22, 0.16, -0.22), Vector3(0.14, 0.10, 0.14), accent)
static func build_sparky(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var metal: Color = COL_IRON
	# 履带底座
	g.box(Vector3(0, 0.20, 0), Vector3(0.86, 0.26, 1.02), COL_STEEL_DARK)
	for sx in [-0.46, 0.46]:
		g.box(Vector3(sx, 0.22, 0), Vector3(0.14, 0.34, 0.94), metal)
		for sz in [-0.28, 0.0, 0.28]:
			g.cyl(Vector3(sx, 0.22, sz), 0.10, 0.10, 0.16, COL_STEEL_DARK, Vector3(0, 0, PI * 0.5))
	# 电磁炮塔
	g.cyl(Vector3(0, 0.48, -0.06), 0.22, 0.26, 0.42, metal)
	g.sphere(Vector3(0, 0.80, -0.02), 0.27, Color(0.55, 0.84, 1.0))
	g.sphere(Vector3(0, 0.80, 0.18), 0.16, Color(0.90, 0.98, 1.0))
	g.torus(Vector3(0, 0.80, -0.02), 0.26, 0.33, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
	g.torus(Vector3(0, 0.62, -0.06), 0.28, 0.34, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
	# 炮口
	g.cyl(Vector3(0, 0.80, 0.34), 0.10, 0.13, 0.34, metal, Vector3(PI * 0.5, 0, 0))
	g.cyl(Vector3(0, 0.80, 0.52), 0.14, 0.14, 0.05, Color(0.75, 0.92, 1.0), Vector3(PI * 0.5, 0, 0))
	g.box(Vector3(0, 0.30, 0.50), Vector3(0.28, 0.10, 0.06), accent)

static func build_ram(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var metal: Color = COL_IRON
	# 车体 + 顶棚
	g.box(Vector3(0, 0.30, 0), Vector3(0.82, 0.28, 1.30), COL_WOOD)
	g.box(Vector3(0, 0.50, 0), Vector3(0.86, 0.10, 1.34), COL_WOOD_DARK)
	g.prism(Vector3(0, 0.72, 0), Vector3(0.90, 0.38, 1.34), COL_CLOTH, Vector3(0, 0, 0), 0.5)
	g.box(Vector3(0, 0.52, 0.60), Vector3(0.70, 0.26, 0.06), accent)
	# 轮子
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.10, 0.56]:
			g.cyl(Vector3(sx, 0.18, sz), 0.16, 0.16, 0.08, COL_WOOD_DARK, Vector3(0, 0, PI * 0.5))
	# 撞锤
	g.cyl(Vector3(0, 0.30, 0.62), 0.10, 0.10, 0.55, COL_WOOD_DARK, Vector3(PI * 0.5, 0, 0))
	g.sphere(Vector3(0, 0.30, 0.92), 0.13, metal, Vector3(1.0, 0.9, 1.2))
	g.torus(Vector3(0, 0.30, 0.74), 0.10, 0.125, accent, Vector3(PI * 0.5, 0, 0))
	# 旗
	g.cyl(Vector3(-0.32, 0.90, -0.30), 0.014, 0.014, 0.36, COL_WOOD_DARK)
	g.box(Vector3(-0.24, 1.02, -0.30), Vector3(0.18, 0.12, 0.012), accent)

# ============================================================
# 炸弹塔 / 地狱之塔 / 迫击炮 / 飞行机器
# ============================================================
static func _build_special_tower(g: Geo, p: Dictionary, kind: String) -> void:
	var stone: Color = p.get("body", COL_STONE)
	var stone_dark: Color = p.get("stone_dark", COL_STONE_DARK)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	g.cyl(Vector3(0, 0.10, 0), 0.44, 0.50, 0.20, stone_dark)
	g.cyl(Vector3(0, 0.44, 0), 0.38, 0.42, 0.52, stone if kind == "bomb" else Color(0.36, 0.33, 0.34))
	g.cyl(Vector3(0, 0.30, 0), 0.44, 0.44, 0.045, stone_dark)
	g.cyl(Vector3(0, 0.72, 0), 0.46, 0.40, 0.09, stone_dark)
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		g.box(Vector3(cos(a) * 0.38, 0.80, sin(a) * 0.38), Vector3(0.15, 0.14, 0.12), stone)
	g.box(Vector3(0, 0.32, 0.40), Vector3(0.20, 0.30, 0.03), COL_LEATHER)
	if kind == "bomb":
		# 塔顶大炸弹 + 引信
		g.sphere(Vector3(0, 1.06, 0), 0.26, Color(0.20, 0.21, 0.25))
		g.sphere(Vector3(-0.08, 1.14, 0.12), 0.07, Color(0.62, 0.66, 0.74))
		g.torus(Vector3(0, 1.06, 0), 0.24, 0.29, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
		g.cyl(Vector3(0.06, 1.34, 0), 0.02, 0.02, 0.16, COL_WOOD_DARK)
		g.sphere(Vector3(0.12, 1.44, 0), 0.05, Color(1.0, 0.72, 0.20))
		g.torus(Vector3(0, 0.10, 0), 0.40, 0.44, accent)
	else:
		# 地狱之塔：开顶火盆 + 橙色火焰柱 + 骷髅浮雕
		g.cyl(Vector3(0, 0.90, 0), 0.30, 0.34, 0.10, Color(0.30, 0.26, 0.28))
		g.torus(Vector3(0, 0.95, 0), 0.26, 0.34, Color(0.55, 0.42, 0.28), Vector3(PI * 0.5, 0, 0))
		g.sphere(Vector3(0, 1.06, 0), 0.22, Color(1.0, 0.50, 0.10))
		g.sphere(Vector3(0, 1.16, 0.02), 0.15, Color(1.0, 0.78, 0.30))
		g.cone(Vector3(0, 1.32, 0), 0.16, 0.42, Color(1.0, 0.42, 0.06))
		g.cone(Vector3(-0.10, 1.26, 0.06), 0.09, 0.30, Color(1.0, 0.62, 0.12), Vector3(0.12, 0, 0.18))
		g.cone(Vector3(0.10, 1.24, -0.04), 0.08, 0.28, Color(1.0, 0.70, 0.18), Vector3(-0.10, 0, -0.16))
		g.sphere(Vector3(0.14, 1.40, 0.0), 0.040, Color(1.0, 0.92, 0.60))
		g.sphere(Vector3(-0.16, 1.34, 0.08), 0.035, Color(1.0, 0.85, 0.40))
		g.box(Vector3(0, 0.40, 0.395), Vector3(0.16, 0.16, 0.03), COL_BONE)
		g.sphere(Vector3(-0.040, 0.42, 0.415), 0.020, COL_DARK)
		g.sphere(Vector3(0.040, 0.42, 0.415), 0.020, COL_DARK)
		g.torus(Vector3(0, 0.10, 0), 0.40, 0.44, accent)

static func _build_mortar(g: Geo, p: Dictionary) -> void:
	var stone: Color = p.get("body", COL_STONE)
	var stone_dark: Color = p.get("stone_dark", COL_STONE_DARK)
	var metal: Color = p.get("metal", COL_IRON)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	# 底座（炮管在 Turret 节点上，可转向目标）
	g.cyl(Vector3(0, 0.14, 0), 0.44, 0.50, 0.28, stone_dark)
	g.cyl(Vector3(0, 0.30, 0), 0.40, 0.40, 0.05, stone)
	g.box(Vector3(0, 0.34, 0), Vector3(0.56, 0.10, 0.56), metal)
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		g.sphere(Vector3(cos(a) * 0.40, 0.12, sin(a) * 0.40), 0.13, Color(0.72, 0.66, 0.52), Vector3(1.2, 0.7, 1.0))
	g.sphere(Vector3(-0.26, 0.16, 0.26), 0.09, Color(0.30, 0.31, 0.35))
	g.sphere(Vector3(-0.32, 0.16, 0.08), 0.07, Color(0.30, 0.31, 0.35))
	g.torus(Vector3(0, 0.10, 0), 0.40, 0.44, accent)
static func build_flying_machine(g: Geo, p: Dictionary) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var wood: Color = COL_WOOD
	var metal: Color = COL_STEEL_DARK
	var y0: float = p.get("lift", 0.0)
	# 机身
	g.box(Vector3(0, 0.62 + y0, 0), Vector3(0.42, 0.26, 0.92), wood)
	g.box(Vector3(0, 0.62 + y0, 0.52), Vector3(0.30, 0.22, 0.18), color_wood_dark())
	g.box(Vector3(0, 0.80 + y0, -0.06), Vector3(0.46, 0.06, 0.70), accent)
	# 侧翼
	g.prism(Vector3(-0.36, 0.66 + y0, 0), Vector3(0.42, 0.10, 0.62), wood, Vector3(0, 0, 0.0), 0.0)
	g.prism(Vector3(0.36, 0.66 + y0, 0), Vector3(0.42, 0.10, 0.62), wood, Vector3(0, PI, 0.0), 0.0)
	# 前部机枪
	g.cyl(Vector3(0, 0.60 + y0, 0.62), 0.045, 0.055, 0.34, metal, Vector3(PI * 0.5, 0, 0))
	g.cyl(Vector3(0, 0.60 + y0, 0.80), 0.065, 0.065, 0.05, COL_IRON, Vector3(PI * 0.5, 0, 0))
	# 顶部螺旋桨
	g.cyl(Vector3(0, 0.86 + y0, -0.04), 0.03, 0.03, 0.16, metal)
	g.cyl(Vector3(0, 0.96 + y0, -0.04), 0.05, 0.05, 0.06, COL_IRON)
	for i in 3:
		var a: float = TAU * float(i) / 3.0
		g.box(Vector3(cos(a) * 0.30, 0.99 + y0, sin(a) * 0.30 - 0.04), Vector3(0.58, 0.025, 0.10), wood, Vector3(0, -a, 0))
	# 起落架
	g.cyl(Vector3(-0.22, 0.40 + y0, 0.14), 0.03, 0.03, 0.30, metal, Vector3(0, 0, 0.25))
	g.cyl(Vector3(0.22, 0.40 + y0, 0.14), 0.03, 0.03, 0.30, metal, Vector3(0, 0, -0.25))
	g.sphere(Vector3(-0.27, 0.26 + y0, 0.14), 0.07, COL_IRON)
	g.sphere(Vector3(0.27, 0.26 + y0, 0.14), 0.07, COL_IRON)
	# 尾部小旗
	g.cyl(Vector3(0, 0.86 + y0, -0.42), 0.012, 0.012, 0.22, metal)
	g.box(Vector3(0.09, 0.92 + y0, -0.42), Vector3(0.18, 0.10, 0.01), accent)

static func color_wood_dark() -> Color:
	return COL_WOOD_DARK

# ============================================================
# 坐骑类：野猪 / 蛮羊 / 电击车
# ============================================================
static func _mount_rider(g: Geo, p: Dictionary, y: float) -> void:
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var skin: Color = p.get("skin", COL_SKIN)
	var cloth: Color = Color(0.40, 0.30, 0.22)
	g.capsule(Vector3(0, y + 0.24, 0.0), 0.10, 0.22, cloth)
	g.box(Vector3(-0.11, y + 0.28, 0.05), Vector3(0.06, 0.17, 0.06), cloth, Vector3(0.45, 0, 0))
	g.box(Vector3(0.11, y + 0.28, 0.05), Vector3(0.06, 0.17, 0.06), cloth, Vector3(0.45, 0, 0))
	g.box(Vector3(-0.15, y + 0.06, 0.12), Vector3(0.10, 0.08, 0.28), Color(0.30, 0.26, 0.22))
	g.box(Vector3(0.15, y + 0.06, 0.12), Vector3(0.10, 0.08, 0.28), Color(0.30, 0.26, 0.22))
	g.sphere(Vector3(0, y + 0.40, 0.02), 0.10, skin, Vector3(1.0, 1.05, 0.98))
	g.sphere(Vector3(-0.035, y + 0.415, 0.085), 0.017, COL_DARK)
	g.sphere(Vector3(0.035, y + 0.415, 0.085), 0.017, COL_DARK)
	# 头盔
	g.cyl(Vector3(0, y + 0.475, 0.0), 0.105, 0.115, 0.075, accent)
	g.cyl(Vector3(0, y + 0.515, 0.0), 0.035, 0.045, 0.09, accent)
	# 武器（长矛/锤）
	g.cyl(Vector3(0.24, y + 0.22, 0.10), 0.020, 0.022, 0.55, COL_WOOD, Vector3(1.15, 0, -0.25))
	g.cone(Vector3(0.36, y + 0.44, 0.36), 0.05, 0.16, COL_STEEL, Vector3(1.15, 0, -0.25))

static func build_boar(g: Geo, p: Dictionary, with_rider: bool) -> void:
	var hide: Color = p.get("body", Color(0.42, 0.32, 0.24))
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	var dark: Color = hide.darkened(0.30)
	g.capsule(Vector3(0, 0.58, -0.02), 0.30, 0.70, hide, Vector3(PI * 0.5, 0, 0))
	g.sphere(Vector3(0, 0.62, 0.24), 0.30, hide, Vector3(1.0, 1.0, 0.9))
	g.sphere(Vector3(0, 0.60, -0.30), 0.28, hide, Vector3(1.0, 1.0, 0.9))
	# 头 + 鼻 + 眼 + 獠牙 + 耳
	g.sphere(Vector3(0, 0.66, 0.46), 0.26, hide, Vector3(1.0, 0.95, 1.0))
	g.box(Vector3(0, 0.60, 0.66), Vector3(0.18, 0.14, 0.18), dark)
	g.sphere(Vector3(-0.055, 0.61, 0.745), 0.028, Color(0.18, 0.12, 0.10))
	g.sphere(Vector3(0.055, 0.61, 0.745), 0.028, Color(0.18, 0.12, 0.10))
	g.sphere(Vector3(-0.14, 0.75, 0.42), 0.035, COL_DARK)
	g.sphere(Vector3(0.14, 0.75, 0.42), 0.035, COL_DARK)
	g.cone(Vector3(-0.13, 0.55, 0.70), 0.035, 0.20, Color(0.94, 0.92, 0.82), Vector3(-0.5, 0, 0.25))
	g.cone(Vector3(0.13, 0.55, 0.70), 0.035, 0.20, Color(0.94, 0.92, 0.82), Vector3(-0.5, 0, -0.25))
	g.cone(Vector3(-0.13, 0.85, 0.40), 0.06, 0.15, dark, Vector3(0.3, 0, 0.4))
	g.cone(Vector3(0.13, 0.85, 0.40), 0.06, 0.15, dark, Vector3(0.3, 0, -0.4))
	for i in 5:
		g.cone(Vector3(0, 0.87, 0.16 - float(i) * 0.14), 0.05, 0.16, dark, Vector3(-0.95, 0, 0))
	for sx in [-0.17, 0.17]:
		for sz in [-0.30, 0.30]:
			g.cyl(Vector3(sx, 0.22, sz), 0.065, 0.075, 0.34, hide)
			g.cyl(Vector3(sx, 0.045, sz), 0.065, 0.065, 0.06, Color(0.20, 0.16, 0.13))
	g.cyl(Vector3(0, 0.62, -0.44), 0.02, 0.03, 0.18, dark, Vector3(1.2, 0, 0))
	g.box(Vector3(0, 0.82, 0.0), Vector3(0.36, 0.06, 0.36), accent)
	if with_rider:
		_mount_rider(g, p, 0.80)

static func build_ram_mount(g: Geo, p: Dictionary, with_rider: bool) -> void:
	var wool: Color = Color(0.94, 0.92, 0.86)
	var dark: Color = Color(0.30, 0.24, 0.20)
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	# 蓬松羊毛身体
	g.sphere(Vector3(0, 0.62, 0.02), 0.34, wool, Vector3(1.15, 1.0, 1.05))
	g.sphere(Vector3(0, 0.66, -0.28), 0.30, wool)
	g.sphere(Vector3(0, 0.60, 0.30), 0.28, wool)
	g.sphere(Vector3(-0.16, 0.72, -0.05), 0.20, wool)
	g.sphere(Vector3(0.16, 0.72, -0.05), 0.20, wool)
	# 头 + 脸
	g.sphere(Vector3(0, 0.72, 0.54), 0.22, Color(0.82, 0.76, 0.68))
	g.box(Vector3(0, 0.64, 0.70), Vector3(0.14, 0.12, 0.16), Color(0.74, 0.68, 0.62))
	g.sphere(Vector3(-0.075, 0.76, 0.72), 0.022, COL_DARK)
	g.sphere(Vector3(0.075, 0.76, 0.72), 0.022, COL_DARK)
	# 大卷角
	g.torus(Vector3(-0.20, 0.82, 0.48), 0.13, 0.18, Color(0.66, 0.52, 0.34), Vector3(0.5, 0, 0.9))
	g.torus(Vector3(0.20, 0.82, 0.48), 0.13, 0.18, Color(0.66, 0.52, 0.34), Vector3(0.5, 0, -0.9))
	# 腿
	for sx in [-0.18, 0.18]:
		for sz in [-0.28, 0.28]:
			g.cyl(Vector3(sx, 0.22, sz), 0.06, 0.07, 0.34, dark)
			g.cyl(Vector3(sx, 0.05, sz), 0.06, 0.06, 0.07, Color(0.18, 0.15, 0.12))
	# 鞍 + 披风
	g.box(Vector3(0, 0.88, 0.0), Vector3(0.38, 0.06, 0.38), accent)
	g.box(Vector3(0, 0.96, -0.16), Vector3(0.30, 0.05, 0.30), accent.darkened(0.15))
	if with_rider:
		_mount_rider(g, p, 0.94)

static func build_zappy(g: Geo, p: Dictionary) -> void:
	var wood: Color = COL_WOOD_DARK
	var metal: Color = COL_IRON
	var accent: Color = p.get("accent", COL_TEAM_PLAYER)
	# 车体 + 拖杆
	g.box(Vector3(0, 0.30, 0), Vector3(0.48, 0.24, 0.70), wood)
	g.box(Vector3(0, 0.43, 0), Vector3(0.52, 0.06, 0.74), accent)
	g.cyl(Vector3(0, 0.22, 0.52), 0.03, 0.03, 0.40, metal, Vector3(PI * 0.5, 0, 0))
	# 双轮
	for sx in [-0.30, 0.30]:
		g.cyl(Vector3(sx, 0.18, -0.08), 0.18, 0.18, 0.09, COL_IRON, Vector3(0, 0, PI * 0.5))
		g.cyl(Vector3(sx, 0.18, -0.08), 0.06, 0.06, 0.11, COL_STEEL_DARK, Vector3(0, 0, PI * 0.5))
	# 电极柱 + 电球
	g.cyl(Vector3(0, 0.60, 0.0), 0.07, 0.10, 0.34, metal)
	g.sphere(Vector3(0, 0.84, 0.0), 0.16, Color(0.55, 0.85, 1.0))
	g.torus(Vector3(0, 0.84, 0.0), 0.15, 0.21, COL_STEEL_DARK, Vector3(PI * 0.5, 0, 0))
	g.torus(Vector3(0, 0.66, 0.0), 0.10, 0.14, accent, Vector3(PI * 0.5, 0, 0))
	# 天线 + 电弧尖刺
	g.cyl(Vector3(0.17, 0.66, -0.24), 0.012, 0.012, 0.34, metal)
	g.sphere(Vector3(0.17, 0.85, -0.24), 0.04, Color(0.85, 0.97, 1.0))
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		g.cone(Vector3(cos(a) * 0.19, 0.84, sin(a) * 0.19), 0.03, 0.14, Color(0.75, 0.92, 1.0), Vector3(0, -a, PI * 0.5))
static func build_egg(g: Geo, p: Dictionary) -> void:
	var shell: Color = p.get("body", Color(0.92, 0.86, 0.66))
	g.sphere(Vector3(0, 0.34, 0), 0.34, shell, Vector3(1.0, 1.32, 1.0))
	g.sphere(Vector3(-0.12, 0.42, 0.10), 0.20, shell.lightened(0.08), Vector3(1.0, 1.2, 1.0))
	g.sphere(Vector3(0.14, 0.22, -0.06), 0.18, shell.darkened(0.06), Vector3(1.0, 1.1, 1.0))
	# 裂纹 + 发光缝隙
	g.box(Vector3(0.02, 0.52, 0.24), Vector3(0.05, 0.20, 0.03), Color(1.0, 0.55, 0.10), Vector3(0.2, 0, 0.4))
	g.box(Vector3(-0.14, 0.40, 0.24), Vector3(0.04, 0.16, 0.03), Color(1.0, 0.65, 0.15), Vector3(0.1, 0, -0.5))
	g.box(Vector3(0.16, 0.34, 0.22), Vector3(0.04, 0.12, 0.03), Color(1.0, 0.70, 0.20), Vector3(0.0, 0, 0.2))
	g.sphere(Vector3(0, 0.62, 0), 0.06, Color(1.0, 0.85, 0.40))
	g.torus(Vector3(0, 0.06, 0), 0.26, 0.32, Color(0.55, 0.45, 0.30))
# 站立+背后翅膀（重甲亡灵 / 精灵女王）
static func build_winged(g: Geo, p: Dictionary) -> void:
	build_humanoid(g, p)
	var body: Color = p.get("body", Color(0.55, 0.62, 0.72))
	var wing: Color = p.get("wing", body.lightened(0.12))
	var membrane: Color = p.get("wing_membrane", wing.lightened(0.18))
	for side in [-1.0, 1.0]:
		g.cone(Vector3(side * 0.26, 0.98, -0.16), 0.055, 0.52, wing, Vector3(0.15, 0, side * 0.75))
		g.prism(Vector3(side * 0.52, 0.86, -0.34), Vector3(0.80, 0.52, 0.04), membrane, Vector3(0, side * 0.55, side * 0.5), 0.0)
		g.prism(Vector3(side * 0.40, 0.62, -0.40), Vector3(0.58, 0.36, 0.04), membrane.darkened(0.10), Vector3(0, side * 0.6, side * 0.35), 0.0)
		g.cone(Vector3(side * 0.20, 1.18, -0.14), 0.035, 0.34, wing.darkened(0.15), Vector3(0.1, 0, side * 0.9))
static func build_bush(g: Geo, p: Dictionary) -> void:
	var green: Color = Color(0.30, 0.52, 0.20)
	var light: Color = Color(0.42, 0.66, 0.26)
	var dark: Color = Color(0.18, 0.34, 0.14)
	# 主草丛：几团低矮球体
	g.sphere(Vector3(0, 0.28, 0), 0.46, green, Vector3(1.15, 0.82, 1.05))
	g.sphere(Vector3(-0.28, 0.24, 0.10), 0.30, green, Vector3(1.0, 0.78, 1.0))
	g.sphere(Vector3(0.30, 0.26, -0.06), 0.32, light, Vector3(1.0, 0.80, 1.0))
	g.sphere(Vector3(0.02, 0.30, -0.28), 0.28, green, Vector3(1.0, 0.85, 1.0))
	# 草叶
	for i in range(7):
		var a: float = TAU * float(i) / 7.0
		var r: float = 0.26
		g.box(Vector3(cos(a) * r, 0.52, sin(a) * r), Vector3(0.07, 0.34, 0.03), dark, Vector3(0.35 * cos(a), a, 0.3 * sin(a)))
	# 底部阴影
	g.cyl(Vector3(0, 0.04, 0), 0.44, 0.50, 0.08, dark)