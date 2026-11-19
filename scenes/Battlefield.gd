# scripts/scenes/Battlefield.gd
# 玩具沙盘风格战场：草地 + 河流 + 木桥 + 石质边界 + 场景装饰
extends Node3D

const SUN_DIR := Vector3(0.42, 0.72, -0.42)
const WATER_SHADER := "res://assets/shaders/water.gdshader"

const COL_GRASS_A := Color(0.17, 0.30, 0.15)
const COL_GRASS_B := Color(0.27, 0.42, 0.21)
const COL_STONE := Color(0.66, 0.63, 0.56)
const COL_STONE_DARK := Color(0.48, 0.46, 0.41)
const COL_WOOD := Color(0.60, 0.41, 0.25)
const COL_WOOD_DARK := Color(0.42, 0.28, 0.18)

const GROUND_KINDS := ["grass","bones","sand","arcane","planks","metal","marble","ice","moss","rock","neon","cobblestone","dirt","jade","tracks","checker","sandstone","jade","lava","dirt","festival","pancake","ice","gold","wood","cobblestone","brick","marble","arcane","void","wood","spirit"]
const RIVER_KINDS := ["water","pit","water","magic","gears","electric","water","ice","swamp","lava","electric","spirit","creek","water","lava","grease","sand","water","lava","mud","confetti","syrup","cloud","starlight","creek","water","canal","cloud","magic","void","barrel","spirit"]
const BRIDGE_KINDS := ["stone","bone","wood","crystal","iron","steel","gold","ice","rope","stone","metal","bone","rope","stone","iron","steel","stone","gold","bone","wood","festival","waffle","rainbow","gold","log","stone","iron","marble","crystal","chain","wood","spirit"]
const DECOR_KINDS := ["goblin","bones","barbarian","arcane","factory","metal","royal","ice","jungle","rock","electro","spooky","rascal","serene","mine","kitchen","tomb","sanctuary","dragon","camp","festival","pancake","valhalla","legend","lumber","road","street","hero","academy","void","tavern","spirit"]
const COL_TEAM_PLAYER := Color(0.16, 0.45, 0.90)
const COL_TEAM_ENEMY := Color(0.88, 0.20, 0.22)

var ground_body: StaticBody3D
var _grass_tex: ImageTexture
static var _stone_nrm: ImageTexture
var arena_idx: int = 1
var forced_arena: int = 0
var is_workshop: bool = false
var _gears: Array = []
var th_grass: Color = COL_GRASS_A
var th_grass2: Color = COL_GRASS_B
var th_stone: Color = COL_STONE
var th_stone_dark: Color = COL_STONE_DARK
var th_wood: Color = COL_WOOD
var th_wood_dark: Color = COL_WOOD_DARK
var th_path: Color = Color(0.55, 0.44, 0.28)
var th_water: Color = Color(0.18, 0.52, 0.68)
var th_sky: Color = Color(0.52, 0.72, 0.90)
var th_accent: Color = Color(0.90, 0.72, 0.28)
var ground_kind: String = "grass"
var river_kind: String = "water"
var bridge_kind: String = "wood"
var decor_kind: String = "goblin"
static var _wood_nrm: ImageTexture

const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")

func _ready():
	# 按对战模式决定战场长度（冲线 80 米），必须在生成地形前设置
	var mode := BATTLE_MODES.current()
	var env_mode := OS.get_environment("CR_MODE_ID")
	if env_mode != "":
		mode = BATTLE_MODES.get_by_id(env_mode)
	var td := String(mode.get("win_condition", "")) == "touchdown"
	Config.set_arena_size(
		Config.ARENA_TOUCHDOWN_WIDTH if td else Config.ARENA_BASE_WIDTH,
		Config.ARENA_TOUCHDOWN_HEIGHT if td else Config.ARENA_BASE_HEIGHT)
	var force_arena := OS.get_environment("CR_ARENA_FORCE")
	if forced_arena > 0:
		arena_idx = forced_arena
	elif force_arena != "":
		arena_idx = int(force_arena)
	elif PlayerData.test_mode:
		arena_idx = randi_range(1, 32)
	else:
		arena_idx = PlayerData.get_arena()
	is_workshop = arena_idx == 5
	if td:
		_apply_football_theme()
		_setup_lighting()
		_apply_arena_environment()
		_grass_tex = _make_grass_texture()
		_generate_touchdown_field()
		_generate_stadium()
		_apply_touchdown_camera()
		return
	_apply_arena_theme()
	_setup_lighting()
	_apply_arena_environment()
	_grass_tex = _make_grass_texture()
	generate_grass()
	generate_river()
	generate_bridges()
	_generate_border()
	_generate_outer_ground()
	_generate_decor()
	_generate_theme_decor()
	if td:
		_apply_touchdown_camera()

func _generate_stadium() -> void:
	var W: float = Config.ARENA_WIDTH
	var H: float = Config.ARENA_HEIGHT
	var z0: float = Config.ARENA_ORIGIN.z
	# 广告板（长边）
	for sx in [-1.0, 1.0]:
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 1.1, H * 0.82)
		board.mesh = bm
		board.position = Vector3(sx * (W * 0.5 + 1.0), 0.55, 0)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.10, 0.16, 0.26) if sx < 0 else Color(0.24, 0.10, 0.12)
		bmat.roughness = 0.9
		board.material_override = bmat
		add_child(board)
	# 看台（两层，安静的中性色，带观众点）
	for sx in [-1.0, 1.0]:
		for tier in 2:
			var stand := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(2.2, 0.9 + tier * 0.9, H * 0.88)
			stand.mesh = sm
			stand.position = Vector3(sx * (W * 0.5 + 3.0 + tier * 1.8), (0.9 + tier * 0.9) * 0.5, 0)
			var stm := StandardMaterial3D.new()
			stm.albedo_color = Color(0.12, 0.13, 0.16) if tier == 0 else Color(0.16, 0.16, 0.19)
			stm.roughness = 1.0
			stand.material_override = stm
			add_child(stand)
		# 观众小点
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		for i in 70:
			var crowd := MeshInstance3D.new()
			var cmm := BoxMesh.new()
			cmm.size = Vector3(0.22, 0.22, 0.22)
			crowd.mesh = cmm
			crowd.position = Vector3(
				sx * (W * 0.5 + 2.4 + rng.randf_range(0.0, 3.4)),
				rng.randf_range(0.9, 1.9),
				z0 + rng.randf_range(H * 0.06, H * 0.94))
			var cmat := StandardMaterial3D.new()
			var ccol := Color.from_hsv(rng.randf(), 0.25, 0.55)
			cmat.albedo_color = ccol
			crowd.material_override = cmat
			add_child(crowd)
	# 四角灯柱
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = Vector3(0.18, 7.0, 0.18)
			pole.mesh = pbm
			pole.position = Vector3(sx * (W * 0.5 + 2.2), 3.5, z0 + (0.8 if sz < 0 else H - 0.8))
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.32, 0.34, 0.38)
			pm.roughness = 0.7
			pole.material_override = pm
			add_child(pole)
			var lamp := MeshInstance3D.new()
			var lbm := BoxMesh.new()
			lbm.size = Vector3(1.4, 0.35, 0.5)
			lamp.mesh = lbm
			lamp.position = pole.position + Vector3(0, 3.5, 0)
			var lm := StandardMaterial3D.new()
			lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lm.albedo_color = Color(1.0, 0.98, 0.85)
			lamp.material_override = lm
			add_child(lamp)


