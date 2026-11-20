extends Node
# 跨网 WebRTC 传输：房主可接受多个 Guest（2v2 最多 3 个客户端）。

signal status(text: String)
signal connected(peer_id: int)
signal failed(reason: String)
signal message_received(method: String, args: Array, sender_id: int)

const ROOM_PREFIX := "rtc_room:"
const CLAIM_PREFIX := "rtc_claim:"
const OFFER_PREFIX := "rtc_offer:"
const ANSWER_PREFIX := "rtc_answer:"
const ICE_PREFIX := "rtc_ice:"
const TURN_CFG := "user://webrtc_turn.cfg"

func _turn_cfg_path() -> String:
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("shared_data_path"):
		return String(am.shared_data_path("webrtc_turn.cfg"))
	return TURN_CFG
const HOST_ID := 1

var active := false
var is_host := false
var room_code := ""
var local_id := 0
var sessions: Dictionary = {}
var _guest_slot := 0
var _poll_acc := 0.0
var _polling := false
var _started_at := 0
var _ice_seen: Dictionary = {}
var _ice_seq := 0


func _ready() -> void:
	set_process(false)


func turn_config() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(_turn_cfg_path())
	var env_url := OS.get_environment("CR_TURN_URL").strip_edges()
	var mode := String(cfg.get_value("turn", "mode", "manual"))
	if env_url != "":
		mode = "manual"
	return {
		"url": env_url if env_url != "" else String(cfg.get_value("turn", "url", "")),
		"user": OS.get_environment("CR_TURN_USER") if OS.get_environment("CR_TURN_USER") != "" else String(cfg.get_value("turn", "user", "")),
		"pass": OS.get_environment("CR_TURN_PASS") if OS.get_environment("CR_TURN_PASS") != "" else String(cfg.get_value("turn", "pass", "")),
		"mode": mode,
		"expires": int(cfg.get_value("turn", "expires", 0)),
	}


func save_turn_config(url: String, user: String, password: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("turn", "url", url.strip_edges())
	cfg.set_value("turn", "user", user.strip_edges())
	cfg.set_value("turn", "pass", password)
	cfg.set_value("turn", "mode", "manual")
	cfg.set_value("turn", "expires", 0)
	cfg.save(_turn_cfg_path())


func _save_cloudflare_turn(url: String, user: String, password: String, expires: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("turn", "url", url)
	cfg.set_value("turn", "user", user)
	cfg.set_value("turn", "pass", password)
	cfg.set_value("turn", "mode", "cloudflare")
	cfg.set_value("turn", "expires", expires)
	cfg.save(_turn_cfg_path())


func _pick_ice_url(urls: Array) -> String:
	var all: Array = []
	for u in urls:
		if u is Array:
			for x in u: all.append(String(x))
		else:
			all.append(String(u))
	for u in all:
		if u.begins_with("turns:") and u.contains(":443") and u.contains("transport=tcp"):
			return u
	for u in all:
		if u.begins_with("turns:") and u.contains(":443"):
			return u
	for u in all:
		if u.begins_with("turn:"):
			return u
	return all[0] if not all.is_empty() else ""


func fetch_cloudflare_turn(ttl: int = 7200) -> Dictionary:
	if not AccountManager.is_supabase_authenticated():
		return {"ok": false, "error": "请先登录 Supabase"}
	var r: Dictionary = await SupabaseAPI.edge_function("turn-credentials", {"ttl": ttl})
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "Cloudflare TURN 获取失败"))}
	var servers: Array = Array(r.get("iceServers", []))
	for s in servers:
		if not (s is Dictionary): continue
		var urls: Array = Array(s.get("urls", []))
		var url := _pick_ice_url(urls)
		if url == "" or not url.contains("turn"):
			continue
		var user := String(s.get("username", ""))
		var cred := String(s.get("credential", s.get("password", "")))
		if user == "" or cred == "":
			continue
		var exp := int(r.get("expires_at", int(Time.get_unix_time_from_system()) + ttl))
		_save_cloudflare_turn(url, user, cred, exp)
		return {"ok": true, "url": url, "expires_at": exp}
	return {"ok": false, "error": "Cloudflare 未返回 TURN 凭据"}


