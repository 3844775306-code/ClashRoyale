# scripts/data/CardAnimationStore.gd
# 卡牌实战动画录制存储：本地 JSON + Supabase 云端同步；播放优先云端。
extends RefCounted

const FILE_NAME := "card_animations.json"
const CLOUD_PREFIX := "cardanim:"
const LIBRARY_KEY := "cardanim:library"

static var _cloud_recs: Dictionary = {}
static var _cloud_loaded := false
static var _cloud_busy := false


static func _path() -> String:
	var dir := "user://"
	if PlayerData != null and String(PlayerData.account_save_path) != "":
		dir = String(PlayerData.account_save_path).get_base_dir() + "/"
	var p: String = dir + FILE_NAME
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p).get_base_dir())
	return ProjectSettings.globalize_path(p)


static func _pid() -> String:
	if ClanManager != null:
		return str(ClanManager.get_player_id())
	return ""


static func _cloud_key() -> String:
	# 动画演示是公共内容而非账号私有数据：使用全账号共享库
	return LIBRARY_KEY


static func _can_cloud() -> bool:
	return _pid() != "" and _pid() != "0" and AccountManager != null and AccountManager.is_supabase_authenticated()


static func _read_json(p: String) -> Dictionary:
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


static func load_all() -> Dictionary:
	var all := _read_json(ProjectSettings.globalize_path("user://" + FILE_NAME))
	var account := _read_json(_path())
	# 账号目录覆盖旧的全局 user:// 录制，同时兼容迁移前的本地文件
	for k in account.keys():
		all[k] = account[k]
	return all


static func _write_all(all: Dictionary) -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all, "\t"))
		f.close()


static func _key(card_name: String, mode: String) -> String:
	return "%s|%s" % [card_name, mode]


static func has_recording(card_name: String, mode: String) -> bool:
	var rec := get_recording(card_name, mode)
	return not rec.is_empty() and not (rec.get("events", []) as Array).is_empty()


static func get_recording(card_name: String, mode: String) -> Dictionary:
	var k := _key(card_name, mode)
	var cloud = _cloud_recs.get(k, null)
	if cloud is Dictionary and not (cloud.get("events", []) as Array).is_empty():
		return Dictionary(cloud).duplicate(true)
	var all := load_all()
	var data = all.get(k, {})
	return data if data is Dictionary else {}


static func save_recording(card_name: String, mode: String, events: Array, duration: float) -> bool:
	var all := load_all()
	all[_key(card_name, mode)] = {
		"card": card_name,
		"mode": mode,
		"duration": maxf(0.1, duration),
		"updated": Time.get_datetime_string_from_system(),
		"events": events,
	}
	_write_all(all)
	return true


static func remove_recording(card_name: String, mode: String) -> void:
	var all := load_all()
	all.erase(_key(card_name, mode))
	_write_all(all)


static func reset_cloud_cache() -> void:
	_cloud_recs.clear()
	_cloud_loaded = false


static func sync_from_cloud() -> bool:
	# 登录自动同步可能正在进行；等待它完成，避免播放时直接错过云端录制
	var wait := 0
	while _cloud_busy and wait < 240:
		wait += 1
		await Engine.get_main_loop().process_frame
	if _cloud_loaded:
		return true
	if _cloud_busy or not _can_cloud():
		return false
	_cloud_busy = true
	var res: Dictionary = await SupabaseAPI.get_value_status(_cloud_key())
	if not bool(res.get("ok", false)):
		_cloud_busy = false
		return false
	var v: Dictionary = Dictionary(res.get("value", {}))
	var local := load_all()
	_merge_cloud_payload(v, local)
	# 兼容旧版本按账号保存的云端录制，并让所有账号共享动画库
	var rows: Array = await SupabaseAPI.list_prefix(CLOUD_PREFIX, 300)
	for row in rows:
		if not (row is Dictionary):
			continue
		var k := String(row.get("key", ""))
		if k == LIBRARY_KEY:
			continue
		var rv = row.get("value", {})
		if rv is Dictionary:
			_merge_cloud_payload(Dictionary(rv), local)
	_write_all(local)
	_cloud_loaded = true
	_cloud_busy = false
	return true


static func _merge_cloud_payload(payload: Dictionary, local: Dictionary) -> void:
	var recs = payload.get("recordings", payload)
	if not (recs is Dictionary):
		return
	for k in recs.keys():
		var cv: Dictionary = Dictionary(recs[k])
		var lv = local.get(k, null)
		var existing = _cloud_recs.get(k, null)
		if existing is Dictionary:
			var et := String(existing.get("updated", ""))
			var ct := String(cv.get("updated", ""))
			if et != "" and ct != "" and et > ct:
				cv = Dictionary(existing)
		if lv is Dictionary:
			var lt := String(lv.get("updated", ""))
			var ct2 := String(cv.get("updated", ""))
			if lt != "" and ct2 != "" and lt > ct2:
				_cloud_recs[k] = Dictionary(lv)
				continue
		_cloud_recs[k] = cv
		local[k] = cv


static func upload_recording_to_cloud(card_name: String, mode: String, events: Array, duration: float) -> bool:
	if not _can_cloud():
		return false
	var synced: bool = await sync_from_cloud()
	if not synced:
		return false
	_cloud_recs[_key(card_name, mode)] = {
		"card": card_name,
		"mode": mode,
		"duration": maxf(0.1, duration),
		"updated": Time.get_datetime_string_from_system(),
		"events": events,
	}
	var ok: bool = await SupabaseAPI.upsert(_cloud_key(), {
		"recordings": _cloud_recs.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
	})
	return ok


static func upload_all_local_to_cloud() -> bool:
	if not _can_cloud():
		return false
	var local := load_all()
	var synced: bool = await sync_from_cloud()
	if not synced:
		return false
	if local.is_empty() and _cloud_recs.is_empty():
		return false
	for k in local.keys():
		var lv: Dictionary = Dictionary(local[k])
		var cv = _cloud_recs.get(k, null)
		if cv is Dictionary:
			var lt := String(lv.get("updated", ""))
			var ct := String(cv.get("updated", ""))
			if lt != "" and ct != "" and ct > lt:
				continue
		_cloud_recs[k] = lv
	var ok: bool = await SupabaseAPI.upsert(_cloud_key(), {
		"recordings": _cloud_recs.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
	})
	return ok