func _apply_touchdown_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	cam.size = 72.0
	cam.position = Vector3(0.0, 30.0, 18.0)
	cam.near = 8.0
	cam.far = 400.0


func _apply_football_theme() -> void:
	th_grass = Color(0.16, 0.48, 0.20)
	th_grass2 = Color(0.23, 0.60, 0.26)
	th_path = Color(0.95, 0.95, 0.95)
	th_stone = Color(0.85, 0.87, 0.85)
	th_wood = Color(0.55, 0.42, 0.28)
	th_water = Color(0.22, 0.52, 0.72)
	th_sky = Color(0.48, 0.74, 0.95)
	th_accent = Color(0.95, 0.80, 0.35)


func _football_line(center: Vector3, size: Vector3, y := 0.02) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.02, size.z)
	mi.mesh = bm
	mi.position = Vector3(center.x, y, center.z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.96, 0.94)
	mi.material_override = mat
	add_child(mi)


func _generate_touchdown_field() -> void:
	var W: float = Config.ARENA_WIDTH
	var H: float = Config.ARENA_HEIGHT
	var z0: float = Config.ARENA_ORIGIN.z
	# 碰撞体（BattleManager 依赖 GroundPlane）
	if ground_body:
		remove_child(ground_body)
	ground_body = StaticBody3D.new()
	ground_body.name = "GroundPlane"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, 0.1, H)
	col_shape.shape = box
	ground_body.add_child(col_shape)
	ground_body.position = Vector3(0, -0.05, 0)
	add_child(ground_body)
	# 外围草地
	var outer := MeshInstance3D.new()
	var opm := PlaneMesh.new()
	opm.size = Vector2(W + 46.0, H + 40.0)
	outer.mesh = opm
	outer.position = Vector3(0, -0.015, 0)
	var omat := StandardMaterial3D.new()
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.albedo_color = Color(0.06, 0.15, 0.08)
	omat.roughness = 1.0
	outer.material_override = omat
	add_child(outer)
	# 草皮底色 + 修剪条纹（每 5 米一条）
	var base := MeshInstance3D.new()
	var bpm := PlaneMesh.new()
	bpm.size = Vector2(W, H)
	base.mesh = bpm
	base.position = Vector3(0, 0.0, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = _grass_tex
	bmat.uv1_scale = Vector3(Config.ARENA_WIDTH * 0.9, Config.ARENA_HEIGHT * 0.9, 1)
	bmat.albedo_color = Color(0.42, 0.66, 0.42)
	bmat.roughness = 1.0
	base.material_override = bmat
	add_child(base)
	var stripes := 16
	var stripe_h: float = H / float(stripes)
	for i in stripes:
		if i % 2 == 0:
			continue
		var st := MeshInstance3D.new()
		var spm := PlaneMesh.new()
		spm.size = Vector2(W, stripe_h)
		st.mesh = spm
		st.position = Vector3(0, 0.006, z0 + stripe_h * (float(i) + 0.5))
		var smat := StandardMaterial3D.new()
		smat.albedo_texture = _grass_tex
		smat.uv1_scale = Vector3(Config.ARENA_WIDTH * 0.9, Config.ARENA_HEIGHT * 0.9, 1)
		smat.albedo_color = Color(0.34, 0.56, 0.34)
		smat.roughness = 1.0
		st.material_override = smat
		add_child(st)
	# 白色场地线
	var m := 1.0
	_football_line(Vector3(-W * 0.5 + m, 0, 0), Vector3(0.14, 0.02, H - m * 2.0))
	_football_line(Vector3(W * 0.5 - m, 0, 0), Vector3(0.14, 0.02, H - m * 2.0))
	_football_line(Vector3(0, 0, z0 + m), Vector3(W - m * 2.0, 0.02, 0.14))
	_football_line(Vector3(0, 0, z0 + H - m), Vector3(W - m * 2.0, 0.02, 0.14))
	_football_line(Vector3(0, 0, 0), Vector3(W - m * 2.0, 0.02, 0.14))
	# 中圈
	for i in 40:
		var a := TAU * float(i) / 40.0
		var seg := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(0.55, 0.02, 0.14)
		seg.mesh = sbm
		seg.position = Vector3(cos(a) * 6.0, 0.02, sin(a) * 6.0)
		seg.rotation.y = -a
		var wm := StandardMaterial3D.new()
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.albedo_color = Color(0.95, 0.96, 0.94)
		seg.material_override = wm
		add_child(seg)
	# 中圈点
	var spot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = 0.02
	spot.mesh = cm
	spot.position = Vector3(0, 0.03, 0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.95, 0.96, 0.94)
	spot.material_override = sm
	add_child(spot)
	# 两端禁区 + 小禁区 + 点球点 + 球门
	for end in [-1.0, 1.0]:
		var goal_z: float = z0 + (m if end < 0 else H - m)
		var dir: float = 1.0 if end < 0 else -1.0
		var pa_depth := 14.0
		var pa_w := W * 0.58
		var pa_front: float = goal_z + dir * pa_depth
		_football_line(Vector3(0, 0, pa_front), Vector3(pa_w, 0.02, 0.14))
		_football_line(Vector3(-pa_w * 0.5, 0, (goal_z + pa_front) * 0.5), Vector3(0.14, 0.02, pa_depth))
		_football_line(Vector3(pa_w * 0.5, 0, (goal_z + pa_front) * 0.5), Vector3(0.14, 0.02, pa_depth))
		var ga_depth := 6.0
		var ga_w := W * 0.30
		var ga_front: float = goal_z + dir * ga_depth
		_football_line(Vector3(0, 0, ga_front), Vector3(ga_w, 0.02, 0.14))
		_football_line(Vector3(-ga_w * 0.5, 0, (goal_z + ga_front) * 0.5), Vector3(0.14, 0.02, ga_depth))
		_football_line(Vector3(ga_w * 0.5, 0, (goal_z + ga_front) * 0.5), Vector3(0.14, 0.02, ga_depth))
		# 点球点
		var ps := MeshInstance3D.new()
		var pcm := CylinderMesh.new()
		pcm.top_radius = 0.15
		pcm.bottom_radius = 0.15
		pcm.height = 0.02
		ps.mesh = pcm
		ps.position = Vector3(0, 0.03, goal_z + dir * 10.0)
		var psm := StandardMaterial3D.new()
		psm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		psm.albedo_color = Color(0.95, 0.96, 0.94)
		ps.material_override = psm
		add_child(ps)
		# 球门柱 + 横梁 + 球网
		for gx in [-W * 0.09, W * 0.09]:
			var post := MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = Vector3(0.16, 2.4, 0.16)
			post.mesh = pbm
			post.position = Vector3(gx, 1.2, goal_z)
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.97, 0.97, 0.95)
			pm.roughness = 0.6
			post.material_override = pm
			add_child(post)
		var bar := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(W * 0.18, 0.16, 0.16)
		bar.mesh = bbm
		bar.position = Vector3(0, 2.4, goal_z)
		bar.material_override = StandardMaterial3D.new()
		bar.material_override.albedo_color = Color(0.97, 0.97, 0.95)
		add_child(bar)
		var net := MeshInstance3D.new()
		var nbm := BoxMesh.new()
		nbm.size = Vector3(W * 0.18, 2.3, 2.2 * dir)
		net.mesh = nbm
		net.position = Vector3(0, 1.15, goal_z + dir * 0.8)
		var nm := StandardMaterial3D.new()
		nm.albedo_color = Color(1, 1, 1, 0.12)
		nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		net.material_override = nm
		add_child(net)
	# 角旗
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var plbm := BoxMesh.new()
			plbm.size = Vector3(0.06, 1.2, 0.06)
			pole.mesh = plbm
			pole.position = Vector3(sx * (W * 0.5 - m), 0.6, z0 + (m if sz < 0 else H - m))
			pole.material_override = StandardMaterial3D.new()
			pole.material_override.albedo_color = Color(0.95, 0.95, 0.95)
			add_child(pole)

