# scripts/core/AccountManager.gd
# 账号系统：邮箱账号、按账号分目录存档、LootLocker 云存档、同设备 30 天免登录。
# 云端：LootLocker White Label 账号 + Player Files（玩家文件）存 JSON。
extends Node

signal session_changed
signal cloud_status_changed

const SESSION_DAYS := 30
const CLOUD_KEY := "cr_player_data"
const CLOUD_FILE := "player_data.json"

var is_authenticated: bool = false
var auto_login_pending: bool = false
var account_email: String = ""
var account_id: String = ""
var cloud_status: String = "未连接"
var last_error: String = ""
var offline_only: bool = false

var _busy := false
var _dirty := false
var _last_save_ms := 0
var _uploading := false
var _syncing := false
var _upload_retry_at := 0
var _session_online := false
var _fresh_account := false


func _data_dir() -> String:
	var env := OS.get_environment("CR_ACCOUNT_DATA_DIR")
	return env.trim_suffix("/") if env != "" else "user://"


func _ensure_data_dir() -> void:
	DirAccess.make_dir_recursive_absolute(_data_dir())


func session_path() -> String:
	return _data_dir().trim_suffix("/") + "/account_session.cfg"


func index_path() -> String:
	return _data_dir().trim_suffix("/") + "/accounts_index.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var skip := OS.get_environment("CR_SKIP_ACCOUNT") != ""
	if skip:
		is_authenticated = true
		account_email = ""
		account_id = "default"
		auto_login_pending = false
		cloud_status = "开发模式"
		return
	auto_login_pending = true
	call_deferred("_boot")


func _boot() -> void:
	_ensure_data_dir()
	offline_only = OS.get_environment("CR_ACCOUNT_OFFLINE") != ""
	var sess := _load_session()
	if sess.is_empty() or int(sess.get("expires", 0)) < int(Time.get_unix_time_from_system()):
		if FileAccess.file_exists(session_path()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(session_path()))
		auto_login_pending = false
		session_changed.emit()
		return
	account_email = String(sess.get("email", ""))
	account_id = String(sess.get("id", _make_id(account_email)))
	_session_online = bool(sess.get("online", false))
	_player_load_account(false)
	# 有本机最近账号时先显示登录选择，不再直接跳过登录界面。
	if not recent_accounts().is_empty():
		is_authenticated = false
		auto_login_pending = false
		session_changed.emit()
		return
	if _session_online and not offline_only:
		await _restore_online_session()
	# 先完成云端同步再放开登录态，避免主菜单先渲染旧数据
	if _session_online and not offline_only:
		await _sync_cloud_after_login()
	is_authenticated = true
	auto_login_pending = false
	print("[Account] 30 天免登录恢复：", account_email, " 剩余 ", session_remaining_days(), " 天")
	session_changed.emit()
	if _session_online and not offline_only:
		_sync_public_profile()


func _player_load_account(migrate_legacy := true) -> void:
	_fresh_account = not FileAccess.file_exists(_account_save_path(account_id))
	PlayerData.use_account(account_id, migrate_legacy)
	# 新账号默认用邮箱前缀作为实际玩家名（随后仍可改名）
	if not PlayerData.name_chosen and PlayerData.player_name.strip_edges() in ["", "玩家"] and account_email != "":
		PlayerData.player_name = account_email.get_slice("@", 0)
		PlayerData.save_data()


func _account_save_path(acct_id: String) -> String:
	var root := PlayerData._data_root().trim_suffix("/")
	return root + "/accounts/" + acct_id + "/player_data.cfg"


