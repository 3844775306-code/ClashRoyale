# scripts/entities/Bullet.gd


class_name Bullet
extends Area3D
const ProjectileKit := preload("res://scripts/visuals/ProjectileKit.gd")
var config: CardData
var team: int
var target: Unit
var source_unit: Unit
var damage_multiplier: float = 1.0
var level: int = 0
# 法术投射物相关
var is_spell_projectile: bool = false
var spell_target_pos: Vector3
var arc_height: float = 0.0
var _shadow: MeshInstance3D = null
var shadow_scale: float = 1.0
var _roll_angle: float = 0.0
var aim_offset: Vector3 = Vector3.ZERO
var _flight_start: Vector3 = Vector3.INF
var _flight_total: float = 1.0
var _last_aim_pos: Vector3 = Vector3.ZERO
var axe_return: bool = false
var _axe_returning: bool = false
var _spell_start: Vector3 = Vector3.ZERO
var _spell_flat_total: float = 1.0
var on_arrive_callback: Callable
# 分裂相关
var split: bool = false
var splited: bool = false
var split_angle: float = 0.0
var split_speed: float = 0.0
var split_distance: float = 0.0
var split_penetrate: bool = false
var split_index: float = 0.0
var back = 0

# 通用
var speed: float = 7.0
var size: float = 0.4
var attacked_targets: Array = []
var time_alive: float = 0.0
var max_lifetime: float = 10.0
var damage : int =0
var damage_bonus: int = 0
var chain_serial: int = -1
var accumulate_val = 1
var type =1
var redmg = 0
# 子弹类型 → 模型文件路径映射
const BULLET_MODEL_MAP = {
	#"arrow": "res://assets/models/bullet_arrow.glb",
	#"energy": "",
	#"lightning": "res://assets/models/bullet_lightning.glb",
	#"fire": "res://assets/models/bullet_fire.glb",
	#"bullet": "res://assets/models/bullet_modern.glb",
	#"firework": "res://assets/models/bullet_firework.glb",
	# "normal" 没有模型，将使用默认球体
}