# ============================================================
# 光照 / 环境
# ============================================================
func _process(delta: float) -> void:
	for g in _gears:
		if is_instance_valid(g):
			g.rotation.y += delta * 1.4

func _apply_arena_theme() -> void:
	var hue: float = fmod(float(arena_idx) * 0.137, 1.0)
	th_grass = Color.from_hsv(0.20 + hue * 0.28, 0.42, 0.40)
	th_grass2 = th_grass.lightened(0.18)
	th_stone = Color.from_hsv(0.10, 0.14, 0.64)
	th_stone_dark = th_stone.darkened(0.28)
	th_wood = Color.from_hsv(0.07 + hue * 0.04, 0.48, 0.46)
	th_wood_dark = th_wood.darkened(0.28)
	th_path = Color.from_hsv(0.09 + hue * 0.08, 0.30, 0.56)
	th_water = Color.from_hsv(0.52 + hue * 0.08, 0.62, 0.58)
	th_sky = Color.from_hsv(0.53 + hue * 0.10, 0.38, 0.86)
	th_accent = Color.from_hsv(hue, 0.55, 0.92)
	ground_kind = GROUND_KINDS[clampi(arena_idx - 1, 0, 31)]
	river_kind = RIVER_KINDS[clampi(arena_idx - 1, 0, 31)]
	bridge_kind = BRIDGE_KINDS[clampi(arena_idx - 1, 0, 31)]
	decor_kind = DECOR_KINDS[clampi(arena_idx - 1, 0, 31)]
	match ground_kind:
		"ice":
			th_grass = Color(0.30, 0.46, 0.58); th_grass2 = Color(0.46, 0.62, 0.74); th_path = Color(0.44, 0.58, 0.70); th_sky = Color(0.62, 0.82, 0.96)
		"lava", "void":
			th_grass = Color(0.16, 0.12, 0.13); th_grass2 = Color(0.26, 0.18, 0.16); th_path = Color(0.30, 0.22, 0.18); th_sky = Color(0.16, 0.10, 0.12)
		"checker", "pancake":
			th_grass = Color(0.62, 0.44, 0.22); th_grass2 = Color(0.82, 0.66, 0.34); th_path = Color(0.74, 0.52, 0.28); th_sky = Color(0.92, 0.78, 0.48)
		"gold", "marble":
			th_grass = Color(0.40, 0.34, 0.22); th_grass2 = Color(0.62, 0.54, 0.36); th_path = Color(0.78, 0.68, 0.42); th_sky = Color(0.76, 0.66, 0.42)
		"spirit", "arcane", "neon":
			th_grass = Color(0.18, 0.28, 0.38); th_grass2 = Color(0.28, 0.46, 0.56); th_path = Color(0.36, 0.62, 0.72); th_sky = Color(0.24, 0.40, 0.56)
		"metal", "tracks":
			th_grass = Color(0.24, 0.26, 0.28); th_grass2 = Color(0.34, 0.36, 0.38); th_path = Color(0.40, 0.42, 0.44); th_sky = Color(0.46, 0.48, 0.50)
	if is_workshop:
		th_wood = Color(0.46, 0.29, 0.14)
		th_wood_dark = Color(0.30, 0.19, 0.10)
		th_stone = Color(0.42, 0.44, 0.48)
		th_stone_dark = Color(0.24, 0.26, 0.30)
		th_path = Color(0.38, 0.40, 0.44)
		th_water = Color(0.10, 0.10, 0.12)
		th_sky = Color(0.55, 0.48, 0.36)

func _apply_arena_environment() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var we := parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = th_sky
		env.ambient_light_color = th_sky.lightened(0.25)
		env.fog_light_color = th_sky.lightened(0.10)

func _setup_lighting() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var we := parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if we and we.environment:
		var env: Environment = we.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		# Compatibility 渲染器整体更亮，需要压曝光/环境光才能和 mobile/vulkan 观感一致
		env.ambient_light_energy = 0.44 if compat else 0.52
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.90 if compat else 1.0
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.04
		env.adjustment_saturation = 1.14
		env.ssao_enabled = true
		env.ssao_radius = 1.1
		env.ssao_intensity = 1.5
		env.fog_enabled = true
		env.fog_light_color = Color(0.68, 0.74, 0.80)
		env.fog_light_energy = 0.6
		env.fog_density = 0.0012
		env.fog_sky_affect = 0.0
	var sun := parent.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.light_energy = 1.15 if compat else 1.35
		sun.shadow_enabled = true
		sun.shadow_blur = 1.2
		sun.shadow_bias = 0.015
		sun.shadow_normal_bias = 1.2
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 45.0
		sun.position = Vector3(0, 12, 0)
		sun.look_at(sun.global_position - SUN_DIR * 10.0, Vector3.UP)
	# 冷色补光：让暗部有层次
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.70, 1.0)
	fill.light_energy = 0.28 if compat else 0.38
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-30, 150, 0)
	add_child(fill)

