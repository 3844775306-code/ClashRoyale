# scripts/core/ObservationBuilder.gd
# 统一玩家/AI 的观察格式，供录像与离线训练复用。
class_name ObservationBuilder
extends RefCounted

static func build(battle, team: int, hand_ids: Array, opponent_elixir_est: float = -1.0, archetype: String = "unknown") -> Dictionary:
	var foe: int = Config.Team.PLAYER if team == Config.Team.ENEMY else Config.Team.ENEMY
	var my_elixir: float = battle.enemy_elixir if team == Config.Team.ENEMY else battle.player_elixir
	var units: Array = []
	var foe_units: Array = []
	for u in battle.units.get_children():
		if not (u is Unit) or u.health <= 0:
			continue
		units.append([
			int(u.team), int(u.config.card_id),
			float(u.global_position.x), float(u.global_position.z),
			float(u.health / maxf(1.0, u.max_health)), int(u.config.type)
		])
		if u.team == foe and u.config.card_id > 3:
			foe_units.append(u)

	var hand: Array = []
	for cid_v in hand_ids:
		var cid: int = int(cid_v)
		var cfg = battle.get_config(cid)
		if cfg:
			hand.append([
				cid, int(cfg.cost), float(cfg.damage), float(cfg.max_health),
				float(cfg.attack_range), int(cfg.attack_speed), int(cfg.type), int(cfg.target_type)
			])

	var lane_threat: Array = [0.0, 0.0]
	var threat_tank := false
	var threat_swarm := false
	var threat_air := false
	var mid_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	for u in foe_units:
		var lane: int = 0 if u.global_position.x < mid_x else 1
		lane_threat[lane] += 1.0 + u.config.cost * 0.5
		if u.config.type == Config.UnitType.AIR:
			threat_air = true
		elif u.config.max_health >= 1800 or u.config.cost >= 5:
			threat_tank = true
		if u.config.num >= 3:
			threat_swarm = true
	var threat_level := 1
	if threat_tank or threat_air:
		threat_level = 3
	elif lane_threat[0] + lane_threat[1] >= 2.0:
		threat_level = 2
	var left_idx: int = 0 if team == Config.Team.ENEMY else 3
	var right_idx: int = 1 if team == Config.Team.ENEMY else 4
	var lh: float = battle.healths[left_idx] if battle.healths.size() > right_idx else 1.0
	var rh: float = battle.healths[right_idx] if battle.healths.size() > right_idx else 1.0

	return {
		"time": float(battle.game_time),
		"elixir": float(my_elixir),
		"player_elixir_est": float(opponent_elixir_est),
		"threat_level": threat_level,
		"threat_tank": threat_tank,
		"threat_swarm": threat_swarm,
		"threat_air": threat_air,
		"lane_threat": lane_threat,
		"defense_lane": 0 if lane_threat[0] >= lane_threat[1] else 1,
		"target_lane": 0 if lh <= rh else 1,
		"towers": battle.healths.duplicate(),
		"hand": hand,
		"units": units,
		"archetype": archetype,
		"team": int(team)
	}
