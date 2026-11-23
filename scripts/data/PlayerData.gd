# scripts/data/PlayerData.gd
extends Node

const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

const SAVE_PATH = "user://player_data.cfg"
const STARTER_CARDS: Array = [44, 10, 4, 8, 9, 11]
const SAVE_VERSION = 1               # 当前版本
# 2026 官方国王塔升级条件：[目标塔等级, 需要达到该卡等级的张数, 卡牌最低等级]
# 2026 官方 Trophy Road：32 个竞技场（名称、起始奖杯、国王塔等级门槛）
const ARENA_DATA := [
	["哥布林竞技场",0,1],["骨坑",300,2],["野蛮人擂台",600,3],["法术幽谷",1000,4],
	["建筑工坊",1300,5],["皮卡超人乐园",1600,6],["皇家竞技场",2000,7],["冰封之巅",2300,8],
	["丛林竞技场",2600,9],["野猪山脉",3000,9],["电磁峡谷",3400,9],["惊魂小镇",3800,10],
	["绿林小妹藏身处",4200,10],["宁静峰",4600,10],["矿工矿场",5000,10],["屠夫厨房",5500,11],
	["皇家陵墓",6000,11],["寂静圣所",6500,11],["龙之温泉",7000,11],["新兵训练营",7500,11],
	["部落节",8000,12],["PANCAKES!",8500,12],["瓦尔哈拉",9000,12],["传奇竞技场",9500,12],
	["伐木者小屋",10000,12],["皇家大道",10500,12],["火枪手街",11000,13],["英雄之巅",11500,13],
	["魔法学院",12000,13],["终极对战坑",12500,13],["小王子酒馆",13000,13],["灵魂广场",13500,13],
]
const KING_TOWER_REQS := [[2,9,1],[3,9,2],[4,10,3],[5,10,4],[6,10,5],[7,10,6],[8,10,7],[9,10,8],[10,10,9],[11,10,10],[12,11,11],[13,11,12],[14,12,13],[15,13,14],[16,14,15]]
var gold: int = 100
var gems: int = 10
var email_bind_reward_claimed: bool = false
var experience: int = 0
var player_name:String = "玩家"
var name_chosen: bool = false        # 玩家是否已完成取名（首次启动强制取名）
signal mail_added(title: String, body: String, sender: String)
var bio: String = "热爱皇室战争的玩家，欢迎一起交流卡组与战术。"
var clan_role: String = ""
var total_donations: int = 0
var challenge_state: Dictionary = {}   # 挑战/锦标赛进度（active: {id,wins,losses}）
var party_deck: Array = []             # 派对模式专用卡组（全卡可用，固定 11 级）
var trophies: int = 0          # 当前奖杯（永不为负）
var highest_trophies: int = 0  # 历史最高奖杯（奖杯门保护）
var arena_seen: int = 0        # 已看过入场动画的最高竞技场
var claimed_achievements: Array = []  # 已领取的皇室征程成就（竞技场序号）
var donations_used: int = 0          # 今日已捐赠次数
var battle_wins: int = 0
var weekly_week: String = ""
var weekly_trophies: int = 0
var weekly_wins: int = 0
var weekly_three_crowns: int = 0
var weekly_reward_week: String = ""
var honor_title: String = ""
var battle_losses: int = 0
var battle_draws: int = 0
var three_crown_wins: int = 0
var current_streak: int = 0
var best_streak: int = 0
var recent_battles: Array = []
var chest_reward_day: String = ""    # 每日宝箱奖励日期
var chest_reward_wins: int = 0        # 当日已获得宝箱的胜利次数
# 卡牌拥有数量 { card_id: int }
var card_quantities: Dictionary = {}
# 卡牌等级：{ card_id: level (1-16) }
var card_levels: Dictionary = {}
var new_cards: Dictionary = {}   # 新获得但尚未点击查看的卡牌 {cid: true}
# 宝箱队列（存储 Chest 数据，可序列化）
var chests: Array = []   # 每个元素 { "rarity": "silver"/"gold"/"magical", "ready": bool }
var ai_levels: Dictionary = {}
var ai_king_level: int = 1
var custom_decks: Array = [[], [], [], [], []]   # 5 套自定义卡组
var active_deck_index: int = 0
var deck_clipboard: Array = []
var custom_deck: Array = []          # 旧字段，保留用于迁移
var use_custom_deck: bool = false    # 对战时是否使用自定义卡组
var test_mode: bool = false            # 测试模式：随机卡组 + 固定11级
var deck_sort_mode: String = "level"   # 卡组配置排序记忆：level/rarity/default
var chest_open_index: int = -1        # 当前进入开箱界面的宝箱索引（不持久化）
var shop_day: String = ""
var shop_free_claimed_day: String = ""
var shop_offers: Array = []
var owned_emotes: Array = []
var wildcards: Dictionary = {}
var tower_choice: int = 1   # 1=公主塔, 2=王子塔, 3=厨师塔, 4=飞刀塔
var tower_usage: Dictionary = {}
var last_card_request: float = 0.0
var record_replays: bool = true
var spectator_approval_required: bool = false
var tutorial_done: bool = false
var tutorial_guide_seen: bool = false
var tutorial_practice: bool = false
var tutorial_chest_claimed: bool = false
var starter_cards_v2: bool = false
var chest_reveal_pending: bool = false
var collection_rewards_claimed: Array = []
var card_mastery: Dictionary = {}
var mailbox: Array = []
var mail_alert_pending: String = ""
var mail_version_seen: String = ""
var announcement_seen: int = 0
var _global_mail_busy: bool = false
var season_key: String = ""
var season_crowns: int = 0
var season_claimed: Array = []
var _collection_rewards_cache: Array = []
var avatar_seed: int = 0
var avatar_index: int = 0
var avatar_custom_path: String = ""
var account_id: String = "default"          # 当前账号 id（default = 旧版单存档）
var account_save_path: String = ""          # 当前账号本地存档路径（空=默认/环境目录）
var portable_data_root: String = ""         # 当 user:// 不可写时使用的 EXE 同目录数据根
var last_save_error: String = ""
func _ready():
	
	load_data()
	_ensure_avatar()
	_ensure_season()
	_ensure_starter_cards()
	_ensure_default_mail()
	call_deferred("sync_global_mail")
	for i in range(130):
		ai_levels[i] = get_ai_card_level()
	
func _data_root() -> String:
	if portable_data_root != "":
		return portable_data_root
	var env := OS.get_environment("CR_ACCOUNT_DATA_DIR")
	return env.trim_suffix("/") if env != "" else "user://"


func _default_save_path() -> String:
	var env := OS.get_environment("CR_ACCOUNT_DATA_DIR")
	return (env.trim_suffix("/") + "/player_data.cfg") if env != "" else SAVE_PATH


func current_save_path() -> String:
	return account_save_path if account_save_path != "" else _default_save_path()

func replay_dir() -> String:
	if account_save_path != "":
		return account_save_path.get_base_dir() + "/replays"
	return _data_root().trim_suffix("/") + "/replays"


func ensure_save_dir(for_path: String) -> bool:
	var dir := for_path.get_base_dir()
	if dir == "":
		return false
	if dir.begins_with("user://") or dir.begins_with("res://"):
		return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) == OK
	return DirAccess.make_dir_recursive_absolute(dir) == OK

func fallback_save_path(acct_id: String) -> String:
	return "%s/account_%s.cfg" % [_data_root().trim_suffix("/"), acct_id]

## 切换到指定账号的本地存档；首次登录会把旧版单存档迁移到该账号
func use_account(acct_id: String, migrate_legacy := true) -> void:
	account_id = acct_id
	if acct_id == "" or acct_id == "default":
		account_id = "default"
		account_save_path = _default_save_path()
	else:
		var normal_path := "%s/accounts/%s/player_data.cfg" % [_data_root().trim_suffix("/"), acct_id]
		var fb_path := fallback_save_path(acct_id)
		if FileAccess.file_exists(normal_path):
			account_save_path = normal_path
		elif FileAccess.file_exists(fb_path):
			account_save_path = fb_path
		elif migrate_legacy and FileAccess.file_exists(_default_save_path()):
			account_save_path = normal_path
		else:
			# 新账号直接使用 user:// 根目录的单文件，避免子目录创建失败
			account_save_path = fb_path
	ensure_save_dir(account_save_path)
	if migrate_legacy and acct_id != "default" and not FileAccess.file_exists(account_save_path) \
			and FileAccess.file_exists(_default_save_path()):
		var legacy := FileAccess.get_file_as_bytes(_default_save_path())
		if legacy.size() > 0:
			var f := FileAccess.open(account_save_path, FileAccess.WRITE)
			if f:
				f.store_buffer(legacy)
				f.close()
	load_data()
	_ensure_avatar()
	_ensure_season()
	_ensure_starter_cards()
	_ensure_default_mail()
	ai_levels.clear()
	for i in range(130):
		ai_levels[i] = get_ai_card_level()
	ensure_local_save()


