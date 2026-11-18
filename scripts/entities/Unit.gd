# scripts/entities/Unit.gd
extends Area3D
class_name Unit
const UnitModelKit := preload("res://scripts/visuals/UnitModelKit.gd")
const CardVisualCatalog := preload("res://scripts/visuals/CardVisualCatalog.gd")
const UnitVisualAnim := preload("res://scripts/visuals/UnitVisualAnim.gd")
const ProceduralAudio := preload("res://scripts/core/ProceduralAudio.gd")
var visual_root: Node3D
var contact_shadow: MeshInstance3D
var inferno_beam: Node3D
var weapon_kind: String = "none"
var replay_visual: bool = false
var king_duo: bool = false
var anim_state: int = 0
var anim_time: float = 0.0
var attack_anim_start: float = -1.0
var attack_anim_duration: float = 0.45
var hit_anim_end: float = 0.0
var status_particles: Node3D = null   # 用于放置状态特效
var status_fx: Node3D = null          # 新的状态视觉特效
var tunnel: bool = false              # 掘地矿工钻地移动中
var charge_fx: Node3D = null          # 冲锋速度线
var sparky_fx: Node3D = null          # 电磁炮蓄能特效
var sparky_orb: MeshInstance3D = null
var sparky_mat: StandardMaterial3D = null
var _chain_until: float = 0.0
var _chain_attack_serial: int = 0
var _chain_attack_targets: Array = []
var _special_fx: Node3D = null
var _jump_prev: int = 0
var _hook_rope: Node3D = null
var _special_color: Color = Color(0.70, 0.40, 1.0)
var _prev_z: float = 0.0
var _river_jumping: bool = false
var _river_jump_from: Vector3 = Vector3.ZERO
var _river_jump_to: Vector3 = Vector3.ZERO
var _river_jump_t: float = 0.0
var _spin_remaining: float = 0.0
var _spawn_tween: Tween = null
var _hook_start_ms: float = 0.0
var _hook_to: Vector3 = Vector3.ZERO
var _hook_retracting: bool = false
var _hook_retract_t: float = 0.0
var _recoil_remaining: float = 0.0
var _knock_remaining: float = 0.0
var tesla_buried: bool = false
var _tesla_last_attack: float = -10000.0
var _anim_last_pos: Vector3 = Vector3.ZERO
var _charge_bypass: bool = false
var _charge_attack_time: float = -10000.0
var _charge_dust_t: float = 0.0
var _last_move_pos: Vector3 = Vector3.ZERO
var status_kind: String = ""# 静态 ID 分配
static var _next_id := 0
var anim_player: AnimationPlayer
var status_ring: MeshInstance3D
var body_mesh: MeshInstance3D   # 用于修改自身颜色（冰冻变蓝）# 基本属性
var id: int
var config: CardData
var team: int
var health: float
var max_health: float
var shield_used: bool = false
var level: int =0
var ignore_level_clamp: bool = false
var follow= null# 状态效果
var state: int = 0               # 0=正常, 2=电击, 3=冰冻
var slow_factor: float = 1.0     # 移动攻击速度倍率
var froze_timer: float = -3000.0 # 冰冻结束时间（毫秒）
var shock_timer: float = 0.0     # 电击结束时间（毫秒）
var shock_anim_frozen: bool = false   # 是否因电击而冻结动画
var pois_timer: float = 0.0  
var fix_timer:float = 0.0
var fix_factor:  float = 1.0   # 电击结束时间（毫秒）
var jump = 0
var jump_timer: float =0.0
var hit_flash_end_time: float = 0.0   # 受击闪白结束时间（毫秒）
var hit_anim_end_time: float = 0.0   # 受击动画应结束的时间(毫秒)
var hid =0
var hit_timer = 0
var quick_timer = 0
var quick =0
var slow_change = 0# 新增变量（在 var attack_cooldown 后添加）
var deploy_cooldown: float = 0.0
var max_deploy_cooldown: float = 0.0# 移动相关
var speed: float = 0.0
var accelerate: float = 1.0      # 冲锋修正
var accumulate: float = 1.0      # 灼烧攻击修正
var move_direction: Vector2 = Vector2.ZERO  # 朝向角度（2D平面）# 目标与攻击
var target: Unit = null
var attack_cooldown: float = 0.0
var spawn_cooldown: float = 0.0
var last_lose_health_time: float = 0.0  # 建筑扣血计时# 国王塔激活系统
var king_tower_activated: bool = false
var king_tower_cooldown: float = 0.0
var _special_action_cd: float = 0.0
var _spawn_invuln_until: float = 0.0
var _lifetime_until_ms: float = 0.0
var _collector_t: float = 0.0
var _rune_owner: Unit = null
var _rune_targets: Array = []
var _demolisher_charge_started: bool = false
var _rune_hits: int = 0
var _rune_bonus_pending: int = 0
var _enchant_t: float = 0.0
var _curse_team: int = -1
var _curse_until: float = 0.0
var _entangled_until: float = 0.0
var _slow15_until: float = 0.0
var _reflect_ready_ms: float = -100000.0
var _rune_marker: Node3D
var _chain_fx: Node3D
var _chain_segs: Array = []
var _chain_tips: Array = []
var _chain_points: Array = []
var _king_anim_active: bool = false
var _king_anim_t: float = 0.0
var _king_turret: Node3D = null# 动画文件名前缀映射，键为 CardData.card_name
const ANIM_PREFIX: Dictionary = {
	"巨人": "giant",
	"骑士": "knight",
	"法师":"firewizard",
	"女巫":"witch",
	"野蛮人精锐":"elitebarbarians",
	"寒冰法师":"icewizard",
	"蝙蝠":"bat",
	"骷髅军团":"skeleton",
	"飞龙宝宝":"dragonbaby"
	# 可继续添加其他单位，如 "迷你皮卡": "minipekka" 等
}
# 攻击管理
var attacked_list: Array = []    # 本轮已攻击目标（多目标攻击用）# 引用游戏状态
@onready var battle: BattleManager = get_tree().get_first_node_in_group("battle_manager")
func _ready():
	if config != null and config.card_id == 95:
		config = config.duplicate()
	if config:
		initialize_from_config()
	add_to_group("units")
	 # 统一添加血条
	if battle and battle.hud:
		battle.hud.add_health_bar(self)
	#anim_player = _find_animation_player(self)
	if anim_player:
		play_anim("idle")   # 默认播放待机
func initialize_from_config():
	id = Unit._next_id
	Unit._next_id += 1
	#team = 0  # 由外部调用者设置
	max_health = config.max_health
	speed = config.move_speed*0.05   # 调整为每秒米数
	attack_cooldown = 0.0  # 测试时立即攻击，正式可设为 config.attack_speed/1000.0
	if config.spawn_unit:
		spawn_cooldown = config.spawn_unit[2]/1000-4.0
	if level == 0:
		if team ==Config.Team.PLAYER:
			level =PlayerData.get_card_level(config.card_id)
			if config.card_id <=3:
				level = PlayerData.get_tower_level()
		else:
			level = PlayerData.ai_level(config.card_id)
	# 测试模式：战斗中统一按 11 级结算（镜像 +1 可绕过）
	if not ignore_level_clamp:
		level = Config.battle_level(level)
		if battle != null:
			level = battle.mode_level(level)
				##print(max_health)
		#print(max_health)
	if config.shield > 0:
		max_health = config.shield
		health = config.shield
		shield_used = false
	else:
		health = config.max_health
	health = int(health*Config.level_mult(level))
	max_health=int(max_health*Config.level_mult(level))
	# 创建视觉模型（记录 body_mesh 引用）
	# ---------- 程序化模型（单位模型套件） ----------
	var spec: Dictionary = CardVisualCatalog.spec_for(config.card_name, team, config.attack_range)
	visual_root = UnitModelKit.create_unit(spec)
	add_child(visual_root)
	# 贴地投影：增强落地感
	contact_shadow = UnitModelKit.contact_shadow(1.725 if config.type == Config.UnitType.BUILDING else 0.87)
	contact_shadow.top_level = true
	add_child(contact_shadow)
	body_mesh = visual_root.get_node_or_null("Body") as MeshInstance3D
	if config.card_id == 3 and body_mesh:
		_king_turret = body_mesh.get_node_or_null("Turret") as Node3D
		if _king_turret:
			_king_turret.visible = false
			_king_turret.scale = Vector3.ONE * 0.01
	weapon_kind = String(spec.get("weapon", "none"))
	if config.card_id == 97:
		weapon_kind = "boulder_throw"
	if config.extra_spell.size() > 0 and config.extra_spell[4] < 0:
		_spawn_invuln_until = Time.get_ticks_msec() + 500.0
	# 建筑寿命通过 _degrade_health 的自然衰减倍率实现
	if config.card_id == 121:
		await get_tree().process_frame
		if battle:
			battle.spawn_unit(battle.get_config(39), team, global_position + Vector3(-0.5, 0, 0), 3)
			battle.spawn_unit(battle.get_config(62), team, global_position + Vector3(0.5, 0, 0.3), 3)
		die()
		return
	if config.card_id == 117:
		await get_tree().process_frame
		if battle:
			var back: float = 1.0 if team == Config.Team.PLAYER else -1.0
			battle.spawn_unit(battle.get_config(118), team, global_position + Vector3(-0.8, 0, back * 1.2), 1, level)
			battle.spawn_unit(battle.get_config(118), team, global_position + Vector3(0.8, 0, back * 1.2), 1, level)
	# 非建筑单位：从天而降（放置手感）
	if config.type != Config.UnitType.BUILDING and not follow:
		_play_spawn_drop()
	# 地狱飞龙 / 地狱之塔：持续激光视觉（伤害仍由隐身快速子弹结算）
	if _is_inferno():
		_setup_beam()
	# 放置单位碰撞体
	var col_shape = CollisionShape3D.new()
	if config.type == Config.UnitType.BUILDING:
		var box = BoxShape3D.new()
		box.size = Vector3(config.size,config.size,config.size)*2
		col_shape.shape = box
	else:
		var sphere = SphereShape3D.new()
		sphere.radius = config.size
		col_shape.shape = sphere
	add_child(col_shape)
	# 如果配置了额外法术（登场即触发，如闪电法师）
	if config.extra_spell.size() > 0 and config.extra_spell[4] < 0 and not replay_visual:
		var hid = 1
		_play_sky_strike_vfx()
		_cast_spell(config.extra_spell)
	# 部署冷却（单位默认1秒，特殊单位特殊值）
	deploy_cooldown = 0.5
	if config.card_id == 55 or config.card_id == 72 or config.card_id == 3:   # 十字连弩
		deploy_cooldown = 3.0
	elif config.card_id == 61:
		deploy_cooldown = 1.2
	if follow:
		deploy_cooldown =0
			# 其他特殊单位可继续扩展
	max_deploy_cooldown = deploy_cooldown
func _load_animations():
	# 寻找或创建 AnimationPlayer
	#anim_player = _find_animation_player(self)
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "ExternalAnimPlayer"
		body_mesh.add_child(anim_player)
	var prefix = ANIM_PREFIX.get(config.card_name, "")
	if prefix.is_empty():
		return
	# 获取默认动画库（若没有则创建）
	var library = anim_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)
	var anim_names = ["idle", "walk", "attack"]
	for state in anim_names:
		var path = "res://assets//animations/%s_%s.anim" % [prefix, state]
		#print(path)
		if ResourceLoader.exists(path):
			#print(1)
			var anim_res = load(path) as Animation
			if anim_res:
				# 设置循环模式
				if state in ["idle", "walk"]:
					anim_res.loop_mode = Animation.LOOP_LINEAR
				else:
					anim_res.loop_mode = Animation.LOOP_NONE
				# 添加到库中
				library.add_animation(state, anim_res)
func _activate_king_tower():
	if not king_tower_activated:
		king_tower_activated = true
		deploy_cooldown = 3.0
		# 觉醒动画：国王手忙脚乱地架起炮台（时长=觉醒 3 秒）
		_king_anim_active = true
		_king_anim_t = 0.0# ----- 每帧更新 -----
