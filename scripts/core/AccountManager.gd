# scripts/core/AccountManager.gd
# 账号系统：邮箱账号、按账号分目录存档、LootLocker 云存档、同设备 30 天免登录。
# 云端：LootLocker White Label 账号 + Player Files（玩家文件）存 JSON。
extends Node

signal session_changed
signal cloud_status_changed

const SESSION_DAYS := 30
const CLOUD_KEY := "cr_player_data"
const CLOUD_FILE := "player_data.json"
const SUPABASE_URL := "https://oewvixujojsbqwxfnkfk.supabase.co"
const SUPABASE_KEY := "sb_publishable_ppeyEdIwDfUDkcrmTFBVjQ_6P8i64F3"

var is_authenticated: bool = false
var auto_login_pending: bool = false
var account_email: String = ""
var account_username: String = ""
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
var _supabase_access_token := ""
var _supabase_refresh_token := ""
var _supabase_user_id := ""
var _supabase_using := false
var _otp_sent_at: int = 0
var _bind_sent_at: int = 0


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
	_supabase_access_token = String(sess.get("supabase_access", ""))
	_supabase_refresh_token = String(sess.get("supabase_refresh", ""))
	_supabase_user_id = String(sess.get("supabase_user", ""))
	_supabase_using = _supabase_access_token != ""
	_player_load_account(false)
	# 有本机最近账号时先显示登录选择，不再直接跳过登录界面。
	if not recent_accounts().is_empty():
		is_authenticated = false
		auto_login_pending = false
		session_changed.emit()
		return
	if _session_online and not offline_only:
		if _supabase_using:
			await _restore_supabase_session()
		else:
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


func recent_supabase_accounts(days: int = 30) -> Array:
	var out: Array = []
	var idx := _load_index()
	for acct in recent_accounts(days):
		var email := String(acct.get("email", ""))
		var online := bool(idx.get_value(email, "supabase_online", false))
		var refresh := String(idx.get_value(email, "supabase_refresh", ""))
		if not online and refresh == "":
			continue
		acct["online"] = online
		acct["username"] = String(idx.get_value(email, "username", ""))
		out.append(acct)
	return out

func _player_load_account(migrate_legacy := true) -> void:
	_fresh_account = not FileAccess.file_exists(_account_save_path(account_id))
	PlayerData.use_account(account_id, migrate_legacy)
	if _fresh_account:
		PlayerData.save_data()
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
	if not _local_has(email):
		return {"ok": false, "error": "本机没有该账号"}
	var idx := _load_index()
	var saved_refresh := String(idx.get_value(email, "supabase_refresh", ""))
	var saved_user := String(idx.get_value(email, "supabase_user", ""))
	await _end_cloud_session()
	account_email = email
	account_username = String(idx.get_value(email, "username", ""))
	account_id = _make_id(email)
	_supabase_refresh_token = saved_refresh
	_supabase_user_id = saved_user
	_supabase_access_token = ""
	_supabase_using = saved_refresh != ""
	_session_online = false
	_player_load_account(false)
	if _supabase_using and await _supabase_refresh():
		_session_online = true
		cloud_status = "云端已连接（Supabase）"
		await _sync_cloud_after_login()
	else:
		_supabase_using = false
		cloud_status = "本机账号已登录（云端未连接）"
	_save_session(_session_online)
	_upsert_local(email, "")
	is_authenticated = true
	auto_login_pending = false
	cloud_status_changed.emit()
	session_changed.emit()
	return {"ok": true, "online": _session_online}

