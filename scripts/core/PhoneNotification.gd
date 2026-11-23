extends Node
# 手机本地通知：好友消息、好友申请、邮箱消息。
# 不是服务器推送；应用进程存活并收到消息时触发。Android 13+ 会请求通知权限。

var _plugin: Object = null
var _last_unread: Dictionary = {}
var _permission_asked := false
var _online_acc := 0.0
var _online_ready := false
var _friend_online: Dictionary = {}
var _push_token := ""
var _push_token_account := ""


func _ready() -> void:
	if not OS.has_feature("android"):
		return
	if not Engine.has_singleton("NotificationPlugin"):
		return
	_plugin = Engine.get_singleton("NotificationPlugin")
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().create_timer(0.8).timeout
	if _plugin == null or not is_instance_valid(_plugin):
		return
	_plugin_call("createChannel", "create_channel", [])
	_plugin_call("requestPermission", "request_permission", [])
	_permission_asked = true
	if FriendManager != null:
		FriendManager.unread_changed.connect(_on_friend_unread)
		FriendManager.friend_request_received.connect(_on_friend_request)
	if PlayerData != null:
		PlayerData.mail_added.connect(_on_mail_added)
	if ClanManager != null:
		ClanManager.chat_unread_changed.connect(_on_clan_unread)
	set_process(true)


func _process(delta: float) -> void:
	if _plugin == null:
		return
	_online_acc += delta
	if _online_acc < 4.0:
		return
	_online_acc = 0.0
	_check_friend_online()
	if _push_token == "":
		_try_register_push_token()


func _check_friend_online() -> void:
	if FriendManager == null:
		return
	var had_state := _online_ready
	for f in FriendManager.friends:
		var pid := String(Dictionary(f).get("id", ""))
		if pid == "":
			continue
		var online := FriendManager.is_online(pid)
		var was := bool(_friend_online.get(pid, false))
		_friend_online[pid] = online
		if had_state and online and not was:
			var name := String(Dictionary(f).get("name", "好友"))
			_notify("好友上线", "%s 已上线，快去找他玩吧" % name, 6000 + absi(hash(pid)) % 100000)
	_online_ready = true


func _try_register_push_token() -> void:
	if _plugin == null or AccountManager == null or not AccountManager.is_supabase_authenticated():
		return
	var token_value = _plugin_call("getFcmToken", "get_fcm_token", [])
	var token := "" if token_value == null else String(token_value)
	if token == "":
		return
	var acc := String(AccountManager.account_id)
	if token == _push_token and acc == _push_token_account:
		return
	var ok: bool = await SupabaseAPI.upsert("push_token:" + acc, {
		"account_id": acc,
		"scoped_id": str(ClanManager.get_player_id()),
		"token": token,
		"updated_at": int(Time.get_unix_time_from_system()),
	})
	if ok:
		_push_token = token
		_push_token_account = acc


func _on_friend_unread(pid: String, count: int) -> void:
	if count <= 0:
		return
	var prev := int(_last_unread.get(pid, 0))
	_last_unread[pid] = count
	if count <= prev:
		return
	var name := String(pid)
	if FriendManager != null:
		for f in FriendManager.friends:
			if String(Dictionary(f).get("id", "")) == pid:
				name = String(Dictionary(f).get("name", pid))
				break
	_notify("新好友消息", "%s 给你发来一条消息" % name, 2000 + absi(hash(pid)) % 100000)


func _on_friend_request(request: Dictionary) -> void:
	var prof: Dictionary = Dictionary(request.get("profile", {}))
	var name := String(prof.get("name", prof.get("player_name", "玩家")))
	_notify("好友申请", "%s 想添加你为好友" % name, 3000 + absi(hash(name)) % 100000)


func _on_mail_added(title: String, body: String, sender: String) -> void:
	if title.strip_edges() == "":
		return
	_notify(title, body if body.strip_edges() != "" else "来自 %s 的新消息" % sender, 4000 + absi(hash(title + body)) % 100000)


func _on_clan_unread(count: int) -> void:
	if count > 0:
		_notify("部落消息", "部落里有 %d 条新消息" % count, 5000)


func test_notification() -> String:
	if not OS.has_feature("android"):
		return "仅 Android 手机支持系统通知"
	if _plugin == null or not is_instance_valid(_plugin):
		return "通知插件未加载"
	_plugin_call("requestPermission", "request_permission", [])
	await get_tree().create_timer(0.6).timeout
	var has_perm = _plugin_call("isPermissionGranted", "is_permission_granted", [])
	if has_perm != null and not bool(has_perm):
		return "通知权限未授予，请在系统设置中允许通知"
	var shown = _plugin_call("showNotification", "show_notification", ["通知测试", "如果你看到这条通知，说明通知链路正常。", 99999])
	if shown != null:
		return "测试通知已发送"
	var names: Array = []
	for m in _plugin.get_method_list():
		names.append(String(m.get("name", "")))
	return "通知接口不可用；插件方法=" + ", ".join(names)


func _plugin_call(camel: String, snake: String, args: Array) -> Variant:
	if _plugin == null or not is_instance_valid(_plugin):
		return null
	if _plugin.has_method(camel):
		return _plugin.callv(camel, args)
	if _plugin.has_method(snake):
		return _plugin.callv(snake, args)
	# Godot Android JavaObject exposes Java methods dynamically.
	if _plugin.has_method("has_java_method") and _plugin.has_java_method(camel):
		return _plugin.callv(camel, args)
	if _plugin.has_method("has_java_method") and _plugin.has_java_method(snake):
		return _plugin.callv(snake, args)
	return null


func _notify(title: String, body: String, id: int) -> void:
	if _plugin == null or not is_instance_valid(_plugin):
		return
	var has_perm = _plugin_call("isPermissionGranted", "is_permission_granted", [])
	if has_perm != null and not bool(has_perm):
		if _permission_asked:
			return
		_plugin_call("requestPermission", "request_permission", [])
		return
	_plugin_call("showNotification", "show_notification", [title, body, id])