func _physics_process(delta):
	if _spin_remaining > 0.0:
		_spin_remaining = maxf(0.0, _spin_remaining - delta)
	if _recoil_remaining > 0.0:
		_recoil_remaining = maxf(0.0, _recoil_remaining - delta)
	if _knock_remaining > 0.0:
		_knock_remaining = maxf(0.0, _knock_remaining - delta)
	if _special_action_cd > 0.0:
		_special_action_cd = maxf(0.0, _special_action_cd - delta)
	if _lifetime_until_ms > 0.0 and Time.get_ticks_msec() >= _lifetime_until_ms:
		die()
		return
	if config.card_id == 120:
		_collector_t += delta
		if _collector_t >= 15.0:
			_collector_t -= 15.0
			if battle:
				battle.gain_elixir(team, 1, global_position)
	if config.card_id == 111:
		_enchant_t += delta
		if _enchant_t >= 0.5:
			_enchant_t = 0.0
			# 保留已经附魔且存活的单位（离开范围也不解除）
			var alive_targets: Array = []
			for old_t in _rune_targets:
				if is_instance_valid(old_t) and old_t.health > 0 and old_t._rune_owner == self:
					alive_targets.append(old_t)
				elif is_instance_valid(old_t) and old_t._rune_owner == self:
					old_t._rune_owner = null
			_rune_targets = alive_targets
			# 只有已附魔存活数 < 2 时才给范围内新单位附魔
			if _rune_targets.size() < 2:
				for u in battle.units.get_children():
					if _rune_targets.size() >= 2:
						break
					if not (u is Unit) or u == self or u.team != team or u.health <= 0:
						continue
					if u.config.type == Config.UnitType.BUILDING:
						continue
					if u._rune_owner != null:
						continue
					if u.global_position.distance_to(global_position) > 7.0:
						continue
					u._rune_owner = self
					_rune_targets.append(u)
	if config.card_id == 105 and battle and health <= 0.5 * max_health:
		# 生命值低于 50%：清空当前目标，直奔最近的敌方皇家塔
		speed = 2.0
		if not _demolisher_charge_started:
			_demolisher_charge_started = true
			target = null
			attacked_list.clear()
		var nearest_tower: Unit = null
		var best_d: float = 1000000.0
		for u in battle.units.get_children():
			if not (u is Unit) or u.team == team or u.health <= 0:
				continue
			if u.config.card_id > 3:
				continue
			var dd: float = global_position.distance_to(u.global_position)
			if dd < best_d:
				best_d = dd
				nearest_tower = u
		target = nearest_tower
		if target != null and is_instance_valid(target) and distance_to(target) <= 1.0:
			die()
			return
	if _king_anim_active and visual_root:
		_king_anim_t += delta
		var kp: float = clampf(_king_anim_t / 3.0, 0.0, 1.0)
		visual_root.rotation.z = 0.0
		visual_root.position.y = 0.0
		if _king_turret:
			if kp > 0.08:
				_king_turret.visible = true
				var ts: float = clampf((kp - 0.08) / 0.85, 0.0, 1.0)
				ts = ts * ts * (3.0 - 2.0 * ts)
				_king_turret.scale = Vector3.ONE * maxf(ts, 0.01)
				_king_turret.rotation.y = (1.0 - ts) * TAU * 0.75
		if kp >= 1.0:
			_king_anim_active = false
			visual_root.rotation.z = 0.0
			visual_root.position.y = 0.0
			if _king_turret:
				_king_turret.visible = true
				_king_turret.scale = Vector3.ONE
				_king_turret.rotation.y = 0.0
	if tunnel:
		return
	if health <= 0:
		if not follow:
			die()
			return
		else:
			if follow.health <=0:
				global_position.y -=0.6
				follow = null
				die()
				return
	if config.card_id == 95 :
		if health <= 0.5*max_health:
			config.type = Config.UnitType.BUILDING
			config.move_speed = 0
		else:
			config.type = Config.UnitType.GROUND
			config.move_speed = 1.2
	var now = Time.get_ticks_msec()
	# 碰撞分离
	if not follow:
				_separate_overlap()
	_update_status_visuals()
	_apply_status_effects(now)
		# 国王塔激活逻辑
	if config.card_id == 3 and config.type == Config.UnitType.BUILDING:
		if not king_tower_activated:
			var idx1 = 0 if team == Config.Team.PLAYER else 3
			var idx2 = 1 if team == Config.Team.PLAYER else 4
			if battle.healths[idx1] <= 0.0 or battle.healths[idx2] <= 0.0:
				_activate_king_tower()
			else:
				return
	if deploy_cooldown > 0:
		deploy_cooldown -= delta
		return
	elif config.card_id !=90:
		if hid == 1:
			hid = 0
	# 建筑持续扣血（非皇家塔）
	if config.type == Config.UnitType.BUILDING and id > 5:  # id>5 确保不是初始塔
		_degrade_health(now, delta)
	# 生成子单位
	if config.spawn_unit.size() >= 3:
		spawn_cooldown -= delta
		if spawn_cooldown <= 0:
			_spawn_children()
	# 主要行为：找目标→移动或攻击
	if follow:
		global_position = follow.global_position
		global_position.y +=0.6
	if state != 2 or (now - shock_timer >= 500):  # 电击停顿
		if target and target.has_method("is_tesla_buried") and target.is_tesla_buried():
			target = null
		var _keep_demolisher_tower: bool = config.card_id == 105 and health <= 0.5 * max_health
		if target and (target.health <= 0 or target.hid ==1 or (distance_to(target) > config.horizon and not _keep_demolisher_tower)) :
			# 目标死亡/丢失：保留当前攻击冷却，不重置（这里刻意不改 attack_cooldown）
			target = null
		if not target:
			attacked_list = []
			find_target(self)
		if target:
			var dist = distance_to(target)
			if config.card_id == 108 and dist <= 1.0:
				die()
				return
			if dist > config.attack_range or (config.card_id == 105 and _demolisher_charge_started):
				if not follow:
					if config.move_type >=5 :
						var bridge_only: bool = _needs_bridge_crossing(target)
						if bridge_only:
							_move_towards(target.global_position, delta)
						elif jump ==0 and _special_action_cd <= 0.0 and 3.5<=dist and dist<=config.move_type:
							jump_timer = now
							jump = config.move_type-4
						elif jump > 0 and (now - jump_timer) >= 800*jump:
							if jump < 3:
								global_position = target.global_position*0.8+global_position*0.2
							else:
								if target.config.type == Config.UnitType.BUILDING:
									global_position = target.global_position*0.8+global_position*0.2
								else:
									target.global_position = target.global_position*0.2+global_position*0.8
								target.slow_factor = 10
								target.froze_timer = now
							_separate_overlap()
							_attack()
							if jump < 3:
								_attack()
							jump=0
							_special_action_cd = 1.2
						else:
							# 超级骑士等 move_type>=5 单位：超出跳跃距离时必须继续走，
							# 否则会卡在 5 格外原地不动。
							_move_towards(target.global_position, delta)
					else:
						_move_towards(target.global_position, delta)
				else:
					global_position = follow.global_position
			else:
				if config.damage > 0 and attack_cooldown <= 0:
					_attack()
				elif _is_charge_attacker() and accelerate >= 1.2 and config.damage > 0 and (now - _charge_attack_time) > 400.0:
					# 冲锋单位：碰到目标立即攻击，不等冷却
					_charge_attack_time = now
					_charge_bypass = true
					_attack()
		else:
			if not follow:
				_move_forward(delta)
								# 冷却递减
	if attack_cooldown > 0:
		attack_cooldown -= delta / slow_factor*(1+quick*0.01)
	if config.type == Config.UnitType.AIR and not is_entangled():
		global_position.y = 1.9 + sin(Time.get_ticks_msec() * 0.003) * 0.05
	_rotate_to_direction()
	if contact_shadow:
		contact_shadow.global_position = Vector3(global_position.x - 0.30, 0.025, global_position.z + 0.36)
	_update_animation(delta)
	_update_charge_fx(delta)
	_update_special_fx(delta)
	_update_river_jump(delta)
	_update_tesla(delta)
	_update_sparky(delta)
	_update_beam()
	_update_chain_fx()
	_update_rune_marker(delta)
	_update_turret()
func _update_turret() -> void:
	if body_mesh == null:
		return
	var turret := body_mesh.get_node_or_null("Turret") as Node3D
	if turret == null:
		return
	if target and is_instance_valid(target) and distance_to(target) <= config.attack_range + 1.0:
		var d: Vector3 = target.global_position - global_position
		turret.rotation.y = atan2(d.x, d.z)
func _is_inferno() -> bool:
	# 光束类：地狱飞龙/地狱之塔(火焰光束) + 闪电法师/雷电飞龙(闪电链)
	return config != null and (config.card_id in [6, 21, 27, 33, 36, 60, 93])
func _is_charge_attacker() -> bool:
	return config != null and config.move_type == 2
func _is_beam_unit() -> bool:
	return _is_inferno()
func _beam_is_lightning() -> bool:
	return config != null and (config.card_id == 6 or config.card_id == 21 or config.card_id == 36 or config.card_id == 60 or config.card_id == 93)
func _setup_beam() -> void:
	inferno_beam = Node3D.new()
	inferno_beam.top_level = true
	inferno_beam.visible = false
	add_child(inferno_beam)
	if _beam_is_lightning():
		for i in 12:
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.05, 1.0, 0.05)
			mi.mesh = bx
			var col: Color = Color(0.78, 0.92, 1.0).lerp(Color(0.32, 0.52, 1.0), float(i % 3) / 3.0)
			mi.material_override = _beam_mat(col, 2.2)
			mi.name = "Seg%d" % i
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inferno_beam.add_child(mi)
		var tip := MeshInstance3D.new()
		var ts := SphereMesh.new()
		ts.radius = 0.16
		ts.height = 0.32
		tip.mesh = ts
		tip.material_override = _beam_mat(Color(0.90, 0.97, 1.0), 2.6)
		tip.name = "Tip"
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inferno_beam.add_child(tip)
	else:
		var specs := [
			{"r": 0.105, "col": Color(1.0, 0.32, 0.06), "e": 1.3, "nm": "Glow"},
			{"r": 0.068, "col": Color(1.0, 0.58, 0.12), "e": 1.9, "nm": "Mid"},
			{"r": 0.036, "col": Color(1.0, 0.92, 0.70), "e": 2.8, "nm": "Core"},
		]
		for sp in specs:
			var mi2 := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = sp.r
			cm.bottom_radius = sp.r
			cm.height = 1.0
			cm.radial_segments = 12
			mi2.mesh = cm
			mi2.material_override = _flame_beam_mat(sp.col, sp.e, float(specs.find(sp)))
			mi2.name = String(sp.nm)
			mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inferno_beam.add_child(mi2)
		for i in 6:
			var band := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.075
			tor.outer_radius = 0.135
			tor.rings = 16
			tor.ring_segments = 6
			band.mesh = tor
			band.material_override = _flame_beam_mat(Color(1.0, 0.76, 0.32), 2.1, float(i) * 0.7)
			band.name = "Band%d" % i
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inferno_beam.add_child(band)
		var hit := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.18
		hs.height = 0.36
		hit.mesh = hs
		hit.material_override = _beam_mat(Color(1.0, 0.82, 0.45), 2.2)
		hit.name = "Tip"
		hit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inferno_beam.add_child(hit)
func _beam_end_offset() -> Vector3:
	var h: int = int(get_instance_id()) % 89
	var ang: float = float(h) * 2.39996
	return Vector3(cos(ang), 0.0, sin(ang)) * 0.30 + Vector3(0.0, 0.18 * sin(ang * 1.7), 0.0)
func _flame_beam_mat(col: Color, energy: float, s: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/beam_flame.gdshader")
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("seed", s + float(int(get_instance_id()) % 17) * 0.37)
	return m
func _beam_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
func _update_beam() -> void:
	if inferno_beam == null:
		return
	if target == null or not is_instance_valid(target) or health <= 0.0 or distance_to(target) > config.attack_range + 0.8:
		inferno_beam.visible = false
		return
	if _beam_is_lightning() and (config.card_id == 36 or config.card_id == 45):
		_update_chain_fx()
		inferno_beam.visible = false
		return
	var from: Vector3 = _bullet_spawn_pos()
	var to: Vector3 = target.global_position + Vector3.UP * 0.55
	var d: Vector3 = to - from
	var length: float = d.length()
	if length < 0.1:
		inferno_beam.visible = false
		return
	var dir: Vector3 = d / length
	var now_ms: float = Time.get_ticks_msec()
	if _beam_is_lightning() and now_ms > _chain_until:
		inferno_beam.visible = false
		return
	var now: float = now_ms * 0.001
	inferno_beam.visible = true
	inferno_beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), from)
	var tip := inferno_beam.get_node_or_null("Tip") as Node3D
	if _beam_is_lightning():
		var segs: Array = []
		for ch in inferno_beam.get_children():
			if String(ch.name).begins_with("Seg"):
				segs.append(ch)
		var n: int = segs.size()
		var seg_len: float = length / float(n + 1)
		var idx := 0
		for sg in segs:
			idx += 1
			var t: float = float(idx) / float(n + 1)
			var jx: float = sin(now * 23.0 + float(idx) * 2.1) * 0.055
			var jz: float = cos(now * 19.0 + float(idx) * 1.7) * 0.055
			sg.position = Vector3(jx, t * length, jz)
			sg.scale = Vector3(1.0 + 0.35 * sin(now * 31.0 + float(idx)), seg_len * 1.6, 1.0 + 0.35 * sin(now * 27.0 + float(idx)))
		if tip:
			tip.position = Vector3(0, length, 0)
	else:
		for ch in inferno_beam.get_children():
			var nm := String(ch.name)
			if nm == "Glow" or nm == "Mid" or nm == "Core":
				var thick: float = 1.0 + clampf(accumulate - 1.0, 0.0, 1.6) * 0.95
				ch.scale = Vector3(thick * (1.0 + 0.12 * sin(now * 15.0 + float(ch.get_index()))), length, thick * (1.0 + 0.12 * sin(now * 13.0 + float(ch.get_index()))))
				ch.position = Vector3(0, length * 0.5, 0)
			elif nm.begins_with("Band"):
				var t2: float = fmod(now * 1.4 + float(ch.get_index()) * 0.17, 1.0)
				ch.position = Vector3(0, t2 * length, 0)
				ch.scale = Vector3.ONE * (0.7 + 0.45 * sin(now * 9.0 + float(ch.get_index())))
		if tip:
			tip.position = Vector3(0, length, 0)
func play_anim(anim_name: String, custom_speed: float = 1.0):
	if not anim_player: return
	var anim_list = anim_player.get_animation_list()
	for a in anim_list:
		if a.strip_edges().to_lower() == anim_name.strip_edges().to_lower():
			if anim_player.current_animation != a:
				anim_player.play(a, -1, custom_speed)
			else:
				# 已经在播放同一个动画，但速度可能不同，重新设置
				anim_player.speed_scale = custom_speed
			return
