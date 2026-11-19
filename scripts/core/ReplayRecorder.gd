# scripts/core/ReplayRecorder.gd
# 轻量对局录像：只记录双方出牌的“时间 + 位置 + 卡牌”，播放时重新模拟。
extends Node

var battle
var meta: Dictionary = {}
var actions: Array = []
var emotes: Array = []
var _path: String = ""
var _dir: String = "user://replays"
const MAX_REPLAYS := 20
var _finished: bool = false
var _bound_ai: Dictionary = {}
var _meta_ready: bool = false
var snapshots: Array = []
var _snap_acc: float = 0.0
var _snap_file: FileAccess
var _snap_path: String = ""
var _snap_count: int = 0
var _snap_interval: float = 0.033
const MAX_SNAPSHOTS := 6000

func _ready():
	battle = get_parent()
	if battle == null:
		return
	_dir = PlayerData.replay_dir()
	var env_dir := OS.get_environment("CR_MATCH_REPLAY_DIR")
	if env_dir != "":
		_dir = env_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_path = "%s/replay_%s.json" % [_dir, stamp]
	if OS.has_feature("mobile"):
		_snap_interval = 0.05
	_snap_path = _path.get_basename() + ".snap.jsonl"
	_open_snap_file()
	call_deferred("_capture_meta")
	call_deferred("_bind_ais")
	call_deferred("_capture_frame")
	call_deferred("_bind_hud")
	set_process(true)

func _open_snap_file() -> void:
	if _snap_file:
		_snap_file.close()
	_snap_file = FileAccess.open(ProjectSettings.globalize_path(_snap_path), FileAccess.WRITE)
	_snap_count = 0

func _bind_hud():
	if battle and battle.hud and battle.hud.has_signal("emote_sent"):
		if not battle.hud.emote_sent.is_connected(_on_emote):
			battle.hud.emote_sent.connect(_on_emote)

func _on_emote(id: String, team: int) -> void:
	emotes.append({"t": float(battle.game_time / 1000.0), "id": id, "team": int(team)})

func bind_ai(ai) -> void:
	if ai == null or _bound_ai.has(ai.get_instance_id()):
		return
	_bound_ai[ai.get_instance_id()] = true
	ai.decision_made.connect(_on_ai_decision)

func refresh_meta() -> void:
	_meta_ready = false
	_capture_meta()
	snapshots.clear()
	_open_snap_file()
	_capture_frame()

func _bind_ais():
	if battle == null:
		return
	for c in battle.get_children():
		if c is AISystem:
			bind_ai(c)

func _capture_meta():
	if battle == null or _meta_ready:
		return
	_meta_ready = true
	var arena_id: int = 0
	var bf = battle.get_node_or_null("Battlefield")
	if bf != null:
		var v = bf.get("arena_idx")
		if v != null:
			arena_id = int(v)
	var self_play: bool = false
	for c in battle.get_children():
		if c is AISystem and c.team == Config.Team.PLAYER:
			self_play = true
			break
	var towers: Array = []
	for u in battle.units.get_children():
		if u is Unit and u.config and u.config.card_id <= 3:
			towers.append({
				"team": int(u.team),
				"card_id": int(u.config.card_id),
				"x": float(u.global_position.x),
				"z": float(u.global_position.z),
				"max_health": float(u.max_health),
				"level": int(u.level)
			})
	meta = {
		"version": 3,
		"started_at": Time.get_datetime_string_from_system(),
		"arena": arena_id,
		"arena_name": PlayerData.get_arena_name_at(arena_id) if arena_id > 0 else PlayerData.get_arena_name(),
		"player_name": PlayerData.player_name,
		"test_mode": PlayerData.test_mode,
		"difficulty": int(GameSettings.difficulty),
		"self_play": self_play,
		"towers": towers,
		"player_deck": _deck_for_team(Config.Team.PLAYER),
		"enemy_deck": _deck_for_team(Config.Team.ENEMY),
		"player_levels": _levels_for_team(Config.Team.PLAYER),
		"enemy_levels": _levels_for_team(Config.Team.ENEMY),
		"mode": battle.battle_mode.duplicate(true) if battle else {},
		"mode_name": battle.mode_name if battle else "标准对战",
		"result": -2
	}

func _deck_for_team(t: int) -> Array:
	if battle and battle.get("network_host_mode") and t == Config.Team.ENEMY:
		return battle.remote_deck.duplicate()
	for c in battle.get_children():
		if c is AISystem and c.team == t:
			var d: Array = []
			for id in c.ai_hand:
				d.append(int(id))
			for id in c.ai_deck:
				d.append(int(id))
			return d
	if t == Config.Team.PLAYER:
		var d: Array = []
		for card in battle.player_hand:
			if card and card.config:
				d.append(int(card.config.card_id))
		for id in battle.card_desk:
			d.append(int(id))
		return d
	return []

