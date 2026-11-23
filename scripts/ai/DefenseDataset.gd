extends Node
# 轻量防御训练日志：每 0.2 秒记录战场状态，并记录所有出牌动作。
# 用法：启动游戏前设置 CR_AI_DEFENSE_LOG=1
# 输出：user://ai_defense_logs/<timestamp>.jsonl

var battle: BattleManager
var _file: FileAccess
var _snap_acc := 0.0
var _last_action_count := 0
var _ai_connected := false
var ai_system = null


func bind(b: BattleManager, ai = null) -> void:
	battle = b
	ai_system = ai
	var dir := "user://ai_defense_logs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%d.jsonl" % [dir, int(Time.get_unix_time_from_system())]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("[DefenseLog] 无法写入训练日志")
		set_process(false)
		return
	_connect_ai()


func record_action(team: int, card_id: int, pos: Vector3) -> void:
	_write({
		"type": "action", "t": float(battle.game_time / 1000.0) if battle else 0.0,
		"team": int(team), "card_id": int(card_id),
		"x": float(pos.x), "z": float(pos.z),
	})


func _connect_ai() -> void:
	if _ai_connected or battle == null:
		return
	if ai_system and ai_system.has_signal("decision_made"):
		ai_system.decision_made.connect(_on_ai_action)
		_ai_connected = true


func _process(delta: float) -> void:
	if battle == null or _file == null:
		return
	_connect_ai()
	_capture_actions()
	_snap_acc += delta
	if _snap_acc < 0.2:
		return
	_snap_acc = 0.0
	_write_snapshot()


func _capture_actions() -> void:
	var rec = battle.match_replay_recorder
	if rec == null:
		return
	var actions = rec.get("actions")
	if not (actions is Array):
		return
	while _last_action_count < actions.size():
		var a: Dictionary = Dictionary(actions[_last_action_count])
		_last_action_count += 1
		_write({
			"type": "action",
			"t": float(a.get("t", 0.0)),
			"team": int(a.get("team", 0)),
			"card_id": int(a.get("card_id", -1)),
			"x": float(a.get("x", 0.0)),
			"z": float(a.get("z", 0.0)),
		})


func _on_ai_action(state: Dictionary, action: Dictionary) -> void:
	_write({
		"type": "action",
		"t": float(battle.game_time / 1000.0),
		"team": int(state.get("team", Config.Team.ENEMY)),
		"card_id": int(action.get("card_id", -1)),
		"x": float(action.get("x", 0.0)),
		"z": float(action.get("z", 0.0)),
		"style": String(action.get("style", "")),
	})


func _write_snapshot() -> void:
	var units: Array = []
	for u in battle.units.get_children():
		if not (u is Unit) or u.health <= 0 or u.config == null:
			continue
		units.append({
			"id": int(u.id), "team": int(u.team), "card_id": int(u.config.card_id),
			"x": float(u.global_position.x), "z": float(u.global_position.z),
			"hp": float(u.health), "max_hp": float(u.max_health),
			"level": int(u.level), "size": float(u.config.size),
			"type": int(u.config.type), "range": float(u.config.attack_range),
		})
	var hands: Array = [_player_hand_ids()]
	if ai_system:
		hands.append(Array(ai_system.ai_hand).duplicate())
	else:
		hands.append([])
	_write({
		"type": "snapshot",
		"t": float(battle.game_time / 1000.0),
		"towers": battle.healths.duplicate(),
		"elixir": [float(battle.player_elixir), float(battle.enemy_elixir)],
		"hands": hands,
		"units": units,
		"crowns": [int(battle.player_crowns), int(battle.enemy_crowns)],
		"overtime": bool(battle.overtime),
	})


func _player_hand_ids() -> Array:
	var out: Array = []
	for card in battle.player_hand:
		if card and card.config:
			out.append(int(card.config.card_id))
	return out


func _write(d: Dictionary) -> void:
	if _file:
		_file.store_line(JSON.stringify(d))