func _update_animation(delta):
	if visual_root == null:
		return
	if _spin_remaining > 0.0:
		return
	var now := Time.get_ticks_msec()
	anim_time += delta
	var speed_mult: float = 1.0 / maxf(slow_factor, 0.01)
	# 攻击优先：蓄力-挥击-收招
	if attack_anim_start > 0.0:
		var p: float = clampf(float(now - attack_anim_start) / (attack_anim_duration * 1000.0), 0.0, 1.0)
		if p >= 1.0:
			attack_anim_start = -1.0
		else:
			anim_state = UnitVisualAnim.State.ATTACK
			UnitVisualAnim.apply(visual_root, anim_state, anim_time, p, speed_mult, config.type == Config.UnitType.BUILDING, weapon_kind)
			return
	# 受击
	if now < hit_anim_end:
		anim_state = UnitVisualAnim.State.HIT
		UnitVisualAnim.apply(visual_root, anim_state, anim_time, 0.0, speed_mult, config.type == Config.UnitType.BUILDING, weapon_kind)
		return
	# 移动 / 待机：攻击中或实际未位移时不播走路
	var moved: float = Vector2(global_position.x - _anim_last_pos.x, global_position.z - _anim_last_pos.z).length()
	_anim_last_pos = global_position
	var in_combat: bool = target != null and is_instance_valid(target) and distance_to(target) <= config.attack_range + 0.3
	var is_building: bool = config.type == Config.UnitType.BUILDING
	if moved > 0.003 and not in_combat and not is_building:
		anim_state = UnitVisualAnim.State.WALK
		UnitVisualAnim.apply(visual_root, anim_state, anim_time, 0.0, (config.move_speed * 0.05) * speed_mult, is_building, weapon_kind)
	else:
		anim_state = UnitVisualAnim.State.IDLE
		UnitVisualAnim.apply(visual_root, anim_state, anim_time, 0.0, speed_mult, is_building, weapon_kind)
func _handle_shock_anim():
	if not anim_player: return
	if not shock_anim_frozen:
		anim_player.speed_scale = 0.0   # 冻结当前动画
		shock_anim_frozen = true
func _rotate_to_direction():
	if _spin_remaining > 0.0:
		return
	if not body_mesh: return
	if config.type == Config.UnitType.BUILDING:
		return   # 建筑不动
	var target_angle: float = 0.0
	# 优先朝向攻击目标（攻击时 face 目标）
	if target and distance_to(target) <= config.attack_range:
		var dir = target.global_position - global_position
		if dir.length() > 0.01:
			target_angle = atan2(dir.x, dir.z)   # Godot 中 Y 轴向上，XZ 平面
	# 否则朝向移动方向
	elif move_direction.length() > 0.01:
		target_angle = atan2(move_direction.x, move_direction.y)
	# 平滑旋转（可选）
	var current_y = visual_root.rotation.y
	var new_y = lerp_angle(current_y, target_angle, 0.15)   # 0.15 是转向速度
	visual_root.rotation.y = new_y
func _update_status_visuals():
	if not body_mesh: return
	var now = Time.get_ticks_msec()
	var flash := 0.0
	var shock := 0.0
	var frozen := 0.0
	var poison := 0.0
	var curse := 0.0
	var rage := 0.0
	var slow_v := 0.0
	var dark := 0.0
	var shocked = shock_timer > 0.0 and (now - shock_timer) < 500
	var is_frozen = (now - froze_timer) <= 2000
	var pois = pois_timer > 0.0 and (now - pois_timer) < 5000
	var is_curse = fix_timer > 0.0 and (now - fix_timer) < 2000
	var is_rage = quick_timer > 0 and (now - quick_timer) <= 2000
	var is_slow = slow_factor > 1.05 and not is_frozen and not shocked
	if now < hit_flash_end_time:
		flash = 1.0
	elif shocked:
		shock = 1.0
	elif is_frozen:
		frozen = 1.0
	elif pois:
		poison = 0.9
	elif is_curse:
		curse = 1.0
	elif is_rage:
		rage = 1.0
	elif is_slow:
		slow_v = 1.0
	elif hid:
		dark = 1.0
	body_mesh.set_instance_shader_parameter("u_flash", flash)
	body_mesh.set_instance_shader_parameter("u_freeze", frozen)
	body_mesh.set_instance_shader_parameter("u_poison", poison)
	body_mesh.set_instance_shader_parameter("u_dark", dark)
	body_mesh.set_instance_shader_parameter("u_curse", curse)
	body_mesh.set_instance_shader_parameter("u_rage", rage)
	body_mesh.set_instance_shader_parameter("u_slow", slow_v)
	var kind := ""
	if shocked: kind = "shock"
	elif is_frozen: kind = "freeze"
	elif pois: kind = "poison"
	elif is_curse: kind = "curse"
	elif is_rage: kind = "rage"
	elif is_slow: kind = "slow"
	_set_status_fx(kind)
	if status_fx:
		_animate_status_fx(now)
func _set_status_fx(kind: String) -> void:
	if kind == status_kind:
		return
	status_kind = kind
	if status_fx:
		status_fx.queue_free()
		status_fx = null
	if kind.is_empty():
		return
	status_fx = Node3D.new()
	status_fx.name = "StatusFX"
	add_child(status_fx)
	var cfg := {}
	match kind:
		"shock": cfg = {"n": 5, "col": Color(0.72, 0.90, 1.0), "r": 0.55, "y": 0.95, "size": 0.06, "spin": 11.0, "shape": "arc"}
		"freeze": cfg = {"n": 9, "col": Color(0.68, 0.90, 1.0), "r": 0.62, "y": 0.75, "size": 0.10, "spin": 0.9, "shape": "shard"}
		"poison": cfg = {"n": 6, "col": Color(0.40, 0.90, 0.35), "r": 0.45, "y": 0.25, "size": 0.07, "spin": 1.4, "shape": "bubble"}
		"curse": cfg = {"n": 6, "col": Color(0.38, 0.95, 0.35), "r": 0.55, "y": 0.90, "size": 0.09, "spin": 2.2, "shape": "wisp"}
		"rage": cfg = {"n": 7, "col": Color(0.75, 0.40, 1.0), "r": 0.50, "y": 0.25, "size": 0.07, "spin": 0.4, "shape": "ember"}
		"slow": cfg = {"n": 5, "col": Color(0.70, 0.90, 1.0), "r": 0.55, "y": 0.25, "size": 0.05, "spin": 0.6, "shape": "bubble"}
	for i in int(cfg.n):
		var mi := MeshInstance3D.new()
		match String(cfg.shape):
			"shard":
				var cone := PrismMesh.new()
				cone.size = Vector3(0.10, 0.26, 0.06)
				mi.mesh = cone
			"arc":
				var bx := BoxMesh.new()
				bx.size = Vector3(0.05, 0.30, 0.05)
				mi.mesh = bx
			"wisp":
				var s := SphereMesh.new()
				s.radius = 0.09
				s.height = 0.18
				mi.mesh = s
			_:
				var s2 := SphereMesh.new()
				s2.radius = float(cfg.size)
				s2.height = float(cfg.size) * 2.0
				mi.mesh = s2
		mi.material_override = _status_mat(cfg.col, 0.85)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * float(i) / float(cfg.n)
		mi.position = Vector3(cos(a) * float(cfg.r), float(cfg.y), sin(a) * float(cfg.r))
		status_fx.add_child(mi)
	status_fx.set_meta("spin", float(cfg.spin))
	status_fx.set_meta("base_y", float(cfg.y))
func _status_mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.5
	return m
func _animate_status_fx(now: int) -> void:
	if status_fx == null:
		return
	var t := now * 0.001
	status_fx.rotation.y = t * float(status_fx.get_meta("spin", 1.0))
	var base_y := float(status_fx.get_meta("base_y", 0.5))
	var idx := 0
	for c in status_fx.get_children():
		idx += 1
		if idx == 1:
			continue
		if status_kind == "rage":
			c.position.y = base_y + fmod(t * 1.4 + float(idx) * 0.17, 0.85)
		elif status_kind == "shock":
			c.position.y = base_y + sin(t * 2.2 + float(idx)) * 0.10
			c.visible = fmod(t * 22.0 + float(idx), 1.0) > 0.2
		else:
			c.position.y = base_y + sin(t * 2.2 + float(idx)) * 0.10
func _create_status_particles():
	if status_particles:
		status_particles.queue_free()
	status_particles = Node3D.new()
	add_child(status_particles)
	var shocked = (Time.get_ticks_msec() - shock_timer) < 500
	var frozen = (Time.get_ticks_msec() - froze_timer) <= 2000
	var pois =(Time.get_ticks_msec() - pois_timer) < 5000
	var fix =(Time.get_ticks_msec() - fix_timer) < 2000
	if shocked:
		# 电击：大号金色闪烁光球环绕
		for i in range(10):
			var spark = MeshInstance3D.new()
			spark.mesh = SphereMesh.new()
			spark.mesh.radius = 0.2              # 明显加大
			spark.mesh.height = 0.4
			spark.material_override = StandardMaterial3D.new()
			spark.material_override.albedo_color = Color(1.0, 0.9, 0.0, 1.0)   # 亮金
			spark.material_override.emission_enabled = true
			spark.material_override.emission = Color(1.0, 0.8, 0.0) * 2.0       # 自发光
			spark.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# 初始位置随机绕单位一圈
			var angle = i * TAU / 10.0
			spark.position = Vector3(cos(angle) * 1.2, randf_range(0.3, 1.8), sin(angle) * 1.2)
			status_particles.add_child(spark)
			# 快速环绕动画 + 上下波动
			var tween = create_tween().set_loops()
			tween.tween_property(spark, "position:x", cos(angle + TAU/4)*1.2, 0.15)
			tween.tween_property(spark, "position:z", sin(angle + TAU/4)*1.2, 0.15)
			tween.tween_property(spark, "position:y", spark.position.y + 0.5, 0.08)
			tween.tween_property(spark, "position:y", spark.position.y - 0.5, 0.08)
	elif jump:   # 冰冻
		# 大块冰晶方块 + 旋转 + 漂浮
		for i in range(12):
			var shard = MeshInstance3D.new()
			shard.mesh = BoxMesh.new()
			shard.mesh.size = Vector3(0.3, 0.3, 0.3)   # 每个0.3米的立方体
			shard.material_override = StandardMaterial3D.new()
			shard.material_override.albedo_color = Color(0.502, 0.502, 0.502, 0.902)   # 冰蓝色
			shard.material_override.emission_enabled = true
			shard.material_override.emission = Color(0.502, 0.502, 0.502, 0.902)  * 1.5       # 自发光
			shard.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var angle = randf_range(0, TAU)
			var radius = config.size * 1.5 + 0.6
			shard.position = Vector3(cos(angle)*radius, randf_range(0.2, 2.0), sin(angle)*radius)
			shard.rotation = Vector3(randf(), randf(), randf()) * 3.0
			status_particles.add_child(shard)
			# 慢速旋转 + 上下漂浮
			var tween = create_tween().set_loops()
			tween.tween_property(shard, "rotation", shard.rotation + Vector3(0, 2, 0), 1.0)
			tween.tween_property(shard, "position:y", shard.position.y + 0.4, 0.4)
			tween.tween_property(shard, "position:y", shard.position.y - 0.4, 0.4)
	elif frozen:   # 冰冻
		# 大块冰晶方块 + 旋转 + 漂浮
		for i in range(12):
			var shard = MeshInstance3D.new()
			shard.mesh = BoxMesh.new()
			shard.mesh.size = Vector3(0.3, 0.3, 0.3)   # 每个0.3米的立方体
			shard.material_override = StandardMaterial3D.new()
			shard.material_override.albedo_color = Color(0.302, 0.902, 1.0, 0.902)   # 冰蓝色
			shard.material_override.emission_enabled = true
			shard.material_override.emission = Color(0.243, 0.8, 1.0, 1.0) * 1.5       # 自发光
			shard.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var angle = randf_range(0, TAU)
			var radius = config.size * 1.5 + 0.6
			shard.position = Vector3(cos(angle)*radius, randf_range(0.2, 2.0), sin(angle)*radius)
			shard.rotation = Vector3(randf(), randf(), randf()) * 3.0
			status_particles.add_child(shard)
			# 慢速旋转 + 上下漂浮
			var tween = create_tween().set_loops()
			tween.tween_property(shard, "rotation", shard.rotation + Vector3(0, 2, 0), 1.0)
			tween.tween_property(shard, "position:y", shard.position.y + 0.4, 0.4)
			tween.tween_property(shard, "position:y", shard.position.y - 0.4, 0.4)
	elif fix:   # 冰冻
		# 大块冰晶方块 + 旋转 + 漂浮
		for i in range(12):
			var shard = MeshInstance3D.new()
			shard.mesh = BoxMesh.new()
			shard.mesh.size = Vector3(0.3, 0.3, 0.3)   # 每个0.3米的立方体
			shard.material_override = StandardMaterial3D.new()
			shard.material_override.albedo_color = Color(0.886, 0.902, 0.91, 0.902)   # 冰蓝色
			shard.material_override.emission_enabled = true
			shard.material_override.emission = Color(0.886, 0.902, 0.91, 0.902)  * 1.5       # 自发光
			shard.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var angle = randf_range(0, TAU)
			var radius = config.size * 1.5 + 0.6
			shard.position = Vector3(cos(angle)*radius, randf_range(0.2, 2.0), sin(angle)*radius)
			shard.rotation = Vector3(randf(), randf(), randf()) * 3.0
			status_particles.add_child(shard)
			# 慢速旋转 + 上下漂浮
			var tween = create_tween().set_loops()
			tween.tween_property(shard, "rotation", shard.rotation + Vector3(0, 2, 0), 1.0)
			tween.tween_property(shard, "position:y", shard.position.y + 0.4, 0.4)
			tween.tween_property(shard, "position:y", shard.position.y - 0.4, 0.4)
	else:
		for i in range(12):
			var shard = MeshInstance3D.new()
			shard.mesh = BoxMesh.new()
			shard.mesh.size = Vector3(0.3, 0.3, 0.3)   # 每个0.3米的立方体
			shard.material_override = StandardMaterial3D.new()
			shard.material_override.albedo_color = Color(0.302, 0.271, 1.0, 0.902)   # 冰蓝色
			shard.material_override.emission_enabled = true
			shard.material_override.emission = Color(0.302, 0.271, 1.0, 0.902)  * 1.5       # 自发光
			shard.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var angle = randf_range(0, TAU)
			var radius = config.size * 1.5 + 0.6
			shard.position = Vector3(cos(angle)*radius, randf_range(0.2, 2.0), sin(angle)*radius)
			shard.rotation = Vector3(randf(), randf(), randf()) * 3.0
			status_particles.add_child(shard)
			# 慢速旋转 + 上下漂浮
			var tween = create_tween().set_loops()
			tween.tween_property(shard, "rotation", shard.rotation + Vector3(0, 2, 0), 1.0)
			tween.tween_property(shard, "position:y", shard.position.y + 0.4, 0.4)
			tween.tween_property(shard, "position:y", shard.position.y - 0.4, 0.4)# ----- 目标选择 -----