func recent_accounts(days: int = 30) -> Array:
	var now := int(Time.get_unix_time_from_system())
	var out: Array = []
	var cfg := _load_index()
	for section in cfg.get_sections():
		var email := String(section)
		if email == "" or email == "session":
			continue
		var last := int(cfg.get_value(email, "last_login", cfg.get_value(email, "created", 0)))
		if last <= 0 or now - last > days * 86400:
			continue
		out.append({
			"email": email,
			"id": String(cfg.get_value(email, "id", _make_id(email))),
			"last_login": last,
			"days_ago": int((now - last) / 86400),
		})
	out.sort_custom(func(a, b): return int(a.last_login) > int(b.last_login))
	return out

func login_recent(email: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	await _end_cloud_session()
	if not _local_has(email):
		return {"ok": false, "error": "本机没有该账号"}
	account_email = email
	account_id = _make_id(email)
	_session_online = false
	_player_load_account(false)
	_save_session(false)
	_upsert_local(email, "")
	is_authenticated = true
	auto_login_pending = false
	cloud_status = "本机账号已登录（云端未连接）"
	cloud_status_changed.emit()
	session_changed.emit()
	return {"ok": true, "online": false}

func _end_cloud_session() -> void:
	if LL_StateData.HasSessionToken():
		await LL_Authentication.EndSession.new().send()
	# 强制清理，避免下一个账号继承上一个 LootLocker 会话
	LootLockerInternal_LootLockerCache.current().delete_data("session_token")
	LootLockerInternal_LootLockerCache.current().delete_data("white_label_session_token")

func login(email: String, password: String) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "正在处理中"}
	email = email.strip_edges().to_lower()
	if not _valid_email(email):
		return {"ok": false, "error": "请输入正确的邮箱地址"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	_busy = true
	last_error = ""
	var online := false
	if not offline_only:
		cloud_status = "正在登录云端…"
		cloud_status_changed.emit()
		await _end_cloud_session()
		var resp = await _white_label_login(email, password)
		online = bool(resp.get("ok", false))
		if not online:
			last_error = String(resp.get("error", "云端登录失败"))
	# 云端失败时使用本机账号（同设备离线登录）
	if not online:
		if not _verify_local(email, password):
			_busy = false
			cloud_status = "离线（本机账号验证失败）"
			cloud_status_changed.emit()
			return {"ok": false, "error": last_error if last_error != "" else "账号或密码错误"}
	var first_account := _load_index().get_sections().is_empty()
	_upsert_local(email, password)
	account_email = email
	account_id = _make_id(email)
	_session_online = online
	_player_load_account(first_account)
	_save_session(online)
	is_authenticated = true
	auto_login_pending = false
	session_changed.emit()
	if online:
		_sync_public_profile()
		await _sync_cloud_after_login()
	else:
		cloud_status = "离线模式（云端未连接）"
		cloud_status_changed.emit()
	_busy = false
	return {"ok": true, "online": online, "error": last_error if not online else ""}


func register(email: String, password: String) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "正在处理中"}
	email = email.strip_edges().to_lower()
	if not _valid_email(email):
		return {"ok": false, "error": "请输入正确的邮箱地址"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	if _local_has(email):
		return {"ok": false, "error": "该邮箱已在本机注册"}
	_busy = true
	last_error = ""
	var online := false
	if not offline_only:
		cloud_status = "正在创建云端账号…"
		cloud_status_changed.emit()
		var req = LL_WhiteLabel.SignUp.new(email, password)
		var resp = await req.send()
		if resp.success:
			online = true
			last_error = "注册成功，请检查邮箱完成验证后再登录云端"
		else:
			last_error = str(resp.error_data)
	# 无论云端是否可用，都创建本机账号（保证离线可进入）
	var first_account := _load_index().get_sections().is_empty()
	_upsert_local(email, password)
	account_email = email
	account_id = _make_id(email)
	_session_online = false
	_player_load_account(first_account)
	_save_session(false)
	is_authenticated = true
	auto_login_pending = false
	session_changed.emit()
	# 注册接口不一定会话登录（多数平台要求邮箱验证后才能登录），
	# 因此先创建本机账号保证可进入，验证邮箱后再点登录同步云端。
	cloud_status = "本机账号已创建；完成邮箱验证后登录云端"
	cloud_status_changed.emit()
	_busy = false
	return {"ok": true, "online": online, "error": last_error}


func logout() -> void:
	var was_online := _session_online
	is_authenticated = false
	session_changed.emit()
	if was_online:
		await _upload_cloud()
	await _end_cloud_session()
	if FileAccess.file_exists(session_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session_path()))
	account_email = ""
	account_id = "default"
	_session_online = false
	cloud_status = "已退出登录"
	PlayerData.use_account("default", false)
	cloud_status_changed.emit()