# 根据卡牌信息决定子弹类型（ID 特判 → 攻击类型 → 名字语义 → 兜底）
func _get_bullet_type() -> String:
	if config != null and config.card_id == 110:
		return "barb_barrel"
	var cfg: CardData = null
	if source_unit and source_unit.config:
		cfg = source_unit.config
	elif config:
		cfg = config
	if cfg == null:
		return "energy"
	var cid: int = cfg.card_id
	if cfg.card_name == "厨师塔":
		return "pancake"
	if cfg.card_name == "飞刀塔":
		return "knife"
	# --- 单卡特判 ---
	if cid == 96:
		return "axe"          # 飞斧屠夫
	if cid == 28:
		return "plasma"       # 电磁炮
	if cid == 43:
		return "firework"     # 烟花炮手
	if cid == 91:
		return "log"          # 滚木类
	# --- 巨石投手 ---
	if cid == 97:
		return "boulder"
	# --- 防御塔 ---
	match cid:
		1:
			return "arrow"        # 公主塔
		2:
			return "cannonball"   # 王子塔
		3:
			return "cannonball"   # 国王塔
	# --- 攻击类型优先：2=电击 4=灼烧 5=电磁/充能 ---
	match cfg.attack_type:
		2:
			return "lightning"
		4:
			return "fireball"
		5:
			return "plasma"
	# --- 名字语义 ---
	var n: String = cfg.card_name
	if n.contains("电磁"):
		return "plasma"
	if n.contains("烟花"):
		return "firework"
	if n.contains("地狱") or n.contains("烈焰") or n.contains("熔炉"):
		return "fireball"
	if n.contains("冰") or n.contains("寒冰") or n.contains("雪"):
		return "ice" if not n.contains("大雪球") else "snowball"
	if n.contains("箭") or n.contains("弓") or n.contains("吹箭") or n.contains("弩") or n.contains("游侠"):
		return "arrow"
	if n.contains("投矛") or n.contains("长矛") or n.contains("枪骑兵") or n.contains("矛"):
		return "spear"
	if n.contains("火枪") or n.contains("枪手") or n.contains("猎人") or n.contains("飞行机器") or n.contains("炮手"):
		return "musket"
	if n.contains("炸弹") or n.contains("爆破") or n.contains("气球") or n.contains("飞桶"):
		return "bomb"
	if n.contains("迫击炮") or n.contains("加农") or n.contains("炮"):
		return "cannonball"
	if n.contains("毒") or n.contains("药"):
		return "potion"
	if n.contains("公主"):
		return "arrow"
	if n.contains("皇家巨人") or n.contains("投手") or n.contains("滚桶"):
		return "cannonball"
	if n.contains("女巫") or n.contains("法师") or n.contains("术") or n.contains("龙") or n.contains("凤凰"):
		return "fireball"
	# --- 兜底：远程用能量球，近战小球 ---
	# --- 兜底：真正远程（射程 >= 2m）用能量球，近战只有贴身小球 ---
	if cfg.attack_range >= 2.0:
		return "energy"
	return "normal"
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
var model_mesh: Node3D   # 可以是 MeshInstance3D 或完整场景
var model_kind: String = ""
var no_visual: bool = false
var force_bullet_kind: String = ""
static var _missing_log: Dictionary = {}
func _ready():
	add_to_group("bullets")
	
	if source_unit:
		level = source_unit.level
	if is_instance_valid(source_unit):
		accumulate_val = source_unit.accumulate
		damage_multiplier *= maxf(float(floor(source_unit.accelerate)), 1.0)
		source_unit.accelerate = 1.0
	if redmg==0:
		damage = (config.damage * damage_multiplier * floor(accumulate_val)*Config.level_mult(level))
		type =config.attack_type
	else:
		if target and target.config.card_id<=3:
			damage = (128*Config.level_mult(level))
		else:
			damage = (197*Config.level_mult(level))
	var col_shape = CollisionShape3D.new()
	if config.card_id != 91:
		
		var sphere = SphereShape3D.new()
		sphere.radius = size
		col_shape.shape = sphere
		add_child(col_shape)
	else:
		var bar = BoxShape3D.new()
		bar.size = Vector3(0.2*size,size,0.2*size)
		col_shape.shape = bar
		add_child(col_shape)
	 
	# --- 加载模型（替换原来的简单球体） ---
	if no_visual:
		model_mesh = Node3D.new()
		add_child(model_mesh)
		return
	if not is_spell_projectile:
		model_mesh = try_load_bullet_model()
		if not model_mesh:
			_log_missing()
			# 回退到简单球体
			var mesh
			if config.card_id != 91:
				mesh = SphereMesh.new()
				mesh.radius = size
				mesh.height = size * 2
			else:
				mesh = BoxMesh.new()
				mesh.size=Vector3(size,0.*size,0.2*size)
			var fallback = MeshInstance3D.new()
			fallback.mesh = mesh
			model_mesh = fallback
		# 回退球才使用队伍色材质，ProjectileKit 模型保留自身顶点色
		if model_mesh is MeshInstance3D and model_mesh.material_override == null:
			model_mesh.material_override = _create_material()
		add_child(model_mesh)
	# 贴地投影（无拖尾）
	var sh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 0.01
	cyl.radial_segments = 12
	sh.mesh = cyl
	var shm := StandardMaterial3D.new()
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shm.albedo_color = Color(0.05, 0.06, 0.09, 0.45)
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.material_override = shm
	sh.top_level = true
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)
	_shadow = sh


# 把仍然使用回退球的卡牌写到文件里，便于一次性排查
func _log_missing() -> void:
	if _get_bullet_type() == "normal":
		return
	var cname: String = config.card_name if config else "?"
	var cid: int = config.card_id if config else -1
	var rng: float = config.attack_range if config else 0.0
	var key := "%s#%d" % [cname, cid]
	if _missing_log.has(key):
		return
	_missing_log[key] = true
	var path := "res://tools/bullet_missing.txt"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s id=%d kind=%s range=%.2f" % [cname, cid, _get_bullet_type(), rng])
		f.close()
	
func _create_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED if team != Config.Team.PLAYER else Color.BLUE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

const BULLET_KIND_MAP := {
	"fire": "fireball",
	"bullet": "musket",
	"normal": "",
}