func find_target(origin):
	accumulate = 1.0
	var potential = []
	for obj in battle.units.get_children():
		if obj == self or obj.team == team or obj in attacked_list:
			continue
		if obj.follow:
			continue
		if obj.hid:
			continue
		if obj.config.card_id == 108:
			continue
		if obj.has_method("is_tesla_buried") and obj.is_tesla_buried():
			continue
		var dist =  sqrt((origin.global_position.x-obj.global_position.x)**2+(origin.global_position.z-obj.global_position.z)**2) - (obj.config.size + origin.config.size)
		if self == origin:
			if dist > config.horizon:
				continue
		else:
			if dist > 2:
				continue
		# 检查目标类型
		match config.target_type:
			Config.TargetType.GROUND_ONLY:
				if obj.config.type == Config.UnitType.AIR and not obj.is_entangled():
					continue
			Config.TargetType.BUILDING_ONLY:
				if obj.config.type != Config.UnitType.BUILDING:
					continue
		potential.append([obj, dist])
	if potential.size() > 0:
		potential.sort_custom(func(a, b): return a[1] < b[1])
		target = potential[0][0]
		attacked_list.append(target)
		return(target)
	else:
		if config.multiple_targets.size() != 0:
			if config.multiple_targets[1] == 1:
				return(target)
			else:
				target = null
		else:
			target = null
		# ----- 移动逻辑 -----
func _move_towards(pos: Vector3, delta):
	if _spin_remaining > 0.0:
		return
	if _recoil_remaining > 0.0:
		return
	if _knock_remaining > 0.0:
		return
	if config.type == Config.UnitType.BUILDING:
		return
	if Time.get_ticks_msec()-shock_timer<=500:
		return
	# 过桥逻辑修正
	var target_pos = pos
	if team == Config.Team.PLAYER:
		if global_position.z >= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 and config.type < Config.UnitType.AIR and not (config.card_id in [16, 17, 23, 38, 86, 98]):
			if pos.z >= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5:
				target_pos = pos
			else:
				var bridge_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2 if global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5 else Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8
				target_pos = Vector3(bridge_x, global_position.y, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 - 0.5)
	else:
		if global_position.z <= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 and config.type < Config.UnitType.AIR and not (config.card_id in [16, 17, 23, 38, 86, 98]):
			if pos.z <= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5:
				target_pos = pos
			else:
				var bridge_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2 if global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5 else Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8
				target_pos = Vector3(bridge_x, global_position.y, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 + 0.5)
	var dir = Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
	if dir.length() > 0.01:
		move_direction = dir.normalized()
		var step = speed * floor(accelerate) * delta
		step /= slow_factor
		step *= 1+quick*0.01
		step /= fix_factor
		global_position.x += move_direction.x * step
		global_position.z += move_direction.y * step
		if config.move_type == 2:
			accelerate = min(accelerate + 0.005 * delta * 60, 2.0)
	global_position.x = clamp(global_position.x, Config.ARENA_ORIGIN.x, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH)
	global_position.z = clamp(global_position.z, Config.ARENA_ORIGIN.z, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT)
	# 最后一排：非国王塔正后方 6 格不可行走
	var back_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 0.9
	var front_z: float = Config.ARENA_ORIGIN.z + 0.9
	if global_position.z > back_z and absf(global_position.x) > 3.0:
		global_position.z = back_z
	if global_position.z < front_z and absf(global_position.x) > 3.0:
		global_position.z = front_z
func _move_forward(delta):
	if config.type == Config.UnitType.BUILDING:
		return
	var target_pos = global_position
	if team == Config.Team.PLAYER:
		if global_position.z >= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 and config.type < Config.UnitType.AIR and not (config.card_id in [16, 17, 23, 38, 86, 98]):
			var bridge_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2 if global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5 else Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8
			target_pos = Vector3(bridge_x, global_position.y, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 - 0.5)
		else:
			if battle.healths[3] > 0 and global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)
			elif battle.healths[4] > 0 and global_position.x >= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)
			else:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 3.0 / 32.0)
	else:
		if global_position.z <= Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 and config.type < Config.UnitType.AIR and not (config.card_id in [16, 17, 23, 38, 86, 98]):
			var bridge_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2 if global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5 else Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8
			target_pos = Vector3(bridge_x, global_position.y, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 + 0.5)
		else:
			if battle.healths[0] > 0 and global_position.x <= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.2, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 24.5 / 32.0)
			elif battle.healths[1] > 0 and global_position.x >= Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.8, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 24.5 / 32.0)
			else:
				target_pos = Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 29.0 / 32.0)
	_move_towards(target_pos, delta)# ----- 攻击 -----
func _attack():
	_chain_attack_serial += 1
	_chain_attack_targets.clear()
	if config.card_id == 90:
		hit_timer = Time.get_ticks_msec()
	if _charge_bypass:
		_charge_bypass = false
	else:
		attack_cooldown = config.attack_speed / 1000.0
	_tesla_last_attack = Time.get_ticks_msec()
	if config.card_id == 63 :
		spawn_cooldown =0
		_spawn_children()
		return
		# 播放攻击音效（近战用现成素材，远程用程序化合成，避免缺失资源）
	var atk_sfx: AudioStream
	if config.attack_range > 1.5:
		atk_sfx = ProceduralAudio.get_sound("arrow")
	else:
		atk_sfx = load("res://assets/audio/sfx/attack_melee.wav")
	if atk_sfx:
		AudioManager.play_sfx(atk_sfx, global_position)
	if not target:
		return
	if config.card_id == 12:
		_do_valkyrie_spin()
		return
	# 生成子弹
	if config.multiple_process.size() >= 5:
		_create_multiple_bullets()
	else:
		_create_single_bullet()
	if config.move_type == 2:
		accelerate = 1.0
	if config.card_id == 43:
		_firecracker_recoil()
	# 攻击附带法术（如战斗天使）
	if config.extra_spell.size() > 0 and config.extra_spell[4] == 0:
		_cast_spell(config.extra_spell)
	if config.shield == -1:
		health = 0
		die()
	if config.attack_type == 4:
		accumulate *= 1.2
		accumulate = min(accumulate, 15.0)
		# 多目标攻击
	if config.multiple_targets.size() >= 2:
		_handle_multi_target()
		#attacked_list = []
	attack_anim_start = Time.get_ticks_msec()
	# 攻击冷却期间，_update_animation 会继续检测到 attack 状态，但动画已播放完会停在最后一帧，
	# 我们可让它在冷却结束后再回到 idle
func _bullet_spawn_pos() -> Vector3:
	var s: float = visual_root.scale.y if visual_root else 1.0
	if config.card_id == 97:
		return global_position + Vector3.UP * 0.5
	# 炮台塔：直接用炮口世界坐标
	if body_mesh:
		var turret := body_mesh.get_node_or_null("Turret") as Node3D
		if turret:
			return turret.global_transform * Vector3(0, 0.15, 0.46)
		# 武器发射口：箭/子弹/法球从对应武器尖端出来
		var muzzle = _weapon_muzzle_local(weapon_kind)
		if muzzle is Vector3:
			var wnode := body_mesh.get_node_or_null("Weapon") as Node3D
			if wnode:
				return wnode.global_transform * (muzzle as Vector3)
	# 公主塔：公主弓的位置；其他建筑：胸口高度
	if config.type == Config.UnitType.BUILDING:
		if config.card_id == 1:
			return global_position + Vector3.UP * (0.95 * s) + Vector3.FORWARD * 0.2
		return global_position + Vector3.UP * (0.62 * s)
	# 普通单位：模型胸口/手部高度
	return global_position + Vector3.UP * (0.62 * s)

func _weapon_muzzle_local(w: String):
	match w:
		"bow":
			return Vector3(0.02, 0.10, 0.49)
		"musket":
			return Vector3(0.02, 0.075, 0.55)
		"staff":
			return Vector3(0.02, 0.60, 0.075)
		"cannon":
			return Vector3(0.10, 0.12, 0.40)
		"crossbow":
			return Vector3(0.0, 0.06, 0.56)
		"mortar":
			return Vector3(0.0, 0.23, 0.20)
		"flask":
			return Vector3(0.04, 0.02, 0.10)
		"spear":
			return Vector3(0.0, 0.0, 0.40)
		"barb_barrel":
			return Vector3(0.0, 0.0, 0.30)
	return null
func _create_single_bullet():
	if config.card_id == 67:
		# 公主：一次 3 支箭，在目标点周围均布
		for i in range(3):
			var ang: float = TAU * float(i) / 3.0
			var off := Vector3(cos(ang), 0.0, sin(ang)) * 0.35
			_create_bullet_to(target, off, 1.0 / 3.0)
		return
	_create_bullet_to(target)
func _create_multiple_bullets():
	var num = config.multiple_process[1]
	for i in range(num):
		var bullet = Bullet.new()
		bullet.config = config
		bullet.team = team
		bullet.source_unit = self
		bullet.target = target
		bullet.speed = 10.0
		bullet.size = 0.3
		bullet.position = _bullet_spawn_pos()
		bullet.split = (config.card_id == 56 or config.card_id == 52 or config.card_id == 96 or config.card_id == 97)
		bullet.split_index = i
		battle.bullets.add_child(bullet)
func allow_chain_hit(tgt: Unit, serial: int) -> bool:
	if config == null or config.card_id != 36:
		return true
	if serial != _chain_attack_serial:
		return false
	if tgt == null or tgt in _chain_attack_targets:
		return false
	if _chain_attack_targets.size() >= 3:
		return false
	_chain_attack_targets.append(tgt)
	return true

func _handle_multi_target():
	if config.multiple_targets.size() < 2:
		return
	var total_targets = mini(int(config.multiple_targets[0]), 3)
	var chain_type = config.multiple_targets[1]
	# 已经通过 find_target 获得了主目标 target，并在 _attack 中生成了主子弹
	# 现在需要生成额外目标的子弹
	var extra_needed = total_targets - 1
	if extra_needed <= 0:
		return
	#var current_exclude = [target]  # 初始排除主目标
	if chain_type == 1:
		# 类型1：从自身寻找额外目标
		for i in range(extra_needed):
			var extra = find_target(self)
			if extra:
				_create_bullet_to(extra)
	elif chain_type == 2:
		# 类型2：攻击链，从上一个目标寻找下一个
		var last_target = target
		for i in range(extra_needed):
			var next_target = find_target(last_target)
			if next_target:
				_create_bullet_to(next_target)
				last_target = next_target
			else:
				break
	# 清除本轮攻击记录，以便下次攻击重新寻找
	attacked_list.clear()
func is_tesla_buried() -> bool:
	return tesla_buried
func notify_bullet_wasted() -> void:
	# 子弹因目标死亡而作废（飞行时间 <0.3s）：立即允许下一次攻击
	attack_cooldown = 0.0
func _create_bullet_to(tgt: Unit, aim_offset: Vector3 = Vector3.ZERO, dmg_mult: float = 1.0, show_chain: bool = true):
	var bullet = Bullet.new()
	bullet.config = config
	bullet.team = team
	bullet.source_unit = self
	bullet.target = tgt
	bullet.speed = 10.0
	bullet.chain_serial = _chain_attack_serial
	bullet.aim_offset = aim_offset
	if _rune_owner != null and is_instance_valid(_rune_owner):
		_rune_hits += 1
		if _rune_hits % 3 == 0:
			bullet.damage_bonus = int(220.0 * pow(1.05, _rune_owner.level - 1))
	bullet.damage_multiplier *= dmg_mult
	# 子弹速度调整
	match config.card_id:
		1, 2, 3:
			bullet.speed = 10.0
		32:
			bullet.speed = 15.0
		67:
			bullet.speed = 7.5
	bullet.size = 0.1 + config.damage_range / 20.0
	bullet.position = _bullet_spawn_pos()
	if config.card_id == 36 or config.card_id == 45:
		var max_chain: int = 3
		if config.multiple_targets.size() > 0:
			max_chain = int(config.multiple_targets[0])
		_show_lightning_chain(_build_lightning_points(tgt, max_chain))
	bullet.split = (config.card_id == 56 or config.card_id == 52)
	if _is_beam_unit() and _beam_is_lightning():
		_chain_until = Time.get_ticks_msec() + 500
	if _is_inferno():
		bullet.no_visual = true   # 激光由 Unit 的 beam 表现，子弹只负责结算
		bullet.speed = 120.0
	if config.card_id == 96:
		var tgt_dist: float = absf(distance_to(tgt)) if tgt else 4.0
		var atk_interval: float = maxf(config.attack_speed / 1000.0, 0.35)
		bullet.speed = maxf(tgt_dist * 2.0 / atk_interval, 5.0)
		bullet.axe_return = true
	if config.card_id in [26, 68, 72]:
		bullet.arc_height = 2.8 if config.card_id == 72 else 1.8
	battle.bullets.add_child(bullet)# ----- 受伤与治疗 -----