func scoped_player_id() -> int:
	# 同一设备多账号：用本地账号 id 派生独立玩家 id，避免部落/排行榜互相覆盖
	if account_id != "" and account_id != "default":
		var h: int = account_id.substr(0, 15).hex_to_int()
		if h > 0:
			return h
		return absi(account_id.hash())
	return int(LL_StateData.GetCachedPlayerLegacyID())

func account_label() -> String:
	return account_email if account_email != "" else PlayerData.player_name


func session_remaining_days() -> int:
	var s := _load_session()
	if s.is_empty():
		return 0
	var left: int = int(s.get("expires", 0)) - int(Time.get_unix_time_from_system())
	return maxi(0, int(ceil(float(left) / 86400.0)))


# ============================================================
# 本机账号索引（离线兜底；密码只存哈希）
# ============================================================
func _load_index() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(index_path())
	return cfg


func _local_has(email: String) -> bool:
	var cfg := _load_index()
	return cfg.has_section(email)


func _upsert_local(email: String, password: String) -> void:
	_ensure_data_dir()
	var cfg := _load_index()
	cfg.set_value(email, "id", _make_id(email))
	var old_hash := String(cfg.get_value(email, "hash", ""))
	cfg.set_value(email, "hash", _hash_password(email, password) if password != "" else old_hash)
	cfg.set_value(email, "last_login", int(Time.get_unix_time_from_system()))
	if not cfg.has_section_key(email, "created"):
		cfg.set_value(email, "created", int(Time.get_unix_time_from_system()))
	cfg.save(index_path())


func _verify_local(email: String, password: String) -> bool:
	var cfg := _load_index()
	if not cfg.has_section(email):
		return false
	return String(cfg.get_value(email, "hash", "")) == _hash_password(email, password)


func _hash_password(email: String, password: String) -> String:
	return ("clash-royale|" + email + "|" + password).sha256_text()


func _make_id(email: String) -> String:
	# 只使用邮箱哈希作为本地目录名，不直接暴露邮箱
	return email.sha256_text().substr(0, 24)


func _valid_email(email: String) -> bool:
	return email.find("@") > 0 and email.find(".") > email.find("@") + 1


# ============================================================
# 30 天免登录会话
# ============================================================
func _load_session() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(session_path()) != OK:
		return {}
	return {
		"email": String(cfg.get_value("session", "email", "")),
		"id": String(cfg.get_value("session", "id", "")),
		"expires": int(cfg.get_value("session", "expires", 0)),
		"online": bool(cfg.get_value("session", "online", false)),
	}


func _save_session(online: bool) -> void:
	_ensure_data_dir()
	var cfg := ConfigFile.new()
	cfg.set_value("session", "email", account_email)
	cfg.set_value("session", "id", account_id)
	cfg.set_value("session", "expires", int(Time.get_unix_time_from_system()) + SESSION_DAYS * 86400)
	cfg.set_value("session", "online", online)
	cfg.save(session_path())


# ============================================================
# LootLocker White Label
# ============================================================
func _white_label_login(email: String, password: String) -> Dictionary:
	_ensure_lootlocker_settings()
	var resp = await LL_WhiteLabel.LoginAndStartSession.new(email, password, true).send()
	if resp.success:
		return {"ok": true}
	return {"ok": false, "error": str(resp.error_data)}


