# scripts/core/FriendManager.gd
# 好友列表（按账号保存） + 同局域网联机邀请（UDP 广播）
extends Node

signal friends_changed
signal invite_received(invite: Dictionary)
signal presence_changed
signal requests_changed
signal friend_request_received(request: Dictionary)
signal friend_request_answered(request: Dictionary, accepted: bool)

const UDP_PORT := 24511
const INVITE_TTL := 300
const PROTOCOL := "cr_room_invite"

var friends: Array = []
var pending_invite: Dictionary = {}
var online_peers: Dictionary = {}   # id -> {name, last_seen}
var incoming_requests: Dictionary = {}  # from_id -> profile
var outgoing_requests: Dictionary = {}  # to_id -> profile
var _presence_acc := 0.0
var _requests_resend_acc := 0.0
var _accept_notices: Dictionary = {}  # id -> {profile, expires}
var _rejected: Dictionary = {}  # id -> ts
var _request_sent_at: Dictionary = {}  # id -> ts
var _recv: PacketPeerUDP
var _send: PacketPeerUDP
var _invite_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_friends()
	_init_udp()
	invite_received.connect(_on_invite_received)
	# 切换账号后好友列表按账号重新加载
	if AccountManager and not AccountManager.session_changed.is_connected(_on_session_changed):
		AccountManager.session_changed.connect(_on_session_changed)


func _on_session_changed() -> void:
	load_friends()


func is_online(pid: String) -> bool:
	var p = online_peers.get(pid, null)
	if not (p is Dictionary):
		return false
	return int(Time.get_unix_time_from_system()) - int(p.get("last", 0)) <= 8


func search_players(query: String, callback: Callable) -> void:
	var q := query.strip_edges()
	if q == "":
		callback.call([])
		return
	var ql := q.to_lower()
	var state := {"pending": 2, "out": []}
	var my_id := str(ClanManager.get_player_id())

	var finish := func():
		state["pending"] = int(state["pending"]) - 1
		if int(state["pending"]) <= 0:
			callback.call(state["out"])

	var add := func(e: Dictionary):
		var pid := String(e.get("player_id", e.get("id", "")))
		if pid == "" or pid == my_id:
			return
		var n := String(e.get("name", e.get("player_name", "玩家")))
		var match_id := pid == q
		var match_name := n.to_lower().contains(ql)
		if not (match_id or match_name):
			return
		for old in state["out"]:
			if String(old.get("player_id", "")) == pid:
				return
		state["out"].append({
			"player_id": pid, "name": n,
			"trophies": int(e.get("trophies", e.get("score", 0))),
			"avatar_seed": int(e.get("avatar_seed", absi(hash(n)))),
			"avatar_index": int(e.get("avatar_index", 0)),
			"clan": String(e.get("clan", "")),
		})

	# 本机好友 / 同局域网在线玩家
	for f in friends:
		add.call(f)
	for pid in online_peers.keys():
		add.call({"player_id": pid, "name": online_peers[pid].get("name", "好友")})

	# 排行榜
	LeaderboardAPI.get_leaderboard(func(entries):
		for e in entries:
			if state["out"].size() >= 30:
				break
			add.call(e)
		finish.call())

	# 部落成员（含不在排行榜前 50 的玩家）
	ClanManager.get_all_clans(func(_ok, clans):
		for clan in clans:
			if state["out"].size() >= 30:
				break
			var cl_name := String(clan.get("name", ""))
			for mid in Dictionary(clan.get("members", {})).keys():
				var m: Dictionary = clan["members"][mid]
				add.call({
					"player_id": str(mid),
					"name": String(m.get("player_name", "玩家")),
					"trophies": int(m.get("trophies", 0)),
					"avatar_seed": int(m.get("avatar_seed", 0)),
					"avatar_index": int(m.get("avatar_index", 0)),
					"clan": cl_name,
				})
		finish.call())


