# scripts/net/NetworkManager.gd
# 局域网联机管理器（ENet）：房主内嵌权威服务器。1V1 / 2V2（共享三塔）。
extends Node

const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")

signal lobby_status(text: String)
signal guest_joined
signal match_started(info: Dictionary)
signal snapshot_received(snap: Dictionary)
signal deploy_rejected(reason: String)
signal disconnected(reason: String)
signal match_ended(info: Dictionary)
signal emote_received(id: String, team: int)
signal clients_ready
signal seats_changed
signal joined_room
signal room_closed
signal countdown_received(seconds: float)
signal entry_started

enum Role { NONE, HOST, GUEST }
const DEFAULT_PORT := 24500
const MAX_PLAYERS := 4

var role: int = Role.NONE
var room_mode: String = "1v1"
var party_rule: String = "standard"   # 联机派对规则 id（BattleModes）
var network_draft_decks: Dictionary = {}   # peer -> 选卡结果（1=房主）
var network_draft_picks: Dictionary = {}   # peer -> 双向选卡：自己选的 4 张
var network_draft_rejects: Dictionary = {} # peer -> 双向选卡：不要的 4 张
var network_draft_swap: bool = false
signal network_draft_started
signal touchdown_break_received(round_no: int, score_a: int, score_b: int)
signal touchdown_break_ended
var room_code: String = ""
var peer: ENetMultiplayerPeer = null
var players: Dictionary = {}          # peer_id -> {name,deck,levels,seated}
var seats: Array = []                  # {team,idx,peer,name,ai,deck,levels}
var local_seat_team: int = -1
var local_seat_idx: int = -1
var local_slot: int = 0
var local_team: int = 0
var host_deck: Array = []
var host_levels: Dictionary = {}
var match_info: Dictionary = {}
var host_match_pending: bool = false
var last_snapshot: Dictionary = {}
var ready_peers: Dictionary = {}
var clients_all_ready: bool = false
var _required_peers: Array = []
var _pending_code: String = ""

# 兼容旧 1V1 字段
var guest_peer_id: int = 0
var guest_name: String = ""
var guest_deck: Array = []
var guest_levels: Dictionary = {}

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(false)

func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			if not addr.begins_with("127."):
				return addr
	return "127.0.0.1"

func _host_player_entry() -> Dictionary:
	host_deck = PlayerData.get_active_deck().duplicate()
	host_levels = {}
	for cid in host_deck:
		host_levels[str(int(cid))] = PlayerData.get_card_level(int(cid))
	return {"slot": 0, "team": 0, "name": PlayerData.player_name, "deck": host_deck, "levels": host_levels}

