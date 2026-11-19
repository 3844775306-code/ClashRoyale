# scripts/core/ClanManager.gd
extends Node
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

## LootLocker 部落管理系统 - 基于通用排行榜 + Metadata
## 原理：每个部落作为一条通用排行榜条目，部落名称作为 member_id，
##       部落总奖杯作为 score，部落详细数据（成员、聊天等）以 JSON 存入 metadata。

const MAX_MEMBERS := 50
const MAX_CHAT_MESSAGES := 100
const CACHE_SECONDS := 12.0
var _clans_cache: Array = []
var _cache_at: float = 0.0
const CLAN_LEADERBOARD_KEY := "global_clan_list"

static func clan_leaderboard_key() -> String:
	var env := OS.get_environment("CR_CLAN_LEADERBOARD_KEY")
	return env if env != "" else CLAN_LEADERBOARD_KEY
func _encode(plain: String) -> String:
	return Marshalls.utf8_to_base64(plain)

func _decode(encoded: String) -> String:
	var s: String = encoded.strip_edges()
	if s == "":
		return ""
	if s.begins_with("{") or s.begins_with("["):
		return s
	for i in range(s.length()):
		var c: String = s[i]
		if not ((c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in ["+", "/", "=", "\n", "\r"]):
			return s
	var decoded := Marshalls.base64_to_utf8(s)
	return decoded if decoded.strip_edges() != "" else s
# 安全地获取响应中的错误信息
# 将 LootLocker 响应转换为标准字典
func _response_to_dict(response) -> Dictionary:
	if response == null:
		return {}
	if typeof(response) == TYPE_DICTIONARY:
		return response
	# 大多数 LootLocker 响应类都支持 to_dict()
	if response.has_method("to_dict"):
		return response.to_dict()
	# 最后尝试用 get 方法（某些响应支持）
	var result = {}
	for prop in ["success", "error", "status_code", "message", "scores"]:
		if response.has_method("get"):
			var val = response.get(prop)
			if val != null:
				result[prop] = val
		elif response.has(prop):
			result[prop] = response[prop]
	return result
func _get_response_error(response) -> String:
	if response.has_method("get"):
		var err = response.get("error")
		if err != null and err != "":
			return err
		var msg = response.get("message")
		if msg != null and msg != "":
			return msg
	return "未知错误"
# ---------- 玩家信息（基于 LL_StateData）----------
func get_player_id() -> int:
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("scoped_player_id"):
		return int(am.scoped_player_id())
	return LL_StateData.GetCachedPlayerLegacyID()

func get_player_name() -> String:
	# 优先使用游戏内的实际玩家名（排行榜/部落/聊天一致）
	var pname := PlayerData.player_name.strip_edges()
	if pname != "":
		return pname
	var name = LL_StateData.GetCachedPlayerName()
	return name if name != "" else "玩家"

func is_logged_in() -> bool:
	if SupabaseAPI and SupabaseAPI.is_ready():
		return true
	return LL_StateData.IsLoggedIn()

# ---------- 初始化 ----------
func guest_login():
	if SupabaseAPI and SupabaseAPI.is_ready():
		return
	if is_logged_in():
		print("ClanManager: 已登录，玩家ID: ", get_player_id())
		get_player_inventory(get_player_id(), func(success, inventory):
			if success and inventory is Dictionary:
				for card_id in inventory.keys():
					PlayerData.card_quantities[int(card_id)] = inventory[card_id]
				PlayerData.save_data()
		)
		return
	var session = LL_Authentication.GuestSession.new()
	var response = await session.send()
	if response.success:
		print("ClanManager: 游客登录成功, player_id=", get_player_id())
	else:
		var err_msg = "登录失败: " + str(response.error)
		print(err_msg)
		# 发送信号或直接弹出提示（确保主场景有接收）
		if get_tree() and get_tree().get_first_node_in_group("ui_notifier"):
			get_tree().get_first_node_in_group("ui_notifier").show_message(err_msg)
# 从排行榜读取某玩家的库存 (callback 返回 Dictionary{ card_id: quantity })
func get_player_inventory(player_id: int, callback: Callable):
	if SupabaseAPI and SupabaseAPI.is_ready():
		var inv_sb := await SupabaseAPI.get_value("inventory:" + str(player_id))
		callback.call(true if not inv_sb.is_empty() else false, inv_sb)
		return
	if not is_logged_in() or player_id <= 0:
		callback.call(false, {})
		return
	var leaderboard_key = "player_inventory_%s" % player_id
	var request = LL_Leaderboards.GetScoreList.new(leaderboard_key, 1)
	var response = await request.send()
	if response.success and response.get("scores") != null and response.scores.size() > 0:
		var metadata_str = response.scores[0].get("metadata", "{}")
		var decoded = _decode(str(metadata_str))
		callback.call(true, JSON.parse_string(decoded))
	else:
		callback.call(true, {})  # 没有库存条目，返回空字典

# 保存某玩家的库存到排行榜
func save_player_inventory(player_id: int, inventory: Dictionary, callback: Callable = Callable()):
	if SupabaseAPI and SupabaseAPI.is_ready():
		var ok_sb2 := await SupabaseAPI.upsert("inventory:" + str(player_id), inventory)
		if _cb_valid(callback): callback.call(ok_sb2, "" if ok_sb2 else "库存同步失败")
		return
	var leaderboard_key = "player_inventory_%s" % player_id
	var member_id = str(player_id)
	var metadata = _encode(JSON.stringify(inventory))
	var request = LL_Leaderboards.SubmitScore.new(leaderboard_key, 0, member_id, metadata)
	var response = await request.send()
	if _cb_valid(callback):
		callback.call(response.success, "" if response.success else "库存同步失败")
# ---------- 获取当前玩家所在部落 ----------
func _cb_valid(cb: Callable) -> bool:
	if cb == null or not cb.is_valid():
		return false
	var obj = cb.get_object()
	if obj != null and not is_instance_valid(obj):
		return false
	return true

func sync_my_inventory(callback: Callable = Callable()) -> void:
	invalidate_cache()
	if not is_logged_in() or get_player_id() <= 0:
		if _cb_valid(callback): callback.call(false)
		return
	get_player_inventory(get_player_id(), func(success, inventory):
		if success and inventory is Dictionary and not inventory.is_empty():
			for cid in inventory.keys():
				PlayerData.card_quantities[int(cid)] = int(inventory[cid])
			PlayerData.save_data()
		_claim_pending_gifts(callback)
	)

const LOCAL_SHARED_DIR := "user://local_shared"

func _local_gift_path(player_id: int) -> String:
	return LOCAL_SHARED_DIR + "/gifts_%s.json" % player_id

func _queue_local_gift(to_player_id: int, card_id: int, amount: int, sender: String, gift_id: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOCAL_SHARED_DIR))
	var path := _local_gift_path(to_player_id)
	var arr: Array = []
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			if parsed is Array:
				arr = parsed
			rf.close()
	arr.append({"card_id": card_id, "amount": amount, "sender": sender, "gift_id": gift_id})
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(arr))
		wf.close()

