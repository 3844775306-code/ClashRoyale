extends Node
signal presence_changed
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
var local_battle_active := false
var local_battle_mode := ""
var local_battle_started := 0
var local_battle_room := ""
var local_battle_transport := ""
var local_battle_ip := ""
var local_battle_spectators := 0


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
		"battle_active": local_battle_active,
		"battle_mode": local_battle_mode,
		"battle_started": local_battle_started,
		"battle_room": local_battle_room,
		"battle_transport": local_battle_transport,
		"battle_ip": local_battle_ip,
		"battle_spectators": local_battle_spectators,
		"battle_wins": PlayerData.battle_wins,
		"battle_losses": PlayerData.battle_losses,
		"battle_draws": PlayerData.battle_draws,
		"three_crowns": PlayerData.three_crown_wins,
		"current_streak": PlayerData.current_streak,
		"best_streak": PlayerData.best_streak,
		"season_crowns": PlayerData.season_crowns,
		"honor_title": PlayerData.honor_title,
		"tower_choice": PlayerData.tower_choice,
		"tower_used": PlayerData.get_most_used_tower(),
		"bio": PlayerData.bio,
		"role": PlayerData.clan_role,
		"donations": PlayerData.total_donations,
		"collection_level": PlayerData.get_collection_level(),
		"current_deck": PlayerData.get_active_deck(),
		"top_cards": PlayerData.get_most_used_cards(3),
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
	var before := JSON.stringify(records)
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
	if JSON.stringify(records) != before:
		presence_changed.emit()


func set_battle_spectators(n: int) -> void:
	local_battle_spectators = n
	if _active:
		_publish()


func set_battle_status(active: bool, mode: String = "", started: int = 0, room: String = "", transport: String = "", ip: String = "") -> void:
	local_battle_active = active
	local_battle_mode = mode
	local_battle_started = started
	local_battle_room = room
	local_battle_transport = transport
	local_battle_ip = ip
	if not active:
		local_battle_spectators = 0
	if _active:
		_publish()


func get_battle_info(pid: String) -> Dictionary:
	if pid == "":
		return {}
	if pid == _my_id():
		return {
			"battle_active": local_battle_active,
			"battle_mode": local_battle_mode,
			"battle_started": local_battle_started,
		}
	if not is_online(pid):
		return {}
	var v = records.get(pid, null)
	if not (v is Dictionary):
		return {}
	return {
		"battle_active": bool(v.get("battle_active", false)),
		"battle_mode": String(v.get("battle_mode", "")),
		"battle_started": int(v.get("battle_started", 0)),
		"battle_room": String(v.get("battle_room", "")),
		"battle_transport": String(v.get("battle_transport", "")),
		"battle_ip": String(v.get("battle_ip", "")),
		"battle_spectators": int(v.get("battle_spectators", 0)),
	}


func public_record(pid: String) -> Dictionary:
	if pid == _my_id():
		var d := {
			"name": PlayerData.player_name,
			"trophies": PlayerData.trophies,
			"highest_trophies": PlayerData.highest_trophies,
			"arena": PlayerData.get_arena(),
			"clan": ClanManager.get_my_clan_name() if ClanManager.has_method("get_my_clan_name") else "",
			"battle_wins": PlayerData.battle_wins,
			"battle_losses": PlayerData.battle_losses,
			"battle_draws": PlayerData.battle_draws,
			"three_crowns": PlayerData.three_crown_wins,
			"current_streak": PlayerData.current_streak,
			"best_streak": PlayerData.best_streak,
			"season_crowns": PlayerData.season_crowns,
			"honor_title": PlayerData.honor_title,
			"tower_choice": PlayerData.tower_choice,
			"tower_used": PlayerData.get_most_used_tower(),
			"bio": PlayerData.bio,
			"role": PlayerData.clan_role,
			"donations": PlayerData.total_donations,
			"collection_level": PlayerData.get_collection_level(),
			"current_deck": PlayerData.get_active_deck(),
			"avatar_seed": PlayerData.avatar_seed,
			"avatar_index": PlayerData.avatar_index,
		}
		d.merge(get_battle_info(pid), true)
		return d
	var v = records.get(pid, null)
	return Dictionary(v).duplicate(true) if v is Dictionary else {}


func online_players() -> Array:
	var out: Array = []
	var me := _my_id()
	for pid in records.keys():
		if String(pid) == me:
			continue
		if not is_online(String(pid)):
			continue
		var v = records[pid]
		if not (v is Dictionary):
			continue
		var p: Dictionary = v.duplicate(true)
		p["player_id"] = String(pid)
		p["name"] = String(v.get("name", "玩家"))
		out.append(p)
	out.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	return out

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