func take_damage(amount: float, _source: Unit = null):
	if Time.get_ticks_msec() < _spawn_invuln_until:
		_flash_hit()
		return
	# 浪人：受近战攻击时 200% 伤害反弹，3.5 秒冷却
	if config.card_id == 129 and _source != null and is_instance_valid(_source) and _source.config != null:
		if _source.config.type != Config.UnitType.AIR and _source.config.attack_range <= 1.0 and Time.get_ticks_msec() >= _reflect_ready_ms and not _source.is_queued_for_deletion():
			_reflect_ready_ms = Time.get_ticks_msec() + 3500.0
			var reflected: float = amount * 2.0
			if _source.has_method("take_damage"):
				_source.take_damage(reflected, null)
			if battle:
				var sp := MeshInstance3D.new()
				var bm := SphereMesh.new()
				bm.radius = 0.14
				bm.height = 0.28
				sp.mesh = bm
				var sm := StandardMaterial3D.new()
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				sm.albedo_color = Color(1.0, 0.55, 0.2)
				sp.material_override = sm
				sp.position = global_position + Vector3(0, 0.8, 0)
				battle.add_child(sp)
				var tw := sp.create_tween()
				tw.tween_property(sp, "position", _source.global_position + Vector3(0, 0.8, 0), 0.12)
				tw.tween_callback(sp.queue_free)
	if not follow and jump !=2 and hid==0 :
		health -= amount
	if config.card_id <= 3 and amount > 0.0 and _source is Unit and _source.config != null and _source.config.card_id > 3 and battle:
		battle.add_tower_damage(_source.team, _source.config.card_id, amount)
	if config.card_id == 93:
		if _source:
			if distance_to(_source) <= 2.5:
				_spawn_counter_bolt(_source)
				var bullet = Bullet.new()
				bullet.config = config
				bullet.team = team
				bullet.source_unit = self
				bullet.target = _source
				bullet.speed = 10.0
				bullet.size = 0.1 + config.damage_range / 20.0
				bullet.position = _bullet_spawn_pos()
				bullet.split = (config.card_id == 56 or config.card_id == 52)
				bullet.redmg = 1
				bullet.type = 2
				battle.bullets.add_child(bullet)
	if config.card_id == 3 and not king_tower_activated:
		_activate_king_tower()
	if health <= 0 and config.shield > 0 and not shield_used:
		# 破盾恢复
		health = config.max_health
		max_health = config.max_health
		max_health = int(max_health * Config.level_mult(level))
		shield_used = true
	# 更新塔血量
	if id <= 5 and battle:
		battle.healths[id] = health
	if health <= 0:
		die()
	else:
		_flash_hit()
	var hit_sfx = load("res://assets/audio/sfx/hit.wav")
	if hit_sfx:
		AudioManager.play_sfx(hit_sfx, global_position)
func _flash_hit():
	if not body_mesh: return
	hit_flash_end_time = Time.get_ticks_msec() + 60
	hit_anim_end = Time.get_ticks_msec() + 130
func heal(amount: float):
	health = min(health + amount, max_health)# ----- 死亡 -----
func die():
	# 哥布林爆破手死亡爆炸：半径 2 米，对所有单位生效
	if config.card_id == 105 and battle:
		var dmg105: int = int(404.0 * pow(1.05, level - 1))
		var sp105 = Spell.create(global_position, team, dmg105, 2.0, 1, 1, Config.TargetType.ALL)
		sp105.card_id = 105
		battle.spells.add_child(sp105)
	# 皇冠处理
	var was_cursed: bool = _curse_team >= 0 and Time.get_ticks_msec() <= _curse_until
	if was_cursed and battle:
		battle.spawn_unit(battle.get_config(39), _curse_team, global_position, 1)
	_curse_team = -1
	if config.card_id == 125 and battle:
		battle.gain_elixir(1 - team, 1, global_position)
	if config.card_id == 120 and battle:
		battle.gain_elixir(team, 1, global_position)
	if config.card_id == 109 and battle:
		battle.spawn_unit(battle.get_config(39), team, global_position, 2)
	_apply_status_effects(Time.get_ticks_msec())
	# 哥布林魔咒只生成被诅咒方哥布林；不再把死亡单位变成小猪
	if status_ring:
		status_ring.visible = false
	if config.card_id <= 2:
		battle._update_deny_masks()
		battle.add_crown(team, global_position)
	elif config.card_id == 3:
		battle.on_king_destroyed(team, global_position)
	# 死亡附加法术
	if config.extra_spell.size() > 0 and config.extra_spell[4] > 0:
		var bomb_delay: float = 0.0
		if config.card_id == 41:
			bomb_delay = 2.0
		elif config.card_id == 25 or config.card_id == 26:
			bomb_delay = 1.0
		if bomb_delay > 0.0:
			_spawn_death_bomb(bomb_delay, config.extra_spell)
		else:
			_cast_spell(config.extra_spell)
	# 骷髅气球死亡爆破（伤害范围 +0.5 格）
	if config.card_id == 64:
		var dmg64: int = int(config.damage * Config.level_mult(level))
		var sp64 = Spell.create(global_position, team, dmg64, config.damage_range + 0.5, 0, 1, Config.TargetType.ALL)
		sp64.card_id = 64
		battle.spells.add_child(sp64)
	if config.card_id == 79:
		var cfg = battle.get_config(78)
		var level
		if team ==Config.Team.PLAYER:
			level =PlayerData.get_card_level(config.card_id)
		else:
			level = PlayerData.ai_level(config.card_id)
		if battle != null:
			level = battle.mode_level(level)
		var spell = Spell.create(global_position, team,
			int(cfg.damage *Config.level_mult(level)), cfg.damage_range,
			0, cfg.attack_type, cfg.target_type)
		spell.card_id = cfg.card_id
		spell.time = cfg.attack_speed
		battle.spells.add_child(spell)
	# 通知HUD移除血条（如果血条由HUD管理，需通过信号或直接调用）
	if config.card_id == 64 or config.card_id == 69 or config.card_id == 49 or config.card_id == 63 or config.card_id == 92 or config.card_id == 82 or config.card_id == 88 or config.card_id == 106 or config.card_id == 108 or config.card_id == 114 or config.card_id == 124:
		_spawn_children()
	if battle.hud:
		battle.hud.remove_health_bar(self)
	# 禁用碰撞与更新
	set_process(false)
	set_physics_process(false)
	var _col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _col:
		_col.disabled = true
	# 播放死亡动画（如果存在）
	if status_particles:
		status_particles.queue_free()
	if contact_shadow:
		contact_shadow.visible = false
	if inferno_beam:
		inferno_beam.visible = false
	# 只有皇家塔播放爆破/倒塌，其他建筑与普通单位一致（圣水消散）
	if config.type != Config.UnitType.BUILDING or config.card_id > 3:
		if config.damage_range >= 0.5:
			_play_death_explosion()
		_play_elixir_death()
		return
	_play_tower_destruction()
	if visual_root:
		visual_root.visible = false
	await get_tree().create_timer(0.18).timeout
	queue_free()# 放置：从空中落下（约 2.6m，带落地尘环）
func _play_spawn_drop() -> void:
	if visual_root == null:
		return
	visual_root.position.y = 2.6
	var tw := create_tween()
	_spawn_tween = tw
	tw.tween_property(visual_root, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_spawn_land_dust)
func _spawn_land_dust() -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.26
	t.outer_radius = 0.40
	t.rings = 20
	t.ring_segments = 5
	ring.mesh = t
	ring.position = Vector3(0, 0.07, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.7, 1.0, 1.7), 0.25)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(ring.queue_free)# 死亡：化作一团不规则圣水并消散（多瓣叠加、多种紫色、顶部高光）
func _elixir_mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.1
	return m
func _play_elixir_death() -> void:
	var blob_size: float = clampf(config.size * 0.9, 0.22, 0.8)
	var palette := [
		Color(0.58, 0.24, 0.95), Color(0.74, 0.30, 1.0), Color(0.46, 0.16, 0.80),
		Color(0.86, 0.42, 1.0), Color(0.52, 0.20, 0.88),
	]
	var blobs: Array[MeshInstance3D] = []
	var mats: Array[StandardMaterial3D] = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 10:
		var lob := MeshInstance3D.new()
		var s := SphereMesh.new()
		var rad: float = blob_size * rng.randf_range(0.42, 0.82)
		s.radius = rad
		s.height = rad * 2.0
		s.radial_segments = 16
		s.rings = 8
		lob.mesh = s
		var ang: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.0, blob_size * 0.75)
		lob.position = Vector3(cos(ang) * dist, rad * rng.randf_range(0.55, 1.05), sin(ang) * dist)
		lob.scale = Vector3(rng.randf_range(0.9, 1.25), rng.randf_range(0.6, 0.95), rng.randf_range(0.9, 1.25))
		lob.rotation.y = rng.randf_range(0.0, TAU)
		lob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := _elixir_mat(palette[i % palette.size()].lightened(rng.randf_range(-0.05, 0.12)), rng.randf_range(0.80, 0.95))
		lob.material_override = m
		add_child(lob)
		blobs.append(lob)
		mats.append(m)
	for i in 2:
		var pud := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var pr: float = blob_size * rng.randf_range(0.8, 1.2)
		cm.top_radius = pr
		cm.bottom_radius = pr * 1.1
		cm.height = 0.02
		cm.radial_segments = 20
		pud.mesh = cm
		pud.position = Vector3(rng.randf_range(-0.15, 0.15), 0.03, rng.randf_range(-0.15, 0.15))
		pud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := _elixir_mat(palette[(i + 1) % palette.size()].darkened(0.15), 0.35)
		pud.material_override = pm
		add_child(pud)
		blobs.append(pud)
		mats.append(pm)
	for i in 3:
		var hi := MeshInstance3D.new()
		var hs := SphereMesh.new()
		var hr: float = blob_size * rng.randf_range(0.10, 0.18)
		hs.radius = hr
		hs.height = hr * 2.0
		hi.mesh = hs
		hi.position = Vector3(rng.randf_range(-0.35, 0.35) * blob_size, blob_size * rng.randf_range(0.7, 1.0), rng.randf_range(-0.35, 0.35) * blob_size)
		var hm := _elixir_mat(Color(0.95, 0.85, 1.0), 0.55)
		hm.emission_energy_multiplier = 0.4
		hi.material_override = hm
		add_child(hi)
		blobs.append(hi)
		mats.append(hm)
	var tw := create_tween().set_parallel(true)
	for b in blobs:
		var dir := Vector3(b.position.x, 0.0, b.position.z).normalized() * rng.randf_range(0.2, 0.7)
		tw.tween_property(b, "position", b.position + dir + Vector3(0.0, -b.position.y * 0.55, 0.0), rng.randf_range(0.35, 0.55))
		tw.tween_property(b, "scale", Vector3(1.35, 0.18, 1.35), rng.randf_range(0.40, 0.60))
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, rng.randf_range(0.35, 0.55))
	if visual_root:
		var tw2 := create_tween()
		tw2.tween_property(visual_root, "scale", visual_root.scale * 0.25, 0.20)
	await get_tree().create_timer(0.6).timeout
	queue_free()
func _animate_death(p: float) -> void:
	if visual_root:
		UnitVisualAnim.apply(visual_root, UnitVisualAnim.State.DIE, anim_time, p, 1.0)# ----- 辅助函数 -----
func apply_king_duo_visual() -> void:
	if not king_duo or visual_root == null or visual_root.has_meta("king_duo_applied"):
		return
	visual_root.set_meta("king_duo_applied", true)
	visual_root.scale *= Vector3(1.35, 1.35, 1.35)
	var extra := MeshInstance3D.new()
	extra.name = "DuoKing"
	var accent: Color = UnitModelKit.COL_TEAM_PLAYER if team == Config.Team.PLAYER else UnitModelKit.COL_TEAM_ENEMY
	extra.mesh = UnitModelKit.seated_king_mesh(accent)
	extra.position = Vector3(0.40, 1.59, 0.18)
	extra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(extra)

func distance_to(other: Unit) -> float:
	if not other: return 1e6
	return sqrt((other.global_position.x-global_position.x)**2+(other.global_position.z-global_position.z)**2) - (config.size + other.config.size)
	#return global_position.distance_to(other.global_position) - (config.size/3.0 + other.config.size/3.0)
func _apply_status_effects(now: float):
	if state == 2:
		shock_timer = now
		target = null
		accelerate = 1.0
		accumulate = 1.0
		if config.attack_type == 5:
			attack_cooldown = 0
		state = 0
	if state == 3:
		froze_timer = now
		slow_change = 1
		state = 0
	if state == 7:
		pois_timer = now
		state = 0
	if state == 6:
		fix_timer = now
		state = 0
	if state == 9:
		quick_timer = now
		state = 0
	if state == 10:
		slow_factor = 1000
		state = 0
		froze_timer = now +2000
	if (now - froze_timer) <= 2000  and slow_factor ==1:
		slow_factor =2.5
	elif (now - froze_timer) > 2000:
		#slow_change = 0
		slow_factor =1
	if now <= _slow15_until:
		slow_factor = maxf(slow_factor, 1.176)
	fix_factor = 20 if (now - fix_timer) <= 2000 else 1.0
	quick = 20 if (now - quick_timer) <= 2000 else 0
	if config.card_id == 90:
		hid = 1 if (now - hit_timer) >= 2000 else 0
		if visual_root:
			var ghost_a: float = 0.72 if hid == 1 else 0.0
			_set_ghost_alpha(visual_root, ghost_a)
func _degrade_health(now: float, delta):
	if last_lose_health_time == 0:
		last_lose_health_time = now
	if now - last_lose_health_time > 500:
		var mult: float = 1.0
		match config.card_id:
			109:
				mult = 3.0     # 钻机：10 秒
			114:
				mult = 1.5     # 牢笼：20 秒
			120:
				mult = 0.27    # 收集器：约 111 秒
		health -= max_health / 60.0 * mult
		last_lose_health_time = now
		if health <= 0:
			die()