func _drain_local_gifts() -> Array:
	var path := _local_gift_path(get_player_id())
	var arr: Array = []
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf:
			var parsed = JSON.parse_string(rf.get_as_text())
			if parsed is Array:
				arr = parsed
			rf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return arr

func _deliver_gift_mail(g: Dictionary) -> void:
	var cid: int = int(g.get("card_id", 0))
	var amount: int = int(g.get("amount", 0))
	if cid <= 0 or amount <= 0:
		return
	var sender := String(g.get("sender", "部落成员"))
	var gid := String(g.get("gift_id", "%s_%s_%s" % [sender, cid, amount]))
	PlayerData.add_gift_mail_once(
		"部落赠卡",
		"来自 %s 的赠卡：卡牌 #%d ×%d\n请点击领取加入卡牌收藏。" % [sender, cid, amount],
		{"cards": {str(cid): amount}}, sender, gid)

func _claim_pending_gifts(callback: Callable = Callable()) -> void:
	var local_gifts := _drain_local_gifts()
	for lg in local_gifts:
		_deliver_gift_mail(lg)
	invalidate_cache()
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(not local_gifts.is_empty())
			return
		var gifts: Dictionary = clan.get("pending_card_gifts", {})
		var key := str(get_player_id())
		var mine = gifts.get(key, [])
		if mine is Dictionary:
			var conv: Array = []
			for k in mine.keys():
				conv.append({"card_id": int(k), "amount": int(mine[k]), "sender": "部落成员"})
			mine = conv
		if mine.is_empty():
			if _cb_valid(callback): callback.call(true)
			return
		for g in mine:
			var cid: int = int(g.get("card_id", 0))
			var amount: int = int(g.get("amount", 0))
			if cid > 0 and amount > 0:
				_deliver_gift_mail(g)
		gifts.erase(key)
		clan["pending_card_gifts"] = gifts
		invalidate_cache()
		_update_clan_on_leaderboard(clan, func(ok, err):
			if _cb_valid(callback): callback.call(ok)
		)
	)