func _end_cloud_session() -> void:
	if _supabase_access_token != "":
		await _supabase_logout()
	_supabase_access_token = ""
	_supabase_refresh_token = ""
	_supabase_user_id = ""
	_supabase_using = false
	if LL_StateData.HasSessionToken():
		# 后台结束旧 LootLocker 会话，不阻塞 Supabase 登录
		LL_Authentication.EndSession.new().send()
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
		var sb := await _supabase_login(email, password)
		online = bool(sb.get("ok", false))
		if online:
			_supabase_using = true
		else:
			last_error = String(sb.get("error", "云端登录失败"))
			# 兼容此前注册的 LootLocker 账号
			var resp = await _white_label_login(email, password)
			online = bool(resp.get("ok", false))
			if online:
				_supabase_using = false
			else:
				last_error = String(resp.get("error", last_error))
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
	_player_load_account(first_account and not online)
	_save_session(online)
	is_authenticated = true
	auto_login_pending = false
	session_changed.emit()
	if online:
		_sync_public_profile()
		await _sync_cloud_after_login()
		if _supabase_using:
			await _edge_request("sync-email", {}, true)
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
	var local_exists := _local_has(email)
	_busy = true
	last_error = ""
	var online := false
	if not offline_only:
		cloud_status = "正在创建云端账号…"
		cloud_status_changed.emit()
		var sb := await _supabase_signup(email, password)
		online = bool(sb.get("ok", false)) and bool(sb.get("has_session", false))
		if bool(sb.get("ok", false)):
			last_error = "注册成功，请检查邮箱完成验证后再登录云端" if not online else ""
		else:
			last_error = String(sb.get("error", "注册失败"))
	# 无论云端是否可用，都创建本机账号（保证离线可进入）
	var first_account := not local_exists and _load_index().get_sections().is_empty()
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


func synthetic_email(username: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(username.strip_edges().to_lower().to_utf8_buffer())
	return "u_%s@login.clashroyale.local" % ctx.finish().hex_encode()

func _edge_request(action: String, payload: Dictionary, use_user_token: bool = false) -> Dictionary:
	var body := payload.duplicate(true)
	body["action"] = action
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + (_supabase_access_token if use_user_token and _supabase_access_token != "" else SUPABASE_KEY),
		"Content-Type: application/json",
	])
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/functions/v1/cr-auth", headers, JSON.stringify(body).to_utf8_buffer())
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (data is Dictionary):
		return {"ok": false, "error": "云端返回格式错误"}
	return data

func register_username(username: String, password: String) -> Dictionary:
	var u := username.strip_edges()
	if u.length() < 2 or u.length() > 20:
		return {"ok": false, "error": "用户名需 2-20 位"}
	if password.length() < 6:
		return {"ok": false, "error": "密码至少 6 位"}
	var r := await _edge_request("signup", {"username": u, "password": password})
	if bool(r.get("ok", false)):
		r["email"] = String(r.get("email", synthetic_email(u)))
	return r

func login_username(username: String, password: String) -> Dictionary:
	var email := synthetic_email(username)
	var r := await _edge_request("resolve", {"username": username.strip_edges()})
	if bool(r.get("ok", false)) and String(r.get("email", "")) != "":
		email = String(r.get("email"))
	return await login(email, password)

func request_bind_email(email: String) -> Dictionary:
	if not is_supabase_authenticated():
		return {"ok": false, "error": "请先登录云端"}
	var now_b := int(Time.get_unix_time_from_system())
	if _bind_sent_at > 0 and now_b - _bind_sent_at < 60:
		return {"ok": false, "error": "发送过于频繁，请 %d 秒后再试" % (60 - (now_b - _bind_sent_at))}
	var body := JSON.stringify({"email": email}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_PUT,
		SUPABASE_URL + "/auth/v1/user", _supabase_headers(_supabase_access_token), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _supabase_error(res)}
	_bind_sent_at = now_b
	await _edge_request("sync-email", {}, true)
	return {"ok": true}