func try_load_bullet_model() -> Node3D:
	var bullet_type: String = force_bullet_kind if force_bullet_kind != "" else _get_bullet_type()
	if bullet_type == "normal":
		bullet_type = "arrow"
	# 默认同名直通；只有旧命名需要映射，避免新增类型时漏配导致回退球
	var kind: String = BULLET_KIND_MAP.get(bullet_type, bullet_type)
	if kind.is_empty():
		return null
	model_kind = kind
	if shadow_scale <= 1.0:
		shadow_scale = clampf(size * 2.6, 0.7, 2.0)
	var node: Node3D = ProjectileKit.create(kind)
	# 塔/远程单位用更大的最小尺寸，保证看得见
	var visual_scale: float = clampf(size * 2.2, 0.75, 1.7) * 1.5 * 1.5
	if config != null and config.damage_range > 0.0:
		visual_scale *= clampf(1.0 + config.damage_range * 0.30, 1.0, 2.2)
	if kind == "barrel":
		visual_scale *= 2.0
	if kind == "boulder":
		visual_scale *= 2.0
		shadow_scale = visual_scale * 1.25
	node.scale = Vector3.ONE * visual_scale
	return node
func _update_bullet_rotation(direction: Vector3):
	if model_mesh and direction.length() > 0.01:
		var dir = direction.normalized()
		var flat_len: float = maxf(Vector2(dir.x, dir.z).length(), 0.001)
		var angle_y: float = atan2(dir.x, dir.z)          # 水平朝向（模型 +Z 为正前）
		var angle_x: float = -atan2(dir.y, flat_len)      # 俯仰（按水平长度归一，避免 -Z 方向翻转）
		# 飞斧：绕竖直轴高速旋转
		if model_kind == "axe":
			model_mesh.rotation = Vector3(0, fmod(Time.get_ticks_msec() * 0.05, TAU), 0)
			return
		# 巨石：朝行进方向 + 沿局部 X 轴滚动
		if model_kind == "boulder":
			model_mesh.rotation = Vector3(_roll_angle / 0.30, angle_y, 0)
			return
		model_mesh.rotation = Vector3(angle_x, angle_y, 0)
		# 电球自旋
		if model_kind == "plasma":
			model_mesh.rotation.z = fmod(Time.get_ticks_msec() * 0.03, TAU)
static func create_spell_projectile(
	start_pos: Vector3,
	target_pos: Vector3,
	speed: float,
	team: int,
	config: CardData = null,
	on_arrive: Callable = Callable()
) -> Bullet:
	var bullet = Bullet.new()
	bullet.is_spell_projectile = true
	bullet.shadow_scale = 2.4
	bullet.position = start_pos
	bullet.speed = speed
	bullet.team = team
	bullet.config = config
	bullet.spell_target_pos = target_pos
	bullet._spell_start = start_pos
	bullet._spell_flat_total = maxf(Vector2(target_pos.x - start_pos.x, target_pos.z - start_pos.z).length(), 0.01)
	bullet.on_arrive_callback = on_arrive
	
	# 法术投射物视觉（按卡牌类型选择）
	var kind := "fireball"
	if config:
		match config.card_id:
			10:
				kind = "arrow"        # 万箭齐发
			11:
				kind = "fireball"     # 火球
			20, 48:
				kind = "lightning"    # 电击/雷电
			31:
				kind = "snowball"     # 大雪球
			77:
				kind = "rocket"       # 火箭
			40:
				kind = "barrel"       # 哥布林飞桶
			43:
				kind = "firework"     # 烟花
			45:
				kind = "potion"       # 毒药/治疗类
			91:
				kind = "log"          # 滚木
	var node: Node3D = ProjectileKit.create(kind)
	var spell_scale := 1.725
	if kind == "barrel":
		spell_scale = 3.45
	elif kind == "fireball":
		spell_scale = 2.15
	elif kind == "snowball":
		spell_scale = 2.10
	elif kind == "rocket":
		spell_scale = 2.35
	node.scale = Vector3.ONE * spell_scale
	bullet.model_mesh = node
	bullet.model_kind = kind
	bullet.add_child(node)
	return bullet