func _friends_path() -> String:
	return PlayerData.current_save_path().get_base_dir() + "/friends.cfg"


func load_friends() -> void:
	friends.clear()
	incoming_requests.clear()
	outgoing_requests.clear()
	var cfg := ConfigFile.new()
	if cfg.load(_friends_path()) != OK:
		friends_changed.emit()
		requests_changed.emit()
		return
	var raw = cfg.get_value("friends", "list", [])
	if raw is Array:
		for f in raw:
			if f is Dictionary and String(f.get("id", "")) != "":
				friends.append((f as Dictionary).duplicate(true))
	var inc = cfg.get_value("requests", "incoming", {})
	if inc is Dictionary:
		for k in inc.keys():
			incoming_requests[String(k)] = Dictionary(inc[k]).duplicate(true)
	var outg = cfg.get_value("requests", "outgoing", {})
	if outg is Dictionary:
		for k in outg.keys():
			outgoing_requests[String(k)] = Dictionary(outg[k]).duplicate(true)
	friends_changed.emit()
	requests_changed.emit()


func save_friends() -> void:
	DirAccess.make_dir_recursive_absolute(_friends_path().get_base_dir())
	var cfg := ConfigFile.new()
	cfg.set_value("friends", "list", friends)
	cfg.set_value("requests", "incoming", incoming_requests)
	cfg.set_value("requests", "outgoing", outgoing_requests)
	cfg.save(_friends_path())
	friends_changed.emit()
	requests_changed.emit()


func all() -> Array:
	return friends.duplicate(true)


func is_friend(pid: String) -> bool:
	for f in friends:
		if String(f.get("id", "")) == pid:
			return true
	return false


func _add_friend(profile: Dictionary) -> bool:
	var pid := String(profile.get("player_id", profile.get("id", "")))
	if pid == "" or pid == str(ClanManager.get_player_id()):
		return false
	if is_friend(pid):
		return true
	friends.append({
		"id": pid,
		"name": String(profile.get("name", profile.get("player_name", "玩家"))),
		"trophies": int(profile.get("trophies", profile.get("score", 0))),
		"avatar_seed": int(profile.get("avatar_seed", 0)),
		"avatar_index": int(profile.get("avatar_index", 0)),
		"clan": String(profile.get("clan", "")),
	})
	save_friends()
	return true


func has_outgoing(pid: String) -> bool:
	return outgoing_requests.has(pid)


func has_incoming(pid: String) -> bool:
	return incoming_requests.has(pid)


func incoming_list() -> Array:
	var out: Array = []
	for k in incoming_requests.keys():
		out.append(Dictionary(incoming_requests[k]).duplicate(true))
	return out


func outgoing_list() -> Array:
	var out: Array = []
	for k in outgoing_requests.keys():
		out.append(Dictionary(outgoing_requests[k]).duplicate(true))
	return out


func _self_profile() -> Dictionary:
	return {
		"player_id": str(ClanManager.get_player_id()),
		"name": PlayerData.player_name,
		"trophies": PlayerData.trophies,
		"avatar_seed": PlayerData.avatar_seed,
		"avatar_index": PlayerData.avatar_index,
	}


func _friend_profile(profile: Dictionary) -> Dictionary:
	return {
		"player_id": String(profile.get("player_id", profile.get("id", ""))),
		"name": String(profile.get("name", profile.get("player_name", "玩家"))),
		"trophies": int(profile.get("trophies", profile.get("score", 0))),
		"avatar_seed": int(profile.get("avatar_seed", 0)),
		"avatar_index": int(profile.get("avatar_index", 0)),
		"clan": String(profile.get("clan", "")),
	}