func _restore_online_session() -> void:
	_ensure_lootlocker_settings()
	var resp = await LL_WhiteLabel.StartSession.new(account_email).send()
	if not resp.success:
		_session_online = false
		cloud_status = "离线模式（云端会话已过期）"
		cloud_status_changed.emit()
		return
	cloud_status = "云端已连接"
	cloud_status_changed.emit()


func _ensure_lootlocker_settings() -> void:
	if LeaderboardAPI and LeaderboardAPI.has_method("_ensure_lootlocker_settings"):
		LeaderboardAPI._ensure_lootlocker_settings()


# ============================================================
# 云端存档（LootLocker Player Files）
# ============================================================
func _sync_public_profile() -> void:
	if not _session_online:
		return
	LeaderboardAPI.submit_trophies(PlayerData.trophies, PlayerData.player_name)
	ClanManager.sync_my_profile()
	ClanManager.sync_my_inventory()


func notify_local_save() -> void:
	if not is_authenticated:
		return
	_dirty = true
	_last_save_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not is_authenticated or not _session_online or _uploading or _syncing:
		return
	if not _dirty:
		return
	if Time.get_ticks_msec() - _last_save_ms < 2000:
		return
	if Time.get_ticks_msec() < _upload_retry_at:
		return
	_dirty = false
	_upload_cloud_async()


func _sync_cloud_after_login() -> void:
	if _syncing:
		return
	_syncing = true
	cloud_status = "正在同步云端存档…"
	cloud_status_changed.emit()
	var remote := await _download_cloud()
	var local_ts := _local_saved_at()
	if bool(remote.get("ok", false)):
		# 全新账号不能把另一个账号的云存档拉过来
		var remote_account := String(remote.get("account", ""))
		var wrong_account: bool = _fresh_account and remote_account != "" and remote_account != account_email
		if wrong_account:
			cloud_status = "检测到其他账号云存档，已跳过"
		elif _fresh_account or int(remote.get("saved_at", 0)) > local_ts:
			var path := PlayerData.current_save_path()
			var data: String = String(remote.get("text", ""))
			if data != "":
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				var f := FileAccess.open(path, FileAccess.WRITE)
				if f:
					f.store_string(data)
					f.close()
					PlayerData.load_data()
					PlayerData._ensure_starter_cards()
					cloud_status = "已从云端恢复存档"
		else:
			var up := await _upload_cloud()
			cloud_status = "已上传云端存档" if up else "云端上传失败"
	elif bool(remote.get("not_found", false)) or int(remote.get("code", 0)) == 404:
		var up2 := await _upload_cloud()
		cloud_status = "已上传云端存档" if up2 else "云端上传失败"
	else:
		cloud_status = "云端不可用，使用本地存档"
	_fresh_account = false
	cloud_status_changed.emit()
	_syncing = false


func _local_saved_at() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PlayerData.current_save_path()) != OK:
		return 0
	return int(cfg.get_value("meta", "saved_at", 0))


func _cloud_json() -> String:
	var cfg_text := FileAccess.get_file_as_string(PlayerData.current_save_path())
	return JSON.stringify({
		"version": 1,
		"account": account_email,
		"saved_at": int(Time.get_unix_time_from_system()),
		"data": Marshalls.utf8_to_base64(cfg_text),
	})


func _upload_cloud_async() -> void:
	if _uploading:
		return
	_uploading = true
	var ok := await _upload_cloud()
	_uploading = false
	if ok:
		cloud_status = "已上传云端存档"
		_upload_retry_at = 0
		cloud_status_changed.emit()
	else:
		# 网络失败后保留 dirty，30 秒后自动重试
		_dirty = true
		_upload_retry_at = Time.get_ticks_msec() + 30000
		cloud_status = "云端上传失败，稍后重试"
		cloud_status_changed.emit()