# ============================================================
# 地面
# ============================================================
func generate_grass():
	if ground_body:
		remove_child(ground_body)
	# 射线落点碰撞体（BattleManager 依赖名字 GroundPlane）
	ground_body = StaticBody3D.new()
	ground_body.name = "GroundPlane"
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(Config.ARENA_WIDTH, 0.1, Config.ARENA_HEIGHT)
	col_shape.shape = box
	ground_body.add_child(col_shape)
	ground_body.position = Vector3(0, -0.05, 0)
	add_child(ground_body)

	# 草地（整块，不再镜像拼接）
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Config.ARENA_WIDTH, Config.ARENA_HEIGHT)
	grass.mesh = plane
	grass.position = Vector3(0, 0.002, 0)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://assets/shaders/ground.gdshader")
	gm.set_shader_parameter("grass_tex", _grass_tex)
	gm.set_shader_parameter("arena_cells", Vector2(Config.ARENA_WIDTH, Config.ARENA_HEIGHT))
	gm.set_shader_parameter("uv_tiles", 9.0)
	gm.set_shader_parameter("path_origin", Vector2(Config.ARENA_ORIGIN.x, Config.ARENA_ORIGIN.z))
	gm.set_shader_parameter("path_size", Vector2(Config.ARENA_WIDTH, Config.ARENA_HEIGHT))
	gm.set_shader_parameter("lane_x1", Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0)
	gm.set_shader_parameter("lane_x2", Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0)
	gm.set_shader_parameter("pad_z_player", Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 25.5 / 32.0)
	gm.set_shader_parameter("pad_z_enemy", Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)
	gm.set_shader_parameter("king_z_player", Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 29.0 / 32.0)
	gm.set_shader_parameter("king_z_enemy", Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 3.0 / 32.0)
	gm.set_shader_parameter("line_color", th_path.darkened(0.42))
	gm.set_shader_parameter("path_color", th_path)
	grass.material_override = gm
	add_child(grass)
	if is_workshop:
		_generate_workshop_floor()
	else:
		_generate_ground_style()

	# 阵营半场淡色提示
	_add_half_tint(Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.75, COL_TEAM_ENEMY)
	_add_half_tint(Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.25, COL_TEAM_PLAYER)

func _add_half_tint(center_z: float, col: Color) -> void:
	var half := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Config.ARENA_WIDTH, Config.ARENA_HEIGHT * 0.5)
	half.mesh = pm
	half.position = Vector3(0, 0.012, center_z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.10)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	half.material_override = mat
	add_child(half)

func _generate_outer_ground() -> void:
	var outer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(64, maxf(74.0, Config.ARENA_HEIGHT + 42.0))
	outer.mesh = pm
	outer.position = Vector3(0, -0.05, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _grass_tex
	mat.uv1_scale = Vector3(20, maxf(22.0, Config.ARENA_HEIGHT * 0.69), 1)
	mat.albedo_color = th_grass2.lightened(0.20)
	mat.roughness = 1.0
	outer.material_override = mat
	add_child(outer)

# ============================================================
# 河 + 桥
# ============================================================
func generate_river():
	if river_kind == "gears":
		_generate_gear_pit()
		return
	if river_kind != "water":
		_generate_style_river()
		return
	var river_width := 2.0
	var river_z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var river := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Config.ARENA_WIDTH + 1.0, river_width)
	river.mesh = pm
	river.position = Vector3(0, 0.03, river_z)
	var mat := ShaderMaterial.new()
	mat.shader = load(WATER_SHADER)
	mat.set_shader_parameter("deep_color", th_water.darkened(0.35))
	mat.set_shader_parameter("shallow_color", th_water.lightened(0.15))
	mat.set_shader_parameter("foam_color", th_water.lightened(0.65))
	river.material_override = mat
	add_child(river)

	# 岸边石
	var sm := StandardMaterial3D.new()
	sm.albedo_color = COL_STONE_DARK
	sm.roughness = 0.95
	for i in 12:
		for side in [-1.0, 1.0]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.55, 0.12, 0.22)
			b.mesh = bm
			b.position = Vector3(-8.5 + float(i) * 1.55, 0.05, river_z + side * (river_width * 0.5 + 0.08))
			b.rotation.y = 0.10 * float(i % 3) * side
			b.material_override = sm
			add_child(b)
	# 芦苇
	for i in 18:
		var side := -1.0 if i % 2 == 0 else 1.0
		var rx := -8.6 + float(i % 9) * 1.9 + (0.35 if side > 0.0 else 0.0)
		var root := Node3D.new()
		root.position = Vector3(rx, 0.02, river_z + side * (river_width * 0.5 + 0.24))
		add_child(root)
		for j in 3:
			var reed := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.03
			cm.height = 0.34 + 0.08 * float(j)
			reed.mesh = cm
			reed.position = Vector3(-0.06 + 0.06 * float(j), cm.height * 0.5, 0.02 * float(j))
			reed.rotation.z = -0.18 + 0.18 * float(j)
			reed.material_override = _flat_mat(Color(0.36, 0.48, 0.24))
			root.add_child(reed)
	# 荷叶
	for i in 6:
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.02
		pad.mesh = cm
		pad.position = Vector3(-7.0 + float(i) * 2.6, 0.045, river_z + (-0.6 + 0.25 * float(i % 4)))
		pad.scale = Vector3(0.8 + 0.1 * float(i % 3), 1.0, 0.7 + 0.08 * float(i % 2))
		pad.material_override = _flat_mat(Color(0.22, 0.44, 0.20))
		add_child(pad)

