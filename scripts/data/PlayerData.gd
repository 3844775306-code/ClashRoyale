# scripts/data/PlayerData.gd
extends Node

const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

const SAVE_PATH = "user://player_data.cfg"
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
var experience: int = 0
var player_name:String = "玩家"
var name_chosen: bool = false        # 玩家是否已完成取名（首次启动强制取名）
var trophies: int = 0          # 新增奖杯
var highest_trophies: int = 0  # 历史最高奖杯（奖杯门保护）
var claimed_achievements: Array = []  # 已领取的皇室征程成就（竞技场序号）
var donations_used: int = 0          # 今日已捐赠次数
# 卡牌拥有数量 { card_id: int }
var card_quantities: Dictionary = {}
# 卡牌等级：{ card_id: level (1-16) }
var card_levels: Dictionary = {}
# 宝箱队列（存储 Chest 数据，可序列化）
var chests: Array = []   # 每个元素 { "rarity": "silver"/"gold"/"magical", "ready": bool }
var ai_levels: Dictionary = {}
var custom_decks: Array = [[], [], [], [], []]   # 5 套自定义卡组
var active_deck_index: int = 0
var deck_clipboard: Array = []
var custom_deck: Array = []          # 旧字段，保留用于迁移
var use_custom_deck: bool = false    # 对战时是否使用自定义卡组
var test_mode: bool = false            # 测试模式：随机卡组 + 固定11级
var deck_sort_mode: String = "level"   # 卡组配置排序记忆：level/rarity/default
var chest_open_index: int = -1        # 当前进入开箱界面的宝箱索引（不持久化）
var shop_day: String = ""
var shop_offers: Array = []
var owned_emotes: Array = []
var wildcards: Dictionary = {}
var tower_choice: int = 1   # 1=公主塔, 2=王子塔
var last_card_request: float = 0.0
var record_replays: bool = true
func _ready():
	
	load_data()
	for i in range(130):
		ai_levels[i] = get_ai_card_level()
	
func get_card_quantity(card_id: int) -> int:
	return card_quantities.get(card_id, 0)

func add_card(card_id: int, amount: int):
	var old: int = get_card_quantity(card_id)
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
	for i in range(amount):
		var cid: int = int(ids[randi() % ids.size()])
		cards[cid] = int(cards.get(cid, 0)) + 1

func _build_full_chest_rewards(rarity: String, lv: int, stars: int, arena: int) -> Dictionary:
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
		var mul: int = 2 if stars == 4 else 3
		_grant_cards_of_rarity(cards, "common", int(CHEST_COMMON[3][lv - 1]) * mul, arena)
		_grant_cards_of_rarity(cards, "rare", int(CHEST_RARE[3][lv - 1]) * mul, arena)
		_grant_cards_of_rarity(cards, "epic", int(CHEST_EPIC[3][lv - 1]) * mul, arena)
		_grant_cards_of_rarity(cards, "legendary", int(CHEST_LEGEND[3][lv - 1]) * mul, arena)
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
func calculate_upgrade_gold(card_id: int, level: int) -> int:
	return CARD_RARITY.gold_needed_by_id(card_id, level + 1)

func calculate_upgrade_cards_needed(card_id: int, level: int) -> int:
	return CARD_RARITY.copies_needed_by_id(card_id, level + 1)
# --- 奖杯操作 ---
func add_trophies(amount: int):
	trophies += amount
	highest_trophies = maxi(highest_trophies, trophies)
	save_data()

func remove_trophies(amount: int):
	trophies = maxi(_arena_floor_by_highest(), trophies - amount)
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
	var err = config.load(SAVE_PATH)

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
		gold = config.get_value("player", "gold", 100)
		gems = config.get_value("player", "gems", 10)
		shop_day = String(config.get_value("shop", "day", ""))
		shop_offers = config.get_value("shop", "offers", [])
		owned_emotes = config.get_value("emotes", "owned", [])
		wildcards = config.get_value("emotes", "wildcards", {})
		tower_choice = int(config.get_value("player", "tower_choice", 1))
		last_card_request = float(config.get_value("player", "last_card_request", 0.0))
		record_replays = bool(config.get_value("player", "record_replays", true))
		experience = config.get_value("player", "experience", 0)
		trophies = config.get_value("player", "trophies", 0)
		highest_trophies = config.get_value("player", "highest_trophies", trophies)
		claimed_achievements = config.get_value("player", "claimed_achievements", [])
		card_levels = config.get_value("player", "card_levels", {})
		card_quantities = config.get_value("player", "card_quantities", {})
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
	player_name = "玩家"
	gold = 100
	gems = 10
	experience = 0
	trophies = 0
	card_levels.clear()
	card_quantities.clear()
	chests.clear()

func save_data():
	var config = ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("player", "name", player_name)
	config.set_value("player", "name_chosen", name_chosen)
	config.set_value("player", "gold", gold)
	config.set_value("player", "gems", gems)
	config.set_value("player", "experience", experience)
	config.set_value("player", "trophies", trophies)
	config.set_value("player", "highest_trophies", highest_trophies)
	config.set_value("player", "claimed_achievements", claimed_achievements)
	config.set_value("player", "card_levels", card_levels)
	config.set_value("player", "card_quantities", card_quantities)
	config.set_value("player", "chests", chests)
	config.set_value("shop", "day", shop_day)
	config.set_value("shop", "offers", shop_offers)
	config.set_value("emotes", "owned", owned_emotes)
	config.set_value("emotes", "wildcards", wildcards)
	config.set_value("player", "tower_choice", tower_choice)
	config.set_value("player", "last_card_request", last_card_request)
	config.set_value("player", "record_replays", record_replays)
	config.set_value("player", "donations_used", donations_used)
	config.set_value("player", "custom_deck", custom_deck)
	config.set_value("player", "custom_decks", custom_decks)
	config.set_value("player", "active_deck_index", active_deck_index)
	config.set_value("player", "use_custom_deck", use_custom_deck)
	config.set_value("player", "test_mode", test_mode)
	config.set_value("player", "deck_sort_mode", deck_sort_mode)
	config.save(SAVE_PATH)

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
func ai_level(card_id):
	# AI 卡牌等级下限按稀有度：普通1/稀有3/史诗6/传奇9
	var base: int = int(ai_levels.get(card_id, 1))
	var min_lv: int = CARD_RARITY.start_level_by_id(int(card_id))
	return clampi(maxi(base, min_lv), Config.LEVEL_MIN, Config.LEVEL_MAX)

func get_active_deck() -> Array:
	if custom_decks.size() <= active_deck_index:
		return []
	return custom_decks[active_deck_index]