func _move_towards_point(delta):
	var flat_pos := Vector3(global_position.x, 0.0, global_position.z)
	var flat_target := Vector3(spell_target_pos.x, 0.0, spell_target_pos.z)
	var flat_dir := flat_target - flat_pos
	var flat_dist := flat_dir.length()
	if flat_dist < speed * delta or flat_dist < 0.01:
		global_position = spell_target_pos
		if on_arrive_callback.is_valid():
			on_arrive_callback.call()
		queue_free()
		return
	global_position += flat_dir.normalized() * speed * delta
	# 抛物线飞行（飞桶等）
	if arc_height > 0.0 and _spell_flat_total > 0.01:
		var trav: float = clampf(Vector2(global_position.x - _spell_start.x, global_position.z - _spell_start.z).length() / _spell_flat_total, 0.0, 1.0)
		var base_y: float = lerpf(_spell_start.y, spell_target_pos.y, trav)
		global_position.y = base_y + arc_height * 4.0 * trav * (1.0 - trav)
		if model_mesh:
			if model_kind in ["barrel", "rocket"]:
				var dir3 := Vector3(flat_dir.x, 0.0, flat_dir.z)
				if dir3.length() > 0.01:
					model_mesh.look_at(model_mesh.global_position + dir3.normalized(), Vector3.UP)
					model_mesh.rotate_object_local(Vector3.UP, PI)
					if model_kind == "barrel":
						model_mesh.rotate_object_local(Vector3.FORWARD, Time.get_ticks_msec() * 0.012)
			else:
				model_mesh.rotation.z = trav * TAU * 2.0
func _physics_process(delta):
	time_alive += delta
	_update_visual_grounding()
	if model_kind == "boulder":
		global_position.y = 0.30
		_roll_angle += speed * delta

	if is_spell_projectile:
		_move_towards_point(delta)
		return
	
	if time_alive > max_lifetime:
		queue_free()
		return
	if split:
		_start_split()
	if splited:
		_move_split(delta)
	else:
		_move_towards_target(delta)

func _move_towards_target(delta):
	# 飞斧：命中后飞回屠夫
	if axe_return and _axe_returning:
		if not is_instance_valid(source_unit):
			queue_free()
			return
		var back: Vector3 = source_unit.global_position + Vector3.UP * 1.0 - global_position
		_update_bullet_rotation(back)
		if back.length() < speed * delta:
			queue_free()
		else:
			global_position += back.normalized() * speed * delta
		return
	if not is_instance_valid(target) or target.health <= 0:
		_release_cooldown_if_quick()
		queue_free()
		return
	var aim_pos: Vector3 = target.global_position + aim_offset
	if arc_height > 0.0:
		# 抛物线（迫击炮等）：按目标速度做提前量，避免砸不中移动目标
		var flight_t: float = (aim_pos - global_position).length() / maxf(speed, 1.0)
		var lead_dir := Vector3(target.move_direction.x, 0.0, target.move_direction.y)
		if lead_dir.length() > 0.01:
			# 限制提前量，避免移动速度配置异常（如跳跃单位 move_speed 很大）时子弹飞出屏幕
			# 用实际移动速度而不是配置原始值，限制弧线弹提前量，避免落点越过目标
			var lead_dist: float = minf(float(target.speed) * flight_t, 0.45)
			aim_pos += lead_dir.normalized() * lead_dist
	_last_aim_pos = aim_pos
	var dir = aim_pos - global_position
	_update_bullet_rotation(dir)
	var dist = dir.length()
	var flat_dist: float = Vector2(dir.x, dir.z).length()
	if arc_height > 0.0:
		# 抛物线弹道用水平距离判定命中（避免高度差导致永远打不中）
		if flat_dist < speed * delta:
			global_position = aim_pos
			_hit_target()
			return
	else:
		if dist < speed * delta:
			_hit_target()
			return
	global_position += dir.normalized() * speed * delta
	if arc_height > 0.0:
		if _flight_start == Vector3.INF:
			_flight_start = global_position - dir.normalized() * speed * delta
			_flight_total = maxf(Vector2(aim_pos.x - _flight_start.x, aim_pos.z - _flight_start.z).length(), 0.1)
		var ft: float = clampf(Vector2(global_position.x - _flight_start.x, global_position.z - _flight_start.z).length() / _flight_total, 0.0, 1.0)
		global_position.y = lerpf(_flight_start.y, aim_pos.y + 0.25, ft) + arc_height * 4.0 * ft * (1.0 - ft)

