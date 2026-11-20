extends Node
# 账号系统 v2：Supabase Auth + 用户名映射 + 每账号独立本地存档 + Auth metadata 云存档

signal session_changed
signal cloud_status_changed

const SUPABASE_URL := "https://oewvixujojsbqwxfnkfk.supabase.co"
const SUPABASE_KEY := "sb_publishable_ppeyEdIwDfUDkcrmTFBVjQ_6P8i64F3"
const SESSION_PATH := "user://account_session_v2.cfg"
const INDEX_PATH := "user://accounts_v2.cfg"
const SESSION_DAYS := 30

const DEBUG_LOG_PATH := "user://account_debug.log"

func debug_log(stage: String, detail: String = "") -> void:
	var line := "[%s] %s %s" % [Time.get_datetime_string_from_system(), stage, detail]
	print("[ACCOUNT_DEBUG] ", line)
	var paths := [
		DEBUG_LOG_PATH,
		OS.get_environment("USERPROFILE") + "/clash_account_debug.log",
		"C:/Users/Public/clash_account_debug.log",
	]
	for path in paths:
		if path == "" or path == "/clash_account_debug.log":
			continue
		var f := FileAccess.open(path, FileAccess.READ_WRITE)
		if f == null:
			f = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()

func debug_log_path() -> String:
	return OS.get_environment("USERPROFILE") + "/clash_account_debug.log"

var is_authenticated := false
var auto_login_pending := false
var offline_only := false
var account_email := ""
var account_username := ""
var account_id := ""
var cloud_status := "未连接"
var last_error := ""

var _access := ""
var _refresh := ""
var _user_id := ""
var _busy := false
var _dirty := false
var _uploading := false
var _syncing := false
var _last_save_ms := 0

func _ready() -> void:
	debug_log("ACCOUNT_BOOT", "version=%s cwd=%s user_dir=%s" % [Config.BUILD_TAG, OS.get_executable_path(), ProjectSettings.globalize_path("user://")])
	call_deferred("_boot")

func _boot() -> void:
	offline_only = OS.get_environment("CR_ACCOUNT_OFFLINE") != ""
	var sess := _load_session()
	if sess.is_empty() or int(sess.get("expires", 0)) < int(Time.get_unix_time_from_system()):
		_clear_session_file()
		auto_login_pending = false
		session_changed.emit()
		return
	_access = String(sess.get("access", ""))
	_refresh = String(sess.get("refresh", ""))
	_user_id = String(sess.get("user_id", ""))
	account_email = String(sess.get("email", ""))
	account_username = String(sess.get("username", ""))
	account_id = _user_id
	if offline_only or (_access == "" and _refresh == ""):
		auto_login_pending = false
		session_changed.emit()
		return
	auto_login_pending = true
	if await _restore_session():
		await _finish_login(account_email, account_username, false)
	else:
		cloud_status = "登录已过期，请重新登录"
		_clear_session_file()
		is_authenticated = false
		auto_login_pending = false
		session_changed.emit()
		cloud_status_changed.emit()

func _restore_session() -> bool:
	var user := await _supabase_get_user()
	if user.is_empty() and _refresh != "":
		if await _supabase_refresh():
			user = await _supabase_get_user()
	if user.is_empty():
		return false
	_user_id = String(user.get("id", _user_id))
	account_email = String(user.get("email", account_email))
	account_username = String(Dictionary(user.get("user_metadata", {})).get("username", account_username))
	return true

# ---------------- 登录 / 注册 ----------------