func generate_bridges():
	if bridge_kind == "iron" or bridge_kind == "steel" or bridge_kind == "chain":
		_generate_iron_bridges()
		return
	if bridge_kind != "wood":
		_generate_style_bridges()
		return
	var bridge_z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var bridges_x := [
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0,
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	]
	for bx in bridges_x:
		var root := Node3D.new()
		root.name = "Bridge"
		root.position = Vector3(bx, 0, bridge_z)
		add_child(root)
		# 支撑桩
		for sx in [-1.15, 1.15]:
			for sz in [-1.2, 1.2]:
				var pile := MeshInstance3D.new()
				var pcm := CylinderMesh.new()
				pcm.top_radius = 0.09
				pcm.bottom_radius = 0.11
				pcm.height = 0.9
				pile.mesh = pcm
				pile.position = Vector3(sx, 0.12, sz)
				pile.material_override = _wood_mat(COL_WOOD_DARK)
				root.add_child(pile)
		# 桥底 + 侧梁（3x3）
		var deck := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(3.0, 0.16, 3.0)
		deck.mesh = dm
		deck.position.y = 0.16
		deck.material_override = _wood_mat(COL_WOOD_DARK)
		root.add_child(deck)
		for side in [-1.0, 1.0]:
			var beam := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.14, 0.18, 3.0)
			beam.mesh = bm
			beam.position = Vector3(side * 1.47, 0.28, 0)
			beam.material_override = _wood_mat(COL_WOOD)
			root.add_child(beam)
		# 木板条
		for i in 8:
			var plank := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(2.96, 0.05, 0.36)
			plank.mesh = pm
			plank.position = Vector3(0, 0.255, -1.26 + float(i) * 0.36)
			plank.material_override = _wood_mat(COL_WOOD if i % 2 == 0 else COL_WOOD.darkened(0.12))
			root.add_child(plank)
		# 栏杆
		for side in [-1.0, 1.0]:
			for j in 3:
				var post := MeshInstance3D.new()
				var pm2 := BoxMesh.new()
				pm2.size = Vector3(0.10, 0.62, 0.10)
				post.mesh = pm2
				post.position = Vector3(side * 1.47, 0.55, -1.2 + float(j) * 1.2)
				post.material_override = _wood_mat(COL_WOOD_DARK)
				root.add_child(post)
				var ball := MeshInstance3D.new()
				var bm2 := SphereMesh.new()
				bm2.radius = 0.07
				bm2.height = 0.14
				ball.mesh = bm2
				ball.position = Vector3(side * 1.47, 0.9, -1.2 + float(j) * 1.2)
				ball.material_override = _wood_mat(Color(0.72, 0.54, 0.32))
				root.add_child(ball)
			for ry in [0.72, 0.42]:
				var rail := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.05, 0.05, 2.9)
				rail.mesh = rm
				rail.position = Vector3(side * 1.47, ry, 0)
				rail.material_override = _wood_mat(COL_WOOD)
				root.add_child(rail)
		# 桥头灯
		for sx in [-1.55, 1.55]:
			for sz in [-1.5, 1.5]:
				var pole := MeshInstance3D.new()
				var pcm2 := CylinderMesh.new()
				pcm2.top_radius = 0.035
				pcm2.bottom_radius = 0.045
				pcm2.height = 0.95
				pole.mesh = pcm2
				pole.position = Vector3(sx, 0.48, sz)
				pole.material_override = _wood_mat(COL_WOOD_DARK)
				root.add_child(pole)
				var lamp := MeshInstance3D.new()
				var lm := SphereMesh.new()
				lm.radius = 0.10
				lm.height = 0.20
				lamp.mesh = lm
				lamp.position = Vector3(sx, 0.98, sz)
				lamp.material_override = _glow_mat(Color(1.0, 0.82, 0.42))
				root.add_child(lamp)

func _generate_workshop_floor() -> void:
	# 木板格子地面
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Config.ARENA_WIDTH, 0.06, Config.ARENA_HEIGHT)
	base.mesh = bm
	base.position = Vector3(0, 0.02, 0)
	base.material_override = _wood_mat(th_wood_dark.darkened(0.25))
	add_child(base)
	var rows := 20
	for r in range(rows):
		var z := Config.ARENA_ORIGIN.z + 0.8 + r * (Config.ARENA_HEIGHT - 1.6) / float(rows - 1)
		for c in range(9):
			var plank := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(Config.ARENA_WIDTH / 9.0 - 0.10, 0.05, (Config.ARENA_HEIGHT - 1.6) / float(rows - 1) - 0.06)
			plank.mesh = pm
			plank.position = Vector3(-Config.ARENA_WIDTH * 0.5 + Config.ARENA_WIDTH / 18.0 + c * Config.ARENA_WIDTH / 9.0, 0.06, z)
			var shade: float = 0.06 * float((r + c) % 3)
			plank.material_override = _wood_mat((th_wood if (r + c) % 2 == 0 else th_wood.darkened(0.10)).darkened(shade))
			add_child(plank)
	# 铁质路径与塔基
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.30, 0.32, 0.36)
	iron.metallic = 0.65
	iron.roughness = 0.42
	for x in [-5.5, 5.5]:
		var lane := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(1.5, 0.06, Config.ARENA_HEIGHT - 2.0)
		lane.mesh = lm
		lane.position = Vector3(x, 0.075, 0)
		lane.material_override = iron
		add_child(lane)
	for pos in [Vector3(-5.5, 0.08, 10.0), Vector3(5.5, 0.08, 10.0), Vector3(-5.5, 0.08, -10.0), Vector3(5.5, 0.08, -10.0), Vector3(0, 0.08, 13.0), Vector3(0, 0.08, -13.0)]:
		var pad := MeshInstance3D.new()
		var pm2 := BoxMesh.new()
		pm2.size = Vector3(3.4, 0.07, 3.4)
		pad.mesh = pm2
		pad.position = pos
		pad.material_override = iron
		add_child(pad)

func _generate_gear_pit() -> void:
	var z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var depth := 2.6
	var trench := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(Config.ARENA_WIDTH, 0.10, depth)
	trench.mesh = tm
	trench.position = Vector3(0, 0.02, z)
	trench.material_override = _flat_mat(Color(0.035, 0.035, 0.045))
	add_child(trench)
	# 沟沿铁板
	for side in [-1.0, 1.0]:
		var lip := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(Config.ARENA_WIDTH, 0.18, 0.22)
		lip.mesh = lm
		lip.position = Vector3(0, 0.11, z + side * (depth * 0.5 + 0.12))
		lip.material_override = _stone_mat(Color(0.30, 0.32, 0.36))
		add_child(lip)
	# 齿轮
	for gx in [-6.4, -3.2, 0.0, 3.2, 6.4]:
		var root := Node3D.new()
		root.position = Vector3(gx, 0.12, z)
		add_child(root)
		var gear := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.55
		gm.bottom_radius = 0.55
		gm.height = 0.16
		gear.mesh = gm
		gear.material_override = _stone_mat(Color(0.42, 0.44, 0.48))
		root.add_child(gear)
		for i in range(10):
			var a := TAU * float(i) / 10.0
			var tooth := MeshInstance3D.new()
			var tm2 := BoxMesh.new()
			tm2.size = Vector3(0.22, 0.16, 0.22)
			tooth.mesh = tm2
			tooth.position = Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62)
			tooth.material_override = _stone_mat(Color(0.36, 0.38, 0.42))
			root.add_child(tooth)
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.18
		hm.bottom_radius = 0.18
		hm.height = 0.20
		hub.mesh = hm
		hub.material_override = _stone_mat(th_accent)
		root.add_child(hub)
		_gears.append(root)