func start_host(port: int = DEFAULT_PORT, mode: String = "1v1", ai0: int = 0, ai1: int = 0) -> bool:
	reset_net()
	room_mode = "1v1"
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 4, 4)
	if err != OK:
		peer = null
		lobby_status.emit("创建房间失败：%s" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	room_code = OS.get_environment("CR_NET_ROOM")
	if room_code == "":
		room_code = str(randi_range(1000, 9999))
	host_deck = PlayerData.get_active_deck().duplicate()
	host_levels = {}
	for cid in host_deck:
		host_levels[str(int(cid))] = PlayerData.get_card_level(int(cid))
	players.clear()
	players[1] = {"name": PlayerData.player_name, "deck": host_deck, "levels": host_levels, "seated": true, "tower_choice": PlayerData.tower_choice, "avatar_seed": PlayerData.avatar_seed, "avatar_index": PlayerData.avatar_index}
	seats.clear()
	seats.append({"team": 0, "idx": 0, "peer": 1, "name": PlayerData.player_name, "ai": false, "deck": host_deck, "levels": host_levels, "tower_choice": PlayerData.tower_choice, "avatar_seed": PlayerData.avatar_seed, "avatar_index": PlayerData.avatar_index})
	seats.append({"team": 1, "idx": 0, "peer": 0, "name": "AI", "ai": true, "deck": PlayerData.get_ai_default_deck(), "levels": {}, "tower_choice": 1, "avatar_seed": 0, "avatar_index": 0})
	local_seat_team = 0
	local_seat_idx = 0
	local_slot = 0
	guest_peer_id = 0
	guest_name = ""
	guest_deck.clear()
	guest_levels.clear()
	print("NET host room=", room_code, " port=", port)
	set_process(true)
	lobby_status.emit("房间已创建：%s" % room_code)
	return true

func mode_name() -> String:
	var b := seats_in_team(0).size()
	var r := seats_in_team(1).size()
	if b <= 1 and r <= 1:
		return "1v1"
	if b >= 2 and r >= 2:
		return "2v2"
	return "1v2"

func seats_in_team(team: int) -> Array:
	var out: Array = []
	for s in seats:
		if int(s.team) == team:
			out.append(s)
	out.sort_custom(func(a, b): return int(a.idx) < int(b.idx))
	return out

func add_seat(team: int) -> bool:
	if role != Role.HOST or seats_in_team(team).size() >= 2:
		return false
	var idx := seats_in_team(team).size()
	seats.append({"team": team, "idx": idx, "peer": 0, "name": "AI", "ai": true, "deck": PlayerData.get_ai_default_deck(), "levels": {}, "tower_choice": 1, "avatar_seed": 0, "avatar_index": 0})
	room_mode = mode_name()
	_broadcast_seats()
	seats_changed.emit()
	lobby_status.emit("已增加 %s 席位（AI托管）" % ("蓝方" if team == 0 else "红方"))
	return true

func _seat_public() -> Array:
	var out: Array = []
	for s in seats:
		out.append({"team": int(s.team), "idx": int(s.idx), "peer": int(s.peer), "name": String(s.name), "ai": bool(s.ai), "deck": Array(s.get("deck", [])), "levels": Dictionary(s.get("levels", {})), "tower_choice": int(s.get("tower_choice", 1)),
			"avatar_seed": int(s.get("avatar_seed", 0)), "avatar_index": int(s.get("avatar_index", 0))})
	return out

func _broadcast_seats() -> void:
	var data := _seat_public()
	for pid in players.keys():
		if pid != 1:
			rpc_id(pid, "room_seats", data, room_code, mode_name(), party_rule, BATTLE_MODES.custom_config() if party_rule == "custom" else {})
	lobby_status.emit("席位已更新：%s" % mode_name())

@rpc("authority", "call_remote", "reliable")
func room_seats(data: Array, code: String, mode: String, rule: String = "standard", custom_cfg: Dictionary = {}) -> void:
	party_rule = rule
	room_code = code
	room_mode = mode
	if rule == "custom" and not custom_cfg.is_empty():
		BATTLE_MODES.set_custom_config(custom_cfg)
	seats.clear()
	for s in data:
		seats.append(s.duplicate(true))
	seats_changed.emit()
	lobby_status.emit("房间 %s · %s" % [room_code, room_mode])

func claim_seat(team: int, idx: int) -> void:
	rpc_id(1, "request_claim_seat", team, idx)

@rpc("any_peer", "call_remote", "reliable")
func request_claim_seat(team: int, idx: int) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	if not players.has(pid):
		return
	var target: Dictionary = {}
	for s in seats:
		if int(s.team) == team and int(s.idx) == idx:
			target = s
			break
	if target.is_empty() or int(target.peer) == 1:
		return
	# 清空该玩家旧席位（变 AI）
	for s in seats:
		if int(s.peer) == pid and not (int(s.team) == team and int(s.idx) == idx):
			s.peer = 0; s.name = "AI"; s.ai = true
	target.peer = pid
	target.name = String(players[pid].name)
	target.ai = false
	target.tower_choice = int(players[pid].get("tower_choice", 1))
	target.avatar_seed = int(players[pid].get("avatar_seed", 0))
	target.avatar_index = int(players[pid].get("avatar_index", 0))
	_broadcast_seats()
	seats_changed.emit()

func remove_seat(team: int, idx: int) -> bool:
	if role != Role.HOST:
		return false
	var team_seats := seats_in_team(team)
	if idx < 0 or idx >= team_seats.size():
		return false
	var target: Dictionary = team_seats[idx]
	var pid := int(target.get("peer", 0))
	if pid > 1:
		rpc_id(pid, "you_are_kicked")
		players.erase(pid)
		if peer:
			peer.disconnect_peer(pid)
	seats.erase(target)
	var n := 0
	for s in seats:
		if int(s.team) == team:
			s.idx = n
			n += 1
	room_mode = mode_name()
	_broadcast_seats()
	seats_changed.emit()
	return true

func destroy_room() -> void:
	if role != Role.HOST:
		return
	rpc("room_destroyed")
	reset_net()
	lobby_status.emit("房间已销毁")
	room_closed.emit()

@rpc("authority", "call_remote", "reliable")
func you_are_kicked() -> void:
	reset_net()
	lobby_status.emit("你已被房主移出房间")
	room_closed.emit()

@rpc("authority", "call_remote", "reliable")
func room_destroyed() -> void:
	reset_net()
	lobby_status.emit("房主已销毁房间")
	room_closed.emit()

func all_players_seated() -> bool:
	if role != Role.HOST:
		return false
	var seated := 0
	for pid in players.keys():
		for s in seats:
			if int(s.peer) == int(pid):
				seated += 1
				break
	return seated >= players.size()

func can_start() -> bool:
	return role == Role.HOST and all_players_seated()


func join_host(ip: String, port: int = DEFAULT_PORT, code: String = "") -> bool:
	reset_net()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		peer = null
		lobby_status.emit("连接失败：%s" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	role = Role.GUEST
	_pending_code = code.strip_edges()
	print("NET join ", ip, ":", port, " code=", code)
	set_process(true)
	return true


func submit_local_draft_deck(deck: Array) -> void:
	var d: Array = []
	for cid in deck:
		if d.size() < 8:
			d.append(int(cid))
	if role == Role.HOST:
		network_draft_decks[1] = d
		if OS.get_environment("CR_MODE_DEBUG") != "":
			print("[DraftNet] host submit deck=", str(d))
		_check_network_draft()
	else:
		if OS.get_environment("CR_MODE_DEBUG") != "":
			print("[DraftNet] guest submit deck=", str(d))
		rpc_id(1, "submit_network_draft_deck", d)


func submit_local_swap_draft(picks: Array, rejects: Array) -> void:
	var p: Array = []
	for cid in picks:
		if p.size() < 4:
			p.append(int(cid))
	var r: Array = []
	for cid in rejects:
		if r.size() < 4:
			r.append(int(cid))
	if role == Role.HOST:
		network_draft_picks[1] = p
		network_draft_rejects[1] = r
		if OS.get_environment("CR_MODE_DEBUG") != "":
			print("[DraftNet] host swap picks=", str(p), " rejects=", str(r))
		_check_network_draft()
	else:
		if OS.get_environment("CR_MODE_DEBUG") != "":
			print("[DraftNet] guest swap picks=", str(p), " rejects=", str(r))
		rpc_id(1, "submit_network_swap_draft", p, r)


@rpc("any_peer", "call_remote", "reliable")
func submit_network_swap_draft(picks: Array, rejects: Array) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	var p: Array = []
	for cid in picks:
		if p.size() < 4:
			p.append(int(cid))
	var r: Array = []
	for cid in rejects:
		if r.size() < 4:
			r.append(int(cid))
	network_draft_picks[pid] = p
	network_draft_rejects[pid] = r
	if OS.get_environment("CR_MODE_DEBUG") != "":
		print("[DraftNet] host recv swap peer=", pid, " picks=", str(p), " rejects=", str(r))
	_check_network_draft()


func _build_network_swap_decks() -> void:
	var order: Array = _draft_required_peers()
	network_draft_decks.clear()
	var used: Array = []
	var all_cards: Array = []
	for pid in order:
		for cid in network_draft_picks.get(pid, []):
			if not all_cards.has(int(cid)):
				all_cards.append(int(cid))
		for cid in network_draft_rejects.get(pid, []):
			if not all_cards.has(int(cid)):
				all_cards.append(int(cid))
	for i in range(order.size()):
		var cur: int = int(order[i])
		var nxt: int = int(order[(i + 1) % order.size()])
		var deck: Array = []
		var candidates: Array = []
		for cid in network_draft_picks.get(cur, []):
			candidates.append(int(cid))
		for cid in network_draft_rejects.get(nxt, []):
			candidates.append(int(cid))
		for cid in all_cards:
			candidates.append(int(cid))
		for cid in candidates:
			if deck.size() >= 8:
				break
			if used.has(cid) or deck.has(cid):
				continue
			deck.append(cid)
			used.append(cid)
		network_draft_decks[cur] = deck
		if OS.get_environment("CR_MODE_DEBUG") != "":
			print("[DraftNet] swap deck for ", cur, " unique=", str(deck))


@rpc("any_peer", "call_remote", "reliable")
func submit_network_draft_deck(deck: Array) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	var d: Array = []
	for cid in deck:
		if d.size() < 8:
			d.append(int(cid))
	network_draft_decks[pid] = d
	if OS.get_environment("CR_MODE_DEBUG") != "":
		print("[DraftNet] host recv peer=", pid, " deck=", str(d), " have=", str(network_draft_decks.keys()))
	_check_network_draft()


func _draft_required_peers() -> Array:
	var out: Array = [1]
	for s in seats:
		if not bool(s.get("ai", false)) and int(s.get("peer", 0)) > 1:
			if not out.has(int(s.peer)):
				out.append(int(s.peer))
	return out

func _check_network_draft() -> void:
	if role != Role.HOST:
		return
	if network_draft_swap:
		if not network_draft_picks.has(1) or not network_draft_rejects.has(1):
			return
		for pid in _draft_required_peers():
			if int(pid) == 1:
				continue
			if not network_draft_picks.has(int(pid)) or not network_draft_rejects.has(int(pid)):
				return
		_build_network_swap_decks()
	else:
		if not network_draft_decks.has(1):
			return
		for pid in _draft_required_peers():
			if int(pid) == 1:
				continue
			if not network_draft_decks.has(int(pid)):
				return
	if OS.get_environment("CR_MODE_DEBUG") != "":
		print("[DraftNet] all ready, begin")
	rpc("network_draft_begin")
	network_draft_started.emit()


@rpc("authority", "call_remote", "reliable")
func network_draft_begin() -> void:
	network_draft_started.emit()


func send_touchdown_break(round_no: int, score_a: int, score_b: int) -> void:
	if role == Role.HOST:
		rpc("touchdown_break", round_no, score_a, score_b)


@rpc("authority", "call_remote", "reliable")
func touchdown_break(round_no: int, score_a: int, score_b: int) -> void:
	touchdown_break_received.emit(round_no, score_a, score_b)


func send_touchdown_break_end() -> void:
	if role == Role.HOST:
		rpc("touchdown_break_end")


@rpc("authority", "call_remote", "reliable")
func touchdown_break_end() -> void:
	touchdown_break_ended.emit()


func sync_room() -> void:
	if role == Role.HOST:
		_broadcast_seats()
		seats_changed.emit()


func start_match() -> void:
	if role != Role.HOST or not can_start():
		return
	network_draft_decks.clear()
	network_draft_picks.clear()
	network_draft_rejects.clear()
	network_draft_swap = party_rule == "swap_draft"
	room_mode = mode_name()
	var base := {
		"mode": room_mode,
		"party_rule": party_rule,
		"custom_config": BATTLE_MODES.custom_config() if party_rule == "custom" else {},
		"room_code": room_code,
		"seats": _seat_public(),
		"arena": PlayerData.get_arena(),
		"draft_seed": randi(),
	}
	for pid in players.keys():
		if pid == 1:
			continue
		var st := -1
		var si := -1
		for s in seats:
			if int(s.peer) == int(pid):
				st = int(s.team); si = int(s.idx)
				break
		var info := base.duplicate(true)
		info["local_slot"] = st * 2 + si
		info["local_team"] = st
		rpc_id(pid, "match_start", info)
	match_info = base.duplicate(true)
	match_info["local_slot"] = 0
	match_info["local_team"] = 0
	host_match_pending = true
	ready_peers.clear()
	clients_all_ready = false
	_required_peers = _guest_pids()
	match_started.emit(match_info)


@rpc("any_peer", "call_remote", "reliable")
func request_join(code: String, deck: Array, levels: Dictionary, pname: String, tower_choice: int = 1, avatar_seed: int = 0, avatar_index: int = 0) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	if code.strip_edges() != room_code:
		rpc_id(pid, "join_rejected", "房间码错误")
		return
	if not players.has(pid):
		var d: Array = []
		for cid in deck:
			if d.size() < 8: d.append(int(cid))
		players[pid] = {"name": pname, "deck": d, "levels": levels.duplicate(true), "seated": false, "tower_choice": tower_choice, "avatar_seed": avatar_seed, "avatar_index": avatar_index}
		if guest_peer_id == 0:
			guest_peer_id = pid
			guest_name = pname
			guest_deck = d.duplicate()
			guest_levels = levels.duplicate(true)
	rpc_id(pid, "join_accepted", room_code, mode_name())
	_broadcast_seats()
	seats_changed.emit()
	lobby_status.emit("%s 已进入房间（%d 人）" % [pname, players.size()])


@rpc("authority", "call_remote", "reliable")
func join_rejected(reason: String) -> void:
	lobby_status.emit(reason)

@rpc("authority", "call_remote", "reliable")
func join_accepted(code: String, mode: String) -> void:
	room_mode = mode
	joined_room.emit()
	lobby_status.emit("已加入 %s 房间 %s" % [mode, code])

@rpc("authority", "call_remote", "reliable")
func match_start(info: Dictionary) -> void:
	match_info = info
	local_slot = int(info.get("local_slot", 0))
	local_team = int(info.get("local_team", 0))
	room_mode = String(info.get("mode", "1v1"))
	party_rule = String(info.get("party_rule", "standard"))
	if party_rule == "custom" and info.get("custom_config", {}) is Dictionary:
		BATTLE_MODES.set_custom_config(Dictionary(info.get("custom_config", {})))
	match_started.emit(info)

@rpc("any_peer", "call_remote", "reliable")
func net_deploy_request(card_id: int, x: float, z: float) -> void:
	if role != Role.HOST:
		return
	var pid := multiplayer.get_remote_sender_id()
	if not players.has(pid):
		return
	var slot := -1
	for s in seats:
		if int(s.peer) == int(pid):
			slot = int(s.team) * 2 + int(s.idx)
			break
	if slot < 0:
		return
	var b = get_tree().get_first_node_in_group("battle_manager")
	if b and b.has_method("network_remote_deploy_slot"):
		var reason: String = b.network_remote_deploy_slot(slot, card_id, x, z)
		if reason != "":
			rpc_id(pid, "net_deploy_rejected", reason)

@rpc("authority", "call_remote", "reliable")
func net_deploy_rejected(reason: String) -> void:
	deploy_rejected.emit(reason)

func consume_host_match() -> bool:
	var pending := host_match_pending
	host_match_pending = false
	return pending

func guest_count() -> int:
	return _guest_pids().size()

func all_clients_ready() -> bool:
	return clients_all_ready

func client_ready() -> void:
	if role == Role.GUEST:
		rpc_id(1, "net_client_ready")

@rpc("any_peer", "call_remote", "reliable")
func net_client_ready() -> void:
	if role != Role.HOST:
		return
	ready_peers[multiplayer.get_remote_sender_id()] = true
	var all_ok := true
	for pid in _required_peers:
		if not ready_peers.has(pid):
			all_ok = false
			break
	if all_ok:
		clients_all_ready = true
		clients_ready.emit()

func request_deploy(card_id: int, x: float, z: float) -> void:
	if role == Role.GUEST and peer:
		rpc_id(1, "net_deploy_request", card_id, x, z)

func _guest_pids() -> Array:
	var out: Array = []
	for pid in players.keys():
		if pid != 1:
			out.append(pid)
	return out

func send_snapshot(snap: Dictionary) -> void:
	if role == Role.HOST and peer:
		var data := var_to_bytes(snap)
		for pid in _guest_pids():
			rpc_id(pid, "net_snapshot", data)

@rpc("authority", "call_remote", "reliable")
func net_snapshot(data: PackedByteArray) -> void:
	var snap = bytes_to_var(data)
	if snap is Dictionary:
		last_snapshot = snap
		snapshot_received.emit(snap)

@rpc("any_peer", "call_remote", "reliable")
func net_emote(id: String, team: int) -> void:
	if role == Role.HOST:
		var b = get_tree().get_first_node_in_group("battle_manager")
		if b and b.hud:
			b.hud.show_emote(id, team)
		for pid in _guest_pids():
			rpc_id(pid, "net_emote", id, team)
	else:
		emote_received.emit(id, team)

func send_emote(id: String, team: int) -> void:
	if role == Role.GUEST:
		rpc_id(1, "net_emote", id, team)

func broadcast_emote(id: String, team: int) -> void:
	if role == Role.HOST:
		for pid in _guest_pids():
			rpc_id(pid, "net_emote", id, team)

func send_entry_start() -> void:
	if role != Role.HOST:
		return
	for pid in _guest_pids():
		rpc_id(pid, "net_entry_start")

@rpc("authority", "call_remote", "reliable")
func net_entry_start() -> void:
	entry_started.emit()

func send_countdown(seconds: float) -> void:
	if role != Role.HOST:
		return
	for pid in _guest_pids():
		rpc_id(pid, "net_countdown", seconds)

@rpc("authority", "call_remote", "reliable")
func net_countdown(seconds: float) -> void:
	countdown_received.emit(seconds)

func send_match_end(winner: int, crowns: Array, duration: float = 0.0, extra: Dictionary = {}) -> void:
	if role != Role.HOST:
		return
	for pid in _guest_pids():
		rpc_id(pid, "net_match_end", winner, crowns, duration, extra)

@rpc("authority", "call_remote", "reliable")
func net_match_end(winner: int, crowns: Array, duration: float = 0.0, extra: Dictionary = {}) -> void:
	var info := {"winner": winner, "crowns": crowns, "duration": duration}
	for k in extra.keys():
		info[k] = extra[k]
	match_info["result"] = info
	match_ended.emit(info)

func _on_connected_to_server():
	if role != Role.GUEST:
		return
	var deck := PlayerData.get_active_deck().duplicate()
	var levels := {}
	for cid in deck:
		levels[str(int(cid))] = PlayerData.get_card_level(int(cid))
	print("NET guest connected, request join")
	rpc_id(1, "request_join", _pending_code, deck, levels, PlayerData.player_name, PlayerData.tower_choice, PlayerData.avatar_seed, PlayerData.avatar_index)
	lobby_status.emit("已连接，正在加入房间…")

func _on_connection_failed():
	if role == Role.GUEST:
		lobby_status.emit("连接失败，请检查 IP / WiFi")
		reset_net()

func _on_server_disconnected():
	disconnected.emit("房主已断开")
	reset_net()

func _on_peer_connected(pid: int):
	print("NET peer_connected pid=", pid, " role=", role)

func _on_peer_disconnected(pid: int):
	if players.has(pid):
		players.erase(pid)
		var lost_slot := -1
		for s in seats:
			if int(s.peer) == pid:
				lost_slot = int(s.team) * 2 + int(s.idx)
				s.peer = 0
				s.name = "AI"
				s.ai = true
		if role == Role.HOST and lost_slot >= 0:
			var b = get_tree().get_first_node_in_group("battle_manager")
			if b and b.has_method("network_ai_takeover"):
				b.network_ai_takeover(lost_slot)
		if pid == guest_peer_id:
			guest_peer_id = 0
		_broadcast_seats()
		lobby_status.emit("玩家已断开，席位由 AI 接管")
		if role == Role.HOST:
			var b = get_tree().get_first_node_in_group("battle_manager")
			if b and b.has_method("network_ai_takeover") and seats.size() > 0:
				# 找到断线玩家原席位对应的全局 slot
				pass

func reset_net():
	if peer:
		peer.close()
	peer = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	room_code = ""
	room_mode = "1v1"
	players.clear()
	seats.clear()
	local_slot = 0
	local_team = 0
	local_seat_team = -1
	local_seat_idx = -1
	guest_peer_id = 0
	guest_name = ""
	guest_deck.clear()
	guest_levels.clear()
	match_info.clear()
	last_snapshot.clear()
	ready_peers.clear()
	clients_all_ready = false
	_required_peers.clear()
	set_process(false)
