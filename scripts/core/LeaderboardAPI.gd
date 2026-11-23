# scripts/core/Leaderboard.gd (Autoload)
extends Node

const LEADERBOARD_ID = "34347"   # 你在 LootLocker 控制台创建的排行榜 key 或整数 id
# 内置兜底配置：部分导出方式不会把 res://LootLockerSettings.cfg 打进包（手机端常见），
# 此时用这里的内置 key 覆盖 LootLocker 单例，保证排行榜/部落可用。修改 key 时两处一起改。
const FALLBACK_API_KEY := "dev_77b82a2fb83744caa9e0d30dc6ec95f3"
const FALLBACK_DOMAIN_KEY := "z59zdqpt"
const FALLBACK_GAME_VERSION := "1.0.0"
var last_error: String = ""

static func leaderboard_id() -> String:
	var env := OS.get_environment("CR_LEADERBOARD_ID")
	return env if env != "" else LEADERBOARD_ID

func _ready():
	_ensure_lootlocker_settings()
	# 有账号会话时由 AccountManager 登录白标账号，避免游客会话覆盖云端账号 token
	if FileAccess.file_exists("user://account_session.cfg"):
		print("[LootLocker] 检测到账号会话，等待账号登录")
		return
	await authenticate()

# 若 LootLockerSettings.cfg 未随包导出，运行时补齐配置
func _ensure_lootlocker_settings() -> void:
	var s: LootLockerInternal_Settings = LootLockerInternal_Settings.GetInstance()
	if s == null:
		return
	if s.apiKey != "" and s.domainKey != "":
		return
	push_warning("[LootLocker] 未找到 LootLockerSettings.cfg（导出未包含），使用内置配置兜底")
	s.apiKey = FALLBACK_API_KEY
	s.domainKey = FALLBACK_DOMAIN_KEY
	s.gameVersion = FALLBACK_GAME_VERSION
	s.url = "https://" + s.domainKey + ".api.lootlocker.com"
	if s.logLevel == "":
		s.logLevel = "Info"

func authenticate():
	var request = LL_Authentication.GuestSession.new()
	var response = await request.send()
	if response.success:
		print("[LootLocker] 登录成功")
	else:
		print("[LootLocker] 登录失败: ", response.error_data)

# 提交奖杯
func current_member_id() -> String:
	var actual := str(LL_StateData.GetCachedPlayerLegacyID())
	if actual != "" and actual != "0":
		return actual
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("scoped_player_id"):
		return str(am.scoped_player_id())
	return ""

func current_score_member_id() -> String:
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("scoped_player_id"):
		var sid := str(am.scoped_player_id())
		if sid != "" and sid != "0":
			return sid
	return current_member_id()

func build_leaderboard_payload(score: int, player_name: String) -> Dictionary:
	PlayerData.ensure_week()
	var pid := current_score_member_id()
	return {
		"player_name": player_name,
		"player_id": pid,
		"scoped_id": pid,
		"score": score,
		"avatar_seed": int(PlayerData.avatar_seed),
		"avatar_index": int(PlayerData.avatar_index),
		"highest_trophies": int(PlayerData.highest_trophies),
		"week_key": String(PlayerData.weekly_week),
		"weekly_score": int(PlayerData.weekly_trophies),
		"weekly_wins": int(PlayerData.weekly_wins),
		"weekly_three_crowns": int(PlayerData.weekly_three_crowns),
		"honor_title": String(PlayerData.honor_title),
		"collection_level": int(PlayerData.get_collection_level()),
		"mastery_count": int(PlayerData.get_mastery_card_count()),
		"battle_wins": int(PlayerData.battle_wins),
		"battle_total": int(PlayerData.battle_total()),
		"clan": ClanManager.get_my_clan_name() if ClanManager.has_method("get_my_clan_name") else "",
	}


