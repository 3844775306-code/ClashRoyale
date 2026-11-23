# scripts/ai/AISystem.gd
class_name AISystem
extends Node

const EMOTES = preload("res://scripts/data/EmoteCatalog.gd")

signal decision_made(state: Dictionary, action: Dictionary)

enum Difficulty { EASY, NORMAL, HARD }
var difficulty: int = Difficulty.NORMAL   # 默认普通

var battle: BattleManager
var ai_think_cd: float = 2.5
var ai_timer: float = 0.0

var ai_deck: Array = []
var ai_hand: Array = []
var ai_cardlevel:Array = []
# 战场分析缓存
var threat_ground_tank: bool = false
var threat_ground_swarm: bool = false
var threat_tank: bool = false
var threat_swarm: bool = false
var threat_air: bool = false
var threat_backline: bool = false       # 是否有后排输出（法师、弓箭手）
var threat_level: int = 0
var emote_cd: float = 8.0
var lane_threat: Array = [0.0, 0.0]
var defense_lane: int = 0
var target_lane: int = 0
var player_elixir_est: float = 7.0
var _seen_player_units: Dictionary = {}
var archetype: String = "control"
var win_condition_id: int = 0
var counterpush_active: bool = false
var committed_lane: int = -1
var collect_mode: bool = false
var team: int = Config.Team.ENEMY
var _demo_cases: Array = []
var _demo_loaded := false
var _demo_lane := -1
var _chip_target_hp := 0.0
var _chip_target_idx := -1
var _chip_target_lane := -1
var _foe_played_at: Dictionary = {}
var _foe_role_at: Dictionary = {}
var _foe_seen_spells: Dictionary = {}

func _foe_team() -> int:
	return Config.Team.PLAYER if team == Config.Team.ENEMY else Config.Team.ENEMY

func _my_elixir() -> float:
	return battle.enemy_elixir if team == Config.Team.ENEMY else battle.player_elixir

func _set_my_elixir(v: float) -> void:
	if team == Config.Team.ENEMY:
		battle.enemy_elixir = v
	else:
		battle.player_elixir = v

func _own_z(frac: float) -> float:
	if team == Config.Team.ENEMY:
		return Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * frac
	return Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (1.0 - frac)

func _foe_tower_idx(lane: int) -> int:
	return lane if team == Config.Team.ENEMY else 3 + lane

func _is_past_bridge(z: float) -> bool:
	var mid: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	return z > mid + 2.0 if team == Config.Team.PLAYER else z < mid - 2.0

func _is_far_on_foe_side(z: float) -> bool:
	var mid: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	return z < mid - 6.0 if team == Config.Team.PLAYER else z > mid + 6.0

func _near_foe_towers(z: float) -> bool:
	var mid: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	return z > mid + 4.0 if team == Config.Team.PLAYER else z < mid - 4.0

# 留牌记录：保留特定关键卡
var reserved_spell: String = ""         # "fireball", "arrows", "zap"
var reserved_tank_killer: String = ""   # "minipekka", "inferno"

func _ready():
	battle = get_parent() as BattleManager
	difficulty = GameSettings.difficulty
	_load_demo_cases()
	_init_ai_deck()

