# scripts/core/MatchRecorder.gd
# 本地对局录像：把玩家/AI 的每次出牌记录为与 AI 数据集相同的 state/action JSONL。
extends Node

const OBS = preload("res://scripts/core/ObservationBuilder.gd")

var battle
var file_path: String = ""
var _bound_ai: Dictionary = {}

func _ready():
	battle = get_parent()
	if battle == null:
		return
	var dir := "user://ai_player_replays"
	var env_dir := OS.get_environment("CR_REPLAY_DIR")
	if env_dir != "":
		dir = env_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	file_path = "%s/match_%s.jsonl" % [dir, stamp]
	# AI 节点可能比录像器晚创建，延迟绑定
	call_deferred("_bind_ai")

func bind_ai(ai) -> void:
	if ai == null or _bound_ai.has(ai.get_instance_id()):
		return
	_bound_ai[ai.get_instance_id()] = true
	ai.decision_made.connect(_on_ai_decision)

func _bind_ai():
	for c in battle.get_children():
		if c is AISystem:
			bind_ai(c)

func record_player_action(cfg: CardData, pos: Vector3) -> void:
	if battle == null or cfg == null:
		return
	var hand_ids: Array = []
	for card in battle.player_hand:
		if card and card.config:
			hand_ids.append(card.config.card_id)
	var state: Dictionary = OBS.build(battle, Config.Team.PLAYER, hand_ids, -1.0, "player")
	_append(state, {
		"card_id": cfg.card_id,
		"x": pos.x,
		"z": pos.z,
		"style": "human",
		"team": Config.Team.PLAYER
	})

func _on_ai_decision(state: Dictionary, action: Dictionary):
	if state.has("team"):
		_append(state, action)

func _append(state: Dictionary, action: Dictionary) -> void:
	if file_path == "":
		return
	var f := FileAccess.open(ProjectSettings.globalize_path(file_path), FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(ProjectSettings.globalize_path(file_path), FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify({"state": state, "action": action}))
	f.close()