func send_friend_request(profile: Dictionary) -> bool:
	var p := _friend_profile(profile)
	var pid := String(p.get("player_id", ""))
	if pid == "" or pid == str(ClanManager.get_player_id()):
		return false
	var now := int(Time.get_unix_time_from_system())
	# 允许重复申请：未成为好友时每次都重新发送（覆盖等待中的申请）
	if is_friend(pid):
		return false
	outgoing_requests[pid] = p
	save_friends()
	var req_data := {
		"type": "cr_friend_request", "target": pid,
		"from_id": str(ClanManager.get_player_id()),
		"from_profile": _self_profile(),
		"ts": int(Time.get_unix_time_from_system()),
	}
	_broadcast_packet(req_data)
	_send_to_ip(String(online_peers.get(pid, {}).get("ip", "")), req_data)
	requests_changed.emit()
	return true


func accept_request(pid: String) -> bool:
	if not incoming_requests.has(pid):
		return false
	var req: Dictionary = incoming_requests[pid]
	_add_friend(Dictionary(req.get("profile", req)))
	incoming_requests.erase(pid)
	save_friends()
	var me := _self_profile()
	_accept_notices[pid] = {"profile": me, "expires": int(Time.get_unix_time_from_system()) + 60}
	_broadcast_packet({
		"type": "cr_friend_accept", "target": pid,
		"from_id": str(ClanManager.get_player_id()),
		"from_profile": me,
		"ts": int(Time.get_unix_time_from_system()),
	})
	requests_changed.emit()
	return true


func reject_request(pid: String) -> bool:
	if not incoming_requests.has(pid):
		return false
	incoming_requests.erase(pid)
	_rejected[pid] = int(Time.get_unix_time_from_system())
	save_friends()
	_broadcast_packet({
		"type": "cr_friend_reject", "target": pid,
		"from_id": str(ClanManager.get_player_id()),
		"ts": int(Time.get_unix_time_from_system()),
	})
	requests_changed.emit()
	return true


func remove_friend(pid: String) -> void:
	for i in range(friends.size() - 1, -1, -1):
		if String(friends[i].get("id", "")) == pid:
			friends.remove_at(i)
	save_friends()


func _init_udp() -> void:
	_recv = PacketPeerUDP.new()
	var err := _recv.bind(UDP_PORT, "0.0.0.0")
	if err != OK:
		push_warning("[FriendManager] 邀请监听端口不可用: %d" % err)
		_recv = null
	_send = PacketPeerUDP.new()
	_send.set_broadcast_enabled(true)


func send_room_invite(room_code: String, host_ip: String, host_name: String, target_pid: String = "") -> bool:
	if _send == null or room_code == "" or host_ip == "":
		return false
	var payload := JSON.stringify({
		"type": PROTOCOL,
		"code": room_code,
		"ip": host_ip,
		"from": host_name,
		"from_id": str(ClanManager.get_player_id()),
		"ts": int(Time.get_unix_time_from_system()),
	})
	var data := payload.to_utf8_buffer()
	var ok := false
	_send.set_dest_address("255.255.255.255", UDP_PORT)
	if _send.put_packet(data) == OK:
		ok = true
	# 同时发一份给本机（方便单机/测试预览）
	_send.set_dest_address("127.0.0.1", UDP_PORT)
	_send.put_packet(data)
	# 已知好友 IP 时再单播一次，避免广播被防火墙拦截
	if target_pid != "":
		var peer_info = online_peers.get(target_pid, {})
		var pip := String(peer_info.get("ip", ""))
		if pip != "":
			_send.set_dest_address(pip, UDP_PORT)
			_send.put_packet(data)
	return ok


func _broadcast_packet(data: Dictionary) -> void:
	if _send == null:
		return
	var buf := JSON.stringify(data).to_utf8_buffer()
	_send.set_dest_address("255.255.255.255", UDP_PORT)
	_send.put_packet(buf)
	_send.set_dest_address("127.0.0.1", UDP_PORT)
	_send.put_packet(buf)


func _send_to_ip(ip: String, data: Dictionary) -> void:
	if _send == null or ip == "":
		return
	_send.set_dest_address(ip, UDP_PORT)
	_send.put_packet(JSON.stringify(data).to_utf8_buffer())

