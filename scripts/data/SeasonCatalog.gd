extends RefCounted
# 主题赛季：按月份轮换，每 10 个皇冠解锁一档奖励，不同赛季奖励侧重不同。

const THEMES := [
	{"name": "哥布林狂欢", "focus": "gold", "color": "5fd47a", "desc": "金币与升级资源"},
	{"name": "皇室盛夏", "focus": "gems", "color": "4db6ff", "desc": "宝石与宝箱"},
	{"name": "冰霜王座", "focus": "wild", "color": "8ee8ff", "desc": "万能卡与稀有卡"},
	{"name": "亡灵夜幕", "focus": "chest", "color": "b58cff", "desc": "魔法宝箱为主"},
	{"name": "丛林秘境", "focus": "gold", "color": "8fd35b", "desc": "金币与卡牌"},
	{"name": "熔岩战场", "focus": "wild", "color": "ff8a4d", "desc": "史诗万能卡"},
	{"name": "皇家庆典", "focus": "gems", "color": "ffd75e", "desc": "宝石与传奇资源"},
	{"name": "海盗宝藏", "focus": "chest", "color": "59d7c8", "desc": "宝箱与金币"},
	{"name": "机械工坊", "focus": "wild", "color": "9db7ff", "desc": "万能卡与宝箱"},
	{"name": "龙之传说", "focus": "gems", "color": "ff7b7b", "desc": "宝石与传奇卡"},
	{"name": "星界之旅", "focus": "gold", "color": "b0a4ff", "desc": "金币与万能卡"},
	{"name": "冠军之路", "focus": "chest", "color": "ffcc55", "desc": "高价值宝箱"},
]
const TIERS := 12

static func current_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d" % [int(d.year), int(d.month)]

static func current_index() -> int:
	return absi(current_key().hash()) % THEMES.size()

static func current() -> Dictionary:
	return THEMES[current_index()]

static func theme_at(index: int) -> Dictionary:
	return THEMES[clampi(index, 0, THEMES.size() - 1)]

static func tier_crowns(tier: int) -> int:
	return clampi(tier, 1, TIERS) * 10

static func reward_for(tier: int, theme: Dictionary = {}) -> Dictionary:
	var th: Dictionary = theme if not theme.is_empty() else current()
	var focus := String(th.get("focus", "gold"))
	var t: int = clampi(tier, 1, TIERS)
	match focus:
		"gems":
			return {"type": "gems", "amount": 10 + t * 3}
		"wild":
			var rar := "epic" if t % 3 == 0 else ("rare" if t % 2 == 0 else "common")
			return {"type": "wild", "rarity": rar, "amount": 3 + t * 2}
		"chest":
			if t % 2 == 0:
				return {"type": "chest", "rarity": "magical", "stars": 4}
			return {"type": "gold", "amount": 600 + t * 200}
		_:
			return {"type": "gold", "amount": 800 + t * 300}

static func reward_text(r: Dictionary) -> String:
	match String(r.get("type", "gold")):
		"gems":
			return "%d 宝石" % int(r.get("amount", 0))
		"wild":
			var names := {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇"}
			return "%d 张%s万能卡" % [int(r.get("amount", 0)), String(names.get(String(r.get("rarity", "common")), "普通"))]
		"chest":
			return "%d 星魔法幸运宝箱" % int(r.get("stars", 4))
		_:
			return "%d 金币" % int(r.get("amount", 0))