func _claim_legacy_membership(clan: Dictionary, old_key: String, new_key: String) -> void:
	var members: Dictionary = clan.get("members", {})
	if members.has(old_key) and not members.has(new_key):
		members[new_key] = Dictionary(members[old_key]).duplicate(true)
		members.erase(old_key)
		clan["members"] = members
	var gifts: Dictionary = clan.get("pending_card_gifts", {})
	if gifts.has(old_key) and not gifts.has(new_key):
		gifts[new_key] = gifts[old_key]
		gifts.erase(old_key)
		clan["pending_card_gifts"] = gifts
	invalidate_cache()
	_update_clan_on_leaderboard(clan)

func get_my_clan(callback: Callable):
	# 这个函数需要在服务器端维护一个映射表；简化处理：扫描整个部落列表寻找当前玩家
	# 更高效的方式是使用另一个排行榜或 player storage 记录每个玩家的所属部落
	# 这里先用遍历方式，适用于小规模测试
	get_all_clans(func(success, clans):
		if not success:
			if _cb_valid(callback): callback.call(false, "获取部落列表失败")
			return
		var pid = str(get_player_id())
		for clan in clans:
			if clan.has("members") and clan.members.has(pid):
				if _cb_valid(callback): callback.call(true, clan)
				return
		# 迁移兼容：旧 LootLocker 部落成员 key 与新建 Supabase 账号 ID 不同，按玩家名认领
		for clan in clans:
			var members: Dictionary = clan.get("members", {})
			for old_key in members.keys():
				var m: Dictionary = Dictionary(members[old_key])
				if String(m.get("player_name", "")) == get_player_name():
					_claim_legacy_membership(clan, String(old_key), pid)
					if _cb_valid(callback): callback.call(true, clan)
					return
		callback.call(true, null)  # 没有加入任何部落
	)

# ---------- 部落操作 ----------

## 创建部落
func create_clan(clan_name: String, description: String, min_trophies: int, is_open: bool, callback: Callable):
	if not is_logged_in():
		callback.call(false, "未登录")
		return

	# 先检查玩家是否已有部落
	get_my_clan(func(success, existing):
		if not success:
			callback.call(false, "检查部落失败")
			return
		if existing != null:
			callback.call(false, "你已经加入了一个部落，请先离开当前部落")
			return

		# 构建部落数据
		var clan_data = {
			"name": clan_name,
			"description": description,
			"min_trophies": min_trophies,
			"is_open": is_open,
			"leader_id": get_player_id(),
			"members": {
				str(get_player_id()): {
					"player_name": get_player_name(),
					"trophies": PlayerData.trophies,
					"role": "leader",
					"donations": 0,
					"avatar_seed": PlayerData.avatar_seed,
					"avatar_index": PlayerData.avatar_index,
					"joined": Time.get_unix_time_from_system()
				}
			},
			"chat": [],
			"applications": [],
			"total_trophies": PlayerData.trophies
		}

		_submit_clan_to_leaderboard(clan_data, callback)
	)

# ---------- 内部：将部落数据提交到排行榜 ----------
func _submit_clan_to_leaderboard(clan_data: Dictionary, callback: Callable):
	if SupabaseAPI and SupabaseAPI.is_ready():
		var sid := "clan_" + str(int(Time.get_unix_time_from_system() * 1000.0)) + "_" + str(randi() % 1000)
		clan_data["clan_id"] = sid
		var ok_sb := await SupabaseAPI.upsert("clan:" + sid, clan_data)
		if _cb_valid(callback): callback.call(ok_sb, sid if ok_sb else "保存部落失败")
		return
	var leaderboard_key = clan_leaderboard_key()
	var member_id = "clan_" + str(int(Time.get_unix_time_from_system() * 1000.0)) + "_" + str(randi() % 1000)
	var score = clan_data.get("total_trophies", 0)
	var metadata = _encode(JSON.stringify(clan_data))

	print("[ClanManager] 提交部落，member_id=", member_id, " metadata长度=", metadata.length())
	var request = LL_Leaderboards.SubmitScore.new(leaderboard_key, score, member_id, metadata)
	var response = await request.send()
	# 响应对象 attr 访问
	if response.success:
		print("[ClanManager] 部落创建成功，clan_id=", member_id)
		clan_data["clan_id"] = member_id
		callback.call(true, member_id)
	else:
		print("[ClanManager] 创建失败，error: ", response.error if response.has("error") else "无错误信息")
		callback.call(false, response.error if response.has("error") else "提交失败")