func _spawn_children():
	spawn_cooldown = config.spawn_unit[2] / 1000.0
	var child_config = battle.get_config(config.spawn_unit[0])
	if not child_config:
		return
	var count = config.spawn_unit[1]   # 每次生成的数量
	if config.card_id == 51:
		_play_furnace_door()
	for i in range(count):
		var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		# 传入 1 作为覆盖数量，避免再读取 child_config.num
		var child: Unit = null
		if config.spawn_unit[2]<0:
			child = battle.spawn_unit(child_config, team, global_position + offset, 1,level,self)
		else:
			child = battle.spawn_unit(child_config, team, global_position + offset, 1,level)
		if config.card_id == 51 and child != null:
			child.play_furnace_emerge(global_position)
	if config.spawn_unit[2]<0:
		spawn_cooldown = 1000000
		return
	var hit_sfx = load("res://assets/audio/sfx/summon.wav")
	if hit_sfx:
		AudioManager.play_sfx(hit_sfx, global_position)
	if config.card_id == 102:
		die()
func _cast_spell(spell_data: Array):
	if spell_data.size() < 5: return
	var dmg = spell_data[0]
	var range = spell_data[1]
	var atk_type = spell_data[2]
	var tgt_type = spell_data[3]
	var spell = Spell.create(global_position, team, dmg, range, 1, atk_type, tgt_type)
	if battle:
		battle.spells.add_child(spell)# 碰撞分离 (不推建筑；死亡单位不再推挤；地面单位不会被推进河里)
func _separate_overlap():
	if config.type == Config.UnitType.BUILDING:
		return
	if health <= 0:
		return
	var overlapping = get_overlapping_areas()
	for area in overlapping:
		if area == self or not area is Unit:
			continue
		if follow:
			continue
		if area.config.type == Config.UnitType.BUILDING:
			continue
		if area.health <= 0:
			continue
		if area.config.type == config.type or (config.type - 3) * (area.config.type - 3) > 0:
			var dist_vec = global_position - area.global_position
			var effective_dist = dist_vec.length() - (config.size + area.config.size)
			if effective_dist < 0:
				# 体积越大越难被挤动（模型高度作为体型权重）
				var self_h: float = visual_root.scale.y if visual_root else 1.0
				var other_h: float = area.visual_root.scale.y if area.visual_root else 1.0
				var push_ratio: float = other_h / maxf(self_h + other_h, 0.01)
				var push = dist_vec.normalized() * (-effective_dist * push_ratio * 1.15)
				var old_pos: Vector3 = global_position
				global_position += Vector3(push.x, 0, push.z)
				# 地面单位不被推进河里（桥面除外）
				if config.type == Config.UnitType.GROUND and config.move_type < 3:
					if absf(global_position.z) < 1.0:
						var on_bridge: bool = absf(absf(global_position.x) - 5.5) <= 1.5
						if not on_bridge:
							global_position = old_pos
func _update_charge_fx(delta: float) -> void:
	var moved: float = Vector2(global_position.x - _last_move_pos.x, global_position.z - _last_move_pos.z).length()
	_last_move_pos = global_position
	var charging: bool = config.move_type == 2 and accelerate >= 1.5 and moved > 0.02 and not tunnel and config.type != Config.UnitType.BUILDING
	if charging and charge_fx == null and visual_root:
		charge_fx = Node3D.new()
		charge_fx.name = "ChargeFX"
		visual_root.add_child(charge_fx)
		for i in 3:
			var mi := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 0.03, 0.55)
			mi.mesh = b
			mi.position = Vector3(-0.18 + float(i) * 0.18, 0.30 + float(i) * 0.32, -0.80)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			charge_fx.add_child(mi)
	if charge_fx:
		charge_fx.visible = charging
		if charging:
			var t: float = Time.get_ticks_msec() * 0.001
			var idx := 0
			for ch in charge_fx.get_children():
				idx += 1
				ch.scale = Vector3(1.0 + 0.4 * sin(t * 18.0 + float(idx)), 1.0, 1.0 + 0.55 * sin(t * 22.0 + float(idx)))
			_charge_dust_t -= delta
			if _charge_dust_t <= 0.0:
				_charge_dust_t = 0.12
				_spawn_charge_dust()
func _spawn_charge_dust() -> void:
	var p := MeshInstance3D.new()
	var s := SphereMesh.new()
	var r: float = randf_range(0.06, 0.12)
	s.radius = r
	s.height = r * 2.0
	p.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.62, 0.55, 0.45, 0.70)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	var back := Vector2(0, -1)
	if move_direction.length() > 0.01:
		back = -move_direction
	p.position = Vector3(randf_range(-0.22, 0.22), 0.10, 0.0) - Vector3(back.x, 0.0, back.y) * 0.35
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position:y", 0.55, 0.5)
	tw.tween_property(p, "scale", Vector3(1.8, 1.8, 1.8), 0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(p.queue_free)# 皇家塔被摧毁：冲击波 + 碎石四散（参考 honor-king 的防御塔倒塌）
func _play_tower_destruction() -> void:
	var host: Node = battle if battle else get_parent()
	if host == null:
		return
	var stone := Color(0.62, 0.60, 0.55)
	var dark := Color(0.40, 0.39, 0.37)
	# 地面冲击波
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.15
	tor.rings = 30
	tor.ring_segments = 6
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.82, 0.78, 0.70, 0.75)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position = global_position + Vector3(0, 0.18, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(ring)
	var twr := ring.create_tween()
	twr.set_parallel(true)
	twr.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.6)
	twr.tween_property(rm, "albedo_color:a", 0.0, 0.6)
	twr.chain().tween_callback(ring.queue_free)
	# 碎石
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.16, 0.42), randf_range(0.14, 0.32), randf_range(0.16, 0.42))
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = stone if i % 2 == 0 else dark
		m.roughness = 1.0
		mi.material_override = m
		var start: Vector3 = global_position + Vector3(randf_range(-0.9, 0.9), randf_range(0.6, 2.8), randf_range(-0.9, 0.9))
		mi.position = start
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		host.add_child(mi)
		var out := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2)) * 2.0
		var peak: Vector3 = start + out + Vector3(0, randf_range(1.6, 3.0), 0)
		var land := Vector3(peak.x * 1.15, randf_range(0.12, 0.22), peak.z * 1.15)
		var tw := mi.create_tween()
		tw.tween_property(mi, "position", peak, randf_range(0.32, 0.48)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position", land, randf_range(0.6, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 1.2)
		tw.tween_interval(1.8)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
		tw.tween_callback(mi.queue_free)
	# 烟尘
	for i in 10:
		var d := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r: float = randf_range(0.25, 0.7)
		s.radius = r
		s.height = r * 2.0
		d.mesh = s
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.albedo_color = Color(0.55, 0.53, 0.50, 0.55)
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d.material_override = m2
		d.position = global_position + Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 2.0), randf_range(-1.0, 1.0))
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(d)
		var tw2 := d.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(d, "position", d.position + Vector3(randf_range(-0.6, 0.6), randf_range(0.8, 2.2), randf_range(-0.6, 0.6)), 1.6)
		tw2.tween_property(d, "scale", Vector3(2.2, 2.2, 2.2), 1.6)
		tw2.tween_property(m2, "albedo_color:a", 0.0, 1.6)
		tw2.chain().tween_callback(d.queue_free)
func _update_sparky(_delta: float) -> void:
	if config == null or config.card_id != 28:
		return
	var max_cd: float = maxf(config.attack_speed / 1000.0, 0.1)
	var charging: bool = attack_cooldown > 0.02 and target != null and is_instance_valid(target) and distance_to(target) <= config.attack_range + 0.6
	if not charging:
		if sparky_fx:
			sparky_fx.visible = false
		return
	var prog: float = clampf(1.0 - attack_cooldown / max_cd, 0.0, 1.0)
	if sparky_fx == null:
		sparky_fx = Node3D.new()
		sparky_fx.top_level = true
		add_child(sparky_fx)
		sparky_mat = StandardMaterial3D.new()
		sparky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sparky_mat.albedo_color = Color(0.60, 0.88, 1.0)
		sparky_mat.emission_enabled = true
		sparky_mat.emission = Color(0.55, 0.85, 1.0)
		sparky_mat.emission_energy_multiplier = 2.2
		sparky_orb = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.30
		s.height = 0.60
		s.radial_segments = 18
		s.rings = 9
		sparky_orb.mesh = s
		sparky_orb.material_override = sparky_mat
		sparky_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparky_fx.add_child(sparky_orb)
		var core := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.15
		cs.height = 0.30
		core.mesh = cs
		core.name = "Core"
		core.material_override = _beam_mat(Color(0.95, 0.99, 1.0), 3.2)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparky_fx.add_child(core)
		for i in 4:
			var arc := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.05, 0.30, 0.05)
			arc.mesh = bx
			arc.name = "Arc%d" % i
			arc.material_override = _beam_mat(Color(0.75, 0.92, 1.0), 2.6)
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sparky_fx.add_child(arc)
		for i in 3:
			var t := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.34
			tor.outer_radius = 0.46
			tor.rings = 18
			tor.ring_segments = 5
			t.mesh = tor
			t.material_override = _beam_mat(Color(0.55, 0.85, 1.0), 1.6)
			t.name = "Ring%d" % i
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sparky_fx.add_child(t)
	sparky_fx.visible = true
	# 蓄力位置：电磁炮炮口
	var muzzle: Vector3 = global_position + Vector3.UP * 1.5
	if visual_root:
		muzzle = visual_root.global_transform * Vector3(0.0, 0.80, 0.58)
	sparky_fx.global_position = muzzle
	var now: float = Time.get_ticks_msec() * 0.001
	var sc: float = 0.60 + prog * 1.70
	sparky_mat.emission_energy_multiplier = 1.6 + prog * 4.2
	var core_n := sparky_fx.get_node_or_null("Core") as Node3D
	if core_n:
		core_n.scale = Vector3.ONE * (0.8 + prog * 0.9)
	var idx := 0
	var arc_idx := 0
	for ch in sparky_fx.get_children():
		var nm := String(ch.name)
		if nm.begins_with("Ring"):
			idx += 1
			ch.rotation = Vector3(now * (2.0 + float(idx)), now * 1.6, 0)
			ch.scale = Vector3.ONE * (sc * (0.85 + 0.18 * float(idx)) * (1.0 + 0.12 * sin(now * 14.0 + float(idx))))
		elif nm.begins_with("Arc"):
			arc_idx += 1
			var aa: float = now * (7.0 + float(arc_idx)) + float(arc_idx) * 1.7
			ch.position = Vector3(cos(aa) * 0.34, 0.10 * sin(aa * 1.7), sin(aa) * 0.34)
			ch.rotation = Vector3(now * 5.0, aa, now * 3.0)
			ch.scale = Vector3(1.0, 1.0 + 0.4 * sin(now * 18.0 + float(arc_idx)), 1.0)# 突袭准备/突袭/渔夫钩绳的视觉效果
func _update_special_fx(_delta: float) -> void:
	if config == null or config.move_type < 5 or config.type == Config.UnitType.BUILDING:
		return
	var mt: int = config.move_type
	var jump_now: int = jump
	if jump_now > 0:
		if _special_fx == null:
			_special_color = Color(0.70, 0.40, 1.0)
			if mt == 5:
				_special_color = Color(1.0, 0.55, 0.15)
			elif mt == 7:
				_special_color = Color(0.55, 0.75, 0.45)
			_special_fx = Node3D.new()
			add_child(_special_fx)
			for i in 4:
				var orb := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.07
				s.height = 0.14
				orb.mesh = s
				orb.name = "Orb%d" % i
				orb.material_override = _beam_mat(_special_color, 2.2)
				orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_special_fx.add_child(orb)
			# 蓄力光环：地面扩散环 + 能量核心（幻影刺客/超级骑士等更明显）
			var aura_ring := MeshInstance3D.new()
			var art := TorusMesh.new()
			art.inner_radius = 0.52
			art.outer_radius = 0.72
			art.rings = 24
			art.ring_segments = 5
			aura_ring.mesh = art
			aura_ring.name = "AuraRing"
			aura_ring.material_override = _beam_mat(_special_color, 1.6)
			aura_ring.position = Vector3(0, 0.06, 0)
			aura_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_special_fx.add_child(aura_ring)
			var aura_core := MeshInstance3D.new()
			var acs := SphereMesh.new()
			acs.radius = 0.42
			acs.height = 0.84
			aura_core.mesh = acs
			aura_core.name = "AuraCore"
			aura_core.material_override = _beam_mat(_special_color.lightened(0.2), 2.0)
			aura_core.position = Vector3(0, 0.7, 0)
			aura_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_special_fx.add_child(aura_core)
		_special_fx.visible = true
		var t: float = Time.get_ticks_msec() * 0.001
		var idx := 0
		for ch in _special_fx.get_children():
			idx += 1
			var a: float = t * 6.0 + float(idx) * TAU / 4.0
			ch.position = Vector3(cos(a) * 0.42, 0.25 + 0.15 * sin(t * 5.0 + float(idx)), sin(a) * 0.42)
			ch.scale = Vector3.ONE * (0.8 + 0.4 * sin(t * 12.0 + float(idx)))
		if mt == 7 and target and is_instance_valid(target):
			_update_fisher_rope()
		var prog: float = clampf(float(Time.get_ticks_msec() - jump_timer) / maxf(800.0 * float(maxi(jump_now, 1)), 1.0), 0.0, 1.0)
		var ar := _special_fx.get_node_or_null("AuraRing") as Node3D
		if ar:
			ar.scale = Vector3.ONE * (0.7 + prog * 1.5)
		var ac := _special_fx.get_node_or_null("AuraCore") as Node3D
		if ac:
			ac.scale = Vector3.ONE * (0.6 + prog * 1.1)
		_jump_prev = jump_now
		return
	if _jump_prev > 0:
		_play_special_land()
	_jump_prev = jump_now
	if _special_fx:
		_special_fx.queue_free()
		_special_fx = null
	if _hook_rope and not _hook_retracting:
		_hook_retracting = true
		_hook_retract_t = 0.0
	if _hook_rope and _hook_retracting:
		_hook_retract_t += _delta
		_update_fisher_rope()
		if _hook_retract_t >= 0.18:
			_hook_rope.queue_free()
			_hook_rope = null
			_hook_retracting = false
