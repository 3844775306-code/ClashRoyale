extends Node
# 全局更新公告：announcement:latest
# 每次版本序列达到 10 的倍数时发布公告，所有玩家登录后领取一次邮件奖励。
# 每完成一个开发任务，Config.UPDATE_COUNT +1；每累计 10 次发送一次公告邮件。
# UPDATE_LOG 保存最近任务摘要，公告介绍最近 10 次更新并附下载链接。

const ANNOUNCE_KEY := "announcement:latest"
const CHECK_SEC := 60.0
const REWARD := {"gold": 1000, "gems": 50}

var _acc := 0.0


func _ready() -> void:
	set_process(true)
	if AccountManager and not AccountManager.session_changed.is_connected(_on_session):
		AccountManager.session_changed.connect(_on_session)
	call_deferred("_ensure_local_announcement")
	call_deferred("_check")


func _on_session() -> void:
	if AccountManager and AccountManager.is_supabase_authenticated():
		call_deferred("_ensure_local_announcement")
	call_deferred("_check")


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= CHECK_SEC:
		_acc = 0.0
		_check()


func _check() -> void:
	_ensure_local_announcement()
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return
	await _publish_if_due()
	var a: Dictionary = await SupabaseAPI.get_value(ANNOUNCE_KEY)
	if a.is_empty():
		return
	var serial := int(a.get("serial", 0))
	if serial <= int(PlayerData.announcement_seen):
		return
	var title := String(a.get("title", "版本更新公告"))
	var body := String(a.get("body", ""))
	var reward = a.get("reward", REWARD)
	if not (reward is Dictionary):
		reward = REWARD
	PlayerData.add_mail(title, body, Dictionary(reward).duplicate(true), "官方", "update", {"announcement_serial": serial})
	PlayerData.announcement_seen = serial
	PlayerData.save_data()


func _ensure_local_announcement() -> void:
	var expected: int = (int(Config.UPDATE_COUNT) / 10) * 10
	if expected <= 0:
		return
	# 已有对应公告邮件则不重复；announcement_seen 只代表已读/已发
	for m in PlayerData.mailbox:
		if m is Dictionary and String(m.get("kind", "")) == "update" and int(m.get("announcement_serial", -1)) == expected:
			if int(PlayerData.announcement_seen) < expected:
				PlayerData.announcement_seen = expected
				PlayerData.save_data()
			return
	var entries := _recent_updates()
	var lines: Array = []
	for e in entries:
		lines.append("· v%s  %s" % [String(e.get("version", "")), String(e.get("summary", ""))])
	if lines.is_empty():
		lines.append("· 累计完成 %d 次更新" % expected)
	var body := "感谢各位玩家的支持！最近 10 次更新内容：\n\n%s\n\n下载最新版本：\n网页版：%s\nWindows：%s\nAndroid：%s\n发布页：%s\n\n附赠：1000 金币 + 50 钻石。\n请前往邮箱领取。" % [
		"\n".join(lines), Config.WEB_URL, Config.WIN_URL, Config.APK_URL, Config.RELEASE_URL]
	PlayerData.add_mail("版本更新公告 · 第 %d 次更新" % expected, body,
		REWARD.duplicate(true), "官方", "update", {"announcement_serial": expected})
	PlayerData.announcement_seen = expected
	PlayerData.save_data()


func _publish_if_due() -> void:
	# 即使更新计数已经越过 10 的倍数，也补发最近一个里程碑
	var serial := (int(Config.UPDATE_COUNT) / 10) * 10
	if serial <= 0:
		return
	var current: Dictionary = await SupabaseAPI.get_value(ANNOUNCE_KEY)
	if int(current.get("serial", 0)) >= serial:
		return
	var log_entries := _recent_updates()
	var lines: Array = []
	for e in log_entries:
		lines.append("· v%s  %s" % [String(e.get("version", "")), String(e.get("summary", ""))])
	if lines.is_empty():
		lines.append("· 累计完成 %d 次更新" % serial)
	var body := "感谢各位玩家的支持！最近 10 次更新内容：\n\n%s\n\n下载最新版本：\n网页版：%s\nWindows：%s\nAndroid：%s\n发布页：%s\n\n附赠：1000 金币 + 50 钻石。\n请前往邮箱领取。" % [
		"\n".join(lines), Config.WEB_URL, Config.WIN_URL, Config.APK_URL, Config.RELEASE_URL]
	await SupabaseAPI.upsert(ANNOUNCE_KEY, {
		"serial": serial,
		"version": Config.VERSION,
		"title": "版本更新公告 · v%s（第 %d 次更新）" % [Config.VERSION, serial],
		"body": body,
		"reward": REWARD.duplicate(true),
		"created": int(Time.get_unix_time_from_system()),
	})


func _recent_updates() -> Array:
	var f := FileAccess.open("res://data/update_log.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Array):
		return []
	var out: Array = parsed
	if out.size() > 10:
		out = out.slice(out.size() - 10, out.size())
	return out