func login(email: String, password: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	if not _valid_email(email):
		return {"ok": false, "error": "请输入正确的邮箱地址"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	if _busy:
		return {"ok": false, "error": "正在登录"}
	_busy = true
	var r := await _supabase_login(email, password)
	if bool(r.get("ok", false)):
		var u := await _supabase_get_user()
		var uname := String(Dictionary(u.get("user_metadata", {})).get("username", ""))
		var result := await _finish_login(email, uname, false)
		_busy = false
		return result
	_busy = false
	return {"ok": false, "error": String(r.get("error", "邮箱或密码错误"))}

func login_username(username: String, password: String) -> Dictionary:
	var uname := username.strip_edges()
	if uname.length() < 2:
		return {"ok": false, "error": "请输入用户名或邮箱"}
	var email := synthetic_email(uname)
	var resolved := await _edge_request("resolve", {"username": uname})
	if bool(resolved.get("ok", false)) and String(resolved.get("email", "")) != "":
		email = String(resolved.get("email"))
	return await login(email, password)

func login_recent(email: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	var cfg := _load_index()
	if not cfg.has_section(email):
		return {"ok": false, "error": "本机没有该云端账号记录"}
	var refresh := String(cfg.get_value(email, "refresh", ""))
	var uid := String(cfg.get_value(email, "user_id", ""))
	if refresh == "":
		return {"ok": false, "error": "账号会话已失效，请用密码登录"}
	_refresh = refresh
	_user_id = uid
	_access = ""
	account_email = email
	account_username = String(cfg.get_value(email, "username", ""))
	if not await _supabase_refresh():
		return {"ok": false, "error": "云端会话已过期，请用密码登录"}
	var user := await _supabase_get_user()
	if user.is_empty():
		return {"ok": false, "error": "无法恢复云端会话"}
	_user_id = String(user.get("id", uid))
	account_username = String(Dictionary(user.get("user_metadata", {})).get("username", account_username))
	return await _finish_login(account_email, account_username, true)

func register_username(username: String, password: String) -> Dictionary:
	debug_log("REG_USERNAME_START", "username=%s pwlen=%d" % [username.strip_edges(), password.length()])
	var uname := username.strip_edges()
	if uname.length() < 2 or uname.length() > 20:
		return {"ok": false, "error": "用户名需 2-20 位"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	debug_log("REG_EDGE_BEFORE", "action=signup username=%s" % uname)
	var r := await _edge_request("signup", {"username": uname, "password": password})
	debug_log("REG_EDGE_AFTER", "ok=%s user_id=%s email=%s has_access=%s err=%s" % [str(r.get("ok")), str(r.get("user_id", "")), str(r.get("email", "")), str(String(r.get("access_token", "")) != ""), str(r.get("error", ""))])
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "注册失败"))}
	if String(r.get("access_token", "")) != "":
		debug_log("REG_DIRECT_SESSION", "using Edge session")
		_set_tokens(r)
		return await _finish_login(String(r.get("email", "")), uname, false)
	debug_log("REG_FALLBACK_LOGIN", "Edge no session, trying password login")
	var login := await login_username(uname, password)
	debug_log("REG_FALLBACK_RESULT", "ok=%s err=%s" % [str(login.get("ok")), str(login.get("error", ""))])
	if not bool(login.get("ok", false)):
		return {"ok": false, "error": String(login.get("error", "账号已创建，请直接登录"))}
	return login

func register(email: String, password: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	if not _valid_email(email):
		return {"ok": false, "error": "请输入正确的邮箱地址"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	var r := await _edge_request("provision-email", {"email": email, "password": password})
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "注册失败"))}
	if String(r.get("access_token", "")) != "":
		_set_tokens(r)
		var uname0 := String(Dictionary(Dictionary(r.get("user", {})).get("user_metadata", {})).get("username", ""))
		return await _finish_login(email, uname0, false)
	return await login(email, password)

func logout() -> void:
	if is_authenticated:
		await _upload_cloud()
	is_authenticated = false
	_busy = false
	_access = ""
	_refresh = ""
	_user_id = ""
	account_email = ""
	account_username = ""
	account_id = ""
	cloud_status = "未连接"
	_clear_session_file()
	session_changed.emit()
	cloud_status_changed.emit()

# ---------------- 登录收尾 / 云存档 ----------------