func _load_demo_cases() -> void:
	if _demo_loaded:
		return
	_demo_loaded = true
	var f := FileAccess.open("res://data/ai/card_demo_cases.jsonl", FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary and d.get("successful_team", -1) >= 0:
			_demo_cases.append(d)
	print("[AI] 卡牌演示案例: ", _demo_cases.size())


func _demo_match(card_id: int) -> Dictionary:
	if _demo_cases.is_empty() or battle == null:
		return {}
	var enemy_ids := {}
	for u in battle.units.get_children():
		if u is Unit and u.team == _foe_team() and u.health > 0 and u.config != null:
			enemy_ids[int(u.config.card_id)] = true
	if enemy_ids.is_empty():
		return {}
	var best := {}
	var best_score := 0.0
	for c in _demo_cases:
		if not (c is Dictionary):
			continue
		var friends: Array = c.get("friendly_cards", [])
		if not friends.has(card_id):
			continue
		var enemies: Array = c.get("enemy_cards", [])
		var overlap := 0
		for eid in enemies:
			if enemy_ids.has(int(eid)):
				overlap += 1
		if overlap <= 0:
			continue
		var score := float(overlap) / maxf(1.0, float(enemy_ids.size())) + float(friends.size()) * 0.03
		if score > best_score:
			best_score = score
			best = c
	if best.is_empty():
		return {}
	var success_team := int(best.get("successful_team", -1))
	var lane := -1
	for ev in best.get("friendly_events", []):
		if int(ev.get("card_id", -1)) == card_id:
			var ex := float(ev.get("x", 0.0))
			if success_team != team:
				ex = -ex
			lane = 0 if ex < 0.0 else 1
			break
	return {"bonus": best_score, "lane": lane}


func _init_ai_deck():
	ai_deck.clear()
	# 模式指定卡组（经典卡组模式）
	if battle != null and not battle.mode_enemy_deck.is_empty():
		ai_deck = battle.mode_enemy_deck.duplicate()
		for i in range(4):
			_draw_ai_card()
		win_condition_id = _find_win_condition()
		archetype = _classify_archetype(win_condition_id)
		return
	var pool: Array = []
	var allowed: Array = PlayerData.get_ai_allowed_cards()
	for cfg in battle.configs:
		if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123 and allowed.has(cfg.card_id):
			pool.append(cfg.card_id)
	pool.shuffle()
	var count := {}
	for card_id in pool:
		if count.get(card_id, 0) < 1:
			ai_deck.append(card_id)
			count[card_id] = 1
		if ai_deck.size() >= 8:
			break
	# 卡组主题约束：保证有制胜卡、法术、对空
	_enforce_deck_roles(pool)
	win_condition_id = _find_win_condition()
	archetype = _classify_archetype(win_condition_id)
	for i in range(4):
		_draw_ai_card()

func _enforce_deck_roles(pool: Array):
	var need_win := _find_win_condition() == 0
	var has_spell := false
	var has_air := false
	for cid in ai_deck:
		var cfg = battle.get_config(cid)
		if cfg == null: continue
		if battle.SPELL_IDS.has(cid): has_spell = true
		if cfg.target_type == Config.TargetType.ALL and cfg.damage > 0 and (cfg.type == Config.UnitType.AIR or cfg.attack_range > 1.5):
			has_air = true
	# 替换末尾卡，避免破坏前几张核心
	var replace_idx := ai_deck.size() - 1
	if need_win:
		for cid in pool:
			if cid in ai_deck: continue
			var cfg = battle.get_config(cid)
			if _is_win_condition(cfg):
				ai_deck[replace_idx] = cid
				replace_idx -= 1
				break
	if not has_spell and replace_idx >= 0:
		for cid in pool:
			if cid in ai_deck: continue
			if battle.SPELL_IDS.has(cid):
				ai_deck[replace_idx] = cid
				replace_idx -= 1
				break
	if not has_air and replace_idx >= 0:
		for cid in pool:
			if cid in ai_deck: continue
			var cfg = battle.get_config(cid)
			if cfg and cfg.target_type == Config.TargetType.ALL and cfg.damage > 0:
				ai_deck[replace_idx] = cid
				break

func _is_win_condition(cfg: CardData) -> bool:
	if cfg == null: return false
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		return true
	if cfg.cost >= 6 and cfg.max_health >= 1800:
		return true
	return cfg.card_name in ["巨人", "皇家巨人", "野猪骑士", "戈仑石人", "熔岩猎犬", "气球兵", "骷髅巨人", "超级骑士", "加农炮战车"]

func _find_win_condition() -> int:
	for cid in ai_deck:
		var cfg = battle.get_config(cid)
		if _is_win_condition(cfg):
			return cid
	return 0

func _has_win_condition_in_hand() -> bool:
	for cid in ai_hand:
		var cfg = battle.get_config(cid)
		if _is_win_condition(cfg):
			return true
	return false

func _classify_archetype(wcid: int) -> String:
	if wcid == 0:
		return "control"
	var cfg = battle.get_config(wcid)
	if cfg == null:
		return "control"
	if cfg.type == Config.UnitType.AIR:
		return "air"
	if cfg.cost <= 4:
		return "cycle"
	if cfg.cost >= 6:
		return "beatdown"
	return "control"

func _update_player_elixir(delta: float):
	player_elixir_est = minf(10.0, player_elixir_est + delta * battle.elixir_rate)
	for u in battle.units.get_children():
		if not (u is Unit) or u.team != _foe_team():
			continue
		if _seen_player_units.has(u.get_instance_id()):
			continue
		_seen_player_units[u.get_instance_id()] = true
		if u.config and u.config.card_id > 3:
			player_elixir_est = maxf(0.0, player_elixir_est - float(u.config.cost))
			_record_foe_card(u.config)
	for s in battle.spells.get_children():
		if not (s is Spell) or s.team != _foe_team() or s.card_id <= 3:
			continue
		var sid := s.get_instance_id()
		if _foe_seen_spells.has(sid):
			continue
		_foe_seen_spells[sid] = true
		var scfg = battle.get_config(int(s.card_id))
		if scfg != null:
			player_elixir_est = maxf(0.0, player_elixir_est - float(scfg.cost))
			_record_foe_card(scfg)

func _record_foe_card(cfg) -> void:
	if cfg == null:
		return
	var now := Time.get_ticks_msec()
	_foe_played_at[int(cfg.card_id)] = now
	for role in _card_roles(cfg):
		_foe_role_at[role] = now


func _card_roles(cfg) -> Array:
	var roles: Array = []
	if cfg.damage_range >= 1.5 or int(cfg.card_id) in [10, 20, 31, 48, 80, 104, 107, 113, 115, 116]:
		roles.append("aoe")
	if int(cfg.num) >= 3 or cfg.card_name in ["骷髅军团", "亡灵大军", "哥布林团伙", "蝙蝠", "野蛮人", "绿林团伙"]:
		roles.append("swarm")
	if (cfg.damage >= 250.0 and cfg.attack_speed <= 1600) or cfg.card_name in ["迷你皮卡", "皮卡超人", "地狱飞龙", "地狱之塔", "王子", "幻影刺客"]:
		roles.append("high_dps")
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		roles.append("siege")
	if int(cfg.move_type) >= 2 and cfg.type != Config.UnitType.BUILDING and int(cfg.move_type) != 5:
		roles.append("charge")
	if cfg.type == Config.UnitType.BUILDING:
		roles.append("building")
	return roles


func _foe_role_recent(role: String, within_ms: int = 6500) -> bool:
	if not _foe_role_at.has(role):
		return false
	return Time.get_ticks_msec() - int(_foe_role_at[role]) <= within_ms


func _foe_has_role(role: String) -> bool:
	# 不知道对手卡组时保守处理；近期已经交过的防守类型视为暂时没有
	if player_elixir_est < 3.0:
		return false
	return not _foe_role_recent(role)


func _draw_ai_card():
	if ai_deck.is_empty(): return
	var card_id = ai_deck.pop_front()
	ai_hand.append(card_id)

func _process(delta):
	if battle.game_over: return
	_update_player_elixir(delta)
	if _urgent_defense() or _my_elixir() >= 9.0:
		ai_timer = minf(ai_timer, 0.15)
	ai_timer -= delta
	emote_cd -= delta
	if emote_cd <= 0:
		emote_cd = randf_range(10.0, 18.0)
		if randf() < 0.35:
			_send_ai_emote()
	if ai_timer <= 0:
		var td_scale := 0.72 if (battle != null and String(battle.win_condition) == "touchdown") else 1.0
		ai_timer = randf_range(1.0, 1.8) * td_scale if difficulty != Difficulty.EASY else randf_range(2.0, 3.2) * td_scale
		if difficulty == Difficulty.HARD:
			ai_timer = randf_range(0.7, 1.2) * td_scale
		_ai_act()

func _ai_act():
	_demo_lane = -1
	_chip_target_idx = -1
	_chip_target_lane = -1
	_analyze_battlefield()
	var elixir = _my_elixir()
	var usable = _get_usable_cards(elixir)

	if usable.is_empty(): return

	var chosen: CardData = null
	var play_style = "normal"
	var defending: bool = threat_level >= 2
	counterpush_active = (not defending) and _has_counterpush()
	if difficulty != Difficulty.EASY and not collect_mode:
		# 防守时保留基本圣水；进攻时按卡组体系等待关键费用
		if defending and elixir < 4.0:
			return
		if not defending:
			if archetype == "beatdown" and elixir < 7.0 and _has_win_condition_in_hand() \
					and not (battle != null and String(battle.win_condition) == "touchdown"):
				return
			if archetype == "cycle" and elixir < 4.0:
				return
			if difficulty == Difficulty.HARD and player_elixir_est >= 6.0 and elixir < 6.0:
				return

	# 困难难度：保留费用应对突发
	if difficulty == Difficulty.HARD and not collect_mode and threat_level >= 2 and elixir < 5.0:
		return   # 等圣水，不立即出牌

	# 紧急情况处理：高威胁时优先使用预留的关键卡
	if threat_level >= 3:
		chosen = _handle_emergency(usable)
		if chosen:
			play_style = "emergency"
	if not chosen and defending:
		chosen = _select_min_cost_defense(usable)
		if chosen:
			play_style = "defensive"
	if not chosen and _should_chip():
		chosen = _select_chip_card(usable)
		if chosen:
			play_style = "chip"
	if not chosen and _should_pressure():
		chosen = _select_pressure_card(usable)
		if chosen:
			play_style = "pressure"
	if not chosen:
		chosen = _select_card(usable)
		if chosen and defending:
			play_style = "defensive"
		elif chosen and counterpush_active:
			play_style = "counterpush"
		else:
			play_style = "offensive"

	if not chosen: return
	# 法术价值不足且无紧急威胁时不浪费
	if battle.SPELL_IDS.has(chosen.card_id) and difficulty != Difficulty.EASY:
		if threat_level < 3 and _spell_value(chosen) < float(chosen.cost) * 0.8 and _spell_tower_target(chosen) == Vector3.ZERO:
			return
		if play_style == "chip" and _spell_tower_target(chosen) == Vector3.ZERO and _chip_target_idx < 0:
			return

	# 放置位置
	var pos = _get_best_place(chosen, play_style)
	if pos == Vector3.ZERO: return
	if not battle.is_valid_placement(chosen, pos, team):
		pos = _find_valid_place(chosen, pos)
		if pos == Vector3.ZERO:
			return
	# 建筑：避免和己方已有建筑重叠，自动错开
	if chosen.type == Config.UnitType.BUILDING:
		var best: Vector3 = Vector3.ZERO
		var offsets: Array = [Vector3(0,0,0), Vector3(1.2,0,0), Vector3(-1.2,0,0), Vector3(0,0,1.2), Vector3(0,0,-1.2), Vector3(1.2,0,1.2), Vector3(-1.2,0,-1.2), Vector3(1.2,0,-1.2), Vector3(-1.2,0,1.2)]
		for off in offsets:
			var cand: Vector3 = pos + off
			if not battle.is_valid_placement(chosen, cand, team):
				continue
			var blocked: bool = false
			for u in battle.units.get_children():
				if u is Unit and u.team == team and u.config.type == Config.UnitType.BUILDING and u.health > 0:
					if u.global_position.distance_to(cand) < 2.2:
						blocked = true
						break
			if not blocked:
				best = cand
				break
		if best == Vector3.ZERO:
			return
		pos = best

	# 部署
	var action_pos: Vector3 = pos
	if battle.SPELL_IDS.has(chosen.card_id):
		action_pos = _find_spell_target(chosen)
	if decision_made.get_connections().size() > 0:
		decision_made.emit(_snapshot_state(), {
			"card_id": chosen.card_id,
			"x": action_pos.x,
			"z": action_pos.z,
			"style": play_style
		})
	if battle.SPELL_IDS.has(chosen.card_id):
		battle.deploy_spell(chosen, team, action_pos)
	else:
		if chosen.card_id == 109:
			battle._deploy_miner_tunnel(chosen, team, pos)
		elif chosen.card_id == 110:
			battle._deploy_log_like(chosen, team, pos)
		else:
			battle.spawn_unit(chosen, team, pos)

	_set_my_elixir(max(0.0, _my_elixir() - chosen.cost))
	battle.stats_elixir_spent[team] += chosen.cost
	ai_hand.erase(chosen.card_id)
	ai_deck.append(chosen.card_id)
	_draw_ai_card()

	# 困难难度：记录留牌
	if difficulty == Difficulty.HARD:
		_update_reserved_cards()

func _find_valid_place(cfg: CardData, origin: Vector3) -> Vector3:
	var offsets: Array = [
		Vector3.ZERO, Vector3(1.5,0,0), Vector3(-1.5,0,0), Vector3(0,0,1.5),
		Vector3(0,0,-1.5), Vector3(3,0,0), Vector3(-3,0,0), Vector3(0,0,3), Vector3(0,0,-3),
	]
	for off in offsets:
		var p: Vector3 = origin + off
		if battle.is_valid_placement(cfg, p, team):
			return p
	return Vector3.ZERO

# ============ 分析函数 ============
func _analyze_battlefield():
	threat_ground_tank = false
	threat_ground_swarm = false
	threat_tank = false
	threat_swarm = false
	threat_air = false
	threat_backline = false
	threat_level = 0
	lane_threat = [0.0, 0.0]

	var mid_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var player_tanks := 0
	var player_air := 0
	var player_backline := 0
	var player_swarm := 0
	var tower_pressure := 0
	var candidates: Array = []
	for unit in battle.units.get_children():
		if not (unit is Unit) or unit.team != _foe_team():
			continue
		if unit.health <= 0 or unit.config == null or unit.config.card_id <= 3:
			continue
		# 只把已经过桥/接近桥的部队当成即时威胁
		# 已过桥并接近敌方塔的部队优先级更高
		var past_bridge: bool = _is_past_bridge(unit.global_position.z)
		if not past_bridge and _is_far_on_foe_side(unit.global_position.z) and unit.config.attack_range < 5.0:
			continue
		candidates.append(unit)
		if _near_foe_towers(unit.global_position.z):
			tower_pressure += 1
		var mid_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
		var lane_i: int = 0 if unit.global_position.x < mid_x else 1
		lane_threat[lane_i] += 1.0 + unit.config.cost * 0.5 + unit.health / maxf(1.0, unit.max_health)
		if unit.config.type == Config.UnitType.AIR:
			threat_air = true
			player_air += 1
		elif unit.config.max_health >= 1800 or unit.config.cost >= 5:
			threat_ground_tank = true
			threat_tank = true
			player_tanks += 1
		if unit.config.attack_range > 4.0 or unit.config.card_id in [62, 63, 64, 65]:
			threat_backline = true
			player_backline += 1
		# 真实群体：附近至少 3 个玩家单位，而不是把 config.num 重复相加
		var near := 0
		for o in candidates:
			if o.global_position.distance_to(unit.global_position) <= 2.5:
				near += 1
		if near >= 3 or unit.config.num >= 3:
			threat_ground_swarm = true
			threat_swarm = true
			player_swarm = maxi(player_swarm, near)
	var total_threat := player_tanks * 3 + player_air * 2 + player_backline * 2 + player_swarm + tower_pressure * 2
	if total_threat >= 6:
		threat_level = 4
	elif total_threat >= 3:
		threat_level = 3
	elif total_threat >= 1:
		threat_level = 2
	else:
		threat_level = 1
	defense_lane = 0 if lane_threat[0] >= lane_threat[1] else 1
	# 进攻优先攻击血量更低的公主塔
	var left_idx: int = _foe_tower_idx(0)
	var right_idx: int = _foe_tower_idx(1)
	var lh: float = battle.healths[left_idx] if battle.healths.size() > right_idx else 1.0
	var rh: float = battle.healths[right_idx] if battle.healths.size() > right_idx else 1.0
	target_lane = 0 if lh <= rh else 1
	_update_lane_commitment()
	if battle != null and String(battle.win_condition) == "touchdown":
		var own_lanes := [0, 0]
		for u in battle.units.get_children():
			if u is Unit and u.team == team and u.health > 0 and u.config.card_id > 3:
				var lx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
				own_lanes[0 if u.global_position.x < lx else 1] += 1
		target_lane = 0 if int(own_lanes[0]) <= int(own_lanes[1]) else 1
		if threat_level >= 2:
			target_lane = defense_lane
		committed_lane = target_lane

func _urgent_defense() -> bool:
	var n := 0
	for u in battle.units.get_children():
		if not (u is Unit) or u.team != _foe_team() or u.health <= 0 or u.config.card_id <= 3:
			continue
		if _is_past_bridge(u.global_position.z):
			n += 1
			if u.config.max_health >= 1800 or u.config.cost >= 5:
				return true
	return n >= 2

func _update_lane_commitment():
	var h0: float = battle.healths[_foe_tower_idx(0)]
	var h1: float = battle.healths[_foe_tower_idx(1)]
	if committed_lane < 0:
		committed_lane = 0 if h0 <= h1 else 1
	if h0 <= 0.0 and h1 > 0.0:
		committed_lane = 1
	elif h1 <= 0.0 and h0 > 0.0:
		committed_lane = 0
	else:
		var other: int = 1 - committed_lane
		var cur_h: float = h0 if committed_lane == 0 else h1
		var other_h: float = h0 if other == 0 else h1
		if other_h > 0.0 and other_h < cur_h * 0.45:
			committed_lane = other
	target_lane = committed_lane

func _spell_tower_target(spell_cfg: CardData) -> Vector3:
	if spell_cfg == null or spell_cfg.damage <= 0.0:
		return Vector3.ZERO
	var lane: int = target_lane
	var idx: int = _foe_tower_idx(lane)
	if idx >= battle.healths.size():
		return Vector3.ZERO
	var hp: float = battle.healths[idx]
	if hp <= 0.0:
		return Vector3.ZERO
	var lv: int = PlayerData.ai_level(spell_cfg.card_id) if team == Config.Team.ENEMY else PlayerData.get_card_level(spell_cfg.card_id)
	if battle != null:
		lv = battle.mode_level(lv)
	var dmg: float = spell_cfg.damage * Config.level_mult(lv)
	if hp <= dmg * 1.15:
		var x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * (3.5 / 18.0 if lane == 0 else 14.5 / 18.0)
		var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (25.5 / 32.0 if team == Config.Team.ENEMY else 6.5 / 32.0)
		return Vector3(x, 0.0, z)
	return Vector3.ZERO

func _get_usable_cards(elixir: float) -> Array:
	var cards = []
	for card_id in ai_hand:
		var cfg = battle.get_config(card_id)
		if cfg and cfg.cost <= elixir:
			# 困难难度：检查是否应该保留某些关键卡
			if difficulty == Difficulty.HARD and _is_reserved(cfg.card_id) and _my_elixir() < 9.0:
				continue   # 暂时不出；圣水溢出时优先用掉
			cards.append(cfg)
	return cards

func _is_reserved(card_id: int) -> bool:
	# 如果保留的卡牌是当前需要的，则不能随意使用
	if reserved_spell != "" and _get_card_label(card_id) == reserved_spell:
		return true
	if reserved_tank_killer != "" and _get_card_label(card_id) == reserved_tank_killer:
		return true
	return false

func _get_card_label(card_id: int) -> String:
	var cfg = battle.get_config(card_id)
	if not cfg: return ""
	# 根据卡牌名称或ID映射类型
	if cfg.card_name == "火球": return "fireball"
	if cfg.card_name == "万箭齐发": return "arrows"
	if cfg.card_name == "电击法术": return "zap"
	if cfg.card_name == "迷你皮卡": return "minipekka"
	if cfg.card_name == "地狱飞龙" or cfg.card_name == "地狱之塔": return "inferno"
	return ""

# ============ 选择逻辑 ============
func _handle_emergency(usable: Array) -> CardData:
	# 紧急情况直接使用预留的最有效卡牌（无视保留）
	if threat_swarm:
		for c in usable:
			if c.damage_range > 2.0 or c.card_name in ["万箭齐发", "火球", "电击法术"]:
				return c
	if threat_air:
		for c in usable:
			if c.target_type == Config.TargetType.ALL:
				return c
	if threat_tank:
		for c in usable:
			if c.damage > 300 or c.card_name in ["迷你皮卡", "地狱飞龙"]:
				return c
	return null

func _should_pressure() -> bool:
	if threat_level >= 2 or collect_mode:
		return false
	var elixir := _my_elixir()
	if elixir < 5.5:
		return false
	var window := float(player_elixir_est) <= 4.0 or elixir >= 8.0 or counterpush_active
	return window


func _pressure_category(cfg) -> String:
	if cfg == null:
		return ""
	if int(cfg.num) >= 3:
		return "swarm"
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		return "siege"
	if int(cfg.move_type) >= 2 and cfg.type != Config.UnitType.BUILDING:
		return "charge"
	if cfg.damage >= 220.0 or cfg.card_name in ["迷你皮卡", "皮卡超人", "王子", "幻影刺客", "火枪手", "飞行机器"]:
		return "high_dps"
	return ""


func _select_pressure_card(usable: Array) -> CardData:
	var best: CardData = null
	var best_score := -1.0
	var elixir := _my_elixir()
	var tank_ready: bool = count_own_tanks() > 0 or counterpush_active
	for c in usable:
		if c == null or battle.SPELL_IDS.has(c.card_id):
			continue
		if _is_support_only(c) and not tank_ready:
			continue
		var cat := _pressure_category(c)
		if cat == "":
			continue
		var score := 10.0
		match cat:
			"swarm":
				# 人海怕范围伤害
				if _foe_has_role("aoe"):
					score -= 80.0
				else:
					score += 18.0
			"high_dps":
				# 高 DPS 怕人海围杀
				if _foe_has_role("swarm"):
					score -= 65.0
				else:
					score += 16.0
			"siege":
				# 攻城单位怕高 DPS/坦克杀手
				if _foe_has_role("high_dps"):
					score -= 55.0
				else:
					score += 14.0
			"charge":
				# 冲锋单位怕人海和建筑拉扯
				if _foe_has_role("swarm"):
					score -= 45.0
				elif _foe_has_role("building"):
					score -= 20.0
				else:
					score += 12.0
		# 未知防守卡：不直接否决，但降低信心
		if not _foe_role_recent("aoe") and not _foe_role_recent("swarm"):
			score -= 3.0
		score += float(c.cost) * 0.8
		if elixir - float(c.cost) < 2.0:
			score -= 20.0
		if score > best_score:
			best_score = score
			best = c
	return best


func _weakest_foe_tower() -> Dictionary:
	var best := {"idx": -1, "hp": 1.0e12, "lane": 0}
	for lane in [0, 1]:
		var idx := _foe_tower_idx(lane)
		if idx < battle.healths.size():
			var hp := float(battle.healths[idx])
			if hp > 0.0 and hp < float(best.hp):
				best = {"idx": idx, "hp": hp, "lane": lane}
	return best


func _should_chip() -> bool:
	if threat_level >= 2 or collect_mode:
		return false
	var elixir := _my_elixir()
	var tower := _weakest_foe_tower()
	_chip_target_idx = int(tower.idx)
	_chip_target_lane = int(tower.lane)
	_chip_target_hp = float(tower.hp)
	if _chip_target_idx < 0:
		return false
	var window := float(player_elixir_est) <= 3.5 or elixir >= 7.0 or _has_counterpush()
	var low_tower := _chip_target_hp <= 1200.0
	if not window and not low_tower:
		return false
	if archetype == "cycle":
		return elixir >= 4.5
	return elixir >= 5.0 or low_tower


func _chip_damage(cfg: CardData) -> float:
	var lv: int = PlayerData.ai_level(cfg.card_id) if team == Config.Team.ENEMY else PlayerData.get_card_level(cfg.card_id)
	if battle != null:
		lv = battle.mode_level(lv)
	return float(cfg.damage) * Config.level_mult(lv)


func _chip_tower_pos() -> Vector3:
	if _chip_target_lane < 0:
		return Vector3.ZERO
	var x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * (3.5 / 18.0 if _chip_target_lane == 0 else 14.5 / 18.0)
	var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (25.5 / 32.0 if team == Config.Team.ENEMY else 6.5 / 32.0)
	return Vector3(x, 0.0, z)


func _select_chip_card(usable: Array) -> CardData:
	var best: CardData = null
	var best_score := -1.0
	var elixir := _my_elixir()
	var tower := _weakest_foe_tower()
	for c in usable:
		if c == null:
			continue
		var score := 0.0
		var is_spell := battle.SPELL_IDS.has(c.card_id)
		if is_spell:
			# 法术只用于磨塔或残血塔处决，不为了空放而空放
			var target := _spell_tower_target(c)
			if target == Vector3.ZERO and _chip_target_idx >= 0:
				target = _chip_tower_pos()
			if target == Vector3.ZERO:
				continue
			var dmg := _chip_damage(c)
			score = dmg / maxf(1.0, float(c.cost))
			if float(tower.hp) <= dmg * 1.10:
				score += 100.0
			if float(tower.hp) <= 700.0:
				score += 25.0
		else:
			# 消耗核心：低费建筑目标卡、矿工/飞桶/野猪等
			var building_target: bool = c.target_type == Config.TargetType.BUILDING_ONLY
			var wincon: bool = _is_win_condition(c)
			if not building_target and not wincon:
				continue
			score = 8.0 + float(c.cost) * 0.5
			if building_target:
				score += 5.0
			if float(cost_elixir_after(c)) >= 3.0:
				score += 3.0
			if float(tower.hp) <= 900.0:
				score += 6.0
		# 必须保留至少 2 点防守圣水；能直接斩杀时允许 all-in
		var kill := float(tower.hp) <= _chip_damage(c) * 1.1
		if not kill and elixir - float(c.cost) < 2.0:
			continue
		if c.cost > 6:
			score -= 8.0
		if score > best_score:
			best_score = score
			best = c
	return best


func cost_elixir_after(c: CardData) -> float:
	return _my_elixir() - float(c.cost)


func _select_min_cost_defense(usable: Array) -> CardData:
	var best: CardData = null
	var best_score: float = -INF
	for c in usable:
		if c == null:
			continue
		var fit: float = 0.0
		if threat_swarm:
			if c.damage_range >= 1.5 or c.card_name in ["万箭齐发", "火球", "电击法术", "毒药法术"]:
				fit += 4.0
		if threat_air:
			if c.target_type == Config.TargetType.ALL or c.damage_range >= 2.0:
				fit += 3.5
		if threat_tank:
			if c.damage >= 300.0 or c.card_name in ["迷你皮卡", "地狱飞龙", "地狱之塔", "皮卡超人"]:
				fit += 4.0
			if c.type == Config.UnitType.BUILDING and c.max_health >= 1500.0:
				fit += 2.0
		if threat_backline:
			if c.attack_range >= 5.0 and c.damage >= 100.0:
				fit += 3.0
			if c.damage_range >= 2.0 and c.damage >= 100.0:
				fit += 2.0
		if fit <= 0.0:
			fit = 0.5 if c.cost <= 3 else 1.0
		# 高血量单体不值得用法术硬砸；除非能击杀/高效清群
		if battle.SPELL_IDS.has(c.card_id) and not _spell_is_efficient(c) and _spell_tower_target(c) == Vector3.ZERO:
			continue
		# 同等克制效果下优先低费；避免为了小威胁交出高费卡
		var score: float = fit / maxf(1.0, float(c.cost))
		score += 0.6 if c.cost <= 3 else 0.0
		score -= 0.5 if c.cost >= 5 else 0.0
		var demo := _demo_match(c.card_id)
		if not demo.is_empty():
			score += float(demo.get("bonus", 0.0)) * 1.4
		if score > best_score:
			best_score = score
			best = c
			if not demo.is_empty() and int(demo.get("lane", -1)) >= 0:
				_demo_lane = int(demo.get("lane", -1))
	return best


func _is_support_only(cfg) -> bool:
	if cfg == null or cfg.type == Config.UnitType.BUILDING:
		return false
	if _is_win_condition(cfg) or cfg.target_type == Config.TargetType.BUILDING_ONLY:
		return false
	if int(cfg.num) >= 3 and float(cfg.max_health) <= 550.0:
		return true
	if float(cfg.max_health) <= 450.0 and int(cfg.cost) <= 3:
		return true
	return cfg.card_name in ["亡灵", "哥布林", "蝙蝠", "骷髅军团", "哥布林团伙", "弓箭手", "吹箭哥布林", "烟花炮手"]


func _select_card(usable: Array) -> CardData:
	match difficulty:
		Difficulty.EASY:
			return usable[randi() % usable.size()]
		_:   # NORMAL / HARD
			# 圣水接近溢出时优先打高费卡，避免空转/浪费
			if _my_elixir() >= 9.0 or (threat_level < 2 and _my_elixir() >= 8.0):
				var heavy: Array = []
				for c in usable:
					if c.cost >= 5:
						heavy.append(c)
				if heavy.size() > 0:
					return _pick_best(heavy)
			# 组合拳：有坦克时，优先出后排；无坦克但费高时，可以出坦克
			var own_tanks = count_own_tanks()
			var has_tank = own_tanks > 0
			var can_afford_combo = _my_elixir() >= 8.0

			# 如果有坦克在前面，优先选择后排远程单位
			if has_tank:
				var backlines = _filter_backline(usable)
				if backlines.size() > 0:
					return _pick_best(backlines)
			# 有存活反打单位时，优先补后排支援而不是再堆前排
			if counterpush_active:
				var support = _filter_backline(usable)
				if support.size() > 0:
					return _pick_best(support)
				for c in usable:
					if _is_win_condition(c):
						return c

			# 如果没有坦克且圣水充足，出一个坦克
			if not has_tank and can_afford_combo:
				var tanks = _filter_tank(usable)
				if tanks.size() > 0:
					return _pick_best(tanks)

			# 根据威胁选择克制卡
			if threat_swarm:
				var anti = _filter_aoe(usable)
				if anti.size() > 0: return _pick_best(anti)
			if threat_air:
				var anti = _filter_anti_air(usable)
				if anti.size() > 0: return _pick_best(anti)
			if threat_tank:
				var anti = _filter_tank_killer(usable)
				if anti.size() > 0: return _pick_best(anti)

			# 没有坦克/反打单位时，低血量辅助卡不能单独桥头送
			var filtered: Array = []
			var allow_support: bool = has_tank or counterpush_active or count_own_tanks() > 0
			for c in usable:
				if _is_support_only(c) and not allow_support:
					continue
				filtered.append(c)
			if filtered.is_empty():
				return null
			return _pick_best(filtered)

func count_own_tanks() -> int:
	var cnt = 0
	for unit in battle.units.get_children():
		if unit.team == team and unit.config.card_id > 3 and unit.config.type != Config.UnitType.BUILDING and unit.config.max_health >= 2000:
			cnt += 1
	return cnt

func _filter_backline(cards: Array) -> Array:
	var res = []
	for c in cards:
		if c.attack_range > 4.0 and c.type != Config.UnitType.BUILDING:
			res.append(c)
	return res

func _filter_tank(cards: Array) -> Array:
	var res = []
	for c in cards:
		if c.max_health >= 2000 or c.cost >= 5:
			res.append(c)
	return res

func _filter_aoe(cards: Array) -> Array:
	var res = []
	for c in cards:
		if c.damage_range > 1.0:
			res.append(c)
	return res

func _filter_anti_air(cards: Array) -> Array:
	var res = []
	for c in cards:
		if c.target_type == Config.TargetType.ALL:
			res.append(c)
	return res

func _filter_tank_killer(cards: Array) -> Array:
	var res = []
	for c in cards:
		if c.damage > 300:
			res.append(c)
	return res

func _card_score(c: CardData) -> float:
	var s: float = 0.0
	if threat_ground_swarm:
		if c.damage_range > 1.0:
			s += 34.0
		if c.card_name in ["万箭齐发", "火球", "电击法术"]:
			s += 18.0
	if threat_air:
		if c.target_type == Config.TargetType.ALL:
			s += 28.0
		if c.type == Config.UnitType.AIR:
			s += 10.0
	if threat_tank:
		if c.damage >= 250 or c.card_name in ["迷你皮卡", "地狱飞龙", "地狱之塔", "皮卡超人"]:
			s += 30.0
		# 单体高 DPS 更克制坦克
		s += minf(20.0, c.damage / maxf(1.0, float(c.attack_speed) * 0.001) * 0.5)
	if threat_backline and c.damage_range > 1.0:
		s += 8.0
	s += c.damage * 0.01 + c.max_health * 0.002
	s -= c.cost * 2.0
	if c.cost <= 3:
		s += 4.0
	if archetype == "cycle" and c.cost <= 3:
		s += 6.0
	if archetype == "beatdown" and _is_win_condition(c):
		s += 8.0
	return s

func _pick_best(cards: Array) -> CardData:
	cards.sort_custom(func(a,b): return _card_score(a) > _card_score(b))
	return cards[0]

# ============ 放置位置 ============
func _get_best_place(cfg: CardData, style: String) -> Vector3:
	if battle != null and String(battle.win_condition) == "touchdown":
		var use_lane_td: int = defense_lane if (style == "defensive" or style == "emergency") else target_lane
		return _touchdown_place(cfg, style, use_lane_td)
	var mid_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH / 2.0
	var tower_left_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0
	var tower_right_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	var use_lane: int = defense_lane if (style == "defensive" or style == "emergency") else target_lane
	if (style == "defensive" or style == "emergency") and _demo_lane >= 0:
		use_lane = _demo_lane
	var lane_x: float = tower_left_x if use_lane == 0 else tower_right_x
	var own_z: float = _own_z(0.15)
	var bridge_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 - 1.0
	var is_tank: bool = _is_win_condition(cfg) or cfg.max_health >= 1800 or cfg.cost >= 5

	if cfg.type == Config.UnitType.BUILDING:
		# 建筑：防守放在双塔之间靠后，进攻/拉扯放在桥前
		if style == "defensive" or style == "emergency":
			return Vector3(mid_x if cfg.cost >= 4 else lane_x, 0.0, _own_z(0.24))
		return Vector3(lane_x, 0.0, _own_z(0.20))

	if style == "defensive" or style == "emergency":
		# 防守：坦克抗在前，远程/群体放塔后
		if is_tank and cfg.type != Config.UnitType.AIR:
			return Vector3(lane_x, 0.0, _own_z(0.28))
		return Vector3(lane_x, 0.0, own_z)

	if style == "pressure":
		# 关键卡进攻：攻城/冲锋压桥，人海在桥后集结，高 DPS 保持距离
		if cfg.type == Config.UnitType.BUILDING:
			return Vector3(lane_x, 0.0, _own_z(0.30))
		if int(cfg.num) >= 3:
			return Vector3(lane_x, 0.0, _own_z(0.30))
		if cfg.target_type == Config.TargetType.BUILDING_ONLY:
			return Vector3(lane_x, 0.0, bridge_z)
		if cfg.attack_range >= 4.0:
			return Vector3(lane_x, 0.0, _own_z(0.36))
		return Vector3(lane_x, 0.0, bridge_z)

	if style == "chip":
		# 消耗：低费核心直接压桥，别在己方半场空转
		if cfg.type == Config.UnitType.BUILDING:
			return Vector3(lane_x, 0.0, _own_z(0.30))
		return Vector3(lane_x, 0.0, bridge_z)

	if style == "counterpush":
		# 反打：支援放在己方桥头后方，避免直接送进塔
		if cfg.attack_range > 3.0 and not is_tank:
			return Vector3(lane_x, 0.0, _own_z(0.36))
		return Vector3(lane_x, 0.0, _own_z(0.28))

	# 进攻：重型推进先在高塔后蓄力，速转/野猪直接桥头
	if archetype == "beatdown" and is_tank:
		return Vector3(lane_x, 0.0, _own_z(0.28))
	if cfg.type == Config.UnitType.AIR:
		return Vector3(lane_x, 0.0, config_bridge_z())
	return Vector3(lane_x, 0.0, bridge_z)

func _touchdown_place(cfg: CardData, style: String, lane: int) -> Vector3:
	var lane_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * (0.28 if lane == 0 else 0.72)
	var origin: float = Config.ARENA_ORIGIN.z
	var h: float = Config.ARENA_HEIGHT
	var own_front: float
	var own_back: float
	if team == Config.Team.ENEMY:
		own_front = origin + h / 3.0 - 2.0
		own_back = origin + 2.5
	else:
		own_front = origin + h * 2.0 / 3.0 + 2.0
		own_back = origin + h - 2.5
	var defensive: bool = style == "defensive" or style == "emergency"
	var is_tank: bool = _is_win_condition(cfg) or cfg.max_health >= 1800 or cfg.cost >= 5
	var z: float = own_back
	if cfg.type == Config.UnitType.BUILDING:
		z = own_back + (2.0 if defensive else 4.0)
	elif defensive:
		z = own_front - (2.0 if is_tank else 5.0)
	else:
		z = own_front
	# 冲线模式 AI 也应该敢于把坦克/推进单位压到前场线
	z = clampf(z, origin + 2.0, origin + h - 2.0)
	if team == Config.Team.ENEMY:
		z = minf(z, origin + h / 3.0 - 1.0)
	else:
		z = maxf(z, origin + h * 2.0 / 3.0 + 1.0)
	return Vector3(lane_x, 0.0, z)


func config_bridge_z() -> float:
	return Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5 - 1.0

# ============ 法术目标 ============
func _has_counterpush() -> bool:
	var mid_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var n := 0
	for u in battle.units.get_children():
		if u is Unit and u.team == team and u.health > 0 and u.config.card_id > 3:
			if _is_past_bridge(u.global_position.z):
				n += 1
	return n >= 1

func _spell_damage(spell_config: CardData) -> float:
	var lv: int = PlayerData.ai_level(spell_config.card_id) if team == Config.Team.ENEMY else PlayerData.get_card_level(spell_config.card_id)
	if battle != null:
		lv = battle.mode_level(lv)
	return float(spell_config.damage) * Config.level_mult(lv)


func _spell_value(spell_config: CardData) -> float:
	var player_units: Array = []
	for u in battle.units.get_children():
		if u is Unit and u.team == _foe_team() and u.health > 0 and u.config.card_id > 3:
			player_units.append(u)
	var radius: float = maxf(2.0, spell_config.damage_range * 1.5)
	var dmg := _spell_damage(spell_config)
	var best := 0.0
	for a in player_units:
		var value := 0.0
		for b in player_units:
			if a.global_position.distance_to(b.global_position) > radius:
				continue
			var hp := float(b.health)
			if hp <= dmg:
				# 能击杀：按完整费用计入价值
				value += float(b.config.cost) * 1.15 + 1.0
			else:
				# 打不死：只按实际伤害比例计入
				value += float(b.config.cost) * (dmg / maxf(1.0, hp)) * 0.85
		best = maxf(best, value)
	return best


func _spell_is_efficient(spell_config: CardData) -> bool:
	if spell_config == null:
		return false
	if _spell_tower_target(spell_config) != Vector3.ZERO:
		return true
	return _spell_value(spell_config) >= float(spell_config.cost) * 0.8


func _find_spell_target(spell_config: CardData) -> Vector3:
	var player_units: Array = []
	for unit in battle.units.get_children():
		if unit is Unit and unit.team == _foe_team() and unit.health > 0 and unit.config.card_id > 3:
			player_units.append(unit)
	if player_units.is_empty():
		var tt := _spell_tower_target(spell_config)
		if tt != Vector3.ZERO:
			return tt
		if _chip_target_idx >= 0:
			return _chip_tower_pos()
		return Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5, 0.0, _own_z(0.2))
	var best_pos: Vector3 = player_units[0].global_position
	var best_score: float = -1.0
	var radius: float = maxf(2.0, spell_config.damage_range * 1.5)
	for candidate in player_units:
		var count := 0
		for other in player_units:
			if candidate.global_position.distance_to(other.global_position) <= radius:
				count += 1
		var score: float = float(count)
		if score > best_score:
			best_score = score
			best_pos = candidate.global_position
	var zmin: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (0.0 if team == Config.Team.PLAYER else 0.35)
	var zmax: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (0.65 if team == Config.Team.PLAYER else 1.0)
	if battle != null and String(battle.win_condition) == "touchdown":
		# 法术可放己方 2/3：玩家覆盖下 2/3，敌方 AI 覆盖上 2/3
		if team == Config.Team.PLAYER:
			zmin = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT / 3.0
			zmax = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT
		else:
			zmin = Config.ARENA_ORIGIN.z
			zmax = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 2.0 / 3.0
	best_pos.z = clampf(best_pos.z, zmin, zmax)
	best_pos.x = clampf(best_pos.x, Config.ARENA_ORIGIN.x, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH)
	return best_pos