# ---------- 内部：更新部落数据（覆盖提交）----------
func _update_clan_on_leaderboard(clan_data: Dictionary, callback: Callable = Callable()):
	if SupabaseAPI and SupabaseAPI.is_ready():
		var sb_id := String(clan_data.get("clan_id", ""))
		if sb_id == "":
			if _cb_valid(callback): callback.call(false, "clan_id 缺失")
			return
		_recalc_total(clan_data)
		var ok_sb := await SupabaseAPI.upsert("clan:" + sb_id, clan_data)
		if _cb_valid(callback): callback.call(ok_sb, null if ok_sb else "更新失败")
		return
	var member_id = clan_data.get("clan_id", "")
	if member_id == "":
		if callback.is_valid(): callback.call(false, "clan_id 缺失")
		return
	_recalc_total(clan_data)
	var score = clan_data.get("total_trophies", 0)
	var metadata = _encode(JSON.stringify(clan_data))
	var request = LL_Leaderboards.SubmitScore.new(clan_leaderboard_key(), score, member_id, metadata)
	var response = await request.send()
	if callback.is_valid():
		if response.success:
			callback.call(true, null)
		else:
			callback.call(false, response.error if response.has("error") else "更新失败")

# ---------- 获取所有部落 ----------
func _recalc_total(clan: Dictionary) -> void:
	var total := 0
	var members: Dictionary = clan.get("members", {})
	for mid in members.keys():
		total += int(members[mid].get("trophies", 0))
	clan["total_trophies"] = total

## 玩家改名后同步自己在部落成员信息里的名字/奖杯/头像
func sync_my_profile(callback: Callable = Callable()) -> void:
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if callback.is_valid():
				callback.call(false, "未加入部落")
			return
		var mid := str(get_player_id())
		var members: Dictionary = clan.get("members", {})
		if not members.has(mid):
			if callback.is_valid():
				callback.call(false, "成员不存在")
			return
		var m: Dictionary = members[mid]
		m["player_name"] = get_player_name()
		m["trophies"] = PlayerData.trophies
		m["avatar_seed"] = PlayerData.avatar_seed
		m["avatar_index"] = PlayerData.avatar_index
		members[mid] = m
		clan["members"] = members
		invalidate_cache()
		_update_clan_on_leaderboard(clan, callback)
	)


func invalidate_cache() -> void:
	_cache_at = 0.0
	_clans_cache.clear()

func get_all_clans(callback: Callable):
	var now: float = Time.get_unix_time_from_system()
	if not _clans_cache.is_empty() and now - _cache_at < CACHE_SECONDS:
		callback.call(true, _clans_cache.duplicate(true))
		return
	if SupabaseAPI and SupabaseAPI.is_ready():
		var rows: Array = await SupabaseAPI.list_prefix("clan:")
		var clans_sb: Array = []
		for row in rows:
			if row is Dictionary and row.get("value") is Dictionary:
				clans_sb.append(Dictionary(row.get("value")))
		_clans_cache = clans_sb.duplicate(true)
		_cache_at = now
		callback.call(true, clans_sb)
		return
	var request = LL_Leaderboards.GetScoreList.new(clan_leaderboard_key(), 100)
	var response = await request.send()
	
	# 使用 response.get("success") 安全访问
	if not response.get("success"):
		var err = response.get("error")
		callback.call(false, str(err) if err != null else "获取失败")
		return

	# 尝试常见字段名获取条目数组
	var items = null
	for key in ["scores", "items", "entries", "results", "data"]:
		var val = response.get(key)
		if val != null and typeof(val) == TYPE_ARRAY:
			items = val
			break

	if items == null:
		# 最后尝试直接遍历属性
		for prop in response.get_property_list():
			var val = response.get(prop.name)
			if typeof(val) == TYPE_ARRAY and val.size() > 0:
				items = val
				break

	if items == null:
		callback.call(false, "响应中没有找到任何条目数组")
		return

	var clans = []
	for entry in items:
		var metadata_str = ""
		var member_id = ""
		var score = 0

		# entry 也可能是对象，安全获取
		metadata_str = _decode(str(entry.get("metadata") if entry.get("metadata") != null else ""))
		member_id = str(entry.get("member_id") if entry.get("member_id") != null else "")
		score = int(entry.get("score") if entry.get("score") != null else 0)

		var clan = JSON.parse_string(metadata_str)
		if clan is Dictionary:
			clan["clan_id"] = member_id
			clan["total_trophies"] = score
			clans.append(clan)

	_cache_at = Time.get_unix_time_from_system()
	_clans_cache = clans.duplicate(true)
	callback.call(true, clans)

