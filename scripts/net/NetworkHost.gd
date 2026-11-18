extends Node
# 房主战斗内的快照广播器（20Hz）
var battle
var _rec: Node
var _acc := 0.0

func _ready():
	battle = get_parent()
	_rec = preload("res://scripts/core/ReplayRecorder.gd").new()
	_rec.battle = battle
	set_process(true)

func _process(delta):
	if NetworkManager.role != NetworkManager.Role.HOST:
		return
	_acc += delta
	if _acc < 0.05:
		return
	_acc = 0.0
	if _rec:
		var snap: Dictionary = _rec.build_snapshot()
		if not snap.is_empty():
			if OS.get_environment("CR_NET_DEBUG") != "":
				print("NET host snapshot t=", snap.get("t",0), " units=", snap.get("units",[]).size())
			NetworkManager.send_snapshot(snap)