func use_account_file(acct_id: String, save_path: String) -> void:
	account_id = acct_id
	account_save_path = save_path
	ensure_save_dir(account_save_path)
	load_data()
	_ensure_avatar()
	_ensure_season()
	_ensure_starter_cards()
	_ensure_default_mail()
	ensure_local_save()

func apply_save_text(text: String) -> bool:
	if text == "":
		return false
	ensure_save_dir(current_save_path())
	var f := FileAccess.open(current_save_path(), FileAccess.WRITE)
	if f == null:
		last_save_error = "无法写入云端存档：%s" % current_save_path()
		return false
	f.store_string(text)
	f.close()
	load_data()
	_ensure_avatar()
	_ensure_season()
	_ensure_starter_cards()
	_ensure_default_mail()
	return true

func get_card_quantity(card_id: int) -> int:
	return card_quantities.get(card_id, 0)

func add_card(card_id: int, amount: int):
	var old: int = get_card_quantity(card_id)
	if old <= 0 and not is_card_owned(card_id):
		new_cards[card_id] = true
	card_quantities[card_id] = old + amount
	if old <= 0 and not card_levels.has(card_id):
		card_levels[card_id] = CARD_RARITY.start_level_by_id(card_id)
	save_data()

func remove_card(card_id: int, amount: int):
	var current = get_card_quantity(card_id)
	card_quantities[card_id] = max(0, current - amount)
	save_data()

# 2026 Lucky Chest 官方奖励表（1★/3★；等级1-16）
const CHEST_GOLD := {
	1: [50,75,100,125,150,200,250,325,400,500,600,700,800,900,1000,1100],
	3: [800,1200,1600,2000,2400,3200,4000,5200,6400,8000,9600,11200,12800,14400,16000,17600],
}
const CHEST_COMMON := {
	1: [2,2,3,4,5,6,8,10,13,16,19,22,25,28,31,34],
	3: [25,38,50,63,75,100,125,163,200,250,300,350,400,450,500,550],
}
const CHEST_RARE := {
	1: [1,1,1,1,1,1,2,2,3,3,4,4,5,6,6,7],
	3: [5,8,10,13,15,20,25,33,40,50,60,70,80,90,100,110],
}
const CHEST_EPIC := {3: [0,0,0,0,0,2,3,4,5,6,8,9,10,11,13,14]}
const CHEST_LEGEND := {3: [0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,2]}
const CHEST_CHAMPION := {3: [0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1]}

# 2★ Lucky Chest 官方数量（等级1-16）
const CHEST2_GOLD := [200,300,400,500,600,800,1000,1300,1600,2000,2400,2800,3200,3600,4000,4400]
const CHEST2_COMMON := [6,9,12,16,19,25,31,40,50,62,75,88,100,112,125,138]
const CHEST2_RARE := [2,2,2,3,4,5,6,8,10,12,15,18,20,23,25,28]
const CHEST2_EPIC := [0,0,0,0,0,1,1,1,1,2,2,2,3,3,3,3]
# --- 宝箱系统 ---
func _roll_chest_stars(rarity: String) -> int:
	var r: float = randf()
	if rarity == "silver":
		if r < 0.3144: return 1
		if r < 0.7720: return 2
		if r < 0.9573: return 3
		return 4
	elif rarity == "gold":
		return 3 if r < 0.4096 else 4
	else:
		if r < 0.4096: return 3
		if r < 0.9793: return 4
		return 5

const DAILY_CHEST_WIN_LIMIT: int = 4


func _today_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]


func _ensure_daily_chest_day() -> void:
	var today := _today_str()
	if chest_reward_day != today:
		chest_reward_day = today
		chest_reward_wins = 0


func daily_chest_wins_remaining() -> int:
	_ensure_daily_chest_day()
	return maxi(0, DAILY_CHEST_WIN_LIMIT - chest_reward_wins)


func consume_daily_chest_win() -> bool:
	_ensure_daily_chest_day()
	if chest_reward_wins >= DAILY_CHEST_WIN_LIMIT:
		return false
	chest_reward_wins += 1
	save_data()
	return true


func add_chest(rarity: String):
	var stars: int = _roll_chest_stars(rarity)
	var taps: int = 4 if rarity == "magical" else 3
	chests.append({
		"rarity": rarity, "ready": true, "level": get_chest_level(),
		"stars": stars, "arena": get_arena(), "taps_left": taps, "total_taps": taps
	})
	save_data()

func open_chest(index: int) -> Dictionary:
	if index < 0 or index >= chests.size(): return {}
	var chest: Dictionary = chests[index]
	if not chest.get("ready", true): return {}
	var lv: int = int(chest.get("level", get_chest_level()))
	var arena: int = int(chest.get("arena", get_arena()))
	var stars: int = int(chest.get("stars", 1))
	var taps: int = int(chest.get("taps_left", 1))
	if not chest.has("pending"):
		chest["pending"] = _build_full_chest_rewards(chest.rarity, lv, stars, arena)
		chest["taps_left"] = taps
	var pending: Dictionary = chest.pending
	var out_gold: int = int(ceil(float(pending.get("gold", 0)) / float(max(taps, 1))))
	var out_cards: Dictionary = {}
	var pcards: Dictionary = pending.get("cards", {})
	for cid in pcards.keys():
		var take: int = int(ceil(float(pcards[cid]) / float(max(taps, 1))))
		take = mini(take, int(pcards[cid]))
		if take > 0:
			out_cards[cid] = take
			pcards[cid] = int(pcards[cid]) - take
	pending["gold"] = maxi(0, int(pending.get("gold", 0)) - out_gold)
	pending["cards"] = pcards
	taps -= 1
	chest["pending"] = pending
	chest["taps_left"] = taps
	if taps <= 0 or (int(pending.get("gold", 0)) <= 0 and out_cards.is_empty()):
		chests.remove_at(index)
	else:
		chests[index] = chest
	gold += out_gold
	for cid in out_cards.keys():
		add_card(cid, out_cards[cid])
	save_data()
	return { "gold": out_gold, "gems": 0, "cards": out_cards, "taps_left": max(taps, 0) }

func prepare_chest_opening(index: int) -> Dictionary:
	if index < 0 or index >= chests.size():
		return {}
	var chest: Dictionary = chests[index]
	var taps: int = 4 if String(chest.get("rarity", "silver")) == "magical" else 3
	chest["total_taps"] = int(chest.get("total_taps", taps))
	if not chest.has("taps_left") or int(chest.get("taps_left", 0)) <= 0:
		chest["taps_left"] = int(chest.get("total_taps", taps))
	if not chest.has("stars"):
		chest["stars"] = _roll_chest_stars(chest.rarity)
	chest["ready"] = true
	chests[index] = chest
	chest_open_index = index
	save_data()
	return chest

func tap_chest(index: int) -> Dictionary:
	if index < 0 or index >= chests.size():
		return {}
	var chest: Dictionary = chests[index]
	var left: int = int(chest.get("taps_left", 0))
	if left <= 0:
		return {}
	var stars: int = int(chest.get("stars", 1))
	var upgraded := false
	var chance: float = 0.38 if String(chest.get("rarity", "silver")) != "magical" else 0.48
	if randf() < chance and stars < 5:
		stars += 1
		upgraded = true
	left -= 1
	chest["stars"] = stars
	chest["taps_left"] = left
	chests[index] = chest
	save_data()
	return { "stars": stars, "taps_left": left, "upgraded": upgraded }

func finish_chest_opening(index: int) -> Dictionary:
	if index < 0 or index >= chests.size():
		return {}
	var chest: Dictionary = chests[index]
	var lv: int = int(chest.get("level", get_chest_level()))
	var arena: int = int(chest.get("arena", get_arena()))
	var stars: int = int(chest.get("stars", 1))
	var rewards: Dictionary = _build_full_chest_rewards(chest.rarity, lv, stars, arena)
	gold += int(rewards.get("gold", 0))
	gems += int(rewards.get("gems", 0))
	for cid in rewards.get("cards", {}).keys():
		add_card(cid, int(rewards.cards[cid]))
	chests.remove_at(index)
	chest_open_index = -1
	save_data()
	return rewards

func _ids_of_rarity(rar: String, max_arena: int = 99) -> Array:
	var out: Array = []
	for key in CARD_RARITY.RARITY_BY_ID.keys():
		var cid: int = int(key)
		if cid < 4 or cid in [98, 99, 100, 101, 102, 103, 118, 124, 125, 126, 127]:
			continue
		if CARD_RARITY.RARITY_BY_ID[key] != rar:
			continue
		if CARD_RARITY.arena_unlock_by_id(cid) > max_arena:
			continue
		out.append(cid)
	return out

func _grant_cards_of_rarity(cards: Dictionary, rar: String, amount: int, arena: int) -> void:
	if amount <= 0:
		return
	var ids: Array = _ids_of_rarity(rar, arena)
	if ids.is_empty():
		return
	# 每个稀有度最多 1 种卡牌，避免开出多种卡刷屏
	ids.shuffle()
	var kinds: int = mini(1, ids.size())
	var chosen: Array = []
	for i in range(kinds):
		chosen.append(ids[i])
	for i in range(amount):
		var cid: int = int(chosen[randi() % chosen.size()])
		cards[cid] = int(cards.get(cid, 0)) + 1