func _move_split(delta):
	split_distance -= split_speed * delta
	if config != null and (config.card_id == 91 or config.card_id == 110):
		global_position.y = 0.30
		_roll_angle += split_speed * delta
		if model_mesh:
			var rb: Basis
			if config != null and config.card_id == 110:
				rb = Basis(Vector3(1, 0, 0), _roll_angle / 0.30) * Basis(Vector3(0, 1, 0), PI * 0.5) * Basis.from_scale(Vector3(3.2, 3.2, 3.2))
			else:
				var wratio: float = clampf(float(config.damage_range) / 3.9, 0.3, 1.5)
				rb = Basis(Vector3(1, 0, 0), _roll_angle / 0.28) * Basis(Vector3(0, 1, 0), PI * 0.5) * Basis.from_scale(Vector3(1.8, 1.8, 6.3 * wratio))
			model_mesh.basis = rb
	
	if split_distance <= 0 :
		var mp: Array = config.multiple_process if config != null else []
		var mode: int = int(mp[4]) if mp.size() > 4 else 4
		if mode != 4 or back == 1 or mp.size() < 4:
			if config != null and config.card_id == 91:
				_spawn_log_shatter()
			elif config != null and config.card_id == 110:
				var bc = get_tree().get_first_node_in_group("battle_manager")
				if bc: bc.spawn_unit(bc.get_config(57), team, global_position, 1)
			queue_free()
			return
		else:
			back = 1
			attacked_targets.clear()
			split_distance = float(mp[3])
			split_angle=PI+split_angle
	var forward = Vector3(cos(split_angle), 0, -sin(split_angle))
	#print(split_speed)
	if config == null or (config.card_id != 91 and config.card_id != 110):
		_update_bullet_rotation(forward)
	global_position += forward * split_speed * delta
	_check_collision()

func _cast_splash(cast_pos: Vector3) -> void:
	var from_unit_flag: int = 0 if config != null and config.card_id == 110 else 1
	var spell = Spell.create(
		cast_pos,
		team,
		damage,
		config.damage_range,
		from_unit_flag,
		config.attack_type,
		config.target_type
	)
	spell.card_id = config.card_id if config else -1
	var battle = get_tree().get_first_node_in_group("battle_manager")
	if battle:
		battle.spells.add_child(spell)
	if damage_bonus > 0:
		_spawn_bonus_damage_number(cast_pos)

func _hit_target():
	if not is_instance_valid(target) or target.health <= 0:
		# 弧线弹（迫击炮等）抵达时目标可能已死：在落点仍然结算溅射
		if arc_height > 0.0 and config != null and config.damage_range > 0.0 and _last_aim_pos != Vector3.ZERO:
			_cast_splash(_last_aim_pos)
		_release_cooldown_if_quick()
		queue_free()
		return
	
	if config != null and config.card_id == 36 and is_instance_valid(source_unit) and source_unit.has_method("allow_chain_hit"):
		if not source_unit.allow_chain_hit(target, chain_serial):
			queue_free()
			return
	attacked_targets.append(target)
	
	
	
	if config.damage_range > 0:
		var cast_pos: Vector3 = global_position
		if arc_height > 0.0 and is_instance_valid(target) and target.health > 0:
			# 目标仍存活时以目标当前位置结算，避免提前量导致炮弹落在目标身后
			cast_pos = target.global_position
		_cast_splash(cast_pos)
	else:
		
		if is_instance_valid(source_unit):
			if target.config.card_id<=3 and source_unit.config.card_id == 70:
				damage/=4
		# 先写入状态，确保"最后一击"也能触发中毒/诅咒等死亡效果
		if type > 1:
			target.state = type
			if type == 7:
				target.pois_timer = Time.get_ticks_msec()
			elif type == 6:
				target.fix_timer = Time.get_ticks_msec()
		var dmg_final: float = damage
		if config != null and config.card_id == 110 and target.config.card_id <= 3:
			dmg_final = damage * 0.25
		target.take_damage(dmg_final, source_unit if is_instance_valid(source_unit) else null)
	if damage_bonus > 0:
		_spawn_bonus_damage_number(target.global_position)
	
	if config != null and config.card_id == 97:
		_spawn_boulder_shatter()
	if is_instance_valid(source_unit) and source_unit.config.card_id == 43:
		split = true
	elif config != null and config.card_id == 96 and not _axe_returning:
		_axe_returning = true
	else:
		queue_free()

