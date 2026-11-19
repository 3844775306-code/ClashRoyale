# scripts/entities/Spell.gd


class_name Spell
extends Node3D
const SpellVFX := preload("res://scripts/visuals/SpellVFX.gd")
var team: int
var damage: float
var damage_range: float
var whether_from_unit: int
var attack_type: int
var target_type: int
var time =0
var color =0
var active: bool = true
var animation_frame: int = 0
var max_duration: int = 20  # 帧数（每帧20ms）
var last_update: float = 0.0
var size: float = 0.0
var elapsed_time: float = 0.0
var last_effect =0
var card_id: int = -1
var vfx: Node3D
var _vines_targets: Array = []
# 雷电法术专用
var is_lightning: bool = false
var lightning_targets: Array = []
var damaged = 0
static func create(pos: Vector3, team: int, dmg: float, range: float, from_unit: int, atk_type: int, tgt_type: int) -> Spell:
	var spell = Spell.new()
	spell.position = pos
	spell.team = team
	spell.damage = dmg
	spell.damage_range = range
	spell.whether_from_unit = from_unit
	spell.attack_type = atk_type
	spell.target_type = tgt_type
	spell.size = range
	spell.is_lightning = (dmg == 1057)  # 简单识别
	return spell

func _ready():
	if time!=0:
		max_duration = 0.05*time
	add_to_group("spells")
	# 程序化法术特效（按卡牌区分）
	vfx = SpellVFX.build(card_id, damage_range, team, attack_type)
	add_child(vfx)
	# 点光源颜色随法术变化；手机端关闭，避免大量动态光源压垮 GLES 驱动
	if not OS.has_feature("mobile"):
		var light = OmniLight3D.new()
		light.light_color = _light_color()
		light.omni_range = damage_range * 1.4
		light.light_energy = 1.6
		add_child(light)

func _light_color() -> Color:
	match card_id:
		11:
			return Color(1.0, 0.50, 0.15)
		10:
			return Color(0.85, 0.90, 1.0)
		20, 48:
			return Color(0.60, 0.85, 1.0)
		31:
			return Color(0.70, 0.92, 1.0)
		40:
			return Color(1.0, 0.75, 0.35)
		_:
			match attack_type:
				8:
					return Color(0.45, 0.95, 0.50)
				9:
					return Color(0.75, 0.40, 1.0)
			return Color(0.55, 0.80, 1.0) if team == Config.Team.PLAYER else Color(1.0, 0.45, 0.35)

func _process(delta):
	if not active:
		return
	elapsed_time += delta
	animation_frame = int(elapsed_time * 50)  # 假设50帧/秒
	
	if animation_frame >= max_duration:
		active = false
		queue_free()
		return
	
	# 视觉效果进度始终跟随法术总时长（长时法术也会持续整个持续时间并在结束前淡出）
	var progress = animation_frame / float(max_duration)
	SpellVFX.animate(vfx, progress, elapsed_time)
	var l := get_child(1) as OmniLight3D
	if l:
		l.light_energy = 1.6 * (1.0 - progress)
	
	# 伤害检测：在过程的第一帧施加伤害（避免每帧伤害）
	if time ==0:
		if damaged == 0:
			damaged = 1
			apply_damage()
	else:
		if elapsed_time-last_effect>0.5:
			last_effect = elapsed_time
			apply_damage()
func apply_damage():
	#print(1)
	var battle = get_tree().get_first_node_in_group("battle_manager")
	if not battle:
		return
	if card_id in [107, 112, 113, 115, 116]:
		_apply_special_spell(battle)
		return
	if damage ==0:
		var hit_sfx = load("res://assets/audio/sfx/summon.wav")
		if hit_sfx:
			AudioManager.play_sfx(hit_sfx, global_position)
		var offset = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		# 传入 1 作为覆盖数量，避免再读取 child_config.num
		var child_config = battle.get_config(5)
		
			
		if team ==Config.Team.PLAYER:
			battle.spawn_unit(child_config, team, global_position + offset, 1,PlayerData.get_card_level(85))
		else:
			battle.spawn_unit(child_config, team, global_position + offset, 1,PlayerData.ai_level(85))
	for unit in battle.units.get_children():
		# 遁地的特斯拉免疫法术（地震法术除外）
		if unit.has_method("is_tesla_buried") and unit.is_tesla_buried() and card_id != 115:
			continue
		if unit.team == team and attack_type != 8 and attack_type != 9:  # 非治疗法术不对友方生效
			continue
		if unit.team != team and attack_type == 8 :
			continue  # 治疗法术仅治疗友方
		var dist = sqrt((unit.global_position.x-global_position.x)**2+(unit.global_position.z-global_position.z)**2) - ( unit.config.size)
		# 边缘接触即命中（目标半径已扣除，再留 0.2m 容差）
		if dist <= damage_range + 0.05:
			# 目标类型筛选
			var can_hit = false
			match target_type:
				3:  # all
					can_hit = true
				2:  # ground only
					if unit.config.type != Config.UnitType.AIR:
						can_hit = true
				1:  # building only
					if unit.config.type == Config.UnitType.BUILDING:
						can_hit = true
			if can_hit:
				if attack_type == 8:
					# 治疗
					var heal_amount = damage
					if unit.config.card_id <= 3 :
						heal_amount = 0
					unit.heal(heal_amount)
				elif attack_type == 9:
					if unit.team ==team:
						unit.state = 9
					else:
						if animation_frame !=0:
							return
						var dmg = damage
						if unit.config.card_id <= 3 and whether_from_unit != 1:
							dmg /= 4.0
						unit.take_damage(dmg, null)
				else:
					var dmg = damage
					if unit.config.card_id <= 3 and whether_from_unit != 1:
						dmg /= 4.0
					if unit.config.card_id <= 3 and card_id > 0:
						battle.add_tower_damage(team, card_id, dmg)
					unit.take_damage(dmg, null)
					if attack_type >1:
						unit.state = attack_type
					if card_id == 104 and unit.health > 0:
						unit.knockback(global_position, -0.55)
					if card_id in [11, 31] and unit.config.type != Config.UnitType.BUILDING and unit.health > 0:
						var kb_dist: float = clampf(1.15 / maxf(unit.config.size, 0.25), 0.35, 1.6) * 0.45
						unit.knockback(global_position, kb_dist)
					