func _update_fisher_rope() -> void:
	if target == null or not is_instance_valid(target):
		return
	if _hook_rope == null:
		_hook_start_ms = Time.get_ticks_msec()
		_hook_retracting = false
		_hook_retract_t = 0.0
		_hook_to = Vector3.ZERO
		_hook_rope = Node3D.new()
		_hook_rope.top_level = true
		add_child(_hook_rope)
		for i in range(9):
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.045
			cm.height = 1.0
			cm.radial_segments = 6
			seg.mesh = cm
			seg.name = "Rope%d" % i
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color(0.62, 0.50, 0.32)
			rm.roughness = 1.0
			seg.material_override = rm
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_hook_rope.add_child(seg)
		var hook_node := Node3D.new()
		hook_node.name = "Hook"
		_hook_rope.add_child(hook_node)
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.70, 0.72, 0.78)
		metal.metallic = 0.8
		metal.roughness = 0.35
		var shaft := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.035
		sc.bottom_radius = 0.035
		sc.height = 0.26
		sc.radial_segments = 8
		shaft.mesh = sc
		shaft.material_override = metal
		shaft.position = Vector3(0, -0.13, 0)
		hook_node.add_child(shaft)
		var curve := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.055
		tor.outer_radius = 0.10
		tor.rings = 14
		tor.ring_segments = 6
		curve.mesh = tor
		curve.material_override = metal
		curve.position = Vector3(0.02, -0.28, 0)
		curve.rotation = Vector3(0, 0, PI * 0.35)
		hook_node.add_child(curve)
		var tip := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.0
		tc.bottom_radius = 0.045
		tc.height = 0.14
		tc.radial_segments = 8
		tip.mesh = tc
		tip.material_override = metal
		tip.position = Vector3(0.09, -0.26, 0)
		tip.rotation = Vector3(0, 0, -PI * 0.55)
		hook_node.add_child(tip)
	var from: Vector3 = global_position + Vector3.UP * 1.1
	var extend_p: float = 1.0
	var now_ms: int = Time.get_ticks_msec()
	if _hook_retracting:
		extend_p = 1.0 - clampf(_hook_retract_t / 0.18, 0.0, 1.0)
	elif jump > 0 and target != null and is_instance_valid(target):
		_hook_to = target.global_position + Vector3.UP * 0.7
		extend_p = clampf(float(now_ms - _hook_start_ms) / 2400.0, 0.0, 1.0)
		extend_p = extend_p * extend_p * (3.0 - 2.0 * extend_p)
	if _hook_to == Vector3.ZERO:
		_hook_to = target.global_position + Vector3.UP * 0.7
	var to: Vector3 = from.lerp(_hook_to, extend_p)
	var l: float = (to - from).length()
	if l < 0.1:
		return
	var sag: float = minf(0.45, l * 0.16)
	var mid: Vector3 = (from + to) * 0.5 - Vector3.UP * sag
	var pts: Array = []
	for i in range(10):
		var t: float = float(i) / 9.0
		var a: Vector3 = from.lerp(mid, t)
		var b: Vector3 = mid.lerp(to, t)
		pts.append(a.lerp(b, t))
	for i in range(9):
		var seg := _hook_rope.get_node_or_null("Rope%d" % i) as MeshInstance3D
		if seg == null:
			continue
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var dv: Vector3 = p1 - p0
		var len_i: float = dv.length()
		if len_i < 0.001:
			continue
		seg.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dv.normalized())), (p0 + p1) * 0.5)
		seg.scale = Vector3(1.0, len_i, 1.0)
	var hook_n := _hook_rope.get_node_or_null("Hook") as Node3D
	if hook_n:
		hook_n.global_position = to + Vector3.UP * 0.02
		hook_n.global_rotation = Vector3(0, 0, 0)
func _play_special_land() -> void:
	var col: Color = _special_color
	for i in 10:
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r: float = randf_range(0.05, 0.12)
		s.radius = r
		s.height = r * 2.0
		p.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
		p.material_override = m
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		var a: float = randf_range(0.0, TAU)
		var sp: float = randf_range(1.5, 3.2)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", Vector3(cos(a) * sp, randf_range(0.2, 0.9), sin(a) * sp), 0.35)
		tw.tween_property(p, "scale", Vector3(0.2, 0.2, 0.2), 0.35)
		tw.chain().tween_callback(p.queue_free)
	if config.move_type == 5 and visual_root:
		visual_root.position.y = 1.3
		var tw2 := create_tween()
		tw2.tween_property(visual_root, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif config.move_type == 6:
		for i in 2:
			var ghost := MeshInstance3D.new()
			var s2 := SphereMesh.new()
			s2.radius = 0.35
			s2.height = 0.7
			ghost.mesh = s2
			ghost.position = Vector3((float(i) - 0.5) * 0.4, 0.6, 0)
			var m2 := StandardMaterial3D.new()
			m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m2.albedo_color = Color(col.r, col.g, col.b, 0.45)
			m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.material_override = m2
			ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ghost)
			var tw3 := ghost.create_tween()
			tw3.set_parallel(true)
			tw3.tween_property(ghost, "scale", Vector3(1.6, 1.6, 1.6), 0.4)
			tw3.tween_property(m2, "albedo_color:a", 0.0, 0.4)
			tw3.chain().tween_callback(ghost.queue_free)# 跨河跳跃动画（野猪骑士/王子/黑暗王子/皇家野猪/蛮羊骑士等）
func _update_river_jump(delta: float) -> void:
	if config.type != Config.UnitType.GROUND or visual_root == null:
		_prev_z = global_position.z
		return
	if _river_jumping:
		_river_jump_t += delta / 0.45
		var t: float = clampf(_river_jump_t, 0.0, 1.0)
		visual_root.position.y = sin(t * PI) * 1.2
		global_position = _river_jump_from.lerp(_river_jump_to, t)
		if t >= 1.0:
			_river_jumping = false
			visual_root.position.y = 0.0
		_prev_z = global_position.z
		return
	var z: float = global_position.z
	var hop_ids := [16, 17, 23, 38, 86]
	var on_bridge: bool = absf(absf(global_position.x) - 5.5) <= 1.5
	var in_band: bool = absf(z) < 1.2
	var want: bool = in_band and (config.card_id in hop_ids)
	if not want and in_band and not on_bridge and not (config.card_id in hop_ids):
		# 非跳跃单位不允许在河面上，推回最近岸边
		global_position.z = signf(z if absf(z) > 0.01 else 1.0) * 1.35
	elif want:
		var dir_sign: float = signf(move_direction.y)
		if absf(dir_sign) < 0.01:
			dir_sign = -signf(z) if absf(z) > 0.05 else -1.0
		_river_jumping = true
		_river_jump_t = 0.0
		_river_jump_from = global_position
		# 一次跳到对岸（落在河岸外，避免反复触发）
		_river_jump_to = Vector3(global_position.x, global_position.y, dir_sign * 1.35)
		for i in 5:
			var p := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = randf_range(0.05, 0.10)
			s.height = s.radius * 2.0
			p.mesh = s
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.75, 0.92, 1.0, 0.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.material_override = m
			p.position = Vector3(global_position.x + randf_range(-0.3, 0.3), 0.1, 0.0)
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(p)
			var tw := p.create_tween()
			tw.set_parallel(true)
			tw.tween_property(p, "position", p.position + Vector3(randf_range(-0.5, 0.5), randf_range(0.4, 0.9), randf_range(-0.5, 0.5)), 0.4)
			tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
			tw.chain().tween_callback(p.queue_free)
	_prev_z = global_position.z
func _play_death_explosion() -> void:
	var host: Node = battle if battle else get_parent()
	if host == null:
		return
	var rad: float = maxf(config.damage_range, 1.0)
	# 冲击球
	var flash := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = rad * 0.7
	fs.height = rad * 1.4
	flash.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.80, 0.40, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.65, 0.25)
	fm.emission_energy_multiplier = 2.0
	flash.material_override = fm
	flash.position = global_position + Vector3.UP * 0.5
	host.add_child(flash)
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(2.2, 2.2, 2.2), 0.35)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(flash.queue_free)
	# 碎石/火屑
	for i in 16:
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r: float = randf_range(0.08, 0.20)
		s.radius = r
		s.height = r * 2.0
		p.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.55, 0.50, 0.46) if i % 3 == 0 else Color(1.0, 0.60, 0.20)
		p.material_override = m
		p.position = global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.0), randf_range(-0.4, 0.4))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(p)
		var a: float = randf_range(0.0, TAU)
		var sp: float = randf_range(1.5, 4.0)
		var tw2 := p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "position", p.position + Vector3(cos(a) * sp, randf_range(0.5, 2.0), sin(a) * sp), 0.5)
		tw2.tween_property(p, "scale", Vector3(0.2, 0.2, 0.2), 0.5)
		tw2.chain().tween_callback(p.queue_free)# 雷电巨人反击闪电链
func _spawn_counter_bolt(src: Unit) -> void:
	if src == null or not is_instance_valid(src):
		return
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	root.global_position = global_position
	var from: Vector3 = global_position + Vector3.UP * 1.2
	var to: Vector3 = src.global_position + Vector3.UP * 0.8
	var d: Vector3 = to - from
	var l: float = d.length()
	if l < 0.1:
		root.queue_free()
		return
	var n := 8
	for i in n:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.06, 0.06, l / float(n) * 1.4)
		mi.mesh = bx
		var col: Color = Color(0.78, 0.92, 1.0) if i % 2 == 0 else Color(0.40, 0.60, 1.0)
		mi.material_override = _beam_mat(col, 2.2)
		var t: float = (float(i) + 0.5) / float(n)
		mi.position = from + d * t + Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
		root.add_child(mi)
		mi.look_at(to, Vector3.UP)
	var tw := root.create_tween()
	tw.tween_interval(0.28)
	tw.tween_callback(root.queue_free)# 特斯拉电磁塔：脱战 1 秒后遁入地下（不可被锁定、免疫法术，地震除外）
func _update_tesla(_delta: float) -> void:
	if config == null or config.card_id != 21:
		return
	var now_ms: int = Time.get_ticks_msec()
	var near: bool = target != null and is_instance_valid(target) and distance_to(target) <= config.attack_range + 0.3
	if tesla_buried:
		if near:
			tesla_buried = false
			if visual_root:
				var tw := create_tween()
				tw.tween_property(visual_root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if contact_shadow:
				contact_shadow.visible = true
	elif (now_ms - _tesla_last_attack) > 1000.0 and not near:
		tesla_buried = true
		if visual_root:
			var tw2 := create_tween()
			tw2.tween_property(visual_root, "position:y", -1.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if contact_shadow:
			contact_shadow.visible = false# 闪电法师/皇家速递等登场伤害：从天而降的打击视觉
func _play_sky_strike_vfx() -> void:
	var col: Color = Color(0.55, 0.85, 1.0)
	if config.card_id == 53:
		col = Color(1.0, 0.82, 0.35)
	elif config.card_id == 60:
		col = Color(0.55, 0.88, 1.0)
	elif config.card_id == 18:
		col = Color(0.60, 0.95, 1.0)
	elif config.card_id == 83:
		col = Color(1.0, 0.60, 0.25)
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	root.global_position = global_position
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.34
	cm.height = 6.0
	cm.radial_segments = 12
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(col.r, col.g, col.b, 0.85)
	bm.emission_enabled = true
	bm.emission = col
	bm.emission_energy_multiplier = 3.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, 3.2, 0)
	root.add_child(beam)
	var flash := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.6
	fs.height = 1.2
	flash.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1, 1, 1, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = fm
	flash.position = Vector3(0, 0.2, 0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.75
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(col.r, col.g, col.b, 0.8)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position = Vector3(0, 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	for i in 8:
		var st := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.05, float(randi_range(8, 16)) * 0.1, 0.05)
		st.mesh = sb
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = col.lerp(Color.WHITE, 0.5)
		st.material_override = sm
		st.position = Vector3(randf_range(-0.5, 0.5), 3.0 + randf_range(0, 2.0), randf_range(-0.5, 0.5))
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(st)
		var tws := st.create_tween()
		tws.tween_property(st, "position:y", 0.1, 0.22)
		tws.tween_callback(st.queue_free)
	# 角色专属：冰锥 / 闪电 / 速递箱 / 震地裂纹
	if config.card_id == 18:
		for i in range(8):
			var shard := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.16, 0.42, 0.16)
			shard.mesh = pm
			var sm2 := StandardMaterial3D.new()
			sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm2.albedo_color = Color(0.72, 0.92, 1.0, 0.9)
			sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shard.material_override = sm2
			var ang: float = randf_range(0.0, TAU)
			shard.position = Vector3(cos(ang) * randf_range(0.4, 1.0), randf_range(3.0, 5.0), sin(ang) * randf_range(0.4, 1.0))
			root.add_child(shard)
			var tws2 := shard.create_tween()
			tws2.tween_property(shard, "position:y", 0.1, 0.28)
			tws2.tween_callback(shard.queue_free)
	elif config.card_id == 6:
		for i in range(10):
			var seg := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.06, randf_range(0.5, 1.1), 0.06)
			seg.mesh = bx
			var sm3 := StandardMaterial3D.new()
			sm3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm3.albedo_color = Color(0.82, 0.95, 1.0)
			seg.material_override = sm3
			seg.position = Vector3(randf_range(-1.0, 1.0), randf_range(1.2, 4.6), randf_range(-1.0, 1.0))
			seg.rotation = Vector3(randf_range(-0.6, 0.6), randf_range(0, TAU), randf_range(-0.6, 0.6))
			root.add_child(seg)
			var twseg := seg.create_tween()
			twseg.tween_interval(0.05 * float(i))
			twseg.tween_property(seg, "scale", Vector3(0.1, 0.1, 0.1), 0.12)
	elif config.card_id == 53:
		var crate := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.7, 0.5, 0.7)
		crate.mesh = cb
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.62, 0.42, 0.22)
		crate.material_override = cmat
		crate.position = Vector3(0, 4.2, 0)
		root.add_child(crate)
		var twc := crate.create_tween()
		twc.tween_property(crate, "position:y", 0.35, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		twc.tween_callback(crate.queue_free)
		for i in range(4):
			var band := MeshInstance3D.new()
			var tor2 := TorusMesh.new()
			tor2.inner_radius = 0.26
			tor2.outer_radius = 0.33
			band.mesh = tor2
			var bm2 := StandardMaterial3D.new()
			bm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm2.albedo_color = Color(1.0, 0.82, 0.35)
			band.material_override = bm2
			band.position = Vector3(0, 4.2 - float(i) * 0.7, 0)
			band.rotation.x = PI * 0.5
			root.add_child(band)
			var twb := band.create_tween()
			twb.tween_property(band, "position:y", 0.2, 0.24 + float(i) * 0.03)
			twb.tween_callback(band.queue_free)
	elif config.card_id == 83:
		for i in range(6):
			var crack := MeshInstance3D.new()
			var cb2 := BoxMesh.new()
			cb2.size = Vector3(0.07, 0.02, randf_range(0.6, 1.3))
			crack.mesh = cb2
			var cm2 := StandardMaterial3D.new()
			cm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cm2.albedo_color = Color(0.35, 0.20, 0.12)
			crack.material_override = cm2
			var a2: float = randf_range(0.0, TAU)
			crack.position = Vector3(cos(a2) * randf_range(0.3, 0.9), 0.05, sin(a2) * randf_range(0.3, 0.9))
			crack.rotation.y = a2
			root.add_child(crack)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(beam, "position:y", 3.2, 0.01)
	tw.tween_property(ring, "scale", Vector3(2.6, 1.0, 2.6), 0.35)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.15)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(root.queue_free)# 瓦基丽武神：持斧原地快速旋转一圈，碰到即伤害