func _generate_iron_bridges() -> void:
	var bridge_z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var bridges_x := [
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0,
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	]
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.34, 0.36, 0.40)
	iron.metallic = 0.7
	iron.roughness = 0.38
	for bx in bridges_x:
		var root := Node3D.new()
		root.name = "IronBridge"
		root.position = Vector3(bx, 0, bridge_z)
		add_child(root)
		var deck := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(3.0, 0.18, 3.0)
		deck.mesh = dm
		deck.position.y = 0.16
		deck.material_override = iron
		root.add_child(deck)
		for i in range(6):
			var plate := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(2.94, 0.04, 0.48)
			plate.mesh = pm
			plate.position = Vector3(0, 0.26, -1.25 + i * 0.5)
			plate.material_override = _stone_mat(Color(0.40, 0.42, 0.46))
			root.add_child(plate)
			for sx in [-1.0, 0.0, 1.0]:
				var rivet := MeshInstance3D.new()
				var rm := SphereMesh.new()
				rm.radius = 0.045
				rm.height = 0.09
				rivet.mesh = rm
				rivet.position = Vector3(sx * 1.1, 0.29, -1.25 + i * 0.5)
				rivet.material_override = _stone_mat(th_accent)
				root.add_child(rivet)
		for side in [-1.0, 1.0]:
			var beam := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.16, 0.20, 3.0)
			beam.mesh = bm
			beam.position = Vector3(side * 1.55, 0.28, 0)
			beam.material_override = iron
			root.add_child(beam)
			for j in range(3):
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.12, 0.70, 0.12)
				post.mesh = pm
				post.position = Vector3(side * 1.55, 0.62, -1.1 + j * 1.1)
				post.material_override = iron
				root.add_child(post)
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.08, 0.08, 2.8)
			rail.mesh = rm
			rail.position = Vector3(side * 1.55, 0.96, 0)
			rail.material_override = iron
			root.add_child(rail)

func _mk_box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi

func _generate_ground_style() -> void:
	match ground_kind:
		"ice":
			for i in range(8):
				var sx := -8.0 + i * 2.2
				_add_snow_pile(Vector3(sx, 0.0, -13.0 if i % 2 == 0 else 13.0))
		"air", "checker", "pancake":
			for x in range(-8, 9, 2):
				for z in range(-14, 15, 2):
					if int((x + z) / 2) % 2 == 0:
						var c := Color(0.74, 0.54, 0.28) if ground_kind == "pancake" else Color(0.54, 0.52, 0.60)
						_mk_box(Vector3(x, 0.035, z), Vector3(1.9, 0.02, 1.9), _stone_mat(c))
		"tracks":
			for x in [-5.5, 5.5]:
				for rx in [-0.55, 0.55]:
					_mk_box(Vector3(x + rx, 0.06, 0), Vector3(0.10, 0.04, Config.ARENA_HEIGHT - 2.0), _stone_mat(Color(0.44, 0.46, 0.50)))
				for z in range(-14, 15, 2):
					_mk_box(Vector3(x, 0.045, z), Vector3(1.5, 0.04, 0.18), _wood_mat(th_wood_dark))
		"lava", "void":
			var crack_mat := _glow_mat(Color(0.95, 0.34, 0.12) if ground_kind == "lava" else Color(0.55, 0.32, 1.0))
			for i in range(12):
				var x := -8.0 + i * 1.45
				_mk_box(Vector3(x, 0.045, -11.0 + (i % 5) * 5.4), Vector3(0.16, 0.02, 4.2), crack_mat)
			if ground_kind == "lava":
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.40, 0.14)
				l.light_energy = 1.4
				l.omni_range = 7.0
				l.position = Vector3(0, 1.0, 0)
				add_child(l)
		"arcane", "spirit", "neon":
			for i in range(5):
				var x := -6.0 + i * 3.0
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.55
				tm.outer_radius = 0.72
				ring.mesh = tm
				ring.position = Vector3(x, 0.05, -3.0 + (i % 2) * 6.0)
				ring.material_override = _glow_mat(th_accent)
				add_child(ring)
		"bones", "sandstone", "cobblestone", "brick":
			var c := Color(0.78, 0.70, 0.54) if ground_kind == "sandstone" else Color(0.46, 0.44, 0.40)
			for i in range(10):
				var x := -7.5 + i * 1.7
				_mk_box(Vector3(x, 0.045, -13.5 if i % 2 == 0 else 13.5), Vector3(1.4, 0.05, 0.8), _stone_mat(c))
		"gold", "marble":
			for i in range(6):
				_mk_box(Vector3(-7.0 + i * 2.8, 0.04, 0), Vector3(2.3, 0.025, 3.4), _stone_mat(Color(0.82, 0.68, 0.34)))
		"festival":
			for i in range(24):
				var x: float = -8.0 + fmod(float(i) * 2.7, 16.0)
				var z: float = -13.5 + fmod(float(i) * 5.3, 27.0)
				var dot := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.08
				sm.height = 0.08
				dot.mesh = sm
				dot.position = Vector3(x, 0.06, z)
				dot.material_override = _flat_mat(Color.from_hsv(float(i) / 24.0, 0.8, 1.0))
				add_child(dot)

func _generate_style_river() -> void:
	var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var width := 2.6
	var col := Color(0.20, 0.52, 0.68)
	var glow := false
	match river_kind:
		"lava":
			col = Color(1.0, 0.36, 0.10)
			glow = true
		"ice":
			col = Color(0.24, 0.42, 0.58)
		"void", "starlight":
			col = Color(0.14, 0.10, 0.26)
		"syrup":
			col = Color(0.48, 0.26, 0.08)
		"swamp", "mud", "creek":
			col = Color(0.24, 0.34, 0.20)
		"magic", "spirit":
			col = Color(0.24, 0.72, 0.78)
			glow = true
		"cloud":
			col = Color(0.88, 0.92, 1.0)
		"confetti":
			col = Color(0.66, 0.30, 0.52)
		"barrel":
			col = Color(0.28, 0.20, 0.12)
		"grease":
			col = Color(0.28, 0.24, 0.14)
		"canal":
			col = Color(0.20, 0.40, 0.52)
		"electric":
			col = Color(0.36, 0.36, 0.86)
			glow = true
		"pit":
			col = Color(0.015, 0.015, 0.02)
		"water":
			col = th_water
	var mat: Material = _glow_mat(col) if glow else _stone_mat(col)
	_mk_box(Vector3(0, 0.04, z), Vector3(Config.ARENA_WIDTH, 0.08, width), mat)
	if river_kind in ["lava", "magic", "spirit", "electric"]:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.8
		l.omni_range = 9.0
		l.position = Vector3(0, 0.8, z)
		add_child(l)
	if river_kind in ["starlight", "void"]:
		for i in range(18):
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.05
			s.mesh = sm
			s.position = Vector3(-8.5 + fmod(float(i) * 2.1, 17.0), 0.10, z - 0.9 + fmod(float(i) * 0.7, 1.8))
			s.material_override = _glow_mat(Color(0.85, 0.90, 1.0))
			add_child(s)
	if river_kind == "cloud":
		for i in range(9):
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.55
			sm.height = 0.55
			puff.mesh = sm
			puff.position = Vector3(-8.0 + i * 2.0, 0.25, z)
			puff.material_override = _flat_mat(Color(0.92, 0.96, 1.0))
			add_child(puff)
	if river_kind == "barrel":
		for i in range(7):
			var bar := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.32
			cm.bottom_radius = 0.32
			cm.height = 0.8
			bar.mesh = cm
			bar.rotation.z = PI * 0.5
			bar.position = Vector3(-7.0 + i * 2.4, 0.30, z)
			bar.material_override = _wood_mat(th_wood)
			add_child(bar)