func _hand_for_team(t: int) -> Array:
	if battle and battle.get("network_host_mode") and t == Config.Team.ENEMY:
		return battle.network_team_hand(Config.Team.ENEMY)
	for c in battle.get_children():
		if c is AISystem and c.team == t:
			return c.ai_hand.duplicate()
	if t == Config.Team.PLAYER:
		var h: Array = []
		for card in battle.player_hand:
			if card and card.config:
				h.append(int(card.config.card_id))
		return h
	return []

func build_snapshot() -> Dictionary:
	if battle == null:
		return {}
	var units: Array = []
	if OS.get_environment("CR_NET_DEBUG") != "":
		print("BUILD raw units=", battle.units.get_child_count())
	for u in battle.units.get_children():
		if not (u is Unit) or u.health <= 0 or u.config == null:
			continue
		var entry := {
			"id": int(u.id),
			"team": int(u.team),
			"card_id": int(u.config.card_id),
			"name": String(u.config.card_name),
			"level": int(u.level),
			"x": float(u.global_position.x),
			"y": float(u.global_position.y),
			"z": float(u.global_position.z),
			"hp": float(u.health),
			"max_hp": float(u.max_health),
			"type": int(u.config.type),
			"king_duo": bool(u.king_duo)
		}
		if u.visual_root:
			entry["rot"] = [float(u.visual_root.rotation.x), float(u.visual_root.rotation.y), float(u.visual_root.rotation.z)]
			entry["vpos"] = [float(u.visual_root.position.x), float(u.visual_root.position.y), float(u.visual_root.position.z)]
			entry["vscale"] = [float(u.visual_root.scale.x), float(u.visual_root.scale.y), float(u.visual_root.scale.z)]
		if u.inferno_beam and u.inferno_beam.visible and u.target and is_instance_valid(u.target):
			var bfrom: Vector3 = u.inferno_beam.global_position
			var bto: Vector3 = u.target.global_position + Vector3.UP * 0.55
			entry["beam"] = {
				"from": [float(bfrom.x), float(bfrom.y), float(bfrom.z)],
				"to": [float(bto.x), float(bto.y), float(bto.z)],
				"lightning": bool(u._beam_is_lightning())
			}
		elif u._chain_fx and u._chain_fx.visible and u._chain_points.size() >= 2:
			var cps: Array = []
			for p in u._chain_points:
				cps.append([float(p.x), float(p.y), float(p.z)])
			entry["chain"] = cps
		if u.body_mesh:
			entry["body_pos"] = [float(u.body_mesh.position.x), float(u.body_mesh.position.y), float(u.body_mesh.position.z)]
			entry["body_rot"] = [float(u.body_mesh.rotation.x), float(u.body_mesh.rotation.y), float(u.body_mesh.rotation.z)]
			entry["body_scale"] = [float(u.body_mesh.scale.x), float(u.body_mesh.scale.y), float(u.body_mesh.scale.z)]
			for leg_name in ["LegL", "LegR", "Weapon"]:
				var leg = u.body_mesh.get_node_or_null(leg_name) as Node3D
				if leg:
					entry["%s_rot" % leg_name] = [float(leg.rotation.x), float(leg.rotation.y), float(leg.rotation.z)]
			var turret = u.body_mesh.get_node_or_null("Turret") as Node3D
			if turret:
				entry["turret_pos"] = [float(turret.position.x), float(turret.position.y), float(turret.position.z)]
				entry["turret_rot"] = [float(turret.rotation.x), float(turret.rotation.y), float(turret.rotation.z)]
				entry["turret_scale"] = [float(turret.scale.x), float(turret.scale.y), float(turret.scale.z)]
				entry["turret_visible"] = bool(turret.visible)
			for pname in ["u_flash", "u_freeze", "u_poison", "u_dark", "u_curse", "u_rage", "u_slow"]:
				var pv = u.body_mesh.get_instance_shader_parameter(pname)
				if pv != null:
					entry[pname] = float(pv)
		units.append(entry)
	var bullets: Array = []
	for b in battle.bullets.get_children():
		if b is Bullet and b.config:
			var br := Vector3.ZERO
			if b.model_mesh:
				br = b.model_mesh.rotation
			var bkind: String = b.model_kind if b.model_kind != "" else b._get_bullet_type()
			if bkind == "normal": bkind = "arrow"
			var bweapon: String = ""
			if b.source_unit and is_instance_valid(b.source_unit):
				bweapon = String(b.source_unit.weapon_kind)
			bullets.append({
				"id": int(b.get_instance_id()), "card_id": int(b.config.card_id), "team": int(b.team),
				"kind": bkind, "weapon": bweapon,
				"x": float(b.global_position.x), "y": float(b.global_position.y), "z": float(b.global_position.z),
				"rot": [float(br.x), float(br.y), float(br.z)]
			})
	var spells: Array = []
	for s in battle.spells.get_children():
		if s is Spell:
			spells.append({
				"id": int(s.get_instance_id()), "card_id": int(s.card_id), "team": int(s.team),
				"x": float(s.global_position.x), "y": float(s.global_position.y), "z": float(s.global_position.z),
				"progress": clampf(float(s.elapsed_time) / maxf(0.05, float(s.max_duration) / 50.0), 0.0, 1.0)
			})
	var snap := {
		"t": float(battle.game_time / 1000.0),
		"units": units,
		"bullets": bullets,
		"spells": spells,
		"towers": battle.healths.duplicate(),
		"elixir": [float(battle.player_elixir), float(battle.enemy_elixir)],
		"hands": [_hand_for_team(0), _hand_for_team(1)],
		"crowns": [int(battle.player_crowns), int(battle.enemy_crowns)],
		"touchdown_scores": [int(battle.touchdown_score[0]), int(battle.touchdown_score[1])],
		"touchdown_round": int(battle.touchdown_round),
		"touchdown_resetting": bool(battle.touchdown_resetting),
	}
	if battle.get("network_host_mode"):
		snap["player_hands"] = battle.network_player_hands()
		snap["player_elixirs"] = battle.network_player_elixirs()
		snap["player_max_elixirs"] = battle.network_player_max_elixirs()
	return snap

