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
func submit_trophies(score: int, player_name: String):
	var pid: String = ""
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("scoped_player_id"):
		pid = str(am.scoped_player_id())
	if pid == "" or pid == "0":
		pid = str(LL_StateData.GetCachedPlayerLegacyID())
	if pid == "" or pid == "0":
		pid = player_name
	var meta := {
		"player_name": player_name,
		"avatar_seed": int(PlayerData.avatar_seed),
		"avatar_index": int(PlayerData.avatar_index),
		"clan": "",
	}
	if am and am.has_method("account_label"):
		meta["account"] = am.account_label()
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
	var s := str(raw)
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

func get_leaderboard(callback: Callable):
	last_error = ""
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
				shown = "玩家 #" + member_id.substr(maxi(0, member_id.length() - 4))
			entries.append({
				"rank": int(item.get("rank") if item.has_method("get") else item.rank),
				"name": shown,
				"player_id": member_id,
				"score": int(item.get("score") if item.has_method("get") else item.score),
				"avatar_seed": int(meta.get("avatar_seed", absi(hash(shown)))),
				"avatar_index": int(meta.get("avatar_index", 0)),
				"clan": String(meta.get("clan", "")),
			})
	else:
		last_error = str(resp.error_data)
		print("[Leaderboard] 获取失败: ", resp.error_data)
	callback.call(entries)