func _snapshot_state() -> Dictionary:
	var units: Array = []
	for u in battle.units.get_children():
		if not (u is Unit) or u.health <= 0:
			continue
		units.append([
			int(u.team), int(u.config.card_id),
			float(u.global_position.x), float(u.global_position.z),
			float(u.health / maxf(1.0, u.max_health)), int(u.config.type)
		])
	var hand: Array = []
	for cid in ai_hand:
		var cfg = battle.get_config(cid)
		if cfg:
			hand.append([
				int(cid), int(cfg.cost), float(cfg.damage), float(cfg.max_health),
				float(cfg.attack_range), int(cfg.attack_speed), int(cfg.type), int(cfg.target_type)
			])
	return {
		"time": float(battle.game_time),
		"elixir": float(_my_elixir()),
		"team": int(team),
		"player_elixir_est": float(player_elixir_est),
		"threat_level": int(threat_level),
		"threat_tank": threat_tank,
		"threat_swarm": threat_swarm,
		"threat_air": threat_air,
		"lane_threat": lane_threat.duplicate(),
		"defense_lane": int(defense_lane),
		"target_lane": int(target_lane),
		"towers": battle.healths.duplicate(),
		"hand": hand,
		"units": units,
		"archetype": archetype
	}

func _send_ai_emote():
	if battle == null or battle.hud == null:
		return
	if not battle.hud.has_method("show_emote"):
		return
	var all: Array = EMOTES.all()
	if all.is_empty():
		return
	var item: Dictionary = all[randi() % all.size()]
	battle.hud.show_emote(String(item.id), Config.Team.ENEMY)

# ============ 困难难度留牌 ============
func _update_reserved_cards():
	# 根据当前威胁，决定保留哪类关键卡
	reserved_spell = ""
	reserved_tank_killer = ""
	if threat_swarm:
		# 如果手中有火球或万箭齐发，则保留
		for cid in ai_hand:
			var lab = _get_card_label(cid)
			if lab in ["fireball", "arrows", "zap"]:
				reserved_spell = lab
				break
	if threat_tank:
		for cid in ai_hand:
			var lab = _get_card_label(cid)
			if lab in ["minipekka", "inferno"]:
				reserved_tank_killer = lab
				break

# ============ 原有分析变量（为避免报错，变量名统一） ============
# 注意将原脚本中的变量名改为了 threat_ 开头的新名字，我们已在前面的 _analyze_battlefield 中更新。
var enemy_heavy: bool = false   # 可能未使用
var enemy_swarm: bool = false
var enemy_air: bool = false