func _do_valkyrie_spin() -> void:
	if visual_root == null or battle == null:
		return
	_spin_remaining = 0.42
	var tw := create_tween()
	tw.tween_property(visual_root, "rotation:y", visual_root.rotation.y + TAU * 3.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.16).timeout
	if not is_inside_tree():
		return
	var dmg: float = config.damage * Config.level_mult(level)
	var radius: float = 1.9
	for u in battle.units.get_children():
		if not (u is Unit) or u == self:
			continue
		if u.team == team or u.health <= 0:
			continue
		if u.config.type == Config.UnitType.AIR:
			continue
		if distance_to(u) <= radius + u.config.size:
			u.take_damage(dmg, self)
			var spark := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			spark.mesh = sm
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.albedo_color = Color(1.0, 0.85, 0.4)
			spark.material_override = mm
			spark.position = u.global_position + Vector3.UP * 0.7
			spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			battle.add_child(spark)
			var t2 := spark.create_tween()
			t2.tween_property(spark, "scale", Vector3.ZERO, 0.2)
			t2.tween_callback(spark.queue_free)# 烈焰熔炉开门动画
func _play_furnace_door() -> void:
	var dir := Vector3(0, 0, -1) if team == Config.Team.PLAYER else Vector3(0, 0, 1)
	var pivot := Node3D.new()
	pivot.position = global_position + dir * 0.55 + Vector3(-0.32, 0.55, 0)
	add_child(pivot)
	var door := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.78, 0.07)
	door.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.34, 0.22, 0.16)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.45, 0.10)
	dm.emission_energy_multiplier = 0.6
	door.material_override = dm
	door.position = Vector3(0.31, 0, 0)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(door)
	pivot.rotation.y = -PI * 0.5 if team == Config.Team.PLAYER else PI * 0.5
	var tw := create_tween()
	tw.tween_property(pivot, "rotation:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(pivot, "rotation:y", -PI * 0.6 if team == Config.Team.PLAYER else PI * 0.6, 0.25)
	tw.tween_callback(pivot.queue_free)
	# 炉口火焰
	for i in 6:
		var f := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = randf_range(0.10, 0.20)
		s.height = s.radius * 2.0
		f.mesh = s
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0, randf_range(0.35, 0.65), 0.12, 0.9)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		f.material_override = fm
		f.position = global_position + dir * 0.65 + Vector3(randf_range(-0.25, 0.25), 0.25, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		var ftw := f.create_tween()
		ftw.set_parallel(true)
		ftw.tween_property(f, "position:y", f.position.y + randf_range(0.6, 1.2), 0.45)
		ftw.tween_property(fm, "albedo_color:a", 0.0, 0.45)
		ftw.chain().tween_callback(f.queue_free)# 从熔炉门里跳出（覆盖普攻落动画）
func play_furnace_emerge(from_pos: Vector3) -> void:
	if _spawn_tween:
		_spawn_tween.kill()
		_spawn_tween = null
	if visual_root == null:
		return
	var dir := Vector3(0, 0, -1) if team == Config.Team.PLAYER else Vector3(0, 0, 1)
	global_position = from_pos + dir * 0.4
	var start: Vector3 = global_position
	visual_root.position.y = -0.9
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual_root, "position:y", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", start + dir * 0.9, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)# 烟花炮手：攻击后向后滑步 1 格（约 1m），可见滑动过程
func _firecracker_recoil() -> void:
	if visual_root == null:
		return
	var away := global_position - (target.global_position if target != null and is_instance_valid(target) else global_position - Vector3.FORWARD)
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	var to: Vector3 = global_position + away * 1.0
	to.x = clampf(to.x, Config.ARENA_ORIGIN.x + 0.6, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH - 0.6)
	to.z = clampf(to.z, Config.ARENA_ORIGIN.z + 0.6, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 0.6)
	# 不滑进河里（桥面除外）
	var on_bridge: bool = absf(absf(to.x) - 5.5) <= 1.5
	if absf(to.z) < 1.2 and not on_bridge:
		to.z = signf(to.z if absf(to.z) > 0.01 else away.z) * 1.2
	_recoil_remaining = 0.24
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	visual_root.rotation.x = -0.14
	var tw2 := create_tween()
	tw2.tween_property(visual_root, "rotation:x", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)# 被法术击退（大雪球/火球）：方向由法术中心指向目标，距离与目标大小成反比
func knockback(from_pos: Vector3, distance: float) -> void:
	if config.type == Config.UnitType.BUILDING:
		return
	var dir := global_position - from_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var to: Vector3 = global_position + dir * distance
	to.x = clampf(to.x, Config.ARENA_ORIGIN.x + 0.6, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH - 0.6)
	to.z = clampf(to.z, Config.ARENA_ORIGIN.z + 0.6, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 0.6)
	if config.type == Config.UnitType.GROUND:
		var on_bridge: bool = absf(absf(to.x) - 5.5) <= 1.5
		if absf(to.z) < 1.2 and not on_bridge:
			to.z = signf(to.z if absf(to.z) > 0.01 else dir.z) * 1.25
	_knock_remaining = 0.22
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if visual_root:
		var tw2 := create_tween()
		tw2.tween_property(visual_root, "position:y", 0.35, 0.09)
		tw2.tween_property(visual_root, "position:y", 0.0, 0.12)# 死亡后留下带倒计时时钟的炸弹
func _spawn_death_bomb(delay: float, spell_data: Array) -> void:
	if battle == null or spell_data.size() < 5:
		return
	var bomb = preload("res://scripts/entities/DeathBomb.gd").new()
	var lv: int = level
	var dmg: int = int(spell_data[0] * Config.level_mult(lv))
	bomb.setup(delay, dmg, spell_data[1], spell_data[2], spell_data[3], team, config.card_id)
	bomb.position = global_position
	battle.add_child(bomb)
func _needs_bridge_crossing(t: Unit) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if config.card_id in [16, 17, 23, 38, 86, 98]:
		return false
	var mid_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	return (global_position.z - mid_z) * (t.global_position.z - mid_z) < 0.0

func _set_ghost_alpha(node: Node, a: float) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).transparency = a
	for ch in node.get_children():
		_set_ghost_alpha(ch, a)
func _on_tunnel_emerge() -> void:
	if battle == null:
		return
	for u in battle.units.get_children():
		if not (u is Unit) or u.team == team or u.health <= 0:
			continue
		if u.global_position.distance_to(global_position) > 2.0:
			continue
		var dmg: float = 21.0 if u.config.card_id <= 3 else 84.0 * Config.level_mult(level)
		u.take_damage(dmg, null)
	# 钻机破土特效
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.7
	tor.outer_radius = 0.95
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.72, 0.30)
	ring.material_override = rm
	ring.position = global_position + Vector3(0, 0.15, 0)
	ring.rotation.x = PI * 0.5
	battle.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.35)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
func _build_lightning_points(first: Unit, max_targets: int) -> Array:
	var pts: Array = []
	pts.append(_bullet_spawn_pos())
	if first == null or not is_instance_valid(first):
		return pts
	pts.append(first.global_position + Vector3.UP * 0.55)
	var used: Array = [first]
	var prev: Unit = first
	for i in range(clampi(max_targets, 1, 8) - 1):
		var best: Unit = null
		var best_d: float = 3.8
		for u in battle.units.get_children():
			if not (u is Unit) or u == self or u.team == team or u.health <= 0 or u in used:
				continue
			if u.hid or (u.has_method("is_tesla_buried") and u.is_tesla_buried()):
				continue
			var d: float = prev.global_position.distance_to(u.global_position)
			if d < best_d:
				best_d = d
				best = u
		if best == null:
			break
		pts.append(best.global_position + Vector3.UP * 0.55)
		used.append(best)
		prev = best
	return pts

func _ensure_chain_fx() -> void:
	if _chain_fx != null:
		return
	_chain_fx = Node3D.new()
	_chain_fx.top_level = true
	_chain_fx.visible = false
	add_child(_chain_fx)
	var mat := _beam_mat(Color(0.72, 0.90, 1.0), 2.6)
	for i in 10:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.07, 1.0, 0.07)
		mi.mesh = bx
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chain_fx.add_child(mi)
		_chain_segs.append(mi)
	for i in 10:
		var tp := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.14
		sp.height = 0.28
		tp.mesh = sp
		tp.material_override = _beam_mat(Color(0.88, 0.96, 1.0), 3.0)
		tp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chain_fx.add_child(tp)
		_chain_tips.append(tp)

func _show_lightning_chain(points: Array) -> void:
	_ensure_chain_fx()
	_chain_points = points
	_chain_until = Time.get_ticks_msec() + float(400 + 90 * maxi(0, points.size() - 2))
	_update_chain_fx()

func _update_chain_fx() -> void:
	if _chain_fx == null:
		return
	var now_ms: float = Time.get_ticks_msec()
	if now_ms > _chain_until or _chain_points.size() < 2:
		for s in _chain_segs:
			s.visible = false
		for t in _chain_tips:
			t.visible = false
		_chain_fx.visible = false
		return
	_chain_fx.visible = true
	var now: float = now_ms * 0.001
	for i in range(_chain_segs.size()):
		var seg: MeshInstance3D = _chain_segs[i]
		if i < _chain_points.size() - 1:
			var p0: Vector3 = _chain_points[i]
			var p1: Vector3 = _chain_points[i + 1]
			var d: Vector3 = p1 - p0
			var ln: float = d.length()
			if ln < 0.05:
				seg.visible = false
				continue
			var dir: Vector3 = d / ln
			var right: Vector3 = dir.cross(Vector3.UP)
			if right.length() < 0.1:
				right = dir.cross(Vector3.RIGHT)
			right = right.normalized()
			var jitter: float = sin(now * 34.0 + float(i) * 2.3) * 0.06
			var mid: Vector3 = (p0 + p1) * 0.5 + right * jitter
			seg.visible = true
			seg.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), mid)
			seg.scale = Vector3(1.0, ln, 1.0)
		else:
			seg.visible = false
	for j in range(_chain_tips.size()):
		var tip: MeshInstance3D = _chain_tips[j]
		if j < _chain_points.size():
			tip.visible = true
			tip.global_position = _chain_points[j]
			tip.scale = Vector3.ONE * (0.8 + 0.25 * sin(now * 28.0 + float(j)))
		else:
			tip.visible = false

func _update_rune_marker(delta: float) -> void:
	var active: bool = _rune_owner != null and is_instance_valid(_rune_owner) and _rune_owner.health > 0
	if _rune_marker == null:
		if not active:
			return
		_rune_marker = Node3D.new()
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.46
		tor.outer_radius = 0.58
		tor.rings = 20
		tor.ring_segments = 8
		mi.mesh = tor
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.78, 0.28)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.62, 0.18)
		m.emission_energy_multiplier = 2.2
		mi.material_override = m
		mi.rotation.x = PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rune_marker.add_child(mi)
		_rune_marker.position = Vector3(0, 0.08, 0)
		add_child(_rune_marker)
	_rune_marker.visible = active
	if active:
		_rune_marker.rotation.y += delta * 2.4
		var pulse: float = 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
		_rune_marker.scale = Vector3(pulse, 1.0, pulse)
func is_entangled() -> bool:
	return Time.get_ticks_msec() < _entangled_until
func _spawn_muzzle_flash(pos: Vector3, w: String) -> void:
	if battle == null:
		return
	if not (w in ["bow", "musket", "staff", "cannon", "crossbow", "mortar", "flask", "spear"]):
		return
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.075
	sp.height = 0.15
	mi.mesh = sp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col: Color = Color(1.0, 0.82, 0.35)
	if w == "staff":
		col = Color(0.72, 0.60, 1.0)
	elif w == "bow" or w == "crossbow":
		col = Color(0.90, 0.96, 1.0)
	mi.material_override = m
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	battle.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.10)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.10)
	tw.chain().tween_callback(mi.queue_free)