func _finish_login(email: String, username: String, from_recent: bool) -> Dictionary:
	debug_log("FINISH_START", "email=%s username=%s uid=%s recent=%s" % [email, username, _user_id, str(from_recent)])
	account_email = email
	account_username = username
	account_id = _user_id
	if _user_id == "":
		return {"ok": false, "error": "云端账号 ID 无效"}
	var save_path := "user://saves/%s.cfg" % _user_id
	var abs_save := ProjectSettings.globalize_path(save_path)
	var had_local := FileAccess.file_exists(save_path)
	debug_log("FINISH_LOCAL_BEFORE", "path=%s abs=%s exists=%s" % [save_path, abs_save, str(had_local)])
	PlayerData.use_account_file(_user_id, save_path)
	debug_log("FINISH_LOCAL_AFTER", "exists=%s size=%d last_err=%s" % [str(FileAccess.file_exists(save_path)), FileAccess.get_file_as_string(save_path).length() if FileAccess.file_exists(save_path) else -1, PlayerData.last_save_error])
	is_authenticated = true
	auto_login_pending = false
	var sess_ok := _save_session()
	var idx_ok := _save_index()
	debug_log("FINISH_META_SAVED", "session_ok=%s index_ok=%s session_file=%s index_file=%s" % [str(sess_ok), str(idx_ok), str(FileAccess.file_exists(SESSION_PATH)), str(FileAccess.file_exists(INDEX_PATH))])
	cloud_status = "正在同步云端存档…"
	cloud_status_changed.emit()
	await _sync_cloud(had_local)
	debug_log("FINISH_SYNC_DONE", "status=%s local_exists=%s" % [cloud_status, str(FileAccess.file_exists(save_path))])
	_sync_public_profile()
	session_changed.emit()
	cloud_status_changed.emit()
	return {"ok": true, "online": true, "username": account_username}

func _sync_cloud(_had_local: bool) -> void:
	_syncing = true
	debug_log("SYNC_START")
	var remote := await _download_cloud()
	debug_log("SYNC_REMOTE", "ok=%s not_found=%s saved_at=%s textlen=%s" % [str(remote.get("ok")), str(remote.get("not_found", false)), str(remote.get("saved_at", "")), str(String(remote.get("text", "")).length())])
	if bool(remote.get("ok", false)):
		var text := String(remote.get("text", ""))
		if text != "" and PlayerData.apply_save_text(text):
			_dirty = false
			cloud_status = "已从云端读取存档"
			debug_log("SYNC_APPLIED")
		else:
			cloud_status = "云端存档读取失败"
	elif bool(remote.get("not_found", false)):
		var ok2 := await _upload_cloud()
		cloud_status = "已上传云端存档" if ok2 else ("云端上传失败：" + last_error)
		debug_log("SYNC_UPLOAD_NEW", "ok=%s err=%s" % [str(ok2), last_error])
	else:
		cloud_status = "云端不可用"
	_syncing = false
	cloud_status_changed.emit()

func notify_local_save() -> void:
	if not is_authenticated:
		return
	_dirty = true
	_last_save_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if not is_authenticated or _busy or _uploading or _syncing:
		return
	if _access == "":
		return
	if not _dirty:
		return
	if Time.get_ticks_msec() - _last_save_ms < 600:
		return
	_uploading = true
	var ok := await _upload_cloud()
	_uploading = false
	if ok:
		_dirty = false
		cloud_status = "已上传云端存档"
	else:
		cloud_status = "云端上传失败：" + last_error
	cloud_status_changed.emit()

func _sync_public_profile() -> void:
	if not is_authenticated:
		return
	LeaderboardAPI.submit_trophies(PlayerData.trophies, PlayerData.player_name)
	ClanManager.sync_my_profile()
	ClanManager.sync_my_inventory()

# ---------------- Supabase Auth ----------------

func _headers(token: String = "") -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + (token if token != "" else SUPABASE_KEY),
		"Content-Type: application/json",
	])

func _http(method: int, path: String, body: Dictionary = {}, token: String = "") -> Array:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var err := http.request(SUPABASE_URL + path, _headers(token), method,
		JSON.stringify(body) if not body.is_empty() else "")
	if err != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var res: Array = await http.request_completed
	http.queue_free()
	return res

func _error_of(res: Array) -> String:
	var text := String(res[3].get_string_from_utf8())
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for k in ["msg", "message", "error_description", "error"]:
			if String(parsed.get(k, "")) != "":
				return String(parsed.get(k))
	return "HTTP %d" % int(res[1])

func _supabase_login(email: String, password: String) -> Dictionary:
	var res: Array = await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email, "password": password})
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _error_of(res)}
	var d = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (d is Dictionary):
		return {"ok": false, "error": "云端返回格式错误"}
	_set_tokens(d)
	return {"ok": _access != ""}

func _set_tokens(d: Dictionary) -> void:
	_access = String(d.get("access_token", ""))
	_refresh = String(d.get("refresh_token", ""))
	var u: Dictionary = Dictionary(d.get("user", {}))
	_user_id = String(u.get("id", ""))
	account_email = String(u.get("email", account_email))
	account_username = String(Dictionary(u.get("user_metadata", {})).get("username", account_username))

