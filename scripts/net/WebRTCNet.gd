extends Node
# WebRTC 1v1 跨局域网连接：Supabase 交换 SDP/ICE，DataChannel 承载现有联机消息。

signal status(text: String)
signal connected(peer_id: int)
signal failed(reason: String)
signal message_received(method: String, args: Array, sender_id: int)

const ROOM_PREFIX := "rtc_room:"
const ANSWER_PREFIX := "rtc_answer:"
const ICE_PREFIX := "rtc_ice:"
const HOST_ID := 1
const GUEST_ID := 2

var active := false
var is_host := false
var room_code := ""
var local_id := 0
var remote_id := 0

var _pc: WebRTCPeerConnection
var _control: WebRTCDataChannel
var _fast: WebRTCDataChannel
var _control_open := false
var _fast_open := false
var _connected_emitted := false
var _offer_done := false
var _answer_done := false
var _answer_written := false
var _room_written := false
var _remote_set := false
var _gathering_done := false
var _pending_offer := ""
var _pending_answer := ""
var _ice_seen: Dictionary = {}
var _ice_seq := 0
var _poll_acc := 0.0
var _polling := false
var _started_at := 0
var _pending_ice: Array = []


func _ready() -> void:
	set_process(false)


func _ice_servers() -> Array:
	var out: Array = [{"urls": ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"]}]
	var turn_url := OS.get_environment("CR_TURN_URL").strip_edges()
	if turn_url != "":
		out.append({
			"urls": [turn_url],
			"username": OS.get_environment("CR_TURN_USER"),
			"credential": OS.get_environment("CR_TURN_PASS"),
		})
	return out


func _reset_local() -> void:
	if _pc:
		_pc.close()
	_pc = null
	_control = null
	_fast = null
	_control_open = false
	_fast_open = false
	_connected_emitted = false
	_offer_done = false
	_answer_done = false
	_answer_written = false
	_room_written = false
	_remote_set = false
	_gathering_done = false
	_pending_offer = ""
	_pending_answer = ""
	_ice_seen.clear()
	_ice_seq = 0
	_poll_acc = 0.0
	_polling = false
	_pending_ice.clear()
	active = false
	set_process(false)


func _make_pc() -> void:
	_pc = WebRTCPeerConnection.new()
	var err := _pc.initialize({"ice_servers": _ice_servers()})
	if err != OK:
		failed.emit("WebRTC 初始化失败")
	_pc.session_description_created.connect(_on_sdp)
	_pc.ice_candidate_created.connect(_on_ice)
	_pc.data_channel_received.connect(_on_data_channel)
	if is_host:
		_control = _pc.create_data_channel("control", {})
		_fast = _pc.create_data_channel("fast", {"ordered": false, "maxRetransmits": 0})

func _on_data_channel(channel: WebRTCDataChannel) -> void:
	if channel == null:
		return
	var label := channel.get_label()
	if label == "control":
		_control = channel
	elif label == "fast":
		_fast = channel


func host_room() -> bool:
	_reset_local()
	if not SupabaseAPI.is_ready():
		failed.emit("请先登录 Supabase 账号")
		return false
	is_host = true
	local_id = HOST_ID
	remote_id = GUEST_ID
	room_code = OS.get_environment("CR_RTC_ROOM").strip_edges()
	if room_code == "":
		room_code = "%06d" % randi_range(100000, 999999)
	active = true
	_started_at = Time.get_ticks_msec()
	_make_pc()
	_pc.create_offer()
	set_process(true)
	status.emit("已创建跨网房间，等待好友加入：%s" % room_code)
	return true


func join_room(code: String) -> bool:
	_reset_local()
	if not SupabaseAPI.is_ready():
		failed.emit("请先登录 Supabase 账号")
		return false
	is_host = false
	local_id = GUEST_ID
	remote_id = HOST_ID
	room_code = code.strip_edges()
	if room_code == "":
		return false
	active = true
	_started_at = Time.get_ticks_msec()
	status.emit("正在连接房间 %s…" % room_code)
	var room: Dictionary = {}
	for _i in range(12):
		room = await SupabaseAPI.get_value(ROOM_PREFIX + room_code)
		if not room.is_empty() and String(room.get("offer", "")) != "":
			break
		await get_tree().create_timer(0.5).timeout
	if room.is_empty() or String(room.get("offer", "")) == "":
		failed.emit("房间不存在或房主尚未就绪")
		active = false
		return false
	_make_pc()
	_pending_offer = String(room.get("offer", ""))
	_pc.set_remote_description("offer", _pending_offer)
	_remote_set = true
	set_process(true)
	return true


func _on_sdp(type: String, sdp: String) -> void:
	if type == "offer":
		_pending_offer = sdp
		_pc.set_local_description("offer", sdp)
		_offer_done = true
	elif type == "answer":
		_pending_answer = sdp
		_pc.set_local_description("answer", sdp)
		_answer_done = true


func _on_ice(mid: String, index: int, name: String) -> void:
	if room_code == "":
		return
	_ice_seq += 1
	var key := ICE_PREFIX + room_code + ":" + ("host" if is_host else "guest") + ":" + str(_ice_seq)
	var data := {"mid": mid, "index": index, "name": name, "role": "host" if is_host else "guest"}
	_ice_seen[key] = true
	SupabaseAPI.upsert(key, data)


func _process(delta: float) -> void:
	if not active:
		return
	if _pc:
		_pc.poll()
	_drain_channel(_control)
	_drain_channel(_fast)
	_update_open()
	if _connected_emitted:
		return
	_poll_acc += delta
	if _poll_acc >= 0.6 and not _polling:
		_poll_acc = 0.0
		_polling = true
		await _poll_signaling()
		_polling = false
	if Time.get_ticks_msec() - _started_at > 45000 and not _connected_emitted:
		failed.emit("连接超时，请检查网络或配置 TURN")
		_reset_local()


func _update_open() -> void:
	if _control == null:
		return
	if not _control_open and _control.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_control_open = true
	if _fast and not _fast_open and _fast.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_fast_open = true
	if _control_open and _fast_open and not _connected_emitted:
		_connected_emitted = true
		status.emit("WebRTC 已连接")
		connected.emit(remote_id)


func _poll_signaling() -> void:
	if room_code == "" or not active:
		return
	if is_host:
		if _offer_done and not _room_written:
			_room_written = true
			await SupabaseAPI.upsert(ROOM_PREFIX + room_code, {
				"host_id": String(AccountManager.account_id),
				"host_name": PlayerData.player_name,
				"offer": _pending_offer,
				"created": int(Time.get_unix_time_from_system()),
			})
		if not _remote_set:
			var ans: Dictionary = await SupabaseAPI.get_value(ANSWER_PREFIX + room_code)
			var answer := String(ans.get("answer", ""))
			if answer != "":
				_pc.set_remote_description("answer", answer)
				_remote_set = true
	else:
		if _answer_done and not _answer_written:
			_answer_written = true
			await SupabaseAPI.upsert(ANSWER_PREFIX + room_code, {
				"guest_id": String(AccountManager.account_id),
				"guest_name": PlayerData.player_name,
				"answer": _pending_answer,
				"created": int(Time.get_unix_time_from_system()),
			})
	await _poll_ice()
	if _remote_set:
		for c in _pending_ice:
			_pc.add_ice_candidate(String(c.get("mid", "")), int(c.get("index", 0)), String(c.get("name", "")))
		_pending_ice.clear()


func _poll_ice() -> void:
	var rows: Array = await SupabaseAPI.list_prefix(ICE_PREFIX + room_code + ":", 200)
	for row in rows:
		var key := String(row.get("key", ""))
		if key == "" or _ice_seen.has(key):
			continue
		var v = row.get("value", {})
		if not (v is Dictionary):
			continue
		var role := String(v.get("role", ""))
		if (is_host and role == "host") or (not is_host and role == "guest"):
			_ice_seen[key] = true
			continue
		_ice_seen[key] = true
		if _remote_set:
			_pc.add_ice_candidate(String(v.get("mid", "")), int(v.get("index", 0)), String(v.get("name", "")))
		else:
			_pending_ice.append(v)


func _apply_ice_from_dc() -> void:
	pass


func is_room_connected() -> bool:
	return _connected_emitted

func send_message(method: String, args: Array, target: int = 0) -> void:
	if not active or _control == null or not _control_open:
		return
	var payload := var_to_bytes({"m": method, "a": args})
	var channel := _control
	if method == "net_snapshot" and _fast_open:
		channel = _fast
	channel.put_packet(payload)


func broadcast_message(method: String, args: Array) -> void:
	send_message(method, args, 0)


func _drain_channel(channel: WebRTCDataChannel) -> void:
	if channel == null:
		return
	while channel.get_available_packet_count() > 0:
		var bytes := channel.get_packet()
		var msg = bytes_to_var(bytes)
		if msg is Dictionary:
			message_received.emit(String(msg.get("m", "")), Array(msg.get("a", [])), remote_id)


func close_room() -> void:
	_reset_local()
	room_code = ""


func _exit_tree() -> void:
	close_room()