func _ensure_turn() -> void:
	var c := turn_config()
	if String(c.get("mode", "")) != "cloudflare":
		return
	var exp := int(c.get("expires", 0))
	if exp > int(Time.get_unix_time_from_system()) + 120:
		return
	var r: Dictionary = await fetch_cloudflare_turn()
	if not bool(r.get("ok", false)):
		status.emit("Cloudflare TURN 刷新失败：%s" % String(r.get("error", "")))


func turn_summary() -> String:
	var c := turn_config()
	if String(c.get("url", "")) == "":
		return "TURN 未配置"
	if String(c.get("mode", "")) == "cloudflare":
		var left := maxi(0, int(c.get("expires", 0)) - int(Time.get_unix_time_from_system()))
		return "Cloudflare TURN（剩余 %d 分钟）" % int(left / 60)
	return "TURN 已配置"


func _ice_servers() -> Array:
	var out: Array = [{"urls": ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"]}]
	var c := turn_config()
	if String(c.get("url", "")) != "":
		out.append({"urls": [String(c.get("url", ""))], "username": String(c.get("user", "")), "credential": String(c.get("pass", ""))})
	return out


func _new_session(peer_id: int, remote_id: int, host_side: bool) -> Dictionary:
	var pc := WebRTCPeerConnection.new()
	var s := {
		"peer_id": peer_id, "remote_id": remote_id, "pc": pc,
		"control": null, "fast": null, "connected": false,
		"offer": "", "answer": "", "offer_ready": false, "answer_ready": false,
		"offer_written": false, "answer_written": false, "remote_set": false,
		"pending_ice": [],
	}
	var err := pc.initialize({"ice_servers": _ice_servers()})
	if err != OK:
		failed.emit("WebRTC 初始化失败")
		return s
	if host_side:
		s["control"] = pc.create_data_channel("control", {})
		s["fast"] = pc.create_data_channel("fast", {"ordered": false, "maxRetransmits": 0})
		pc.session_description_created.connect(_on_host_sdp.bind(s))
		pc.ice_candidate_created.connect(_on_ice.bind(s))
	else:
		pc.data_channel_received.connect(_on_guest_channel.bind(s))
		pc.session_description_created.connect(_on_guest_sdp.bind(s))
		pc.ice_candidate_created.connect(_on_ice.bind(s))
	return s


func host_room() -> bool:
	_reset_local()
	if not SupabaseAPI.is_ready():
		failed.emit("请先登录 Supabase 账号")
		return false
	await _ensure_turn()
	is_host = true
	local_id = HOST_ID
	room_code = OS.get_environment("CR_RTC_ROOM").strip_edges()
	if room_code == "":
		room_code = "%06d" % randi_range(100000, 999999)
	active = true
	_started_at = Time.get_ticks_msec()
	await SupabaseAPI.upsert(ROOM_PREFIX + room_code, {
		"host_id": String(AccountManager.account_id), "host_name": PlayerData.player_name,
		"created": int(Time.get_unix_time_from_system()), "turn": turn_summary(),
	})
	set_process(true)
	status.emit("已创建跨网房间 %s（可加入 3 人）" % room_code)
	return true


func join_room(code: String) -> bool:
	_reset_local()
	if not SupabaseAPI.is_ready():
		failed.emit("请先登录 Supabase 账号")
		return false
	await _ensure_turn()
	is_host = false
	room_code = code.strip_edges()
	if room_code == "":
		return false
	active = true
	_started_at = Time.get_ticks_msec()
	status.emit("正在连接房间 %s…" % room_code)
	var room: Dictionary = await SupabaseAPI.get_value(ROOM_PREFIX + room_code)
	if room.is_empty():
		failed.emit("房间不存在")
		active = false
		return false
	var claims: Array = await SupabaseAPI.list_prefix(CLAIM_PREFIX + room_code + ":", 10)
	var used: Array = []
	for row in claims:
		var key := String(row.get("key", ""))
		var parts := key.split(":")
		if parts.size() >= 3:
			used.append(int(parts[2]))
	var slot := 0
	for cand in [2, 3, 4]:
		if not used.has(cand):
			slot = cand
			break
	if slot == 0:
		failed.emit("房间已满")
		active = false
		return false
	_guest_slot = slot
	local_id = slot
	await SupabaseAPI.upsert(CLAIM_PREFIX + room_code + ":" + str(slot), {
		"guest_id": String(AccountManager.account_id), "guest_name": PlayerData.player_name,
		"slot": slot, "created": int(Time.get_unix_time_from_system()),
	})
	var offer := ""
	for _i in range(16):
		var of: Dictionary = await SupabaseAPI.get_value(OFFER_PREFIX + room_code + ":" + str(slot))
		offer = String(of.get("offer", ""))
		if offer != "": break
		await get_tree().create_timer(0.5).timeout
	if offer == "":
		failed.emit("房主未响应")
		active = false
		return false
	var s := _new_session(slot, HOST_ID, false)
	sessions[slot] = s
	s.pc.set_remote_description("offer", offer)
	s["remote_set"] = true
	status.emit("已提交加入，等待 WebRTC 连接…")
	set_process(true)
	return true


func _on_host_sdp(type: String, sdp: String, s: Dictionary) -> void:
	if type != "offer": return
	s["offer"] = sdp
	s["offer_ready"] = true
	s.pc.set_local_description("offer", sdp)


func _on_guest_sdp(type: String, sdp: String, s: Dictionary) -> void:
	if type != "answer": return
	s["answer"] = sdp
	s["answer_ready"] = true
	s.pc.set_local_description("answer", sdp)


func _on_guest_channel(channel: WebRTCDataChannel, s: Dictionary) -> void:
	if channel == null: return
	var label := channel.get_label()
	if label == "control": s["control"] = channel
	elif label == "fast": s["fast"] = channel


func _on_ice(mid: String, index: int, name: String, s: Dictionary) -> void:
	if room_code == "": return
	_ice_seq += 1
	var role := "host" if is_host else "guest"
	var key := ICE_PREFIX + room_code + ":" + str(int(s.get("peer_id", 0))) + ":" + role + ":" + str(_ice_seq)
	_ice_seen[key] = true
	SupabaseAPI.upsert(key, {"mid": mid, "index": index, "name": name, "role": role, "slot": int(s.get("peer_id", 0)), "seq": _ice_seq})


func _process(delta: float) -> void:
	if not active: return
	for s in sessions.values():
		if s.get("pc"): s.pc.poll()
		_drain_session(s)
		_update_session(s)
	_poll_acc += delta
	if _poll_acc >= 0.6 and not _polling:
		_poll_acc = 0.0
		_polling = true
		await _poll_signaling()
		_polling = false
	if Time.get_ticks_msec() - _started_at > 60000 and not _any_connected():
		failed.emit("连接超时，请检查网络或配置 TURN")
		_reset_local()


func _any_connected() -> bool:
	for s in sessions.values():
		if bool(s.get("connected", false)): return true
	return false


func _update_session(s: Dictionary) -> void:
	var c: WebRTCDataChannel = s.get("control")
	var f: WebRTCDataChannel = s.get("fast")
	if c == null or f == null: return
	if c.get_ready_state() != WebRTCDataChannel.STATE_OPEN: return
	if f.get_ready_state() != WebRTCDataChannel.STATE_OPEN: return
	if bool(s.get("connected", false)): return
	s["connected"] = true
	status.emit("WebRTC 已连接：玩家 %d" % int(s.get("peer_id", 0)))
	connected.emit(int(s.get("peer_id", 0)))


func _poll_signaling() -> void:
	if not active or room_code == "": return
	if is_host:
		var claims: Array = await SupabaseAPI.list_prefix(CLAIM_PREFIX + room_code + ":", 10)
		for row in claims:
			var key := String(row.get("key", ""))
			var parts := key.split(":")
			if parts.size() < 3: continue
			var slot := int(parts[2])
			if sessions.has(slot): continue
			var s := _new_session(slot, slot, true)
			sessions[slot] = s
			s.pc.create_offer()
		for slot in sessions.keys():
			var s: Dictionary = sessions[slot]
			if bool(s.get("offer_ready", false)) and not bool(s.get("offer_written", false)):
				s["offer_written"] = true
				await SupabaseAPI.upsert(OFFER_PREFIX + room_code + ":" + str(slot), {"offer": String(s.get("offer", "")), "slot": slot})
			if not bool(s.get("remote_set", false)):
				var ans: Dictionary = await SupabaseAPI.get_value(ANSWER_PREFIX + room_code + ":" + str(slot))
				if String(ans.get("answer", "")) != "":
					s.pc.set_remote_description("answer", String(ans["answer"]))
					s["remote_set"] = true
					for c in s.get("pending_ice", []):
						s.pc.add_ice_candidate(String(c.get("mid", "")), int(c.get("index", 0)), String(c.get("name", "")))
					s["pending_ice"] = []
	else:
		for slot in sessions.keys():
			var s: Dictionary = sessions[slot]
			if bool(s.get("answer_ready", false)) and not bool(s.get("answer_written", false)):
				s["answer_written"] = true
				await SupabaseAPI.upsert(ANSWER_PREFIX + room_code + ":" + str(slot), {"answer": String(s.get("answer", "")), "slot": slot})
	await _poll_ice()


func _poll_ice() -> void:
	var rows: Array = await SupabaseAPI.list_prefix(ICE_PREFIX + room_code + ":", 300)
	for row in rows:
		var key := String(row.get("key", ""))
		if _ice_seen.has(key): continue
		_ice_seen[key] = true
		var v = row.get("value", {})
		if not (v is Dictionary): continue
		var slot := int(v.get("slot", 0))
		var role := String(v.get("role", ""))
		if is_host and role == "host": continue
		if not is_host and role == "guest": continue
		var s: Dictionary = sessions.get(slot, {})
		if s.is_empty(): continue
		if bool(s.get("remote_set", false)):
			s.pc.add_ice_candidate(String(v.get("mid", "")), int(v.get("index", 0)), String(v.get("name", "")))
		else:
			var arr: Array = s.get("pending_ice", [])
			arr.append(v)
			s["pending_ice"] = arr


func _drain_session(s: Dictionary) -> void:
	for channel in [s.get("control"), s.get("fast")]:
		var dc: WebRTCDataChannel = channel
		if dc == null: continue
		while dc.get_available_packet_count() > 0:
			var msg = bytes_to_var(dc.get_packet())
			if msg is Dictionary:
				var sender := int(s.get("peer_id", 0)) if is_host else HOST_ID
				message_received.emit(String(msg.get("m", "")), Array(msg.get("a", [])), sender)


func send_message(method: String, args: Array, target: int = 0) -> void:
	if not active: return
	var payload := var_to_bytes({"m": method, "a": args})
	var list: Array = []
	if is_host:
		if target == 0:
			list = sessions.values()
		elif sessions.has(target):
			list = [sessions[target]]
	else:
		list = sessions.values()
	for s in list:
		var dc: WebRTCDataChannel = s.get("fast") if method == "net_snapshot" else s.get("control")
		if dc != null and dc.get_ready_state() == WebRTCDataChannel.STATE_OPEN and dc.put_packet(payload) != OK:
			pass


func broadcast_message(method: String, args: Array) -> void:
	send_message(method, args, 0)


func is_room_connected() -> bool:
	return _any_connected()


func _reset_local() -> void:
	for s in sessions.values():
		if s.get("pc"): s.pc.close()
	sessions.clear()
	_guest_slot = 0
	_ice_seen.clear()
	_ice_seq = 0
	_poll_acc = 0.0
	_polling = false
	active = false
	set_process(false)


func close_room() -> void:
	_reset_local()
	room_code = ""


func _exit_tree() -> void:
	close_room()