## 搜索部落
func search_clans(callback: Callable, keyword: String = ""):
	get_all_clans(func(ok, clans):
		if not ok:
			callback.call(false, clans)
			return
		var kw: String = keyword.strip_edges()
		if kw == "":
			callback.call(true, clans)
			return
		var filtered: Array = []
		for c in clans:
			if String(c.get("name", "")).contains(kw) or String(c.get("description", "")).contains(kw):
				filtered.append(c)
		callback.call(true, filtered)
	)

## 加入部落
func join_clan(clan_id: String, callback: Callable):
	get_all_clans(func(success, clans):
		if not success:
			if _cb_valid(callback): callback.call(false, "获取部落列表失败")
			return
		var target_clan = null
		for c in clans:
			if c.get("clan_id") == clan_id:
				target_clan = c
				break
		if target_clan == null:
			callback.call(false, "部落不存在")
			return
		if target_clan.members.size() >= MAX_MEMBERS:
			callback.call(false, "部落已满")
			return
		if target_clan.min_trophies > 0 and PlayerData.trophies < target_clan.min_trophies:
			callback.call(false, "奖杯不足，无法加入")
			return
		if not target_clan.is_open:
			if not target_clan.has("applications"):
				target_clan["applications"] = []
			for app in target_clan.applications:
				if int(app.get("player_id", -1)) == get_player_id():
					callback.call(false, "你已经提交过申请")
					return
			target_clan.applications.append({
				"player_id": get_player_id(),
				"player_name": get_player_name(),
				"trophies": PlayerData.trophies,
				"time": Time.get_unix_time_from_system()
			})
			_update_clan_on_leaderboard(target_clan, func(ok, err):
				if ok:
					callback.call(true, "applied")
				else:
					callback.call(false, err)
			)
			return

		# 把当前玩家加入成员列表
		target_clan.members[str(get_player_id())] = {
			"player_name": get_player_name(),
			"trophies": PlayerData.trophies,
			"role": "member",
			"donations": 0,
			"avatar_seed": PlayerData.avatar_seed,
			"avatar_index": PlayerData.avatar_index,
			"joined": Time.get_unix_time_from_system()
		}
		_recalc_total(target_clan)
		_update_clan_on_leaderboard(target_clan, callback)
	)

## 离开部落
func leave_clan(callback: Callable):
	get_my_clan(func(success, clan):
		if not success:
			callback.call(false, "获取部落信息失败")
			return
		if clan == null:
			if _cb_valid(callback): callback.call(false, "你不在任何部落中")
			return
		if clan.leader_id == get_player_id():
			callback.call(false, "你是首领，请先转让首领或解散部落")
			return
		clan.members.erase(str(get_player_id()))
		_recalc_total(clan)
		_update_clan_on_leaderboard(clan, callback)
	)

## 首领踢人
func kick_member(member_id: int, callback: Callable):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		if clan.leader_id != get_player_id():
			callback.call(false, "只有首领可以踢人")
			return
		if not clan.members.has(str(member_id)):
			callback.call(false, "该成员不在部落中")
			return
		if member_id == get_player_id():
			callback.call(false, "不能踢自己")
			return
		clan.members.erase(str(member_id))
		_recalc_total(clan)
		_update_clan_on_leaderboard(clan, callback)
	)