func submit_trophies(score: int, player_name: String):
	PlayerData.ensure_week()
	var scoped := ""
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("scoped_player_id"):
		scoped = str(am.scoped_player_id())
	# 排行榜 member_id 必须是当前 LootLocker 玩家真实 ID；
	# 账号派生 ID 只放在 metadata 里用于区分本机账号。
	var pid: String = scoped
	if pid == "" or pid == "0":
		pid = current_member_id()
	if pid == "":
		pid = player_name
	if SupabaseAPI and SupabaseAPI.is_ready():
		var payload := build_leaderboard_payload(score, player_name)
		payload["player_id"] = pid
		payload["scoped_id"] = scoped
		await SupabaseAPI.upsert("leader:" + pid, payload)
		return
	var meta := {
		"player_name": player_name,
		"avatar_seed": int(PlayerData.avatar_seed),
		"avatar_index": int(PlayerData.avatar_index),
		"clan": "",
	}
	if am and am.has_method("account_label"):
		meta["account"] = am.account_label()
	meta["scoped_id"] = scoped
	var metadata := Marshalls.utf8_to_base64(JSON.stringify(meta))
	var req = LL_Leaderboards.SubmitScore.new(leaderboard_id(), score, pid, metadata)
	var resp = await req.send()
	if resp.success:
		print("[LootLocker] 奖杯上传成功")
	else:
		last_error = str(resp.error_data)
		print("[LootLocker] 上传失败: ", resp.error_data)