func _start_split():
	
	var num_projectiles = config.multiple_process[1]
	var spread_angle = deg_to_rad(config.multiple_process[0])
	var bullet_speed = config.multiple_process[2] * 0.3
	var distance = config.multiple_process[3]
	var base_angle
	var angle_offset = (split_index - (num_projectiles - 1) / 2.0) * spread_angle
	if config.card_id == 43:
		if not is_instance_valid(source_unit): return
		base_angle = atan2(-global_position.z + source_unit.global_position.z, global_position.x - source_unit.global_position.x)
	else:
		if not is_instance_valid(target): return
		if not is_instance_valid(source_unit): return
		base_angle = atan2(-target.global_position.z + source_unit.global_position.z, target.global_position.x - source_unit.global_position.x)
	split = false
	splited = true
	split_angle = base_angle + angle_offset
	split_speed = bullet_speed
	split_distance = distance
	var _smp: Array = config.multiple_process if config != null else []
	split_penetrate = int(_smp[4]) != 3 if _smp.size() > 4 else true
	


func _check_collision():
	var battle = get_tree().get_first_node_in_group("battle_manager")
	if not battle: return
	var _mp: Array = config.multiple_process if config != null else []
	var _mode: int = int(_mp[4]) if _mp.size() > 4 else -1
	var hit_radius: float = 1.3 if (config != null and config.card_id == 110) else config.size
	for unit in battle.units.get_children():
		if unit.team != team and not (unit in attacked_targets):
			if sqrt((unit.global_position.x-global_position.x)**2+(unit.global_position.z-global_position.z)**2) - (hit_radius + unit.config.size)<0:
				var src = source_unit if is_instance_valid(source_unit) else null
				if _mode == 5 or (config != null and config.card_id == 91):
					if unit.config.type ==Config.UnitType.GROUND:
						unit.global_position+=Vector3(cos(split_angle), 0, -sin(split_angle))* split_speed*hit_radius/(hit_radius+unit.config.size)*0.2
				if config.card_id == 97 and unit.config.type == Config.UnitType.AIR:
					attacked_targets.append(unit)
					continue
				unit.take_damage(damage, src)
				attacked_targets.append(unit)
				if not split_penetrate:
					queue_free()
					return

func _update_visual_grounding():
	if _shadow:
		var h: float = maxf(global_position.y, 0.0)
		var s: float = clampf(1.0 - h * 0.08, 0.35, 1.0) * shadow_scale
		_shadow.global_position = Vector3(global_position.x, 0.03, global_position.z)
		_shadow.scale = Vector3(s, 1.0, s)
		var m := _shadow.material_override as StandardMaterial3D
		if m:
			m.albedo_color.a = 0.60 * clampf(1.0 - h * 0.10, 0.20, 1.0)