## 转让首领
func promote_to_leader(new_leader_id: int, callback: Callable):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		if clan.leader_id != get_player_id():
			callback.call(false, "你不是首领")
			return
		if not clan.members.has(str(new_leader_id)):
			callback.call(false, "目标玩家不在部落中")
			return
		clan.members[str(get_player_id())].role = "member"
		clan.members[str(new_leader_id)].role = "leader"
		clan.leader_id = new_leader_id
		_update_clan_on_leaderboard(clan, callback)
	)

func approve_application(applicant_id: int, callback: Callable):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		if clan.leader_id != get_player_id():
			callback.call(false, "只有首领可以审批")
			return
		var apps: Array = clan.get("applications", [])
		var target: Dictionary = {}
		for a in apps:
			if int(a.get("player_id", -1)) == applicant_id:
				target = a
				break
		if target.is_empty():
			callback.call(false, "申请不存在")
			return
		if clan.members.size() >= MAX_MEMBERS:
			callback.call(false, "部落已满")
			return
		clan.members[str(applicant_id)] = {
			"player_name": target.get("player_name", "玩家"),
			"trophies": int(target.get("trophies", 0)),
			"role": "member",
			"donations": 0,
			"avatar_seed": int(target.get("avatar_seed", absi(hash(String(target.get("player_name","玩家")))))),
			"avatar_index": int(target.get("avatar_index", 0)),
			"joined": Time.get_unix_time_from_system()
		}
		apps.erase(target)
		clan["applications"] = apps
		_recalc_total(clan)
		_update_clan_on_leaderboard(clan, callback)
	)

func reject_application(applicant_id: int, callback: Callable):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		if clan.leader_id != get_player_id():
			callback.call(false, "只有首领可以审批")
			return
		var apps: Array = clan.get("applications", [])
		for i in range(apps.size() - 1, -1, -1):
			if int(apps[i].get("player_id", -1)) == applicant_id:
				apps.remove_at(i)
		clan["applications"] = apps
		_update_clan_on_leaderboard(clan, callback)
	)

# ---------- 聊天系统 ----------
## 发送聊天消息
func send_chat_message(message: String, callback: Callable = Callable()):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if callback.is_valid(): callback.call(false, "获取部落信息失败")
			return
		if not clan.has("chat"):
			clan["chat"] = []
		clan["chat"].push_front({
			"player_id": get_player_id(),
			"player_name": get_player_name(),
			"message": message,
			"timestamp": Time.get_unix_time_from_system(),
			"type": "chat",
			"avatar_seed": PlayerData.avatar_seed,
			"avatar_index": PlayerData.avatar_index
		})
		if clan["chat"].size() > MAX_CHAT_MESSAGES:
			clan["chat"].resize(MAX_CHAT_MESSAGES)
		_update_clan_on_leaderboard(clan, callback)
	)

## 获取聊天记录（异步）
func get_chat_history(callback: Callable):
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		callback.call(true, clan.get("chat", []))
	)

# ---------- 卡牌请求与捐赠 ----------
## 请求卡牌
func _request_amount_for(card_id: int) -> int:
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	if rar == "common":
		return 40
	if rar == "rare" or rar == "epic":
		return 4
	return 0

func _donation_step_for(card_id: int) -> int:
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	return 10 if rar == "common" else 1

func _is_sunday() -> bool:
	return int(Time.get_date_dict_from_system().weekday) == 0

func request_card(card_id: int, amount: int, callback: Callable):
	if not PlayerData.can_request_card():
		callback.call(false, "卡牌请求冷却中")
		return
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	if rar == "legendary":
		callback.call(false, "无法请求传奇卡")
		return
	var fixed_amount: int = _request_amount_for(card_id)
	if fixed_amount <= 0:
		callback.call(false, "该卡牌无法请求")
		return
	amount = fixed_amount
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		if PlayerData.get_card_quantity(card_id) <= 0:
			callback.call(false, "你还没有这张卡，无法请求")
			return
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if not bm:
			bm = load("res://scripts/core/BattleManager.gd").new()
			bm.load_card_configs()
		var cfg = bm.get_config(card_id)
		if not clan.has("chat"):
			clan["chat"] = []
		clan["chat"].push_front({
			"player_id": get_player_id(),
			"player_name": get_player_name(),
			"message": "请求 %d 张 %s" % [amount, cfg.card_name],
			"timestamp": Time.get_unix_time_from_system(),
			"type": "request",
			"card_id": card_id,
			"card_name": cfg.card_name,
			"amount": amount,
			"donated": 0,
			"donors": [],
			"request_key": "%d_%d_%d" % [get_player_id(), card_id, Time.get_unix_time_from_system()],
			"avatar_seed": PlayerData.avatar_seed,
			"avatar_index": PlayerData.avatar_index
		})
		if clan["chat"].size() > MAX_CHAT_MESSAGES:
			clan["chat"].resize(MAX_CHAT_MESSAGES)
		PlayerData.mark_card_request()
		_update_clan_on_leaderboard(clan, callback)
	)