# 获取排行榜
func _decode_metadata(raw) -> Dictionary:
	if raw == null:
		return {}
	var s := str(raw).strip_edges().trim_prefix("\"").trim_suffix("\"")
	if s.strip_edges() == "":
		return {}
	if s.begins_with("{"):
		var parsed = JSON.parse_string(s)
		return parsed if parsed is Dictionary else {}
	# 只对合法 base64 做解码，避免把普通字符串当 base64 解码触发 Unicode 报错
	for i in range(s.length()):
		var c := s[i]
		if not ((c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in ["+", "/", "=", "\n", "\r"]):
			return {}
	var decoded := Marshalls.base64_to_utf8(s)
	if decoded.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(decoded)
	return parsed if parsed is Dictionary else {}

func claim_weekly_rewards() -> void:
	if not AccountManager.is_supabase_authenticated():
		return
	var d := Time.get_datetime_dict_from_system()
	var wd := int(d.get("weekday", 0))
	if wd != 0 and wd != 6:
		return
	PlayerData.ensure_week()
	var wk := PlayerData.current_week_key()
	if PlayerData.weekly_reward_week == wk:
		return
	var rows: Array = await SupabaseAPI.list_prefix("leader:", 500)
	var list: Array = []
	for row in rows:
		if not (row is Dictionary) or not (row.get("value") is Dictionary):
			continue
		var v: Dictionary = row.value
		if String(v.get("week_key", "")) != wk:
			continue
		list.append(v)
	list.sort_custom(func(a, b): return int(a.get("weekly_score", 0)) > int(b.get("weekly_score", 0)))
	if list.is_empty():
		return
	var my_pid := str(ClanManager.get_player_id())
	var my_name := PlayerData.player_name
	var rank := -1
	for i in range(list.size()):
		var v: Dictionary = list[i]
		if String(v.get("scoped_id", "")) == my_pid or String(v.get("player_id", "")) == my_pid or String(v.get("player_name", "")) == my_name:
			rank = i
			break
	PlayerData.weekly_reward_week = wk
	if rank < 0 or rank > 2:
		PlayerData.save_data()
		return
	var wl := PlayerData.current_week_label()
	var titles := ["冠军", "亚军", "季军"]
	var rewards := [
		{"gold": 2000, "gems": 100},
		{"gold": 1200, "gems": 60},
		{"gold": 800, "gems": 30},
	]
	PlayerData.honor_title = "%s · %s" % [wl, titles[rank]]
	PlayerData.add_mail("周排行榜奖励", "恭喜获得 %s 周榜%s（第 %d 名）！\n荣誉称号已显示在你的个人简介中。" % [wl, titles[rank], rank + 1], rewards[rank], "排行榜", "weekly", {"week": wk})
	PlayerData.save_data()
	ProfileAPI.publish_self()


func get_leaderboard(callback: Callable):
	last_error = ""
	if SupabaseAPI and SupabaseAPI.is_ready():
		var rows: Array = await SupabaseAPI.list_prefix("leader:", 500)
		var sb_entries: Array = []
		for row in rows:
			if not (row is Dictionary) or not (row.get("value") is Dictionary):
				continue
			var v: Dictionary = row.value
			sb_entries.append({
				"rank": 0,
				"name": String(v.get("player_name", "玩家")),
				"player_id": String(v.get("player_id", "")),
				"score": int(v.get("score", 0)),
				"avatar_seed": int(v.get("avatar_seed", 0)),
				"avatar_index": int(v.get("avatar_index", 0)),
				"clan": String(v.get("clan", "")),
				"scoped_id": String(v.get("scoped_id", "")),
				"highest_trophies": int(v.get("highest_trophies", v.get("score", 0))),
				"week_key": String(v.get("week_key", "")),
				"weekly_score": int(v.get("weekly_score", 0)),
				"weekly_wins": int(v.get("weekly_wins", 0)),
				"weekly_three_crowns": int(v.get("weekly_three_crowns", 0)),
				"honor_title": String(v.get("honor_title", "")),
				"collection_level": int(v.get("collection_level", 1)),
				"mastery_count": int(v.get("mastery_count", 0)),
				"battle_wins": int(v.get("battle_wins", 0)),
				"battle_total": int(v.get("battle_total", 0)),
			})
		sb_entries.sort_custom(func(a, b): return int(a.score) > int(b.score))
		for i in range(sb_entries.size()):
			sb_entries[i]["rank"] = i + 1
		if callback != null and callback.is_valid():
			callback.call(sb_entries)
		return
	var req = LL_Leaderboards.GetScoreList.new(leaderboard_id(), 50, -1)
	print("[Leaderboard] 正在获取排行榜...")
	var resp = await req.send()
	var entries: Array = []
	if resp.success:
		var items = resp.get("items") if resp.has_method("get") else resp.items
		if items == null:
			items = []
		print("[Leaderboard] 获取成功, 共 %d 条" % items.size())
		for item in items:
			var member_id := str(item.get("member_id") if item.has_method("get") else item.member_id)
			var meta := _decode_metadata(item.get("metadata") if item.has_method("get") else item.metadata)
			var shown: String = String(meta.get("player_name", ""))
			if shown.strip_edges() == "":
				var pl0 = item.get("player") if item.has_method("get") else item.player
				if pl0 != null:
					shown = String(pl0.get("name", "") if pl0.has_method("get") else pl0.name)
			if shown.strip_edges() == "":
				shown = "玩家"
			entries.append({
				"rank": int(item.get("rank") if item.has_method("get") else item.rank),
				"name": shown,
				"player_id": member_id,
				"score": int(item.get("score") if item.has_method("get") else item.score),
				"avatar_seed": int(meta.get("avatar_seed", absi(hash(shown)))),
				"avatar_index": int(meta.get("avatar_index", 0)),
				"clan": String(meta.get("clan", "")),
				"scoped_id": String(meta.get("scoped_id", "")),
			})
	else:
		last_error = str(resp.error_data)
		print("[Leaderboard] 获取失败: ", resp.error_data)
	if resp.success:
		var self_id := current_score_member_id()
		var has_self := false
		for e in entries:
			if String(e.get("player_id", "")) == self_id and self_id != "":
				has_self = true
				break
		if not has_self and self_id != "":
			var rank_req = LL_Leaderboards.GetMemberRank.new(leaderboard_id(), self_id)
			var rank_resp = await rank_req.send()
			if rank_resp.success and int(rank_resp.rank) > 0:
				var self_meta := _decode_metadata(rank_resp.metadata)
				var self_name := String(self_meta.get("player_name", PlayerData.player_name))
				entries.append({
					"rank": int(rank_resp.rank),
					"name": self_name if self_name.strip_edges() != "" else PlayerData.player_name,
					"player_id": self_id,
					"score": int(rank_resp.score),
					"avatar_seed": int(self_meta.get("avatar_seed", PlayerData.avatar_seed)),
					"avatar_index": int(self_meta.get("avatar_index", PlayerData.avatar_index)),
					"clan": String(self_meta.get("clan", "")),
					"scoped_id": String(self_meta.get("scoped_id", "")),
				})
	if callback != null and callback.is_valid():
		callback.call(entries)