func _generate_style_bridges() -> void:
	var z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var xs := [
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0,
		Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	]
	var col := th_wood
	var metal := false
	match bridge_kind:
		"stone": col = th_stone
		"bone": col = Color(0.82, 0.80, 0.70)
		"crystal": col = Color(0.60, 0.44, 0.92)
		"gold": col = Color(0.94, 0.76, 0.30); metal = true
		"ice": col = Color(0.30, 0.48, 0.64)
		"rope", "log": col = Color(0.48, 0.32, 0.16)
		"festival": col = Color(0.90, 0.42, 0.64)
		"waffle": col = Color(0.62, 0.38, 0.16)
		"rainbow": col = Color(0.50, 0.82, 0.94); metal = true
		"marble": col = Color(0.82, 0.78, 0.66)
		"spirit": col = Color(0.50, 0.92, 0.88)
		_: col = th_stone
	for bx in xs:
		var root := Node3D.new()
		root.name = "Bridge"
		root.position = Vector3(bx, 0, z)
		add_child(root)
		var deck := _mk_box(Vector3(0, 0.16, 0), Vector3(3.0, 0.18, 3.0), _stone_mat(col), root)
		if metal:
			deck.material_override = _stone_mat(col)
		for i in range(7):
			_mk_box(Vector3(0, 0.27, -1.25 + i * 0.42), Vector3(2.9, 0.05, 0.36), _stone_mat(col.lightened(0.10)), root)
		for side in [-1.0, 1.0]:
			_mk_box(Vector3(side * 1.50, 0.62, 0), Vector3(0.10, 0.10, 2.9), _stone_mat(col.darkened(0.22)), root)
			_mk_box(Vector3(side * 1.50, 0.92, 0), Vector3(0.10, 0.10, 2.9), _stone_mat(col.darkened(0.22)), root)
			for j in range(3):
				_mk_box(Vector3(side * 1.50, 0.60, -1.2 + j * 1.2), Vector3(0.12, 0.62, 0.12), _stone_mat(col), root)

func _generate_theme_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + arena_idx
	for i in range(6):
		var x := -8.0 + i * 3.2
		var z := -13.2 if i % 2 == 0 else 13.2
		match decor_kind:
			"goblin", "jungle", "lumber", "camp", "rascal":
				_add_tree(Vector3(x, 0.0, z), rng)
			"arcane", "academy", "electro", "sanctuary", "spirit":
				_add_crystal(Vector3(x, 0.0, z), th_accent)
			"bones", "tomb", "spooky", "dragon":
				_add_bone(Vector3(x, 0.0, z), Color(0.82, 0.80, 0.68))
			"ice", "valhalla", "serene":
				_add_snow_pile(Vector3(x, 0.0, z))
			"metal", "factory", "mine", "kitchen", "street", "road":
				_add_barrel(Vector3(x, 0.0, z), th_wood)
			"royal", "legend", "hero", "barbarian", "festival", "pancake", "tavern":
				_add_banner(Vector3(x, 0.0, z), th_accent)
			_:
				_add_rock(Vector3(x, 0.0, z), rng)

func _add_crystal(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.34
	cm.height = 1.5
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.75, 0)
	mi.material_override = _glow_mat(col)
	add_child(mi)
	mi = MeshInstance3D.new()
	cm = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.22
	cm.height = 0.9
	mi.mesh = cm
	mi.position = pos + Vector3(0.35, 0.45, 0.2)
	mi.material_override = _glow_mat(col.lightened(0.2))
	add_child(mi)

func _add_bone(pos: Vector3, col: Color) -> void:
	for i in range(3):
		_mk_box(pos + Vector3(i * 0.35, 0.18 + i * 0.05, 0), Vector3(0.10, 0.10, 0.8), _stone_mat(col))
	_mk_box(pos + Vector3(0.35, 0.28, 0), Vector3(0.8, 0.08, 0.10), _stone_mat(col))

func _add_snow_pile(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 0.7
	mi.mesh = sm
	mi.position = pos + Vector3(0, 0.22, 0)
	mi.material_override = _flat_mat(Color(0.90, 0.96, 1.0))
	add_child(mi)

func _add_barrel(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32
	cm.bottom_radius = 0.32
	cm.height = 0.8
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.4, 0)
	mi.material_override = _wood_mat(col)
	add_child(mi)
	_mk_box(pos + Vector3(0, 0.42, 0), Vector3(0.70, 0.10, 0.70), _stone_mat(Color(0.36, 0.34, 0.30)))

func _add_banner(pos: Vector3, col: Color) -> void:
	_mk_box(pos + Vector3(0, 1.1, 0), Vector3(0.10, 2.2, 0.10), _wood_mat(th_wood_dark))
	_mk_box(pos + Vector3(0.35, 1.75, 0), Vector3(0.7, 0.55, 0.04), _flat_mat(col))

func _generate_border():
	var half_w := Config.ARENA_WIDTH * 0.5
	var half_h := Config.ARENA_HEIGHT * 0.5
	var stone := _stone_mat(th_stone)
	var stone_dark := _stone_mat(th_stone_dark)
	var sides := [
		[Vector3(0, 0.18, -half_h - 0.30), Vector3(Config.ARENA_WIDTH + 1.2, 0.36, 0.45)],
		[Vector3(0, 0.18, half_h + 0.30), Vector3(Config.ARENA_WIDTH + 1.2, 0.36, 0.45)],
		[Vector3(-half_w - 0.30, 0.18, 0), Vector3(0.45, 0.36, Config.ARENA_HEIGHT + 0.6)],
		[Vector3(half_w + 0.30, 0.18, 0), Vector3(0.45, 0.36, Config.ARENA_HEIGHT + 0.6)]
	]
	for s in sides:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s[1]
		mi.mesh = bm
		mi.position = s[0]
		mi.material_override = stone
		add_child(mi)
		var top := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(s[1].x * 1.03, 0.07, s[1].z * 1.15)
		top.mesh = tm
		top.position = s[0] + Vector3(0, 0.20, 0)
		top.material_override = stone_dark
		add_child(top)
	# 四角石柱
	for cx in [-half_w - 0.3, half_w + 0.3]:
		for cz in [-half_h - 0.3, half_h + 0.3]:
			var p := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.32
			cm.bottom_radius = 0.38
			cm.height = 1.1
			p.mesh = cm
			p.position = Vector3(cx, 0.55, cz)
			p.material_override = stone
			add_child(p)
			var cap := MeshInstance3D.new()
			var capm := CylinderMesh.new()
			capm.top_radius = 0.0
			capm.bottom_radius = 0.42
			capm.height = 0.34
			cap.mesh = capm
			cap.position = Vector3(cx, 1.27, cz)
			cap.material_override = _stone_mat(Color(0.60, 0.52, 0.42))
			add_child(cap)
			# 旗帜：己方角落蓝、敌方角落红
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.028
			pm.bottom_radius = 0.038
			pm.height = 2.4
			pole.mesh = pm
			pole.position = Vector3(cx, 1.2, cz)
			pole.material_override = _stone_mat(COL_STONE_DARK)
			add_child(pole)
			var flag := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.75, 0.45, 0.03)
			flag.mesh = fm
			flag.position = Vector3(cx + 0.38, 2.0, cz)
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = COL_TEAM_ENEMY if cz < 0.0 else COL_TEAM_PLAYER
			fmat.roughness = 0.9
			flag.material_override = fmat
			add_child(flag)