func donate_card(to_player_id: int, card_id: int, amount: int, request_key: String, callback: Callable):
	if to_player_id == get_player_id():
		if _cb_valid(callback): callback.call(false, "不能捐赠给自己")
		return
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	if rar == "epic" and not _is_sunday():
		if _cb_valid(callback): callback.call(false, "史诗卡只有周日才能捐赠")
		return
	var step: int = _donation_step_for(card_id)
	if PlayerData.get_card_quantity(card_id) < step:
		if _cb_valid(callback): callback.call(false, "你拥有的该卡牌数量不足")
		return
	get_my_clan(func(success, clan):
		if not success or clan == null:
			if _cb_valid(callback): callback.call(false, "获取部落信息失败")
			return
		var chat_list: Array = clan.get("chat", [])
		var msg_index := -1
		for i in range(chat_list.size()):
			var msg: Dictionary = chat_list[i]
			if msg.get("type", "") != "request":
				continue
			var key_ok: bool = request_key == "" or String(msg.get("request_key", "")) == request_key
			if key_ok and int(msg.get("player_id", -1)) == to_player_id and int(msg.get("card_id", -1)) == card_id:
				msg_index = i
				break
		if msg_index < 0:
			if _cb_valid(callback): callback.call(false, "该请求已完成或不存在")
			return
		var msg: Dictionary = chat_list[msg_index]
		if String(msg.get("player_name", "")) == get_player_name():
			callback.call(false, "不能捐赠给自己")
			return
		var target: int = int(msg.get("amount", amount))
		var donated: int = int(msg.get("donated", 0))
		if donated >= target:
			if _cb_valid(callback): callback.call(false, "该请求已完成")
			return
		var donors: Array = Array(msg.get("donors", []))
		if donors.has(get_player_id()) or donors.has(str(get_player_id())):
			if _cb_valid(callback): callback.call(false, "你已经捐赠过这张请求")
			return
		var contribute: int = mini(step, target - donated)
		if PlayerData.get_card_quantity(card_id) < contribute:
			if _cb_valid(callback): callback.call(false, "你拥有的该卡牌数量不足")
			return
		PlayerData.remove_card(card_id, contribute)
		PlayerData.donations_used += 1
		PlayerData.save_data()
		# 同步捐赠者云端库存，避免下次登录退回
		save_player_inventory(get_player_id(), PlayerData.card_quantities)
		if clan.members.has(str(get_player_id())):
			clan.members[str(get_player_id())].donations += contribute
		msg["donated"] = donated + contribute
		donors.append(get_player_id())
		msg["donors"] = donors
		chat_list[msg_index] = msg
		clan["chat"] = chat_list
		# 接收者的待领取赠卡放在部落数据中，跨账号可靠送达
		var gifts: Dictionary = clan.get("pending_card_gifts", {})
		var gkey := str(to_player_id)
		var mine = gifts.get(gkey, [])
		if mine is Dictionary:
			var conv: Array = []
			for k in mine.keys():
				conv.append({"card_id": int(k), "amount": int(mine[k]), "sender": "部落成员"})
			mine = conv
		var gift_id := "%s_%s_%d_%d" % [str(get_player_id()), str(to_player_id), Time.get_ticks_usec(), card_id]
		mine.append({"card_id": card_id, "amount": contribute, "sender": get_player_name(), "gift_id": gift_id})
		gifts[gkey] = mine
		clan["pending_card_gifts"] = gifts
		_queue_local_gift(to_player_id, card_id, contribute, get_player_name(), gift_id)
		_update_clan_on_leaderboard(clan, func(ok, err):
			if not ok:
				if _cb_valid(callback): callback.call(false, "保存部落失败")
				return
			# 赠卡已经写入部落 pending_card_gifts；接收方通过邮箱领取。
			# 云端库存写入是尽力而为，失败也不影响捐赠/请求进度。
			if _cb_valid(callback): callback.call(true, null)
		)
	)