func _supabase_refresh() -> bool:
	if _refresh == "":
		return false
	var res: Array = await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return false
	var d = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (d is Dictionary):
		return false
	_set_tokens(d)
	return _access != ""

func _supabase_get_user() -> Dictionary:
	if _access == "":
		return {}
	var res: Array = await _http(HTTPClient.METHOD_GET, "/auth/v1/user", {}, _access)
	if int(res[1]) == 401 and await _supabase_refresh():
		res = await _http(HTTPClient.METHOD_GET, "/auth/v1/user", {}, _access)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {}
	var d = JSON.parse_string(String(res[3].get_string_from_utf8()))
	return d if d is Dictionary else {}

func _download_cloud() -> Dictionary:
	var u := await _supabase_get_user()
	if u.is_empty():
		return {"ok": false}
	var meta: Dictionary = Dictionary(u.get("user_metadata", {}))
	var b64 := String(meta.get("cr_save", ""))
	if b64 == "":
		return {"ok": false, "not_found": true}
	return {"ok": true, "saved_at": int(meta.get("cr_saved_at", 0)), "text": Marshalls.base64_to_utf8(b64)}

func _upload_cloud() -> bool:
	debug_log("UPLOAD_START", "access=%s user_id=%s local_path=%s local_exists=%s" % [str(_access != ""), _user_id, PlayerData.current_save_path(), str(FileAccess.file_exists(PlayerData.current_save_path()))])
	if _access == "":
		last_error = "云端未登录"
		return false
	var text := PlayerData.get_save_text()
	if text == "":
		last_error = "本地存档为空"
		debug_log("UPLOAD_EMPTY_TEXT")
		return false
	var body := {"data": {"cr_save": Marshalls.utf8_to_base64(text), "cr_saved_at": int(Time.get_unix_time_from_system())}}
	var res: Array = await _http(HTTPClient.METHOD_PUT, "/auth/v1/user", body, _access)
	if int(res[1]) == 401 and await _supabase_refresh():
		res = await _http(HTTPClient.METHOD_PUT, "/auth/v1/user", body, _access)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		last_error = _error_of(res)
		debug_log("UPLOAD_FAIL", "code=%d err=%s textlen=%d" % [int(res[1]), last_error, text.length()])
		return false
	debug_log("UPLOAD_OK", "code=%d textlen=%d" % [int(res[1]), text.length()])
	return true

# ---------------- Edge / 邮箱绑定 / OTP ----------------

func synthetic_email(username: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(username.strip_edges().to_lower().to_utf8_buffer())
	return "u_%s@login.clashroyale.local" % ctx.finish().hex_encode()

func _edge_request(action: String, payload: Dictionary, auth: bool = false) -> Dictionary:
	var body := payload.duplicate(true)
	body["action"] = action
	var res: Array = await _http(HTTPClient.METHOD_POST, "/functions/v1/cr-auth", body, _access if auth else "")
	var d = JSON.parse_string(String(res[3].get_string_from_utf8()))
	return d if d is Dictionary else {"ok": false, "error": "Edge 返回格式错误"}

func request_bind_email(email: String) -> Dictionary:
	if _access == "":
		return {"ok": false, "error": "请先登录云端"}
	var res: Array = await _http(HTTPClient.METHOD_PUT, "/auth/v1/user", {"email": email.strip_edges().to_lower()}, _access)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _error_of(res)}
	await _edge_request("sync-email", {}, true)
	return {"ok": true}

func send_email_otp(email: String) -> Dictionary:
	var res: Array = await _http(HTTPClient.METHOD_POST, "/auth/v1/otp", {"email": email.strip_edges().to_lower(), "create_user": false})
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _error_of(res)}
	return {"ok": true}

func verify_email_otp(email: String, code: String) -> Dictionary:
	var res: Array = await _http(HTTPClient.METHOD_POST, "/auth/v1/verify", {"email": email.strip_edges().to_lower(), "token": code.strip_edges(), "type": "email"})
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _error_of(res)}
	var d = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (d is Dictionary):
		return {"ok": false, "error": "验证码登录失败"}
	_set_tokens(d)
	var u := await _supabase_get_user()
	var uname := String(Dictionary(u.get("user_metadata", {})).get("username", ""))
	return await _finish_login(account_email, uname, false)

