extends RefCounted
# 主题赛季：每月轮换主题，每 10 个皇冠解锁一档奖励（50 档）。
# 每个赛季侧重某几张主题卡牌，而不是单一资源。

const TIERS := 50
const THEMES := [
	{"name": "哥布林狂欢", "desc": "哥布林系卡牌", "color": "5fd47a", "cards": [
		{"id": 32, "name": "吹箭哥布林"}, {"id": 39, "name": "哥布林"},
		{"id": 40, "name": "哥布林飞桶"}, {"id": 94, "name": "哥布林巨人"}]},
	{"name": "皇室盛夏", "desc": "皇室系远程与王子", "color": "4db6ff", "cards": [
		{"id": 44, "name": "弓箭手"}, {"id": 45, "name": "火枪手"},
		{"id": 16, "name": "王子"}, {"id": 34, "name": "皇家巨人"}]},
	{"name": "冰霜王座", "desc": "冰霜与减速卡牌", "color": "8ee8ff", "cards": [
		{"id": 35, "name": "冰雪精灵"}, {"id": 36, "name": "戈仑冰人"},
		{"id": 80, "name": "冰冻法术"}, {"id": 24, "name": "骷髅墓碑"}]},
	{"name": "亡灵夜幕", "desc": "亡灵与骷髅系卡牌", "color": "b58cff", "cards": [
		{"id": 5, "name": "骷髅军团"}, {"id": 8, "name": "亡灵"},
		{"id": 24, "name": "骷髅墓碑"}, {"id": 82, "name": "熔岩猎犬"}]},
	{"name": "丛林秘境", "desc": "野蛮人与哥布林卡牌", "color": "8fd35b", "cards": [
		{"id": 57, "name": "野蛮人"}, {"id": 69, "name": "野蛮人攻城槌"},
		{"id": 32, "name": "吹箭哥布林"}, {"id": 39, "name": "哥布林"}]},
	{"name": "熔岩战场", "desc": "飞行与熔岩系卡牌", "color": "ff8a4d", "cards": [
		{"id": 14, "name": "飞龙宝宝"}, {"id": 25, "name": "气球"},
		{"id": 82, "name": "熔岩猎犬"}, {"id": 11, "name": "火球"}]},
	{"name": "皇家庆典", "desc": "皇家系核心卡牌", "color": "ffd75e", "cards": [
		{"id": 16, "name": "王子"}, {"id": 34, "name": "皇家巨人"},
		{"id": 44, "name": "弓箭手"}, {"id": 45, "name": "火枪手"}]},
	{"name": "海盗宝藏", "desc": "野猪与飞桶卡牌", "color": "59d7c8", "cards": [
		{"id": 17, "name": "野猪骑士"}, {"id": 40, "name": "哥布林飞桶"},
		{"id": 39, "name": "哥布林"}, {"id": 94, "name": "哥布林巨人"}]},
	{"name": "机械工坊", "desc": "法师与建筑卡牌", "color": "9db7ff", "cards": [
		{"id": 6, "name": "闪电法师"}, {"id": 7, "name": "法师"},
		{"id": 48, "name": "雷电法术"}, {"id": 33, "name": "地狱之塔"}]},
	{"name": "龙之传说", "desc": "龙系与飞行卡牌", "color": "ff7b7b", "cards": [
		{"id": 14, "name": "飞龙宝宝"}, {"id": 25, "name": "气球"},
		{"id": 82, "name": "熔岩猎犬"}, {"id": 6, "name": "闪电法师"}]},
	{"name": "星界之旅", "desc": "法术与冰霜卡牌", "color": "b0a4ff", "cards": [
		{"id": 7, "name": "法师"}, {"id": 6, "name": "闪电法师"},
		{"id": 35, "name": "冰雪精灵"}, {"id": 48, "name": "雷电法术"}]},
	{"name": "冠军之路", "desc": "竞技场核心卡牌", "color": "ffcc55", "cards": [
		{"id": 15, "name": "皮卡超人"}, {"id": 16, "name": "王子"},
		{"id": 76, "name": "三个火枪手"}, {"id": 13, "name": "迷你皮卡"}]},
]

static func current_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d" % [int(d.year), int(d.month)]

static func current_index() -> int:
	return absi(current_key().hash()) % THEMES.size()

static func current() -> Dictionary:
	return THEMES[current_index()]

static func tier_crowns(tier: int) -> int:
	return clampi(tier, 1, TIERS) * 10

static func reward_for(tier: int, theme: Dictionary = {}) -> Dictionary:
	var th: Dictionary = theme if not theme.is_empty() else current()
	var cards: Array = th.get("cards", [])
	var t: int = clampi(tier, 1, TIERS)
	# 每个 10 档给 3D 宝箱，其余档给主题卡牌
	if t % 10 == 0:
		return {"type": "chest", "rarity": "magical", "stars": 4, "label": "%s 宝箱" % String(th.get("name", "主题"))}
	if cards.is_empty():
		return {"type": "gold", "amount": 1000}
	var card: Dictionary = cards[(t - 1) % cards.size()]
	return {"type": "card", "card_id": int(card.get("id", 0)), "card_name": String(card.get("name", "卡牌")), "amount": 10 + t * 2}

static func reward_text(r: Dictionary) -> String:
	match String(r.get("type", "gold")):
		"card":
			return "%s ×%d" % [String(r.get("card_name", "卡牌")), int(r.get("amount", 0))]
		"chest":
			return String(r.get("label", "主题宝箱"))
		_:
			return "%d 金币" % int(r.get("amount", 0))