func send_email_otp(email: String) -> Dictionary:
	var now_o := int(Time.get_unix_time_from_system())
	if _otp_sent_at > 0 and now_o - _otp_sent_at < 60:
		return {"ok": false, "error": "验证码发送过于频繁，请 %d 秒后再试" % (60 - (now_o - _otp_sent_at))}
	var body := JSON.stringify({"email": email, "create_user": false}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/otp", _supabase_headers(), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _supabase_error(res)}
	_otp_sent_at = now_o
	return {"ok": true}

func verify_email_otp(email: String, token: String) -> Dictionary:
	var body := JSON.stringify({"email": email, "token": token, "type": "email"}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/verify", _supabase_headers(), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _supabase_error(res)}
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (data is Dictionary):
		return {"ok": false, "error": "验证码登录失败"}
	var d: Dictionary = data
	_supabase_access_token = String(d.get("access_token", ""))
	_supabase_refresh_token = String(d.get("refresh_token", ""))
	var user: Dictionary = Dictionary(d.get("user", {}))
	_supabase_user_id = String(user.get("id", ""))
	_supabase_using = true
	_session_online = true
	account_email = email
	account_id = _make_id(email)
	_player_load_account(false)
	_save_session(true)
	is_authenticated = true
	auto_login_pending = false
	await _edge_request("sync-email", {}, true)
	await _sync_cloud_after_login()
	return {"ok": true, "online": true}

func try_claim_bind_reward() -> bool:
	if not is_supabase_authenticated():
		return false
	var user := await _supabase_get_user()
	if user.is_empty():
		return false
	var email := String(user.get("email", ""))
	if email.ends_with("@login.clashroyale.local"):
		return false
	if String(user.get("email_confirmed_at", "")) == "":
		return false
	var meta: Dictionary = Dictionary(user.get("user_metadata", {}))
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

func supabase_token() -> String:
	return _supabase_access_token

func is_supabase_authenticated() -> bool:
	return _supabase_using and _supabase_access_token != ""

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
		"supabase_access": String(cfg.get_value("session", "supabase_access", "")),
		"supabase_refresh": String(cfg.get_value("session", "supabase_refresh", "")),
		"supabase_user": String(cfg.get_value("session", "supabase_user", "")),
	}


func _save_session(online: bool) -> void:
	_ensure_data_dir()
	var cfg := ConfigFile.new()
	cfg.set_value("session", "email", account_email)
	cfg.set_value("session", "id", account_id)
	cfg.set_value("session", "expires", int(Time.get_unix_time_from_system()) + SESSION_DAYS * 86400)
	cfg.set_value("session", "online", online)
	cfg.set_value("session", "supabase_access", _supabase_access_token)
	cfg.set_value("session", "supabase_refresh", _supabase_refresh_token)
	cfg.set_value("session", "supabase_user", _supabase_user_id)
	cfg.save(session_path())
	if account_email != "":
		var idx := _load_index()
		idx.set_value(account_email, "supabase_refresh", _supabase_refresh_token)
		idx.set_value(account_email, "supabase_user", _supabase_user_id)
		idx.set_value(account_email, "supabase_online", _session_online)
		idx.set_value(account_email, "username", account_username)
		idx.save(index_path())


# ============================================================
# Supabase Auth + 用户 metadata 云存档
# ============================================================
func _supabase_headers(token: String = "") -> PackedStringArray:
	var bearer := token if token != "" else SUPABASE_KEY
	return PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + bearer,
		"Content-Type: application/json",
	])

func _supabase_error(res: Array) -> String:
	var code: int = int(res[1])
	var text := String(res[3].get_string_from_utf8())
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		for k in ["msg", "message", "error_description", "error"]:
			if String(d.get(k, "")) != "":
				var m := String(d.get(k, ""))
				if m.to_lower().contains("rate limit"):
					return "发送过于频繁，请约 60 秒后再试（Supabase 邮件限流）"
				return m
	return "HTTP %d" % code

