extends RefCounted
# ============================================================
# 程序化子弹 / 投射物模型（玩具沙盘风格，统一朝向 +Z）
# 用法：ProjectileKit.create("arrow") -> Node3D
# ============================================================

const KIT := preload("res://scripts/visuals/UnitModelKit.gd")

static var _mesh_cache: Dictionary = {}
static var _light_mat: ShaderMaterial

# 子弹专用材质：比单位更亮、偏自发光，强化"飞行物"的质感
static func light_material() -> ShaderMaterial:
	if _light_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/toon_unit.gdshader")
		m.set_shader_parameter("emissive_boost", 1.45)
		m.set_shader_parameter("rim_strength", 0.55)
		m.set_shader_parameter("rim_color", Color(1.0, 0.92, 0.72))
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			m.set_shader_parameter("vertex_srgb", 0.0)
		var o := ShaderMaterial.new()
		o.shader = load("res://assets/shaders/toon_outline.gdshader")
		o.set_shader_parameter("width", 0.008)
		m.next_pass = o
		_light_mat = m
	return _light_mat

static func create(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Projectile_" + kind
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_for(kind)
	mi.material_override = light_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root

static func mesh_for(kind: String) -> ArrayMesh:
	if _mesh_cache.has(kind):
		return _mesh_cache[kind]
	var g := KIT.Geo.new()
	var wood := Color(0.60, 0.40, 0.24)
	var metal := Color(0.80, 0.84, 0.90)
	var iron := Color(0.30, 0.33, 0.40)
	var accent := Color(0.95, 0.30, 0.20)
	var hot_orange := Color(1.0, 0.52, 0.10)
	var hot_yellow := Color(1.0, 0.88, 0.42)
	var cyan := Color(0.35, 0.80, 1.0)
	var pale := Color(0.95, 0.99, 1.0)
	match kind:
		"arrow":
			g.cyl(Vector3.ZERO, 0.014, 0.014, 0.44, wood, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.10), 0.017, 0.017, 0.02, Color(0.42, 0.30, 0.18), Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, 0.27), 0.035, 0.13, metal, Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(0, 0, -0.21), Vector3(0.02, 0.02, 0.04), accent)
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				g.prism(Vector3(cos(a) * 0.045, sin(a) * 0.045, -0.17), Vector3(0.10, 0.10, 0.012), accent, Vector3(0, 0, a), 0.0)
		"musket":
			# 铅弹：黑色球形（带一点灰色高光）
			g.sphere(Vector3.ZERO, 0.11, Color(0.06, 0.06, 0.07))
			g.sphere(Vector3(-0.03, 0.04, 0.04), 0.045, Color(0.24, 0.24, 0.26))
			g.sphere(Vector3(0.05, -0.02, -0.03), 0.03, Color(0.16, 0.16, 0.18))
		"fireball":
			g.sphere(Vector3(0, 0, 0.02), 0.135, Color(0.95, 0.30, 0.08))
			g.sphere(Vector3(0, 0, 0.04), 0.100, hot_orange)
			g.sphere(Vector3(0, 0, 0.06), 0.058, hot_yellow)
			g.sphere(Vector3(0, 0, 0.08), 0.030, pale)
			g.cone(Vector3(0, 0, -0.22), 0.115, 0.34, Color(0.90, 0.24, 0.06), Vector3(-PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, -0.40), 0.070, 0.24, Color(0.72, 0.14, 0.04), Vector3(-PI * 0.5, 0, 0))
			g.sphere(Vector3(0.07, 0.05, -0.05), 0.045, Color(1.0, 0.62, 0.18))
			g.sphere(Vector3(-0.06, -0.04, -0.10), 0.035, Color(1.0, 0.55, 0.14))
			g.sphere(Vector3(0.02, -0.06, -0.30), 0.028, Color(1.0, 0.45, 0.10))
		"energy":
			g.sphere(Vector3.ZERO, 0.095, Color(0.28, 0.68, 0.95))
			g.sphere(Vector3(0, 0, 0.02), 0.060, cyan)
			g.sphere(Vector3(0, 0, 0.04), 0.028, pale)
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				g.torus(Vector3.ZERO, 0.10, 0.125, Color(0.55, 0.90, 1.0), Vector3(PI * 0.5, a, 0))
			for i in 6:
				var a2: float = TAU * float(i) / 6.0
				g.cone(Vector3(cos(a2) * 0.12, sin(a2) * 0.12, 0), 0.018, 0.06, cyan, Vector3(0, 0, -a2))
			g.cone(Vector3(0, 0, -0.18), 0.07, 0.22, Color(0.40, 0.80, 1.0), Vector3(-PI * 0.5, 0, 0))
		"plasma":
			g.sphere(Vector3.ZERO, 0.145, Color(0.45, 0.75, 1.0))
			g.sphere(Vector3(0, 0, 0.03), 0.095, Color(0.78, 0.94, 1.0))
			g.sphere(Vector3(0, 0, 0.06), 0.045, pale)
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				g.torus(Vector3.ZERO, 0.16, 0.195, Color(0.70, 0.92, 1.0), Vector3(PI * 0.5, a, 0))
			# 电弧
			g.box(Vector3(0.12, 0, 0.10), Vector3(0.05, 0.03, 0.20), pale, Vector3(0, 0.5, 0))
			g.box(Vector3(-0.12, 0.02, -0.08), Vector3(0.04, 0.03, 0.18), pale, Vector3(0, -0.6, 0))
			g.box(Vector3(0, 0.13, -0.02), Vector3(0.03, 0.05, 0.16), pale, Vector3(0.4, 0, 0))
			g.cone(Vector3(0, 0, -0.26), 0.09, 0.22, Color(0.50, 0.85, 1.0), Vector3(-PI * 0.5, 0, 0))
		"lightning":
			g.box(Vector3(0, 0, 0.10), Vector3(0.06, 0.06, 0.22), pale, Vector3(0, 0.35, 0))
			g.box(Vector3(0.05, 0, -0.03), Vector3(0.055, 0.055, 0.20), Color(0.95, 1.0, 1.0), Vector3(0, -0.45, 0))
			g.box(Vector3(-0.03, 0, -0.17), Vector3(0.05, 0.05, 0.18), Color(0.80, 0.95, 1.0), Vector3(0, 0.30, 0))
			g.box(Vector3(0.10, 0.09, 0.02), Vector3(0.035, 0.035, 0.10), Color(0.85, 0.97, 1.0), Vector3(0, 0.9, 0))
			g.sphere(Vector3(0, 0, 0.22), 0.05, pale)
			g.sphere(Vector3(0, 0, -0.28), 0.035, Color(0.75, 0.92, 1.0))
		"cannonball":
			g.sphere(Vector3.ZERO, 0.105, iron)
			g.sphere(Vector3(-0.03, 0.035, 0.045), 0.032, Color(0.66, 0.70, 0.78))
			g.torus(Vector3(0, 0, -0.06), 0.07, 0.095, Color(0.46, 0.50, 0.58), Vector3(PI * 0.5, 0, 0))
			g.sphere(Vector3(0, 0, -0.16), 0.07, Color(0.60, 0.60, 0.63))
			g.sphere(Vector3(0.02, 0, -0.26), 0.085, Color(0.52, 0.52, 0.56))
		"shell":
			g.cyl(Vector3(0, 0, 0.02), 0.075, 0.075, 0.26, Color(0.62, 0.58, 0.42), Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, 0.21), 0.075, 0.14, Color(0.95, 0.72, 0.28), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.10), 0.075, 0.095, Color(0.42, 0.40, 0.34), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.06), 0.075, 0.095, Color(0.42, 0.40, 0.34), Vector3(PI * 0.5, 0, 0))
			g.sphere(Vector3(0, 0, -0.14), 0.06, Color(0.80, 0.78, 0.72))
			g.sphere(Vector3(0, 0, -0.22), 0.075, Color(0.68, 0.66, 0.62))
			g.sphere(Vector3(0.02, 0.02, -0.30), 0.09, Color(0.58, 0.56, 0.54))
		"barrel":
			g.cyl(Vector3(0, 0, 0.06), 0.17, 0.19, 0.42, Color(0.62, 0.42, 0.24), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.06), 0.17, 0.20, Color(0.32, 0.32, 0.34), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.10), 0.17, 0.20, Color(0.32, 0.32, 0.34), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.22), 0.17, 0.20, Color(0.32, 0.32, 0.34), Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.28), 0.17, 0.17, 0.03, Color(0.52, 0.34, 0.20), Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(0, 0.19, 0.06), Vector3(0.10, 0.04, 0.34), Color(0.35, 0.55, 0.30))
		"boulder":
			g.sphere(Vector3(0, 0, 0.02), 0.20, Color(0.52, 0.52, 0.50))
			g.sphere(Vector3(-0.10, 0.05, 0.05), 0.13, Color(0.44, 0.44, 0.42))
			g.sphere(Vector3(0.09, -0.04, 0.10), 0.11, Color(0.60, 0.59, 0.56))
			g.sphere(Vector3(0.02, 0.10, -0.08), 0.10, Color(0.46, 0.46, 0.44))
			g.box(Vector3(-0.04, -0.10, -0.02), Vector3(0.10, 0.06, 0.08), Color(0.40, 0.40, 0.38))
		"bomb":
			g.sphere(Vector3.ZERO, 0.11, Color(0.22, 0.23, 0.27))
			g.sphere(Vector3(-0.03, 0.04, 0.05), 0.03, Color(0.55, 0.58, 0.64))
			g.torus(Vector3(0, 0, 0), 0.085, 0.11, metal, Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0.12, 0), 0.018, 0.018, 0.10, wood)
			g.sphere(Vector3(0.04, 0.20, 0), 0.035, hot_yellow)
			g.sphere(Vector3(0.09, 0.24, 0), 0.022, Color(1.0, 0.55, 0.15))
			g.cone(Vector3(0, 0, -0.20), 0.08, 0.18, Color(0.55, 0.55, 0.58), Vector3(-PI * 0.5, 0, 0))
		"snowball":
			g.sphere(Vector3.ZERO, 0.105, Color(0.92, 0.97, 1.0))
			g.sphere(Vector3(0.05, 0.04, 0.05), 0.048, Color(0.98, 1.0, 1.0))
			g.sphere(Vector3(-0.05, -0.02, 0.04), 0.040, Color(0.84, 0.93, 1.0))
			g.sphere(Vector3(0.01, 0.02, 0.10), 0.022, pale)
			g.cone(Vector3(0, 0, -0.20), 0.075, 0.16, Color(0.78, 0.92, 1.0), Vector3(-PI * 0.5, 0, 0))
		"ice":
			g.cone(Vector3(0, 0, 0.16), 0.075, 0.26, Color(0.85, 0.97, 1.0), Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, -0.10), 0.055, 0.20, Color(0.70, 0.90, 1.0), Vector3(-PI * 0.5, 0, 0))
			g.sphere(Vector3.ZERO, 0.06, Color(0.95, 1.0, 1.0))
			g.torus(Vector3(0, 0, -0.02), 0.07, 0.092, Color(0.75, 0.92, 1.0), Vector3(PI * 0.5, 0, 0))
			g.sphere(Vector3(0.05, 0.05, -0.04), 0.022, pale)
		"spear":
			g.cyl(Vector3.ZERO, 0.016, 0.016, 0.66, wood, Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, 0.40), 0.05, 0.22, metal, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.26), 0.028, 0.044, accent, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.24), 0.026, 0.042, Color(0.45, 0.32, 0.20), Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(0, 0, -0.30), Vector3(0.03, 0.09, 0.10), accent)
		"barb_barrel":
			# 圆胖的木桶 + 铁箍 + 外周尖刺
			g.sphere(Vector3.ZERO, 0.30, Color(0.58, 0.38, 0.22), Vector3(1.0, 1.0, 1.25))
			g.torus(Vector3(0, 0, 0.16), 0.22, 0.275, Color(0.30, 0.30, 0.32), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.16), 0.22, 0.275, Color(0.30, 0.30, 0.32), Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.31), 0.16, 0.16, 0.035, Color(0.44, 0.28, 0.16), Vector3(PI * 0.5, 0, 0))
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				var px: float = cos(a) * 0.29
				var py: float = sin(a) * 0.29
				g.cone(Vector3(px, py, 0), 0.075, 0.18, Color(0.72, 0.74, 0.78), Vector3(0, 0, -a))
				g.cone(Vector3(px * 1.35, py * 1.35, 0), 0.04, 0.13, Color(0.86, 0.88, 0.92), Vector3(0, 0, -a))
			g.box(Vector3(0, 0.29, 0.0), Vector3(0.10, 0.05, 0.30), Color(0.34, 0.52, 0.28))
		"log":
			g.cyl(Vector3.ZERO, 0.155, 0.155, 0.62, Color(0.52, 0.34, 0.20), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, 0.17), 0.145, 0.175, Color(0.34, 0.32, 0.30), Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.17), 0.145, 0.175, Color(0.34, 0.32, 0.30), Vector3(PI * 0.5, 0, 0))
			g.cyl(Vector3(0, 0, 0.32), 0.152, 0.152, 0.02, Color(0.70, 0.52, 0.32), Vector3(PI * 0.5, 0, 0))
			g.box(Vector3(0, 0, 0.335), Vector3(0.18, 0.06, 0.02), accent)
			g.box(Vector3(0.10, 0.10, 0.05), Vector3(0.04, 0.12, 0.06), Color(0.42, 0.28, 0.16), Vector3(0.4, 0, 0.3))
		"rocket":
			g.cyl(Vector3.ZERO, 0.065, 0.065, 0.32, Color(0.86, 0.87, 0.92), Vector3(PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, 0.22), 0.065, 0.14, accent, Vector3(PI * 0.5, 0, 0))
			g.torus(Vector3(0, 0, -0.02), 0.065, 0.085, Color(0.55, 0.58, 0.66), Vector3(PI * 0.5, 0, 0))
			for i in 3:
				var a: float = TAU * float(i) / 3.0
				g.prism(Vector3(cos(a) * 0.075, sin(a) * 0.075, -0.14), Vector3(0.11, 0.08, 0.013), accent, Vector3(0, 0, a), 0.0)
			g.cone(Vector3(0, 0, -0.24), 0.06, 0.18, hot_orange, Vector3(-PI * 0.5, 0, 0))
			g.cone(Vector3(0, 0, -0.34), 0.035, 0.14, hot_yellow, Vector3(-PI * 0.5, 0, 0))
		"firework":
			g.sphere(Vector3.ZERO, 0.095, Color(0.95, 0.35, 0.30))
			g.sphere(Vector3(0, 0, 0.05), 0.05, Color(1.0, 0.82, 0.55))
			g.cone(Vector3(0, 0, -0.18), 0.075, 0.20, Color(1.0, 0.55, 0.25), Vector3(-PI * 0.5, 0, 0))
			g.sphere(Vector3(0.10, 0.06, -0.10), 0.028, hot_yellow)
			g.sphere(Vector3(-0.08, -0.07, -0.16), 0.024, Color(1.0, 0.75, 0.35))
			g.sphere(Vector3(0.02, 0.10, -0.24), 0.020, pale)
		"axe":
			g.cyl(Vector3.ZERO, 0.018, 0.018, 0.52, Color(0.52, 0.36, 0.24), Vector3(PI * 0.5, 0, 0))
			g.prism(Vector3(0.17, 0, 0.03), Vector3(0.32, 0.28, 0.055), metal, Vector3.ZERO, 0.0)
			g.prism(Vector3(-0.15, 0, 0.03), Vector3(0.22, 0.20, 0.05), metal, Vector3(0, 0, PI), 0.0)
			g.box(Vector3(0, 0, 0.24), Vector3(0.09, 0.09, 0.07), accent)
			g.cyl(Vector3(0, 0, -0.22), 0.022, 0.022, 0.08, Color(0.35, 0.22, 0.14), Vector3(PI * 0.5, 0, 0))
		"potion":
			g.sphere(Vector3(0, 0, 0.02), 0.10, Color(0.55, 0.85, 0.35))
			g.sphere(Vector3(0, 0, 0.05), 0.055, Color(0.85, 0.98, 0.55))
			g.cyl(Vector3(0, 0.10, 0), 0.035, 0.05, 0.08, Color(0.80, 0.82, 0.86))
			g.cyl(Vector3(0, 0.15, 0), 0.03, 0.035, 0.04, Color(0.62, 0.45, 0.28))
			g.sphere(Vector3(0.05, 0.06, 0.02), 0.018, pale)
			g.cone(Vector3(0, 0, -0.16), 0.05, 0.14, Color(0.55, 0.85, 0.40), Vector3(-PI * 0.5, 0, 0))
		_:
			g.sphere(Vector3.ZERO, 0.10, accent)
			g.sphere(Vector3(0, 0, 0.045), 0.055, Color(1.0, 0.88, 0.60))
			g.cone(Vector3(0, 0, -0.16), 0.06, 0.16, Color(1.0, 0.55, 0.25), Vector3(-PI * 0.5, 0, 0))
	var m: ArrayMesh = g.commit()
	_mesh_cache[kind] = m
	return m