func _build_full_chest_rewards(rarity: String, lv: int, stars: int, arena: int) -> Dictionary:
	randomize()
	lv = clampi(lv, 1, 16)
	stars = clampi(stars, 1, 5)
	var cards: Dictionary = {}
	var gold_reward: int = 0
	if stars == 1:
		gold_reward = int(CHEST_GOLD[1][lv - 1])
		_grant_cards_of_rarity(cards, "common", int(CHEST_COMMON[1][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "rare", int(CHEST_RARE[1][lv - 1]), arena)
	elif stars == 2:
		gold_reward = int(CHEST2_GOLD[lv - 1])
		_grant_cards_of_rarity(cards, "common", int(CHEST2_COMMON[lv - 1]), arena)
		_grant_cards_of_rarity(cards, "rare", int(CHEST2_RARE[lv - 1]), arena)
		_grant_cards_of_rarity(cards, "epic", int(CHEST2_EPIC[lv - 1]), arena)
	elif stars == 3:
		gold_reward = int(CHEST_GOLD[3][lv - 1])
		_grant_cards_of_rarity(cards, "common", int(CHEST_COMMON[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "rare", int(CHEST_RARE[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "epic", int(CHEST_EPIC[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "legendary", int(CHEST_LEGEND[3][lv - 1]), arena)
	else:
		# 4/5 星：官方以万能卡/进化碎片为主，本项目折算为更多卡牌
		# 4/5 星沿用 3 星卡牌数量，不再乘以 2/3；高星的额外价值由奖励系统/万能卡承载
		_grant_cards_of_rarity(cards, "common", int(CHEST_COMMON[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "rare", int(CHEST_RARE[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "epic", int(CHEST_EPIC[3][lv - 1]), arena)
		_grant_cards_of_rarity(cards, "legendary", int(CHEST_LEGEND[3][lv - 1]), arena)
	return { "gold": gold_reward, "gems": 0, "cards": cards }

# --- 卡牌升级（重写） ---
func upgrade_card(card_id: int) -> bool:
	if not is_card_owned(card_id):
		return false
	var current_level = get_card_level(card_id)
	if current_level >= Config.LEVEL_MAX:
		return false
	var cost_gold: int = calculate_upgrade_gold(card_id, current_level)
	var cost_cards: int = calculate_upgrade_cards_needed(card_id, current_level)
	if cost_gold <= 0 or cost_cards <= 0:
		return false
	if gold < cost_gold or get_card_quantity(card_id) < cost_cards:
		return false
	gold -= cost_gold
	remove_card(card_id, cost_cards)
	card_levels[card_id] = current_level + 1
	save_data()
	return true

# --- 卡牌升级费用（展示用） ---
func get_upgradeable_card_count() -> int:
	var n := 0
	for key in card_quantities.keys():
		var cid: int = int(key)
		if not is_card_owned(cid):
			continue
		var lv: int = get_card_level(cid)
		if lv >= Config.LEVEL_MAX:
			continue
		var cost_gold: int = calculate_upgrade_gold(cid, lv)
		var need_cards: int = calculate_upgrade_cards_needed(cid, lv)
		if cost_gold > 0 and need_cards > 0 and gold >= cost_gold and get_card_quantity(cid) >= need_cards:
			n += 1
	return n

func calculate_upgrade_gold(card_id: int, level: int) -> int:
	return CARD_RARITY.gold_needed_by_id(card_id, level + 1)

func calculate_upgrade_cards_needed(card_id: int, level: int) -> int:
	return CARD_RARITY.copies_needed_by_id(card_id, level + 1)
# --- 奖杯操作 ---
func add_trophies(amount: int):
	if amount < 0:
		# 失败扣杯：不允许低于 0，同时保留历史竞技场奖杯门保护
		var floor_t: int = maxi(0, _arena_floor_by_highest())
		trophies = maxi(floor_t, trophies + amount)
	else:
		trophies += amount
	trophies = maxi(0, trophies)
	highest_trophies = maxi(highest_trophies, trophies)
	save_data()

func remove_trophies(amount: int):
	var floor_t: int = maxi(0, _arena_floor_by_highest())
	trophies = maxi(floor_t, trophies - amount)
	trophies = maxi(0, trophies)
	save_data()


func check_new_arena() -> int:
	# 返回本次新进入的竞技场序号；首次加载只记录当前竞技场，不播动画
	var cur: int = get_arena()
	if arena_seen <= 0:
		arena_seen = cur
		save_data()
		return 0
	if cur > arena_seen:
		return cur
	return 0


func mark_arena_seen(arena_idx: int) -> void:
	if arena_idx > arena_seen:
		arena_seen = arena_idx
		save_data()

func can_lose_trophies() -> bool:
	return trophies >= 100

func _arena_index_for_trophies(t: int) -> int:
	var idx: int = 1
	for i in range(ARENA_DATA.size()):
		if t >= int(ARENA_DATA[i][1]):
			idx = i + 1
		else:
			break
	return idx

func get_arena() -> int:
	var idx: int = _arena_index_for_trophies(trophies)
	# 国王塔等级门：未达到等级门槛则停在上一竞技场
	var kt: int = get_tower_level()
	while idx > 1 and int(ARENA_DATA[idx - 1][2]) > kt:
		idx -= 1
	return idx

func get_arena_name() -> String:
	var idx: int = get_arena()
	if idx <= 0 or idx > ARENA_DATA.size():
		return "训练营"
	return String(ARENA_DATA[idx - 1][0])

func get_arena_name_at(index: int) -> String:
	var i: int = clampi(index, 1, ARENA_DATA.size())
	return String(ARENA_DATA[i - 1][0])

func get_arena_trophies_at(index: int) -> int:
	var i: int = clampi(index, 1, ARENA_DATA.size())
	return int(ARENA_DATA[i - 1][1])

func get_cards_unlocked_at(arena_idx: int) -> Array:
	var out: Array = []
	for key in CARD_RARITY.RARITY_BY_ID.keys():
		var cid: int = int(key)
		if cid < 4 or cid in [98, 99, 100, 101, 102, 103, 118, 124, 125, 126, 127]:
			continue
		if CARD_RARITY.arena_unlock_by_id(cid) == arena_idx:
			out.append(cid)
	out.sort()
	return out

func card_unlock_arena_name(card_id: int) -> String:
	var a: int = CARD_RARITY.arena_unlock_by_id(card_id)
	return get_arena_name_at(a)

# 皇室征程成就：直接使用官方 trophy_road.json 的里程碑与奖励
var _trophy_road_cache: Array = []

func _load_trophy_road() -> Array:
	if not _trophy_road_cache.is_empty():
		return _trophy_road_cache
	var f := FileAccess.open("res://data/trophy_road_rewards.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		_trophy_road_cache = parsed
	return _trophy_road_cache

func get_achievements() -> Array:
	var out: Array = []
	for row in _load_trophy_road():
		var req: int = int(row.get("trophies", 0))
		var aid: String = String(row.get("id", "tr_%d" % req))
		var idx: int = _arena_index_for_trophies(req)
		var a: Dictionary = row.duplicate()
		a["id"] = aid
		a["arena_index"] = idx
		a["name"] = "竞技场 %d · %s · %d杯" % [idx, get_arena_name_at(idx), req]
		a["claimed"] = claimed_achievements.has(aid)
		a["claimable"] = highest_trophies >= req and not claimed_achievements.has(aid)
		if String(row.get("wildcard", "")) != "":
			var wr: String = _wildcard_rarity(String(row.wildcard))
			a["wild_rarity"] = wr
			a["wild_rarity_cn"] = _wildcard_cn(wr)
		out.append(a)
	return out

func has_emote(id: String) -> bool:
	return owned_emotes.has(id)

func add_emote(id: String) -> void:
	if id == "" or owned_emotes.has(id):
		return
	owned_emotes.append(id)
	save_data()

func can_request_card() -> bool:
	return Time.get_unix_time_from_system() - last_card_request >= 6.0 * 3600.0

func request_cooldown_left() -> float:
	return maxf(0.0, 6.0 * 3600.0 - (Time.get_unix_time_from_system() - last_card_request))

func mark_card_request() -> void:
	last_card_request = Time.get_unix_time_from_system()
	save_data()

func get_emote_count() -> int:
	return owned_emotes.size()

func add_wildcards(kind: String, amount: int) -> void:
	var rar: String = _wildcard_rarity(kind)
	wildcards[rar] = int(wildcards.get(rar, 0)) + amount
	save_data()

func get_wildcard_count(rar: String) -> int:
	return int(wildcards.get(rar, 0))

func get_wildcard_for_card(card_id: int) -> int:
	return get_wildcard_count(CARD_RARITY.rarity_of_id(card_id))

func use_wildcard_on_card(card_id: int, amount: int = 1) -> bool:
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	var have: int = get_wildcard_count(rar)
	if have <= 0 or amount <= 0:
		return false
	amount = mini(amount, have)
	wildcards[rar] = have - amount
	add_card(card_id, amount)
	save_data()
	return true

func _wildcard_rarity(w: String) -> String:
	var s: String = w.to_lower()
	if s.contains("common"): return "common"
	if s.contains("rare"): return "rare"
	if s.contains("epic"): return "epic"
	return "legendary"

func _wildcard_cn(rar: String) -> String:
	match rar:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传奇"
	return "普通"

func wildcard_color(rar: String) -> Color:
	match rar:
		"common": return Color(0.74, 0.78, 0.84)
		"rare": return Color(0.96, 0.62, 0.22)
		"epic": return Color(0.72, 0.38, 0.95)
		"legendary": return Color(1.0, 0.80, 0.28)
	return Color(0.74, 0.78, 0.84)

func _chest_key_from_official(name: String) -> String:
	var s: String = name.to_lower()
	if s.contains("silver"): return "silver"
	if s.contains("gold") or s.contains("giant"): return "gold"
	return "magical"

func claim_achievement(id: String) -> Dictionary:
	var row: Dictionary = {}
	for r in _load_trophy_road():
		if String(r.get("id", "")) == id:
			row = r
			break
	if row.is_empty():
		return {}
	if claimed_achievements.has(id):
		return {}
	var req: int = int(row.get("trophies", 0))
	if highest_trophies < req:
		return {}
	var gold_reward: int = int(row.get("gold", 0))
	var gem_reward: int = int(row.get("gems", 0))
	var card_id: int = int(row.get("card_id", 0))
	var card_amount: int = int(row.get("card_amount", 0))
	var chest_kind: String = String(row.get("chest", ""))
	var wildcard: String = String(row.get("wildcard", ""))
	var wild_amount: int = int(row.get("wild_amount", 0))
	var emote: int = int(row.get("emote", 0))
	var emote_id: String = String(row.get("emote_id", ""))
	gold += gold_reward
	gems += gem_reward
	if card_id > 0 and card_amount > 0:
		add_card(card_id, card_amount)
	if chest_kind != "":
		add_chest(_chest_key_from_official(chest_kind))
	var wildcard_got: Dictionary = {}
	if wildcard != "" and wild_amount > 0:
		var rar: String = _wildcard_rarity(wildcard)
		add_wildcards(wildcard, wild_amount)
		wildcard_got[rar] = wild_amount
	if emote > 0:
		add_emote(emote_id if emote_id != "" else "emote_%s" % id)
	claimed_achievements.append(id)
	save_data()
	return { "gold": gold_reward, "gems": gem_reward, "chest": chest_kind, "card": card_id, "card_name": String(row.get("card_name", "")), "card_amount": card_amount, "wild": wild_amount, "emote_id": emote_id, "wildcards": wildcard_got }

func _arena_floor_by_highest() -> int:
	var idx: int = _arena_index_for_trophies(highest_trophies)
	return int(ARENA_DATA[idx - 1][1])

# 官方 Lucky Chest 等级：竞技场 1=1 ... 28+=16
func get_chest_level() -> int:
	var a: int = get_arena()
	if a <= 8:
		return a
	if a <= 10:
		return 9
	if a <= 12:
		return 10
	if a <= 15:
		return 11
	if a <= 18:
		return 12
	if a <= 21:
		return 13
	if a <= 24:
		return 14
	if a <= 27:
		return 15
	return 16

func load_data():
	var config = ConfigFile.new()
	var err = config.load(current_save_path())

	# 1. 文件不存在 → 使用默认值并保存
	if err != OK:
		_apply_defaults()
		save_data()
		return

	# 2. 读取存档版本
	var file_version = config.get_value("meta", "version", 0)

	# 3. 如果版本 ≤ 当前版本，执行“保留+补全”迁移
	if file_version <= SAVE_VERSION:
		# 每个字段先设默认，再尝试用存档值覆盖
		player_name = config.get_value("player", "name", "玩家")
		name_chosen = bool(config.get_value("player", "name_chosen", false))
		bio = String(config.get_value("player", "bio", "热爱皇室战争的玩家，欢迎一起交流卡组与战术。"))
		clan_role = String(config.get_value("player", "clan_role", ""))
		total_donations = int(config.get_value("player", "total_donations", 0))
		challenge_state = config.get_value("player", "challenge_state", {})
		party_deck = config.get_value("player", "party_deck", [])
		gold = config.get_value("player", "gold", 100)
		gems = config.get_value("player", "gems", 10)
		email_bind_reward_claimed = bool(config.get_value("player", "email_bind_reward_claimed", false))
		shop_day = String(config.get_value("shop", "day", ""))
		shop_free_claimed_day = String(config.get_value("shop", "free_claimed_day", ""))
		chest_reward_day = String(config.get_value("player", "chest_reward_day", ""))
		chest_reward_wins = int(config.get_value("player", "chest_reward_wins", 0))
		shop_offers = config.get_value("shop", "offers", [])
		owned_emotes = config.get_value("emotes", "owned", [])
		wildcards = config.get_value("emotes", "wildcards", {})
		tower_choice = int(config.get_value("player", "tower_choice", 1))
		tower_usage = Dictionary(config.get_value("player", "tower_usage", {}))
		last_card_request = float(config.get_value("player", "last_card_request", 0.0))
		record_replays = bool(config.get_value("player", "record_replays", true))
		spectator_approval_required = bool(config.get_value("player", "spectator_approval_required", false))
		tutorial_done = bool(config.get_value("player", "tutorial_done", false))
		tutorial_guide_seen = bool(config.get_value("player", "tutorial_guide_seen", false))
		tutorial_chest_claimed = bool(config.get_value("player", "tutorial_chest_claimed", false))
		starter_cards_v2 = bool(config.get_value("player", "starter_cards_v2", false))
		chest_reveal_pending = bool(config.get_value("player", "chest_reveal_pending", false))
		avatar_seed = int(config.get_value("player", "avatar_seed", 0))
		avatar_index = int(config.get_value("player", "avatar_index", 0))
		avatar_custom_path = String(config.get_value("player", "avatar_custom_path", ""))
		collection_rewards_claimed = config.get_value("player", "collection_rewards_claimed", [])
		card_mastery = config.get_value("player", "card_mastery", {})
		mailbox = config.get_value("player", "mailbox", [])
		for _m in mailbox:
			if _m is Dictionary and String(_m.get("body", "")).contains("\\n"):
				_m["body"] = String(_m.get("body", "")).replace("\\n", "\n")
		mail_version_seen = String(config.get_value("player", "mail_version_seen", ""))
		announcement_seen = int(config.get_value("player", "announcement_seen", 0))
		season_key = String(config.get_value("player", "season_key", ""))
		season_crowns = int(config.get_value("player", "season_crowns", 0))
		season_claimed = config.get_value("player", "season_claimed", [])
		experience = config.get_value("player", "experience", 0)
		trophies = maxi(0, int(config.get_value("player", "trophies", 0)))
		highest_trophies = maxi(trophies, int(config.get_value("player", "highest_trophies", trophies)))
		arena_seen = maxi(0, int(config.get_value("player", "arena_seen", 0)))
		claimed_achievements = config.get_value("player", "claimed_achievements", [])
		card_levels = config.get_value("player", "card_levels", {})
		card_quantities = config.get_value("player", "card_quantities", {})
		new_cards = config.get_value("player", "new_cards", {})
		chests = config.get_value("player", "chests", [])
		donations_used = config.get_value("player", "donations_used", 0)
		custom_deck = config.get_value("player", "custom_deck", [])
		custom_decks = config.get_value("player", "custom_decks", [[], [], [], [], []])
		active_deck_index = config.get_value("player", "active_deck_index", 0)
		use_custom_deck = config.get_value("player", "use_custom_deck", false)
		test_mode = config.get_value("player", "test_mode", false)
		deck_sort_mode = String(config.get_value("player", "deck_sort_mode", "level"))
		while custom_decks.size() < 5:
			custom_decks.append([])
		if custom_decks[0].is_empty() and custom_deck.size() > 0:
			custom_decks[0] = custom_deck.duplicate()

		# 如果存档版本低于当前版本，更新版本号并保存
		if file_version < SAVE_VERSION:
			save_data()
			print("[PlayerData] 存档已从版本 %d 升级至 %d。" % [file_version, SAVE_VERSION])
	else:
		# 4. 未来版本（玩家用过高版本后回退？）→ 安全重置
		_apply_defaults()
		save_data()
		print("[PlayerData] 存档版本高于当前，已重置为默认数据。")

func _apply_defaults():
	# 切换账号/新账号时必须清空全部持久化字段，避免上一账号数据串档
	player_name = "玩家"
	name_chosen = false
	bio = "热爱皇室战争的玩家，欢迎一起交流卡组与战术。"
	clan_role = ""
	total_donations = 0
	challenge_state = {}
	party_deck = []
	gold = 100
	gems = 10
	email_bind_reward_claimed = false
	experience = 0
	trophies = 0
	highest_trophies = 0
	arena_seen = 0
	claimed_achievements.clear()
	card_levels.clear()
	card_quantities.clear()
	new_cards.clear()
	chests.clear()
	shop_day = ""
	shop_free_claimed_day = ""
	shop_offers = []
	owned_emotes.clear()
	wildcards.clear()
	tower_choice = 1
	tower_usage.clear()
	last_card_request = 0.0
	record_replays = true
	spectator_approval_required = false
	tutorial_done = false
	tutorial_guide_seen = false
	tutorial_practice = false
	tutorial_chest_claimed = false
	starter_cards_v2 = false
	chest_reveal_pending = false
	avatar_seed = 0
	avatar_index = 0
	avatar_custom_path = ""
	collection_rewards_claimed = []
	card_mastery = {}
	mailbox = []
	mail_alert_pending = ""
	mail_version_seen = ""
	announcement_seen = 0
	season_key = ""
	season_crowns = 0
	season_claimed = []
	donations_used = 0
	battle_wins = 0
	weekly_week = ""
	weekly_trophies = 0
	weekly_wins = 0
	weekly_three_crowns = 0
	weekly_reward_week = ""
	honor_title = ""
	battle_losses = 0
	battle_draws = 0
	three_crown_wins = 0
	current_streak = 0
	best_streak = 0
	recent_battles.clear()
	custom_deck = []
	custom_decks = [[], [], [], [], []]
	active_deck_index = 0
	use_custom_deck = false
	test_mode = false
	deck_sort_mode = "level"

func build_save_config() -> ConfigFile:
	var config = ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("meta", "saved_at", int(Time.get_unix_time_from_system()))
	config.set_value("meta", "account_id", account_id)
	config.set_value("player", "name", player_name)
	config.set_value("player", "name_chosen", name_chosen)
	config.set_value("player", "challenge_state", challenge_state)
	config.set_value("player", "party_deck", party_deck)
	config.set_value("player", "gold", gold)
	config.set_value("player", "gems", gems)
	config.set_value("player", "email_bind_reward_claimed", email_bind_reward_claimed)
	config.set_value("player", "experience", experience)
	config.set_value("player", "trophies", trophies)
	config.set_value("player", "highest_trophies", highest_trophies)
	config.set_value("player", "arena_seen", arena_seen)
	config.set_value("player", "claimed_achievements", claimed_achievements)
	config.set_value("player", "card_levels", card_levels)
	config.set_value("player", "card_quantities", card_quantities)
	config.set_value("player", "new_cards", new_cards)
	config.set_value("player", "chests", chests)
	config.set_value("shop", "day", shop_day)
	config.set_value("shop", "free_claimed_day", shop_free_claimed_day)
	config.set_value("player", "chest_reward_day", chest_reward_day)
	config.set_value("player", "chest_reward_wins", chest_reward_wins)
	config.set_value("shop", "offers", shop_offers)
	config.set_value("emotes", "owned", owned_emotes)
	config.set_value("emotes", "wildcards", wildcards)
	config.set_value("player", "tower_choice", tower_choice)
	config.set_value("player", "tower_usage", tower_usage)
	config.set_value("player", "last_card_request", last_card_request)
	config.set_value("player", "record_replays", record_replays)
	config.set_value("player", "spectator_approval_required", spectator_approval_required)
	config.set_value("player", "tutorial_done", tutorial_done)
	config.set_value("player", "tutorial_guide_seen", tutorial_guide_seen)
	config.set_value("player", "tutorial_chest_claimed", tutorial_chest_claimed)
	config.set_value("player", "starter_cards_v2", starter_cards_v2)
	config.set_value("player", "chest_reveal_pending", chest_reveal_pending)
	config.set_value("player", "avatar_seed", avatar_seed)
	config.set_value("player", "avatar_index", avatar_index)
	config.set_value("player", "avatar_custom_path", avatar_custom_path)
	config.set_value("player", "collection_rewards_claimed", collection_rewards_claimed)
	config.set_value("player", "card_mastery", card_mastery)
	config.set_value("player", "mailbox", mailbox)
	config.set_value("player", "mail_version_seen", mail_version_seen)
	config.set_value("player", "announcement_seen", announcement_seen)
	config.set_value("player", "season_key", season_key)
	config.set_value("player", "season_crowns", season_crowns)
	config.set_value("player", "season_claimed", season_claimed)
	config.set_value("player", "donations_used", donations_used)
	config.set_value("player", "battle_wins", battle_wins)
	config.set_value("player", "weekly_week", weekly_week)
	config.set_value("player", "weekly_trophies", weekly_trophies)
	config.set_value("player", "weekly_wins", weekly_wins)
	config.set_value("player", "weekly_three_crowns", weekly_three_crowns)
	config.set_value("player", "weekly_reward_week", weekly_reward_week)
	config.set_value("player", "bio", bio)
	config.set_value("player", "clan_role", clan_role)
	config.set_value("player", "total_donations", total_donations)
	config.set_value("player", "honor_title", honor_title)
	config.set_value("player", "battle_losses", battle_losses)
	config.set_value("player", "battle_draws", battle_draws)
	config.set_value("player", "three_crown_wins", three_crown_wins)
	config.set_value("player", "current_streak", current_streak)
	config.set_value("player", "best_streak", best_streak)
	config.set_value("player", "recent_battles", recent_battles)
	config.set_value("player", "custom_deck", custom_deck)
	config.set_value("player", "custom_decks", custom_decks)
	config.set_value("player", "active_deck_index", active_deck_index)
	config.set_value("player", "use_custom_deck", use_custom_deck)
	config.set_value("player", "test_mode", test_mode)
	config.set_value("player", "deck_sort_mode", deck_sort_mode)
	return config


func ensure_local_save() -> Dictionary:
	var normal := current_save_path()
	save_data()
	if FileAccess.file_exists(normal):
		return {"ok": true, "path": normal}
	last_save_error = "无法写入账号目录：%s" % normal
	return {"ok": false, "path": normal}

func save_data():
	var config := build_save_config()

	ensure_save_dir(current_save_path())
	var _save_err := config.save(current_save_path())
	if _save_err != OK:
		last_save_error = "保存失败 %d：%s" % [_save_err, current_save_path()]
		push_warning("PlayerData save failed: %s (%d)" % [current_save_path(), _save_err])
	else:
		last_save_error = ""
		if not FileAccess.file_exists(current_save_path()):
			last_save_error = "保存后文件不存在：%s" % current_save_path()
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("notify_local_save"):
		am.notify_local_save()



func get_save_text() -> String:
	var p := current_save_path()
	var text := FileAccess.get_file_as_string(p)
	if text != "":
		return text
	return build_save_config().encode_to_text()
func _ensure_starter_cards() -> void:
	# 新手固定六张：弓箭手、万箭齐发、骑士、亡灵、巨人、火球
	var STARTER: Array = STARTER_CARDS
	var road_cards: Dictionary = {}
	for row in _load_trophy_road():
		var cid: int = int(row.get("card_id", 0))
		if cid > 3:
			road_cards[cid] = true
	# 第一次应用新手卡池：零奖杯账号清掉旧版“全非征程卡”自动赠送，避免卡组过满
	if not starter_cards_v2 and trophies <= 0:
		for id_key in CARD_RARITY.RARITY_BY_ID.keys():
			var cid: int = int(id_key)
			if cid <= 3 or STARTER.has(cid) or road_cards.has(cid):
				continue
			card_quantities.erase(cid)
			card_levels.erase(cid)
	for cid in STARTER:
		if get_card_quantity(cid) <= 0 and not card_levels.has(cid):
			card_quantities[cid] = 1
			card_levels[cid] = CARD_RARITY.start_level_by_id(cid)
	# 默认出战卡组固定为六张起始卡
	if custom_decks.size() < 5:
		while custom_decks.size() < 5:
			custom_decks.append([])
	if not starter_cards_v2 or custom_decks[0].is_empty():
		custom_decks[0] = STARTER.duplicate()
		custom_deck = STARTER.duplicate()
		active_deck_index = 0
		use_custom_deck = true
	starter_cards_v2 = true
	save_data()

func _ensure_avatar() -> void:
	if avatar_seed == 0:
		avatar_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
		avatar_index = randi() % 12
		save_data()

func get_avatar_texture() -> Texture2D:
	if avatar_custom_path == "":
		return null
	var path := ProjectSettings.globalize_path(avatar_custom_path)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

func set_custom_avatar_image(img: Image) -> bool:
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	# 头像必须是正方形：居中裁剪最大正方形，再缩放到 128，避免拉伸变形
	var side: int = mini(img.get_width(), img.get_height())
	var ox: int = int((img.get_width() - side) / 2)
	var oy: int = int((img.get_height() - side) / 2)
	var cropped := img.get_region(Rect2i(ox, oy, side, side))
	if cropped == null:
		return false
	cropped.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var dst := "user://avatar_custom.png"
	if account_save_path != "":
		dst = account_save_path.get_base_dir() + "/avatar_custom.png"
	var global_dst := ProjectSettings.globalize_path(dst)
	DirAccess.make_dir_recursive_absolute(global_dst.get_base_dir())
	var err := cropped.save_png(global_dst)
	if err != OK:
		return false
	avatar_custom_path = dst
	save_data()
	return true


func set_custom_avatar(source_path: String) -> bool:
	var img := Image.load_from_file(source_path)
	return set_custom_avatar_image(img)

func randomize_avatar() -> void:
	avatar_custom_path = ""
	avatar_seed = int(randi())
	avatar_index = randi() % 12
	save_data()

func _load_collection_rewards() -> Array:
	if not _collection_rewards_cache.is_empty():
		return _collection_rewards_cache
	var f := FileAccess.open("res://data/collection_rewards.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		_collection_rewards_cache = parsed
	return _collection_rewards_cache

func get_collection_rewards() -> Array:
	return _load_collection_rewards()

func get_collection_reward_pending() -> Array:
	var lv: int = get_collection_level()
	var out: Array = []
	for r in _load_collection_rewards():
		var level: int = int(r.get("level", 0))
		if level <= lv and not collection_rewards_claimed.has(level):
			out.append(r)
	return out

func get_collection_reward_pending_count() -> int:
	return get_collection_reward_pending().size()

func get_next_collection_reward() -> Dictionary:
	var lv: int = get_collection_level()
	for r in _load_collection_rewards():
		if int(r.get("level", 0)) > lv:
			return r
	return {}

func _grant_collection_reward(r: Dictionary) -> void:
	var typ := String(r.get("type", "gems"))
	if typ == "gems":
		gems += int(r.get("amount", 0))
	elif typ == "wild":
		add_wildcards(String(r.get("rarity", "common")), int(r.get("amount", 0)))
	elif typ == "chest":
		var stars: int = clampi(int(r.get("stars", 4)), 1, 5)
		add_chest(String(r.get("rarity", "magical")))
		if not chests.is_empty():
			chests[chests.size() - 1]["stars"] = stars
			chests[chests.size() - 1]["taps_left"] = 4
			chests[chests.size() - 1]["total_taps"] = 4
	save_data()

func claim_collection_reward(level: int) -> Dictionary:
	if level > get_collection_level() or collection_rewards_claimed.has(level):
		return {}
	for r in _load_collection_rewards():
		if int(r.get("level", 0)) == level:
			collection_rewards_claimed.append(level)
			_grant_collection_reward(r)
			save_data()
			return r
	return {}

func claim_all_collection_rewards() -> Array:
	var out: Array = []
	for r in get_collection_reward_pending():
		var level: int = int(r.get("level", 0))
		collection_rewards_claimed.append(level)
		_grant_collection_reward(r)
		out.append(r)
	save_data()
	return out

func _shop_unit_price(card_id: int) -> int:
	match CARD_RARITY.rarity_of_id(card_id):
		"common": return 10
		"rare": return 50
		"epic": return 200
		"legendary": return 15000
	return 10

func ensure_daily_shop_offers() -> void:
	var d := Time.get_date_dict_from_system()
	var today := "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
	var valid := shop_day == today and shop_offers.size() == 8
	var arena_now: int = get_arena()
	var allowed_now: Dictionary = {}
	# 按卡牌自身的竞技场解锁配置，和卡组/图鉴显示保持一致
	var token_ids := [98, 99, 100, 101, 102, 103, 118, 124, 125, 126, 127]
	for cid in CARD_RARITY.RARITY_BY_ID.keys():
		var rid: int = int(cid)
		if rid <= 3 or token_ids.has(rid):
			continue
		if CARD_RARITY.arena_unlock_by_id(rid) <= arena_now:
			allowed_now[rid] = true
	for cid in STARTER_CARDS:
		allowed_now[int(cid)] = true
	if valid:
		for o in shop_offers:
			if not o.has("unit") or int(o.get("unit", 0)) != _shop_unit_price(int(o.get("card_id", 0))):
				valid = false
				break
			if not allowed_now.has(int(o.get("card_id", 0))):
				valid = false
				break
	if not valid:
		var bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
		var ids: Array = []
		for cfg in bm.configs:
			if cfg.card_id >= 4 and cfg.cost > 0 and allowed_now.has(int(cfg.card_id)):
				ids.append(cfg.card_id)
		bm.free()
		if ids.is_empty():
			ids = [44, 10, 4, 8, 9, 11]
		var rng := RandomNumberGenerator.new()
		rng.seed = today.hash()
		shop_offers.clear()
		var used: Dictionary = {}
		while shop_offers.size() < 8 and ids.size() > 0:
			var cid: int = int(ids[rng.randi_range(0, ids.size() - 1)])
			if used.has(cid):
				continue
			used[cid] = true
			var unit: int = _shop_unit_price(cid)
			var min_total: int = 300 + arena_now * 100
			var qty: int = 1
			if unit < min_total:
				qty = int(ceil(float(min_total) / float(unit)))
				qty = int(ceil(float(qty) / 5.0)) * 5
				qty += 5 * rng.randi_range(0, 3)
			shop_offers.append({"card_id": cid, "qty": qty, "unit": unit, "price": unit * qty, "sold": false})
		shop_day = today
		# 每天恰好一个免费卡牌；周日固定 5 张随机史诗卡
	var free_claimed_today := shop_free_claimed_day == today
	# 兼容旧存档：已售罄的免费卡视为今日已领取，绝不再生成第二件
	if not free_claimed_today:
		for o in shop_offers:
			if bool(o.get("free", false)) and bool(o.get("sold", false)):
				free_claimed_today = true
				shop_free_claimed_day = today
				break
	if free_claimed_today:
		for o in shop_offers:
			if bool(o.get("free", false)):
				o["free"] = false
				o["sold"] = true
				o["price"] = int(o.get("original_price", o.get("price", 0)))
		shop_day = today
		save_data()
		return

	var free_idx := -1
	for i in range(shop_offers.size()):
		if bool(shop_offers[i].get("free", false)):
			free_idx = i
			break
	var sunday: bool = int(d.weekday) == 0
	if sunday:
		var epic_ids: Array = []
		for cid in allowed_now.keys():
			if CARD_RARITY.rarity_of_id(int(cid)) == "epic":
				epic_ids.append(int(cid))
		if epic_ids.is_empty():
			epic_ids = [15]
		epic_ids.sort()
		var rng_epic := RandomNumberGenerator.new()
		rng_epic.seed = today.hash() ^ 0x5EED
		var epic_id: int = int(epic_ids[rng_epic.randi_range(0, epic_ids.size() - 1)])
		if free_idx < 0:
			for i in range(shop_offers.size()):
				if CARD_RARITY.rarity_of_id(int(shop_offers[i].get("card_id", 0))) == "epic":
					free_idx = i
					break
			if free_idx < 0:
				free_idx = 0
		var eo: Dictionary = shop_offers[free_idx]
		eo["card_id"] = epic_id
		eo["qty"] = 5
		eo["unit"] = 200
		eo["original_price"] = 5000
		eo["price"] = 0
		eo["free"] = true
		eo["sold"] = false
		eo["sunday_epic"] = true
		shop_offers[free_idx] = eo
	else:
		if free_idx < 0:
			var candidates: Array = []
			for i in range(shop_offers.size()):
				var o: Dictionary = shop_offers[i]
				if bool(o.get("sold", false)):
					continue
				if int(o.get("price", 999999)) < 2000:
					candidates.append(i)
			if not candidates.is_empty():
				var rng2 := RandomNumberGenerator.new()
				rng2.seed = today.hash() + 991
				free_idx = int(candidates[rng2.randi_range(0, candidates.size() - 1)])
				var chosen: Dictionary = shop_offers[free_idx]
				chosen["original_price"] = int(chosen.get("price", 0))
				chosen["price"] = 0
				chosen["free"] = true
				shop_offers[free_idx] = chosen
	# 清理多余的免费标记，保证全天只有一个免费位
	for i in range(shop_offers.size()):
		if i != free_idx and bool(shop_offers[i].get("free", false)):
			var extra: Dictionary = shop_offers[i]
			extra["free"] = false
			extra["price"] = int(extra.get("original_price", extra.get("price", 0)))
			shop_offers[i] = extra
	shop_day = today
	save_data()



func mark_shop_free_claimed() -> void:
	var d := Time.get_date_dict_from_system()
	shop_free_claimed_day = "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
	save_data()

func get_shop_free_pending_count() -> int:
	for o in shop_offers:
		if bool(o.get("free", false)) and not bool(o.get("sold", false)):
			return 1
	return 0

const MASTERY_USES := [10, 50, 150]
const MASTERY_TIER_NAMES := ["青铜", "白银", "黄金"]

func _mastery_entry(card_id: int) -> Dictionary:
	var key := str(card_id)
	var e = card_mastery.get(key, null)
	if e == null or not (e is Dictionary):
		e = {"uses": 0, "claimed": []}
		card_mastery[key] = e
		if not e.has("claimed"):
			e["claimed"] = []
	return e

func record_card_use(card_id: int) -> void:
	if card_id <= 3:
		return
	var e := _mastery_entry(card_id)
	e["uses"] = int(e.get("uses", 0)) + 1
	card_mastery[str(card_id)] = e
	save_data()

func get_mastery_uses(card_id: int) -> int:
	return int(_mastery_entry(card_id).get("uses", 0))

func get_most_used_cards(limit: int = 3) -> Array:
	var out: Array = []
	for key in card_mastery.keys():
		var e = card_mastery[key]
		if not (e is Dictionary):
			continue
		var cid: int = int(key)
		var uses: int = int(e.get("uses", 0))
		if uses <= 0:
			continue
		out.append({"id": cid, "uses": uses, "level": get_card_level(cid)})
	out.sort_custom(func(a, b): return int(a.uses) > int(b.uses))
	return out.slice(0, limit)


func get_mastery_next_tier(card_id: int) -> int:
	var e := _mastery_entry(card_id)
	var claimed: Array = Array(e.get("claimed", []))
	for i in range(MASTERY_USES.size()):
		if not claimed.has(i + 1) and get_mastery_uses(card_id) >= int(MASTERY_USES[i]):
			return i + 1
	return 0

func get_mastery_claimable_count_for(card_id: int) -> int:
	var e := _mastery_entry(card_id)
	var uses := int(e.get("uses", 0))
	var claimed: Array = Array(e.get("claimed", []))
	var n := 0
	for i in range(MASTERY_USES.size()):
		if not claimed.has(i + 1) and uses >= int(MASTERY_USES[i]):
			n += 1
	return n

func get_mastery_card_count() -> int:
	var n := 0
	for key in card_mastery.keys():
		var e = card_mastery[key]
		if e is Dictionary and int(e.get("uses", 0)) > 0:
			n += 1
	return n


func get_mastery_claimable_count() -> int:
	var n := 0
	for key in card_mastery.keys():
		var e: Dictionary = card_mastery[key]
		var uses: int = int(e.get("uses", 0))
		var claimed: Array = Array(e.get("claimed", []))
		for i in range(MASTERY_USES.size()):
			if not claimed.has(i + 1) and uses >= int(MASTERY_USES[i]):
				n += 1
	return n

func get_mastery_reward(card_id: int, tier: int) -> Dictionary:
	return _mastery_reward(card_id, tier)

func _mastery_reward(card_id: int, tier: int) -> Dictionary:
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	var gold_amt: int = [500, 1500, 3000][tier - 1]
	var wild_amt: int = [10, 25, 50][tier - 1]
	return {
		"gold": gold_amt,
		"wildcards": {rar: wild_amt},
		"chest": "magical" if tier == 3 else "",
		"tier": tier,
	}

func claim_mastery(card_id: int) -> Dictionary:
	var e := _mastery_entry(card_id)
	var claimed: Array = Array(e.get("claimed", []))
	var uses := get_mastery_uses(card_id)
	var tier := 0
	for i in range(MASTERY_USES.size()):
		if not claimed.has(i + 1) and uses >= int(MASTERY_USES[i]):
			tier = i + 1
			break
	if tier == 0:
		return {}
	var rew := _mastery_reward(card_id, tier)
	gold += int(rew.get("gold", 0))
	for rar in rew.get("wildcards", {}).keys():
		add_wildcards(String(rar), int(rew.wildcards[rar]))
	if String(rew.get("chest", "")) != "":
		add_chest(String(rew.chest))
	claimed.append(tier)
	e["claimed"] = claimed
	card_mastery[str(card_id)] = e
	save_data()
	return rew

func claim_all_mastery() -> Array:
	var out: Array = []
	for key in card_mastery.keys():
		var cid: int = int(key)
		while get_mastery_next_tier(cid) > 0:
			var rew := claim_mastery(cid)
			if rew.is_empty():
				break
			out.append({"card_id": cid, "reward": rew})
	return out

const SEASON = preload("res://scripts/data/SeasonCatalog.gd")

func _ensure_season() -> void:
	var key: String = String(SEASON.current_key())
	if season_key != key:
		season_key = key
		season_crowns = 0
		season_claimed.clear()
		save_data()

func get_season_theme() -> Dictionary:
	_ensure_season()
	return SEASON.current()

func get_season_tier_count() -> int:
	return SEASON.TIERS

func get_season_crowns() -> int:
	_ensure_season()
	return season_crowns

func add_season_crowns(n: int) -> void:
	if n <= 0:
		return
	_ensure_season()
	season_crowns += n
	save_data()

func get_season_pending_count() -> int:
	var n := 0
	for t in range(1, SEASON.TIERS + 1):
		if season_crowns >= SEASON.tier_crowns(t) and not season_claimed.has(t):
			n += 1
	return n

func get_season_reward(tier: int) -> Dictionary:
	return SEASON.reward_for(tier, SEASON.current())

func get_season_reward_state() -> Array:
	var out: Array = []
	for t in range(1, SEASON.TIERS + 1):
		out.append({
			"tier": t,
			"crowns": SEASON.tier_crowns(t),
			"claimed": season_claimed.has(t),
			"available": season_crowns >= SEASON.tier_crowns(t) and not season_claimed.has(t),
			"reward": get_season_reward(t),
		})
	return out

func _grant_season_reward(r: Dictionary) -> void:
	match String(r.get("type", "gold")):
		"card":
			add_card(int(r.get("card_id", 0)), int(r.get("amount", 0)))
		"emote":
			var eid := String(r.get("emote_id", ""))
			if owned_emotes.has(eid):
				gems += 20
			else:
				add_emote(eid)
		"gems":
			gems += int(r.get("amount", 0))
		"wild":
			add_wildcards(String(r.get("rarity", "common")), int(r.get("amount", 0)))
		"chest":
			add_chest(String(r.get("rarity", "magical")))
			if not chests.is_empty():
				chests[chests.size() - 1]["stars"] = clampi(int(r.get("stars", 4)), 1, 5)
		_:
			gold += int(r.get("amount", 0))
	save_data()

func claim_season_reward(tier: int) -> Dictionary:
	if season_claimed.has(tier) or season_crowns < SEASON.tier_crowns(tier):
		return {}
	var r: Dictionary = get_season_reward(tier)
	season_claimed.append(tier)
	_grant_season_reward(r)
	save_data()
	return r

func claim_all_season_rewards() -> Array:
	var out: Array = []
	for t in range(1, SEASON.TIERS + 1):
		if season_crowns >= SEASON.tier_crowns(t) and not season_claimed.has(t):
			var r: Dictionary = get_season_reward(t)
			season_claimed.append(t)
			_grant_season_reward(r)
			out.append(r)
	save_data()
	return out

const APP_VERSION := "1.2.0"
const UPDATE_URL := "https://github.com/3844775306-code/ClashRoyale/releases/tag/v1.2.0"
const GLOBAL_MAIL_URL := "https://raw.githubusercontent.com/3844775306-code/ClashRoyale/main/data/global_mail.json"

func add_gift_mail_once(title: String, body: String, reward: Dictionary, sender: String, gift_id: String) -> void:
	if gift_id != "":
		for m in mailbox:
			if String(m.get("gift_id", "")) == gift_id:
				return
	var extra := {"gift_id": gift_id}
	add_mail(title, body, reward, sender, "donation", extra)

func add_mail(title: String, body: String, reward: Dictionary = {}, sender: String = "官方", kind: String = "official", extra: Dictionary = {}) -> void:
	var mail := {
		"id": "mail_%d_%d" % [Time.get_ticks_usec(), randi() % 100000],
		"title": title, "body": body, "sender": sender, "kind": kind,
		"time": Time.get_unix_time_from_system(), "reward": reward.duplicate(true), "claimed": false,
	}
	for k in extra.keys():
		mail[k] = extra[k]
	mailbox.push_front(mail)
	mail_added.emit(title, body, sender)
	if not (reward.get("cards", {}) as Dictionary).is_empty():
		mail_alert_pending = "收到来自 %s 的赠卡，已放入邮箱" % sender
	save_data()

func get_mail_pending_count() -> int:
	var n := 0
	for m in mailbox:
		if not bool(m.get("claimed", false)):
			n += 1
	return n

func claim_mail(mail_id: String) -> Dictionary:
	for i in range(mailbox.size()):
		var m: Dictionary = mailbox[i]
		if String(m.get("id", "")) != mail_id or bool(m.get("claimed", false)):
			continue
		var r: Dictionary = m.get("reward", {})
		_grant_mail_reward(r)
		m["claimed"] = true
		mailbox[i] = m
		save_data()
		return m
	return {}

func _grant_mail_reward(r: Dictionary) -> void:
	gold += int(r.get("gold", 0))
	gems += int(r.get("gems", 0))
	for cid in r.get("cards", {}).keys():
		add_card(int(cid), int(r.cards[cid]))
	for rar in r.get("wildcards", {}).keys():
		add_wildcards(String(rar), int(r.wildcards[rar]))
	if String(r.get("chest", "")) != "":
		add_chest(String(r.chest))
	if String(r.get("emote", "")) != "":
		add_emote(String(r.emote))
	save_data()

func sync_global_mail() -> void:
	if _global_mail_busy:
		return
	_global_mail_busy = true
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, body):
		_global_mail_busy = false
		req.queue_free()
		if code < 200 or code >= 300:
			return
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if not (parsed is Array):
			return
		for item in parsed:
			if not (item is Dictionary):
				continue
			var gid := String(item.get("id", ""))
			if gid == "":
				continue
			var exists := false
			for m in mailbox:
				if String(m.get("global_id", "")) == gid:
					exists = true
					break
			if exists:
				continue
			var reward: Dictionary = item.get("reward", {})
			add_mail(String(item.get("title", "官方公告")), String(item.get("body", "")),
				reward, String(item.get("sender", "官方")), String(item.get("kind", "official")),
				{"global_id": gid, "url": String(item.get("url", ""))})
	)
	req.request(GLOBAL_MAIL_URL)

func _ensure_default_mail() -> void:
	var has_update := false
	var has_welfare := false
	for m in mailbox:
		if String(m.get("kind", "")) == "update": has_update = true
		if String(m.get("kind", "")) == "welfare": has_welfare = true
	if not has_update:
		add_mail(
			"版本更新 " + APP_VERSION,
			"更新时间：%s\n更新内容：\n· 主题赛季与卡牌大师\n· 部落聊天/捐赠与邮箱\n· 回放 20 条上限与永久保存\n· 账号存档隔离\n新版本地址：%s\n\n奖励：100 宝石" % [Time.get_datetime_string_from_system().replace("T", " "), UPDATE_URL],
			{"gems": 100}, "官方", "update", {"url": UPDATE_URL})
	if not has_welfare:
		add_mail(
			"官方福利 · 新手礼包",
			"感谢支持皇室战争同人项目！\n登录即可领取官方福利：200 金币 + 20 宝石。",
			{"gold": 200, "gems": 20}, "官方", "welfare")

func get_ai_allowed_cards() -> Array:
	# AI 卡池跟随卡牌竞技场解锁，避免新卡在低阶出现
	var out: Array = [44, 10, 4, 8, 9, 11]
	var arena_now: int = get_arena()
	var token_ids := [98, 99, 100, 101, 102, 103, 118, 124, 125, 126, 127]
	for cid in CARD_RARITY.RARITY_BY_ID.keys():
		var rid: int = int(cid)
		if rid <= 3 or token_ids.has(rid):
			continue
		if CARD_RARITY.arena_unlock_by_id(rid) <= arena_now and not out.has(rid):
			out.append(rid)
	return out

func get_ai_default_deck() -> Array:
	var pool: Array = get_ai_allowed_cards()
	pool.shuffle()
	var out: Array = []
	for cid in pool:
		if not out.has(cid):
			out.append(cid)
		if out.size() >= 8:
			break
	return out

func is_new_card(card_id: int) -> bool:
	return bool(new_cards.get(card_id, false))

func mark_card_seen(card_id: int) -> void:
	if new_cards.erase(card_id):
		save_data()

func is_card_owned(card_id: int) -> bool:
	if card_id <= 3:
		return true
	return get_card_quantity(card_id) > 0 or card_levels.has(card_id)

func get_card_level(card_id: int) -> int:
	var start: int = CARD_RARITY.start_level_by_id(card_id)
	var lv: int = int(card_levels.get(card_id, start))
	return maxi(lv, start)
# 2026 官方规则：经验系统已移除；国王塔等级由“达到指定等级的卡牌数量”决定
func _count_cards_at_least(min_level: int) -> int:
	var n: int = 0
	for cid in card_levels.keys():
		var c: int = int(cid)
		if c <= 3:
			continue
		if get_card_level(c) >= min_level:
			n += 1
	return n

func get_tower_level() -> int:
	var lv: int = 1
	for req in KING_TOWER_REQS:
		if _count_cards_at_least(int(req[2])) >= int(req[1]):
			lv = int(req[0])
		else:
			break
	return lv

func current_week_key() -> String:
	var d := Time.get_date_dict_from_system()
	var day := int(d.get("day", 1))
	var month := int(d.get("month", 1))
	var year := int(d.get("year", 2026))
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var now := Time.get_unix_time_from_system()
	var week := int((now - jan1) / 604800.0) + 1
	return "%04d-W%02d" % [year, week]


func ensure_week() -> void:
	var wk := current_week_key()
	if weekly_week == wk:
		return
	weekly_week = wk
	weekly_trophies = 0
	weekly_wins = 0
	weekly_three_crowns = 0
	weekly_reward_week = ""
	save_data()


func add_weekly_trophies(n: int) -> void:
	ensure_week()
	weekly_trophies += n
	save_data()


func current_week_label() -> String:
	var d := Time.get_date_dict_from_system()
	var year := int(d.get("year", 2026))
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var wk_parts := current_week_key().split("-W")
	var wk_no: int = int(wk_parts[1]) if wk_parts.size() > 1 else 1
	var start := int(jan1 + (wk_no - 1) * 604800)
	var s := Time.get_datetime_dict_from_unix_time(start)
	var e := Time.get_datetime_dict_from_unix_time(start + 6 * 86400)
	return "%04d-%02d-%02d ~ %02d-%02d" % [int(s.year), int(s.month), int(s.day), int(e.month), int(e.day)]


func record_tower_use(choice: int) -> void:
	if choice < 1 or choice > 4:
		return
	tower_usage[str(choice)] = int(tower_usage.get(str(choice), 0)) + 1
	save_data()


func get_most_used_tower() -> int:
	var best := int(tower_choice)
	var best_n := -1
	for k in tower_usage.keys():
		var n := int(tower_usage[k])
		if n > best_n:
			best_n = n
			best = int(k)
	return clampi(best, 1, 4)


func battle_total() -> int:
	return battle_wins + battle_losses + battle_draws

func win_rate() -> int:
	var total := battle_total()
	return 0 if total <= 0 else int(round(float(battle_wins) * 100.0 / float(total)))

func record_battle_result(win: bool, draw: bool, crowns_for: int, crowns_against: int, mode: String, duration: float, opponent: String = "", extra: Dictionary = {}) -> void:
	if draw:
		battle_draws += 1
		current_streak = 0
	elif win:
		ensure_week()
		battle_wins += 1
		weekly_wins += 1
		current_streak += 1
		best_streak = maxi(best_streak, current_streak)
		if crowns_for >= 3:
			three_crown_wins += 1
			weekly_three_crowns += 1
	else:
		battle_losses += 1
		current_streak = 0
	var row := {
		"win": win, "draw": draw,
		"crowns_for": int(crowns_for), "crowns_against": int(crowns_against),
		"mode": String(mode), "duration": float(duration),
		"opponent": String(opponent), "ts": int(Time.get_unix_time_from_system()),
	}
	row.merge(extra, true)
	recent_battles.push_front(row)
	while recent_battles.size() > 10:
		recent_battles.pop_back()
	save_data()

func get_collection_level() -> int:
	var total: int = 0
	for cid in card_levels.keys():
		var c: int = int(cid)
		if c <= 3:
			continue
		if is_card_owned(c):
			total += get_card_level(c)
	return total

func get_next_tower_req_level() -> int:
	var lv: int = get_tower_level()
	var idx: int = lv - 1   # 等级2对应数组0
	if idx >= KING_TOWER_REQS.size():
		return 0
	return int(KING_TOWER_REQS[idx][2])

func get_level_progress() -> Array:
	var lv: int = get_tower_level()
	var idx: int = lv - 1
	if lv >= Config.LEVEL_MAX or idx >= KING_TOWER_REQS.size():
		return [0, 0]
	var req = KING_TOWER_REQS[idx]
	var need: int = int(req[1])
	var have: int = mini(_count_cards_at_least(int(req[2])), need)
	return [have, need]

func get_xp_to_next_level() -> int:
	return 0

func get_ai_card_level() -> int:
	var player_level = get_tower_level()
	var lv = player_level + randi_range(-1, 1)
	return clampi(lv, 1, Config.LEVEL_MAX)

func _ai_level_from_trophies(card_id: int) -> int:
	var rarity: String = String(CARD_RARITY.rarity_of_id(card_id))
	var coeff: float = float({"common": 0.5, "rare": 0.1, "epic": 0.01, "legendary": 0.001}.get(rarity, 0.5))
	var copies: int = int(float(trophies) * coeff * randf_range(0.8, 1.2))
	var lv: int = int(CARD_RARITY.start_level_by_id(card_id))
	var costs: Dictionary = CARD_RARITY.COPY_COSTS.get(rarity, {})
	while lv < Config.LEVEL_MAX:
		var need := int(costs.get(lv + 1, 0))
		if need <= 0 or copies < need:
			break
		copies -= need
		lv += 1
	return clampi(lv, 1, Config.LEVEL_MAX)

func refresh_ai_levels() -> void:
	ai_king_level = clampi(get_tower_level() + randi_range(-1, 1), 1, Config.LEVEL_MAX)
	ai_levels.clear()
	for cid in range(1, 130):
		ai_levels[cid] = _ai_level_from_trophies(int(cid))

func ai_level(card_id):
	if ai_levels.is_empty():
		refresh_ai_levels()
	var base: int = int(ai_levels.get(card_id, CARD_RARITY.start_level_by_id(int(card_id))))
	return clampi(base, 1, Config.LEVEL_MAX)

func has_party_deck() -> bool:
	var n := 0
	for cid in party_deck:
		if int(cid) > 0:
			n += 1
	return n >= 8


func get_active_deck() -> Array:
	if custom_decks.size() <= active_deck_index:
		return []
	return custom_decks[active_deck_index]