func _upload_cloud() -> bool:
	if not _session_online:
		return false
	var token := _session_token()
	if token == "":
		cloud_status = "云端会话无效"
		cloud_status_changed.emit()
		return false
	var base := _cloud_base()
	var boundary := "----CRAccount" + str(Time.get_ticks_usec())
	var body := PackedByteArray()
	body.append_array(("--" + boundary + "\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\n" + CLOUD_KEY + "\r\n").to_utf8_buffer())
	body.append_array(("--" + boundary + "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"" + CLOUD_FILE + "\"\r\nContent-Type: application/json\r\n\r\n").to_utf8_buffer())
	body.append_array(_cloud_json().to_utf8_buffer())
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	var headers := PackedStringArray([
		"x-session-token: " + token,
		"LL-Version: 2021-03-01",
		"Content-Type: multipart/form-data; boundary=" + boundary,
	])
	var res: Array = await _http_request(HTTPClient.METHOD_POST, base + "/game/player/files", headers, body)
	if int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) >= 200 and int(res[1]) < 300:
		return true
	last_error = "upload %d: %s" % [int(res[1]), String(res[3].get_string_from_utf8())]
	return false


func _download_cloud() -> Dictionary:
	if not _session_online:
		return {"ok": false, "code": 0}
	var token := _session_token()
	if token == "":
		return {"ok": false, "code": 0}
	var base := _cloud_base()
	var headers := PackedStringArray(["x-session-token: " + token, "LL-Version: 2021-03-01"])
	var res: Array = await _http_request(HTTPClient.METHOD_GET, base + "/game/player/files/key/" + CLOUD_KEY, headers, PackedByteArray())
	var code: int = int(res[1])
	if code == 404:
		return {"ok": false, "not_found": true, "code": 404}
	if code < 200 or code >= 300:
		return {"ok": false, "code": code}
	var meta = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (meta is Dictionary):
		return {"ok": false, "code": code}
	var url := String(meta.get("url", ""))
	if url == "" or bool(meta.get("requires_download_link", false)):
		var fid := int(meta.get("id", 0))
		if fid <= 0:
			return {"ok": false, "code": code}
		var dl: Array = await _http_request(HTTPClient.METHOD_POST,
			base + "/game/player/files/%d/download-link/v1" % fid, headers, PackedByteArray())
		if int(dl[1]) < 200 or int(dl[1]) >= 300:
			return {"ok": false, "code": int(dl[1])}
		var dmeta = JSON.parse_string(String(dl[3].get_string_from_utf8()))
		if dmeta is Dictionary:
			url = String(dmeta.get("url", ""))
	if url == "":
		return {"ok": false, "code": code}
	var file_res: Array = await _http_request(HTTPClient.METHOD_GET, url, PackedStringArray(), PackedByteArray())
	if int(file_res[1]) < 200 or int(file_res[1]) >= 300:
		return {"ok": false, "code": int(file_res[1])}
	var payload = JSON.parse_string(String(file_res[3].get_string_from_utf8()))
	if not (payload is Dictionary):
		return {"ok": false, "code": int(file_res[1])}
	var b64 := String(payload.get("data", ""))
	if b64 == "":
		return {"ok": false, "code": int(file_res[1])}
	return {
		"ok": true,
		"saved_at": int(payload.get("saved_at", 0)),
		"account": String(payload.get("account", "")),
		"text": Marshalls.base64_to_utf8(b64),
	}


func _session_token() -> String:
	return String(LootLockerInternal_LootLockerCache.current().get_data("session_token", ""))


func _cloud_base() -> String:
	var s = LootLockerInternal_Settings.GetInstance()
	if s and s.url != "":
		return s.url.trim_suffix("/")
	return "https://api.lootlocker.com"


func _http_request(method: int, url: String, headers: PackedStringArray, body: PackedByteArray) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var err := http.request_raw(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var result: Array = await http.request_completed
	http.queue_free()
	return result