func _capture_frame() -> void:
	var snap: Dictionary = build_snapshot()
	if snap.is_empty():
		return
	_snap_count += 1
	if _snap_file:
		_snap_file.store_line(JSON.stringify(snap))
	elif snapshots.size() < MAX_SNAPSHOTS:
		snapshots.append(snap)

func _levels_for_team(t: int) -> Dictionary:
	if battle and battle.get("network_host_mode") and t == Config.Team.ENEMY:
		return battle.remote_levels.duplicate()
	var out: Dictionary = {}
	var deck: Array = _deck_for_team(t)
	for cid in deck:
		out[str(int(cid))] = PlayerData.get_card_level(int(cid)) if t == Config.Team.PLAYER else PlayerData.ai_level(int(cid))
	return out

func _on_ai_decision(state: Dictionary, action: Dictionary):
	if not _meta_ready:
		_capture_meta()
	record_action(int(state.get("team", 1)), int(action.get("card_id", -1)),
		Vector3(float(action.get("x", 0.0)), 0.0, float(action.get("z", 0.0))))

func record_action(team: int, card_id: int, pos: Vector3) -> void:
	if card_id <= 0:
		return
	if not _meta_ready:
		_capture_meta()
	actions.append({
		"t": float(battle.game_time / 1000.0),
		"team": int(team),
		"card_id": int(card_id),
		"x": float(pos.x),
		"z": float(pos.z)
	})
	if actions.size() > 4000:
		actions.pop_front()

func _process(delta):
	if battle == null or _finished:
		return
	_bind_ais()
	_snap_acc += delta
	if _snap_acc >= _snap_interval:
		_snap_acc = 0.0
		_capture_frame()
	if battle.game_over:
		_capture_frame()
		_finish()

func _exit_tree():
	if not _finished:
		_finish()

func _finish():
	if _finished:
		return
	_finished = true
	if battle:
		meta["duration"] = float(battle.game_time / 1000.0)
		meta["winner"] = int(battle.winner)
		meta["crowns"] = [int(battle.player_crowns), int(battle.enemy_crowns)]
		meta["result"] = int(battle.winner)
	meta["version"] = 4
	meta["snapshots_file"] = _snap_path.get_file() if _snap_file or _snap_count > 0 else ""
	if _snap_file:
		_snap_file.close()
		_snap_file = null
	var f := FileAccess.open(ProjectSettings.globalize_path(_path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"meta": meta, "actions": actions, "snapshots": snapshots, "emotes": emotes, "permanent": false}))
		f.close()
		print("REPLAY saved ", _path, " frames=", snapshots.size(), " actions=", actions.size())
		cleanup_replays(_dir)
	else:
		print("REPLAY write failed ", _path)

static func cleanup_replays(dir_path: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	var items: Array = []
	for f in d.get_files():
		if not f.ends_with(".json") or not f.begins_with("replay_"):
			continue
		var p := abs_dir + "/" + f
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa == null:
			continue
		var parsed = JSON.parse_string(fa.get_as_text())
		fa.close()
		if not (parsed is Dictionary):
			continue
		var permanent: bool = bool(parsed.get("permanent", false))
		var mtime: int = int(FileAccess.get_modified_time(p))
		items.append({"path": p, "time": mtime, "permanent": permanent})
	items.sort_custom(func(a, b): return int(a.time) > int(b.time))
	var kept := 0
	for it in items:
		if bool(it.permanent):
			continue
		kept += 1
		if kept <= MAX_REPLAYS:
			continue
		DirAccess.remove_absolute(String(it.path))
		DirAccess.remove_absolute(String(it.path).get_basename() + ".snap.jsonl")