func _apply_special_spell(battle) -> void:
	var now_ms: int = Time.get_ticks_msec()
	match card_id:
		107:
			for u in battle.units.get_children():
				if not (u is Unit) or u.team == team or u.health <= 0:
					continue
				if u.global_position.distance_to(global_position) > damage_range + 0.1:
					continue
				var d107: float = damage * (0.25 if u.config.card_id <= 3 else 1.0)
				if u.config.card_id <= 3:
					battle.add_tower_damage(team, card_id, d107)
				u.take_damage(d107, null)
				u._slow15_until = now_ms + 2100
		112:
			if _vines_targets.is_empty():
				var cands: Array = []
				for u in battle.units.get_children():
					if not (u is Unit) or u.team == team or u.health <= 0:
						continue
					if u.global_position.distance_to(global_position) <= damage_range + 0.1:
						cands.append(u)
				cands.sort_custom(func(a, b): return a.health > b.health)
				_vines_targets = cands.slice(0, 3)
			for u in _vines_targets:
				if not is_instance_valid(u) or u.health <= 0:
					continue
				var d112: float = damage * (0.25 if u.config.card_id <= 3 else 1.0)
				if u.config.card_id <= 3:
					battle.add_tower_damage(team, card_id, d112)
				u.take_damage(d112, null)
				u.state = 2
				u.slow_factor = 1000
				u.froze_timer = now_ms + 800
				u.jump = 0
				u.accelerate = 1.0
				if u.config.type == Config.UnitType.AIR:
					u._entangled_until = now_ms + 1200
					u.global_position.y = 0.2
		113:
			var cnt: int = 0
			for u in battle.units.get_children():
				if u is Unit and u.team != team and u.health > 0 and u.global_position.distance_to(global_position) <= damage_range + 0.1:
					cnt += 1
			var mul: float = 1.0 if cnt <= 1 else (0.45 if cnt <= 4 else 0.22)
			for u in battle.units.get_children():
				if u is Unit and u.team != team and u.health > 0 and u.global_position.distance_to(global_position) <= damage_range + 0.1:
					var d113: float = damage * mul * (0.25 if u.config.card_id <= 3 else 1.0)
					if u.config.card_id <= 3:
						battle.add_tower_damage(team, card_id, d113)
					u.take_damage(d113, null)
					if card_id == 113:
						_spawn_void_pillar(u.global_position)
		115:
			for u in battle.units.get_children():
				if not (u is Unit) or u.team == team or u.health <= 0:
					continue
				if u.get("tesla_buried") == true and card_id != 115:
					continue
				if u.global_position.distance_to(global_position) > damage_range + 0.1:
					continue
				var dmg115: float = damage
				if u.config.card_id <= 3:
					dmg115 = damage * 0.5
					battle.add_tower_damage(team, card_id, dmg115)
				elif u.config.type == Config.UnitType.BUILDING:
					dmg115 = damage * 3.5
				u.take_damage(dmg115, null)
				u.state = 3
		116:
			for u in battle.units.get_children():
				if not (u is Unit) or u.team == team or u.health <= 0:
					continue
				if u.global_position.distance_to(global_position) > damage_range + 0.1:
					continue
				u._curse_team = team
				u._curse_until = float(now_ms + 800)
				u.state = 7
				var d116: float = damage * (0.25 if u.config.card_id <= 3 else 1.0)
				if u.config.card_id <= 3:
					battle.add_tower_damage(team, card_id, d116)
				u.take_damage(d116, null)
func _spawn_void_pillar(pos: Vector3) -> void:
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.34
	cyl.height = 8.0
	cyl.radial_segments = 12
	pillar.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.04, 0.07, 0.85)
	m.emission_enabled = true
	m.emission = Color(0.62, 0.05, 0.09)
	m.emission_energy_multiplier = 2.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material_override = m
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.position = pos + Vector3(0, 4.0, 0)
	var bt = get_tree().get_first_node_in_group("battle_manager")
	if bt:
		bt.add_child(pillar)
		var tw := pillar.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pillar, "scale", Vector3(1.6, 1.0, 1.6), 0.45)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
		tw.chain().tween_callback(pillar.queue_free)
	else:
		pillar.queue_free()