func _supabase_login(email: String, password: String) -> Dictionary:
	var body := JSON.stringify({"email": email, "password": password}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/token?grant_type=password", _supabase_headers(), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _supabase_error(res)}
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (data is Dictionary):
		return {"ok": false, "error": "云端返回格式错误"}
	var d: Dictionary = data
	_supabase_access_token = String(d.get("access_token", ""))
	_supabase_refresh_token = String(d.get("refresh_token", ""))
	var user: Dictionary = Dictionary(d.get("user", {}))
	_supabase_user_id = String(user.get("id", ""))
	account_username = String(Dictionary(user.get("user_metadata", {})).get("username", ""))
	return {"ok": _supabase_access_token != "", "error": "" if _supabase_access_token != "" else "未获取到会话"}

func _supabase_signup(email: String, password: String) -> Dictionary:
	var body := JSON.stringify({"email": email, "password": password}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/signup", _supabase_headers(), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "error": _supabase_error(res)}
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	var d: Dictionary = data if data is Dictionary else {}
	_supabase_access_token = String(d.get("access_token", ""))
	_supabase_refresh_token = String(d.get("refresh_token", ""))
	var user: Dictionary = Dictionary(d.get("user", {}))
	_supabase_user_id = String(user.get("id", ""))
	return {"ok": true, "has_session": _supabase_access_token != ""}

func _supabase_refresh() -> bool:
	if _supabase_refresh_token == "":
		return false
	var body := JSON.stringify({"refresh_token": _supabase_refresh_token}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token", _supabase_headers(), body)
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return false
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	_supabase_access_token = String(d.get("access_token", ""))
	_supabase_refresh_token = String(d.get("refresh_token", _supabase_refresh_token))
	return _supabase_access_token != ""

func _supabase_get_user() -> Dictionary:
	if _supabase_access_token == "":
		return {}
	var res: Array = await _http_request(HTTPClient.METHOD_GET,
		SUPABASE_URL + "/auth/v1/user", _supabase_headers(_supabase_access_token), PackedByteArray())
	if int(res[1]) == 401 and await _supabase_refresh():
		res = await _http_request(HTTPClient.METHOD_GET,
			SUPABASE_URL + "/auth/v1/user", _supabase_headers(_supabase_access_token), PackedByteArray())
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {}
	var data = JSON.parse_string(String(res[3].get_string_from_utf8()))
	return data if data is Dictionary else {}

func _supabase_update_metadata(meta: Dictionary) -> bool:
	if _supabase_access_token == "":
		return false
	var body := JSON.stringify({"data": meta}).to_utf8_buffer()
	var res: Array = await _http_request(HTTPClient.METHOD_PUT,
		SUPABASE_URL + "/auth/v1/user", _supabase_headers(_supabase_access_token), body)
	if int(res[1]) == 401 and await _supabase_refresh():
		res = await _http_request(HTTPClient.METHOD_PUT,
			SUPABASE_URL + "/auth/v1/user", _supabase_headers(_supabase_access_token), body)
	var ok_meta := int(res[1]) >= 200 and int(res[1]) < 300
	if not ok_meta:
		last_error = _supabase_error(res)
	return ok_meta

func _supabase_logout() -> void:
	if _supabase_access_token == "":
		return
	await _http_request(HTTPClient.METHOD_POST,
		SUPABASE_URL + "/auth/v1/logout", _supabase_headers(_supabase_access_token), PackedByteArray())

func _restore_supabase_session() -> void:
	if _supabase_access_token == "" and _supabase_refresh_token == "":
		_session_online = false
		return
	var user := await _supabase_get_user()
	if user.is_empty() and _supabase_refresh_token != "":
		if await _supabase_refresh():
			user = await _supabase_get_user()
	if user.is_empty():
		_session_online = false
		cloud_status = "云端会话已过期，请重新登录"
		cloud_status_changed.emit()
		return
	_supabase_using = true
	cloud_status = "云端已连接（Supabase）"
	cloud_status_changed.emit()

func _supabase_download_cloud() -> Dictionary:
	var user := await _supabase_get_user()
	if user.is_empty():
		return {"ok": false, "code": 0}
	var meta: Dictionary = Dictionary(user.get("user_metadata", {}))
	var b64 := String(meta.get("cr_save", ""))
	if b64 == "":
		return {"ok": false, "not_found": true, "code": 404}
	var decoded := Marshalls.base64_to_utf8(b64)
	if decoded == "":
		return {"ok": false, "code": 500}
	return {"ok": true, "saved_at": int(meta.get("cr_saved_at", 0)),
		"account": account_email, "text": decoded}

func _supabase_upload_cloud() -> bool:
	var path := PlayerData.current_save_path()
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		PlayerData.save_data()
		text = FileAccess.get_file_as_string(path)
	if text == "":
		# 即使文件系统暂时不可写，也把当前内存中的账号状态序列化上传
		text = PlayerData.get_save_text()
	if text == "":
		last_error = "本地存档为空：%s" % path
		return false
	var meta := {
		"cr_save": Marshalls.utf8_to_base64(text),
		"cr_saved_at": int(Time.get_unix_time_from_system()),
	}
	return await _supabase_update_metadata(meta)

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
		cloud_status = "已上传云端存档" if up2 else ("云端上传失败：" + last_error)
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
		cloud_status = "云端上传失败，稍后重试：" + last_error
		cloud_status_changed.emit()


func _upload_cloud() -> bool:
	if _supabase_using:
		return await _supabase_upload_cloud()
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
	if _supabase_using:
		return await _supabase_download_cloud()
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
