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

func send_now() -> void:
	if NetworkManager.role != NetworkManager.Role.HOST or _rec == null:
		return
	var snap: Dictionary = _rec.build_snapshot()
	if not snap.is_empty():
		NetworkManager.send_snapshot(snap)


func _process(delta):
	if NetworkManager.role != NetworkManager.Role.HOST:
		return
	# 单机观战房间没有观众时不构建快照；联机对局有玩家时必须继续发送
	if NetworkManager.spectator_count <= 0 and NetworkManager.guest_count() <= 0:
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