# ============================================================
# 场外装饰（树 / 石头）
# ============================================================
func _generate_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 42:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(11.5, 26.0)
		var x := cos(angle) * radius
		var z := sin(angle) * radius * 1.25
		if absf(x) < 10.8 and absf(z) < 17.2:
			continue
		var roll := rng.randf()
		if roll < 0.34:
			_add_tree(Vector3(x, 0, z), rng)
		elif roll < 0.58:
			_add_rock(Vector3(x, 0, z), rng)
		elif roll < 0.80:
			_add_bush(Vector3(x, 0, z), rng)
		else:
			_add_flower_patch(Vector3(x, 0, z), rng)
	# 场内侧边小花，增加层次
	for i in 10:
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_flower_patch(Vector3(rng.randf_range(-8.2, 8.2), 0, side * rng.randf_range(13.2, 14.9)), rng)
	# 边框外侧近景装饰（相机画面边缘可见）
	for i in 7:
		var px := -7.5 + float(i) * 2.5
		_add_bush(Vector3(px + rng.randf_range(-0.4, 0.4), 0, -17.1 + rng.randf_range(-0.4, 0.4)), rng)
		_add_bush(Vector3(px + rng.randf_range(-0.4, 0.4), 0, 17.1 + rng.randf_range(-0.4, 0.4)), rng)
	for i in 5:
		var pz := -10.0 + float(i) * 5.0
		_add_tree(Vector3(-11.3 + rng.randf_range(-0.5, 0.5), 0, pz), rng)
		_add_tree(Vector3(11.3 + rng.randf_range(-0.5, 0.5), 0, pz), rng)
	# 场边小栅栏（左右各一段）
	for sx in [-1.0, 1.0]:
		var fence := Node3D.new()
		fence.position = Vector3(sx * 9.6, 0, 6.5)
		add_child(fence)
		for j in 4:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.12, 0.6, 0.12)
			post.mesh = pm
			post.position = Vector3(0, 0.3, -1.2 + float(j) * 0.8)
			post.material_override = _wood_mat(COL_WOOD_DARK)
			fence.add_child(post)
		for ry in [0.28, 0.48]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.06, 0.06, 2.6)
			rail.mesh = rm
			rail.position = Vector3(0, ry, 0)
			rail.material_override = _wood_mat(COL_WOOD)
			fence.add_child(rail)

func _add_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var t := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12
	tm.bottom_radius = 0.18
	tm.height = 1.0
	t.mesh = tm
	t.position.y = 0.5
	t.material_override = _wood_mat(COL_WOOD_DARK)
	root.add_child(t)
	for j in 2:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.0 - float(j) * 0.28
		cm.height = 1.5 - float(j) * 0.35
		c.mesh = cm
		c.position.y = 1.2 + float(j) * 0.62
		c.material_override = _flat_mat(Color(0.20, 0.38, 0.20) if rng.randf() > 0.5 else Color(0.26, 0.44, 0.22))
		root.add_child(c)

func _add_rock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var r := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = rng.randf_range(0.35, 0.75)
	rm.height = rm.radius * 2.0
	rm.radial_segments = 8
	rm.rings = 4
	r.mesh = rm
	r.position = pos + Vector3(0, rm.radius * 0.5, 0)
	r.scale = Vector3(1.0, 0.7, 1.0)
	r.rotation.y = rng.randf_range(0.0, TAU)
	r.material_override = _stone_mat(COL_STONE_DARK)
	add_child(r)

func _add_bush(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var col := Color(0.20, 0.36, 0.18).lerp(Color(0.30, 0.48, 0.24), rng.randf())
	for i in 3:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.22, 0.38)
		sm.height = sm.radius * 2.0
		s.mesh = sm
		s.position = Vector3(rng.randf_range(-0.25, 0.25), sm.radius * 0.7, rng.randf_range(-0.25, 0.25))
		s.material_override = _flat_mat(col)
		root.add_child(s)

func _add_flower_patch(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var petals := [
		Color(0.95, 0.92, 0.60), Color(0.95, 0.60, 0.65),
		Color(0.72, 0.62, 0.95), Color(0.98, 0.95, 0.95)
	]
	for i in 5:
		var stem := MeshInstance3D.new()
		var stm := CylinderMesh.new()
		stm.top_radius = 0.012
		stm.bottom_radius = 0.014
		stm.height = 0.16
		stem.mesh = stm
		stem.position = Vector3(rng.randf_range(-0.18, 0.18), 0.08, rng.randf_range(-0.18, 0.18))
		stem.material_override = _flat_mat(Color(0.24, 0.40, 0.20))
		root.add_child(stem)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.045
		hm.height = 0.09
		head.mesh = hm
		head.position = stem.position + Vector3(0, 0.09, 0)
		head.material_override = _flat_mat(petals[rng.randi() % petals.size()])
		root.add_child(head)

# ============================================================
# 材质 / 贴图
# ============================================================
func _make_grass_texture() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 11
	n.frequency = 0.030
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var n2 := FastNoiseLite.new()
	n2.seed = 23
	n2.frequency = 0.22
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var v := (n.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			v += n2.get_noise_2d(float(x), float(y)) * 0.10
			img.set_pixel(x, y, th_grass.lerp(th_grass2, clampf(v, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _stone_mat(col: Color) -> StandardMaterial3D:
	if _stone_nrm == null:
		_stone_nrm = _noise_normal(7, 0.10, 3.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	m.normal_enabled = true
	m.normal_texture = _stone_nrm
	m.normal_scale = 0.65
	m.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return m

func _wood_mat(col: Color) -> StandardMaterial3D:
	if _wood_nrm == null:
		_wood_nrm = _noise_normal(13, 0.06, 2.6)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.82
	m.normal_enabled = true
	m.normal_texture = _wood_nrm
	m.normal_scale = 0.5
	m.uv1_scale = Vector3(1.2, 3.0, 1.0)
	return m

# 程序化法线贴图（避免外部资源；用于石头/木头表面细节）
func _noise_normal(seed_value: int, freq: float, strength: float) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var h: float = n.get_noise_2d(float(x), float(y))
			var hx: float = n.get_noise_2d(float(x) + 1.0, float(y)) - h
			var hy: float = n.get_noise_2d(float(x), float(y) + 1.0) - h
			var v := Vector3(-hx * strength, -hy * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m

func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.8
	m.roughness = 0.4
	return m