func _on_invite_received(invite: Dictionary) -> void:
	if _invite_layer != null and is_instance_valid(_invite_layer):
		return
	_invite_layer = CanvasLayer.new()
	_invite_layer.layer = 250
	add_child(_invite_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_invite_layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	root.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(90, 500)
	panel.size = Vector2(620, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.15, 0.98)
	sb.border_color = Color(0.95, 0.76, 0.34, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24; v.offset_top = 22; v.offset_right = -24; v.offset_bottom = -22
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := Label.new()
	title.text = "联机邀请"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	v.add_child(title)
	var info := Label.new()
	info.text = "好友 %s 邀请你加入房间\n房间码：%s\nIP：%s" % [String(invite.get("from", "好友")), String(invite.get("code", "")), String(invite.get("ip", ""))]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	v.add_child(info)
	var accept := UiComponents.make_primary_button("接受邀请", Callable(), Vector2(0, 58))
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(func():
		pending_invite = invite
		if _invite_layer != null:
			_invite_layer.queue_free()
			_invite_layer = null
		NetworkManager.reset_net()
		get_tree().change_scene_to_file("res://scenes/network_lobby.tscn"))
	v.add_child(accept)
	var reject := UiComponents.make_secondary_button("拒绝", Callable(), Vector2(0, 48))
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject.pressed.connect(_on_reject_invite)
	v.add_child(reject)

func _on_reject_invite() -> void:
	pending_invite = {}
	if _invite_layer != null:
		_invite_layer.queue_free()
		_invite_layer = null

func handle_friend_packet(data: Dictionary) -> void:
	var my_id := str(ClanManager.get_player_id())
	var ptype := String(data.get("type", ""))
	if String(data.get("target", "")) != my_id:
		return
	if String(data.get("from_id", "")) == my_id:
		return
	if ptype == "cr_friend_request":
		var pid := String(data.get("from_id", ""))
		if pid == "" or is_friend(pid) or incoming_requests.has(pid):
			return
		if _rejected.has(pid) and int(Time.get_unix_time_from_system()) - int(_rejected[pid]) < 300:
			return
		var from_ip := _recv.get_packet_ip() if _recv else ""
		if from_ip != "":
			online_peers[pid] = {"name": String(data.get("from_profile", {}).get("name", "好友")), "last": int(Time.get_unix_time_from_system()), "ip": from_ip}
		incoming_requests[pid] = {
			"id": pid,
			"profile": Dictionary(data.get("from_profile", {})).duplicate(true),
			"ts": int(data.get("ts", 0)),
		}
		save_friends()
		friend_request_received.emit(incoming_requests[pid])
		requests_changed.emit()
	elif ptype == "cr_friend_accept":
		var pid2 := String(data.get("from_id", ""))
		var accepted_profile: Dictionary = Dictionary(data.get("from_profile", {}))
		_add_friend(accepted_profile)
		outgoing_requests.erase(pid2)
		save_friends()
		var accepted_name := String(accepted_profile.get("name", accepted_profile.get("player_name", "对方")))
		PlayerData.add_mail("好友申请已通过", "%s 已同意你的好友请求，现在你们是好友了。" % accepted_name, {}, accepted_name, "friend")
		_broadcast_packet({
			"type": "cr_friend_accept_ack", "target": pid2,
			"from_id": str(ClanManager.get_player_id()),
			"ts": int(Time.get_unix_time_from_system()),
		})
		friend_request_answered.emit({"id": pid2, "accepted": true}, true)
		requests_changed.emit()
	elif ptype == "cr_friend_accept_ack":
		var pid4 := String(data.get("from_id", ""))
		_accept_notices.erase(pid4)
	elif ptype == "cr_friend_reject":
		var pid3 := String(data.get("from_id", ""))
		outgoing_requests.erase(pid3)
		save_friends()
		friend_request_answered.emit({"id": pid3, "accepted": false}, false)
		requests_changed.emit()


func _broadcast_presence(payload: String) -> void:
	if _send == null:
		return
	var data := payload.to_utf8_buffer()
	_send.set_dest_address("255.255.255.255", UDP_PORT)
	_send.put_packet(data)
	_send.set_dest_address("127.0.0.1", UDP_PORT)
	_send.put_packet(data)
	for pid in online_peers.keys():
		var ip := String(Dictionary(online_peers[pid]).get("ip", ""))
		if ip != "":
			_send.set_dest_address(ip, UDP_PORT)
			_send.put_packet(data)


func _process(delta: float) -> void:
	# 同局域网在线状态心跳
	_presence_acc += delta
	if _presence_acc >= 2.5:
		_presence_acc = 0.0
		_broadcast_presence(JSON.stringify({
			"type": "cr_presence",
			"id": str(ClanManager.get_player_id()),
			"name": PlayerData.player_name,
			"ts": int(Time.get_unix_time_from_system()),
		}))
	# 未处理的请求/同意通知定期重发，目标上线后可收到
	_requests_resend_acc += delta
	if _requests_resend_acc >= 5.0:
		_requests_resend_acc = 0.0
		var now2 := int(Time.get_unix_time_from_system())
		for pid in _accept_notices.keys():
			var notice: Dictionary = _accept_notices[pid]
			if int(notice.get("expires", 0)) < now2:
				_accept_notices.erase(pid)
				continue
			var acc2 := {
				"type": "cr_friend_accept", "target": pid,
				"from_id": str(ClanManager.get_player_id()),
				"from_profile": _self_profile(),
				"ts": now2,
			}
			_broadcast_packet(acc2)
			_send_to_ip(String(online_peers.get(pid, {}).get("ip", "")), acc2)
		for pid in outgoing_requests.keys():
			_broadcast_packet({
				"type": "cr_friend_request", "target": pid,
				"from_id": str(ClanManager.get_player_id()),
				"from_profile": _self_profile(),
				"ts": int(Time.get_unix_time_from_system()),
			})
	# 清理过期在线状态
	var now := int(Time.get_unix_time_from_system())
	var stale: Array = []
	for pid in online_peers.keys():
		if now - int(online_peers[pid].get("last", 0)) > 8:
			stale.append(pid)
	for pid in stale:
		online_peers.erase(pid)
	if not stale.is_empty():
		presence_changed.emit()
	if _recv == null:
		return
	while _recv.get_available_packet_count() > 0:
		var text := _recv.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(text)
		if not (data is Dictionary):
			continue
		var ptype := String(data.get("type", ""))
		var ts := int(Time.get_unix_time_from_system())
		if ptype == "cr_presence":
			var pid2 := String(data.get("id", ""))
			if pid2 == "" or pid2 == str(ClanManager.get_player_id()) or ts - int(data.get("ts", 0)) > 10:
				continue
			var pip := _recv.get_packet_ip() if _recv else ""
			online_peers[pid2] = {"name": String(data.get("name", "好友")), "last": ts, "ip": pip}
			presence_changed.emit()
			# 收到对方 presence 后立刻单播回执，修复单向在线
			if pip != "":
				_send_to_ip(pip, {
					"type": "cr_presence", "id": str(ClanManager.get_player_id()),
					"name": PlayerData.player_name,
					"ts": int(Time.get_unix_time_from_system()),
				})
			continue
		if ptype in ["cr_friend_request", "cr_friend_accept", "cr_friend_reject", "cr_friend_accept_ack"]:
			handle_friend_packet(data)
			continue
		if ptype != PROTOCOL:
			continue
		if ts - int(data.get("ts", 0)) > INVITE_TTL:
			continue
		if String(data.get("from_id", "")) == str(ClanManager.get_player_id()):
			continue
		pending_invite = data
		invite_received.emit(data)
