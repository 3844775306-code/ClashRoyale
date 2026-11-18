extends Node
# 客户端联机回放：把收到的权威快照流式写入本地，供回放页使用

var _main_path := ""
var _snap_path := ""
var _snap_file: FileAccess
var _meta: Dictionary = {}
var _emotes: Array = []
var _finished := false
var _last_t := 0.0
var _last_write_t := -1.0

func start(info: Dictionary) -> void:
	if not PlayerData.record_replays:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://replays"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_main_path = "user://replays/replay_net_%s.json" % stamp
	_snap_path = _main_path.get_basename() + ".snap.jsonl"
	_snap_file = FileAccess.open(ProjectSettings.globalize_path(_snap_path), FileAccess.WRITE)
	if _snap_file == null:
		return
	var my_slot := int(info.get("local_slot", 0))
	var my_team := int(info.get("local_team", 0))
	var my_deck: Array = []
	var my_levels: Dictionary = {}
	var opp_deck: Array = []
	var opp_levels: Dictionary = {}
	for seat in info.get("seats", []):
		var st: int = int(seat.get("team", 0))
		var si: int = int(seat.get("idx", 0))
		if st * 2 + si == my_slot:
			my_deck = Array(seat.get("deck", [])).duplicate()
			my_levels = Dictionary(seat.get("levels", {})).duplicate()
		elif st != my_team and opp_deck.is_empty():
			opp_deck = Array(seat.get("deck", [])).duplicate()
			opp_levels = Dictionary(seat.get("levels", {})).duplicate()
	_meta = {
		"version": 4,
		"started_at": Time.get_datetime_string_from_system(),
		"arena": int(info.get("arena", 1)),
		"self_play": false,
		"room_mode": String(info.get("mode", "1v1")),
		"local_slot": my_slot,
		"local_team": my_team,
		"player_deck": my_deck,
		"enemy_deck": opp_deck,
		"player_levels": my_levels,
		"enemy_levels": opp_levels,
		"towers": [],
		"result": -2,
	}

func push(snap: Dictionary) -> void:
	if _finished or _snap_file == null:
		return
	var st: float = float(snap.get("t", 0.0))
	_last_t = maxf(_last_t, st)
	if _last_write_t >= 0.0 and st - _last_write_t < 0.095:
		return
	_last_write_t = st
	_snap_file.store_line(JSON.stringify(snap))

func add_emote(id: String, team: int) -> void:
	_emotes.append({"t": _last_t, "id": id, "team": int(team)})

func finish() -> void:
	if _finished:
		return
	_finished = true
	if _snap_file:
		_snap_file.close()
		_snap_file = null
	if _main_path == "":
		return
	_meta["duration"] = _last_t
	_meta["snapshots_file"] = _snap_path.get_file()
	var f := FileAccess.open(ProjectSettings.globalize_path(_main_path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"meta": _meta, "actions": [], "snapshots": [], "emotes": _emotes}))
		f.close()

func _exit_tree():
	finish()
