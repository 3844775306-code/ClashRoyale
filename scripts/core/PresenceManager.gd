extends Node
# Supabase 在线状态：定期心跳写入 presence:<scoped_id>，客户端定期拉取。
# 在线判定：last_seen 与当前时间相差 <= ONLINE_WINDOW 秒。

const HEARTBEAT_SEC := 12.0
const PULL_SEC := 10.0
const ONLINE_WINDOW := 35
const PREFIX := "presence:"

var records: Dictionary = {}      # scoped_id -> {last_seen,name,avatar_seed,avatar_index,trophies,clan}
var _hb_acc := 0.0
var _pull_acc := 0.0
var _publishing := false
var _pulling := false
var _active := false


func _ready() -> void:
	set_process(false)
	if AccountManager and not AccountManager.session_changed.is_connected(_on_session_changed):
		AccountManager.session_changed.connect(_on_session_changed)
	if AccountManager and AccountManager.is_supabase_authenticated():
		_start()


func _on_session_changed() -> void:
	if AccountManager and AccountManager.is_supabase_authenticated():
		_start()
	else:
		_active = false
		set_process(false)


func _start() -> void:
	if _active:
		return
	_active = true
	_hb_acc = HEARTBEAT_SEC
	_pull_acc = PULL_SEC
	set_process(true)
	_publish()
	_pull()


func _process(delta: float) -> void:
	if not _active or not AccountManager.is_supabase_authenticated():
		return
	_hb_acc += delta
	_pull_acc += delta
	if _hb_acc >= HEARTBEAT_SEC:
		_hb_acc = 0.0
		_publish()
	if _pull_acc >= PULL_SEC:
		_pull_acc = 0.0
		_pull()


func _my_id() -> String:
	return str(ClanManager.get_player_id())


func _publish() -> void:
	if _publishing or not AccountManager.is_supabase_authenticated():
		return
	var pid := _my_id()
	if pid == "" or pid == "0":
		return
	_publishing = true
	var ok: bool = await SupabaseAPI.upsert(PREFIX + pid, {
		"scoped_id": pid,
		"account_id": String(AccountManager.account_id),
		"name": PlayerData.player_name,
		"avatar_seed": PlayerData.avatar_seed,
		"avatar_index": PlayerData.avatar_index,
		"trophies": PlayerData.trophies,
		"clan": ClanManager.get_my_clan_name() if ClanManager.has_method("get_my_clan_name") else "",
		"last_seen": int(Time.get_unix_time_from_system()),
	})
	_publishing = false
	if not ok:
		push_warning("[Presence] heartbeat failed")


func _pull() -> void:
	if _pulling or not AccountManager.is_supabase_authenticated():
		return
	_pulling = true
	var rows: Array = await SupabaseAPI.list_prefix(PREFIX, 500)
	var now := int(Time.get_unix_time_from_system())
	for row in rows:
		if not (row is Dictionary):
			continue
		var v = row.get("value", {})
		if not (v is Dictionary):
			continue
		var pid := String(v.get("scoped_id", ""))
		if pid == "":
			continue
		var last := int(v.get("last_seen", 0))
		if last > 0 and now - last <= ONLINE_WINDOW:
			records[pid] = v
		else:
			records[pid] = v
	_pulling = false


func is_known(pid: String) -> bool:
	return records.has(pid)


func is_online(pid: String) -> bool:
	if pid == "":
		return false
	if pid == _my_id():
		return true
	var v = records.get(pid, null)
	if not (v is Dictionary):
		return false
	return int(Time.get_unix_time_from_system()) - int(v.get("last_seen", 0)) <= ONLINE_WINDOW


func last_seen(pid: String) -> int:
	var v = records.get(pid, null)
	return int(v.get("last_seen", 0)) if v is Dictionary else 0


func last_seen_text(pid: String) -> String:
	var ts := last_seen(pid)
	if ts <= 0:
		return "上次在线：未知"
	var now := int(Time.get_unix_time_from_system())
	var diff := maxi(0, now - ts)
	if diff < 60:
		return "上次在线：刚刚"
	if diff < 3600:
		return "上次在线：%d 分钟前" % (diff / 60)
	if diff < 86400:
		return "上次在线：%d 小时前" % (diff / 3600)
	var d := Time.get_datetime_dict_from_unix_time(ts)
	return "上次在线：%d-%02d-%02d %02d:%02d" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute)]


func status_text(pid: String) -> String:
	return "在线" if is_online(pid) else last_seen_text(pid)