func try_claim_bind_reward() -> bool:
	if _access == "":
		return false
	var u := await _supabase_get_user()
	if u.is_empty():
		return false
	var email := String(u.get("email", ""))
	if email.ends_with("@login.clashroyale.local") or String(u.get("email_confirmed_at", "")) == "":
		return false
	var meta: Dictionary = Dictionary(u.get("user_metadata", {}))
	if bool(meta.get("bind_reward_claimed", false)) or PlayerData.email_bind_reward_claimed:
		return false
	var r := await _edge_request("claim-bind-reward", {}, true)
	if bool(r.get("ok", false)):
		PlayerData.gold += 500
		PlayerData.gems += 10
		PlayerData.email_bind_reward_claimed = true
		PlayerData.save_data()
		return true
	return false

# ---------------- 会话 / 账号索引 ----------------

func _load_session() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return {}
	return {
		"email": String(cfg.get_value("session", "email", "")),
		"username": String(cfg.get_value("session", "username", "")),
		"user_id": String(cfg.get_value("session", "user_id", "")),
		"access": String(cfg.get_value("session", "access", "")),
		"refresh": String(cfg.get_value("session", "refresh", "")),
		"expires": int(cfg.get_value("session", "expires", 0)),
	}

func _save_session() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "email", account_email)
	cfg.set_value("session", "username", account_username)
	cfg.set_value("session", "user_id", _user_id)
	cfg.set_value("session", "access", _access)
	cfg.set_value("session", "refresh", _refresh)
	cfg.set_value("session", "expires", int(Time.get_unix_time_from_system()) + SESSION_DAYS * 86400)
	var err_session := cfg.save(SESSION_PATH)
	debug_log("SESSION_SAVE", "path=%s abs=%s err=%d exists=%s" % [SESSION_PATH, ProjectSettings.globalize_path(SESSION_PATH), err_session, str(FileAccess.file_exists(SESSION_PATH))])
	return err_session == OK

func _clear_session_file() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func _load_index() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(INDEX_PATH)
	return cfg

func _save_index() -> bool:
	if account_email == "":
		return false
	var cfg := _load_index()
	cfg.set_value(account_email, "user_id", _user_id)
	cfg.set_value(account_email, "username", account_username)
	cfg.set_value(account_email, "refresh", _refresh)
	cfg.set_value(account_email, "last_login", int(Time.get_unix_time_from_system()))
	var err_idx := cfg.save(INDEX_PATH)
	debug_log("INDEX_SAVE", "path=%s abs=%s err=%d exists=%s" % [INDEX_PATH, ProjectSettings.globalize_path(INDEX_PATH), err_idx, str(FileAccess.file_exists(INDEX_PATH))])
	return err_idx == OK

func recent_supabase_accounts(_days: int = 30) -> Array:
	var cfg := _load_index()
	var out: Array = []
	var now := int(Time.get_unix_time_from_system())
	for section in cfg.get_sections():
		var email := String(section)
		var last := int(cfg.get_value(email, "last_login", 0))
		if email == "" or last <= 0 or now - last > 30 * 86400:
			continue
		if String(cfg.get_value(email, "refresh", "")) == "":
			continue
		out.append({
			"email": email,
			"username": String(cfg.get_value(email, "username", "")),
			"last_login": last,
			"days_ago": int((now - last) / 86400),
			"online": true,
		})
	out.sort_custom(func(a, b): return int(a.last_login) > int(b.last_login))
	return out

func recent_accounts(days: int = 30) -> Array:
	return recent_supabase_accounts(days)

func session_remaining_days() -> int:
	var s := _load_session()
	if s.is_empty():
		return 0
	return maxi(0, int(ceil(float(int(s.get("expires", 0)) - int(Time.get_unix_time_from_system())) / 86400.0)))

func account_label() -> String:
	return account_username if account_username != "" else account_email

func supabase_token() -> String:
	return _access

func is_supabase_authenticated() -> bool:
	return is_authenticated and _access != ""

func scoped_player_id() -> int:
	if account_id != "":
		var h := account_id.replace("-", "").substr(0, 12).hex_to_int()
		if h > 0:
			return h
	return absi(account_id.hash())

func _local_saved_at() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PlayerData.current_save_path()) != OK:
		return 0
	return int(cfg.get_value("meta", "saved_at", 0))

func _valid_email(email: String) -> bool:
	return email.find("@") > 0 and email.find(".") > email.find("@") + 1