# 巨石命中：裂开 + 碎石飞散 + 扬尘 + 地面裂纹
func _spawn_boulder_shatter() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var pos: Vector3 = global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.10, 0.26), rng.randf_range(0.08, 0.20), rng.randf_range(0.10, 0.26))
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.52, 0.52, 0.50).lerp(Color(0.34, 0.34, 0.32), rng.randf())
		m.roughness = 1.0
		mi.material_override = m
		mi.position = pos + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.15, 0.4), rng.randf_range(-0.3, 0.3))
		mi.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		host.add_child(mi)
		var out := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.6, 1.8), rng.randf_range(-1.0, 1.0))
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position + out, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(rng.randf_range(-5, 5), rng.randf_range(-5, 5), rng.randf_range(-5, 5)), 0.45)
		tw.tween_property(mi, "scale", Vector3(0.3, 0.3, 0.3), 0.45)
		tw.chain().tween_callback(mi.queue_free)
	# 地面裂纹
	for i in 5:
		var cr := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.07, 0.02, rng.randf_range(0.6, 1.4))
		cr.mesh = bm2
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.albedo_color = Color(0.20, 0.16, 0.12, 0.85)
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cr.material_override = cm
		var ang: float = rng.randf_range(0.0, TAU)
		cr.position = pos + Vector3(cos(ang) * 0.4, 0.04, sin(ang) * 0.4)
		cr.rotation.y = ang
		cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(cr)
		var tw2 := cr.create_tween()
		tw2.tween_interval(1.2)
		tw2.tween_property(cm, "albedo_color:a", 0.0, 0.8)
		tw2.tween_callback(cr.queue_free)
	# 扬尘
	for i in 6:
		var d := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r: float = rng.randf_range(0.18, 0.4)
		s.radius = r
		s.height = r * 2.0
		d.mesh = s
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.albedo_color = Color(0.60, 0.58, 0.52, 0.5)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d.material_override = dm
		d.position = pos + Vector3(rng.randf_range(-0.4, 0.4), 0.25, rng.randf_range(-0.4, 0.4))
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(d)
		var tw3 := d.create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(d, "position", d.position + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.5, 1.2), rng.randf_range(-0.6, 0.6)), 0.9)
		tw3.tween_property(d, "scale", Vector3(2.0, 2.0, 2.0), 0.9)
		tw3.tween_property(dm, "albedo_color:a", 0.0, 0.9)
		tw3.chain().tween_callback(d.queue_free)
# 目标在子弹飞行途中死亡导致子弹作废：飞行 <0.3s 时返还攻击冷却
func _release_cooldown_if_quick() -> void:
	if time_alive < 0.3 and is_instance_valid(source_unit):
		if source_unit.has_method("notify_bullet_wasted"):
			source_unit.notify_bullet_wasted()
# 滚木到头：木屑飞散 + 烟尘 + 地面划痕
func _spawn_log_shatter() -> void:
	var battle = get_tree().get_first_node_in_group("battle_manager")
	if battle == null:
		return
	var pos: Vector3 = global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	for i in range(14):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.08, 0.22), rng.randf_range(0.05, 0.14), rng.randf_range(0.12, 0.34))
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.56, 0.38, 0.22).lerp(Color(0.40, 0.26, 0.14), rng.randf())
		mi.material_override = m
		mi.position = pos + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.15, 0.45), rng.randf_range(-0.8, 0.8))
		mi.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		battle.add_child(mi)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.3, 1.1), rng.randf_range(-1.2, 1.2)), 0.45)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(rng.randf_range(-5, 5), rng.randf_range(-5, 5), rng.randf_range(-5, 5)), 0.45)
		tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.45)
		tw.chain().tween_callback(mi.queue_free)
	for i in range(5):
		var dust := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = rng.randf_range(0.18, 0.32)
		ds.height = ds.radius * 2.0
		dust.mesh = ds
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.albedo_color = Color(0.62, 0.54, 0.42, 0.5)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dust.material_override = dm
		dust.position = pos + Vector3(rng.randf_range(-0.6, 0.6), 0.3, rng.randf_range(-0.6, 0.6))
		battle.add_child(dust)
		var tw2 := dust.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(dust, "position", dust.position + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.4, 1.0), rng.randf_range(-0.8, 0.8)), 0.8)
		tw2.tween_property(dust, "scale", Vector3(2.0, 2.0, 2.0), 0.8)
		tw2.tween_property(dm, "albedo_color:a", 0.0, 0.8)
		tw2.chain().tween_callback(dust.queue_free)
func _spawn_bonus_damage_number(pos: Vector3) -> void:
	var bt = get_tree().get_first_node_in_group("battle_manager")
	if bt == null:
		return
	var lbl := Label3D.new()
	lbl.text = str(int(damage_bonus))
	lbl.font_size = 72
	lbl.modulate = Color(1.0, 0.18, 0.14)
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = pos + Vector3(randf_range(-0.25, 0.25), 1.25, randf_range(-0.25, 0.25))
	bt.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector3(0, 1.0, 0), 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lbl.queue_free)