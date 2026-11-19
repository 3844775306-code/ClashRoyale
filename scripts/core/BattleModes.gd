# scripts/core/BattleModes.gd
# 对战模式表 + 当前选择（开局/重放/联机共用）
# 模式 = 圣水倍率 + 突然死亡 + 卡组来源 + 卡等规则；BattleManager 读取后驱动整局。
extends RefCounted

# 经典卡组（与卡组配置界面的 CLASSIC_DECKS 保持一致）
const CLASSIC_DECKS := {
	"速弩": [55, 21, 4, 44, 11, 91, 20, 119],
	"速猪": [17, 71, 35, 39, 20, 11, 61, 91],
	"速转": [70, 22, 39, 20, 11, 91, 119, 61],
	"天狗": [82, 25, 8, 11, 20, 24, 5, 10],
	"石头人": [92, 37, 59, 36, 24, 107, 20, 104],
	"野猪骑士": [17, 12, 71, 35, 11, 91, 21, 119],
	"墓园": [85, 4, 107, 91, 35, 19, 24, 11],
	"飞桶": [40, 121, 67, 4, 91, 77, 33, 39],
}

const MODES := [
	{
		"id": "standard", "name": "标准对战", "icon": "sword",
		"desc": "3 分钟常规对局，最后阶段圣水加速",
		"elixir": 1.0, "sudden_death": false, "deck": "custom", "level": "own",
	},
	{
		"id": "double_elixir", "name": "双倍圣水", "icon": "flask",
		"desc": "全程双倍圣水，节奏更快、卡组更敢下",
		"party": true, "elixir": 2.0, "sudden_death": false, "deck": "custom", "level": "own",
	},
	{
		"id": "triple_elixir", "name": "三倍圣水", "icon": "flask",
		"desc": "全程三倍圣水，兵海与法术齐飞",
		"party": true, "elixir": 3.0, "sudden_death": false, "deck": "custom", "level": "own",
	},
	{
		"id": "seven_elixir", "name": "七倍圣水", "icon": "flask",
		"desc": "圣水爆炸的娱乐规则，全程七倍回复",
		"party": true, "elixir": 7.0, "sudden_death": false, "deck": "custom", "level": "own",
	},
	{
		"id": "sudden_death", "name": "突然死亡", "icon": "sword",
		"desc": "先推掉一座塔立刻获胜；时间到则比较双方塔血",
		"party": true, "elixir": 1.0, "sudden_death": true, "deck": "custom", "level": "own",
	},
	{
		"id": "classic_deck", "name": "经典卡组", "icon": "deck",
		"desc": "随机一套经典竞技卡组，双方固定 11 级",
		"elixir": 1.0, "sudden_death": false, "deck": "classic", "level": "fixed",
	},
	{
		"id": "touchdown", "name": "冲线 Touchdown", "icon": "sword",
		"desc": "把部队送进对方底线得分，先到 3 分获胜；时间到比分高者胜",
		"party": true, "elixir": 1.0, "sudden_death": false, "deck": "custom", "level": "own",
		"win_condition": "touchdown", "score_to_win": 3,
	},
	{
		"id": "draft", "name": "选卡对战", "icon": "deck",
		"desc": "每轮 4 选 1，双方各抽 8 张卡组成卡组",
		"elixir": 1.0, "sudden_death": false, "deck": "draft", "level": "fixed", "draft_choices": 4,
	},
	{
		"id": "triple_draft", "name": "三选一选卡", "icon": "deck",
		"desc": "每轮 3 选 1 的快速选卡对战",
		"elixir": 1.0, "sudden_death": false, "deck": "draft", "level": "fixed", "draft_choices": 3,
	},
	{
		"id": "mega_deck", "name": "超级卡组", "icon": "deck",
		"desc": "18 张卡的大卡组对战，续航更长；全单位与皇家塔固定 11 级",
		"elixir": 1.0, "sudden_death": false, "deck": "mega", "level": "fixed", "party": true,
	},
	{
		"id": "swap_draft", "name": "双向选卡", "icon": "deck",
		"desc": "4 轮 2 选 1，不要的卡送给对手",
		"elixir": 1.0, "sudden_death": false, "deck": "swap_draft", "level": "fixed",
		"party": true, "draft_choices": 2, "draft_picks": 4,
	},
	{
		"id": "mirror_deck", "name": "镜像卡组", "icon": "deck",
		"desc": "双方使用完全相同的卡组",
		"elixir": 1.0, "sudden_death": false, "deck": "mirror", "level": "fixed",
		"party": true,
	},
	{
		"id": "commando", "name": "主题特种兵", "icon": "sword",
		"desc": "每天随机一个特种兵，每 15 秒从国王塔两侧轮换生成，每分钟数量 +1",
		"elixir": 1.0, "sudden_death": false, "deck": "custom", "level": "fixed",
		"party": true, "commando": true,
	},
	{
		"id": "duel", "name": "决斗 Duel", "icon": "sword",
		"desc": "三套卡组 Bo3：每回合换卡组，先赢 2 回合获胜",
		"elixir": 1.0, "sudden_death": false, "deck": "duel", "level": "own",
		"win_condition": "duel",
	},
	{
		"id": "custom", "name": "友谊战自定义", "icon": "gear",
		"desc": "自定义圣水倍率、突然死亡与卡等规则",
		"party": true, "elixir": 1.0, "sudden_death": false, "deck": "custom", "level": "own",
		"custom": true,
	},
]

static var _current_id: String = "standard"
static var _draft_player: Array = []
static var _draft_enemy: Array = []
static var _swap_player: Array = []
static var _swap_enemy: Array = []
static var _duel: Dictionary = {
	"active": false, "round": 1, "wins": [0, 0],
	"player_decks": [], "enemy_decks": [],
}
static var _custom: Dictionary = {"elixir": 1.0, "sudden_death": false, "level": "own"}


static func all() -> Array:
	var out: Array = []
	for m in MODES:
		out.append((m as Dictionary).duplicate(true))
	return out


static func get_by_id(id: String) -> Dictionary:
	for m in MODES:
		if String((m as Dictionary).get("id", "")) == id:
			return (m as Dictionary).duplicate(true)
	return MODES[0].duplicate(true)


static func current_id() -> String:
	return _current_id


static func current() -> Dictionary:
	var base := get_by_id(_current_id)
	if bool(base.get("custom", false)):
		base["elixir"] = float(_custom.get("elixir", 1.0))
		base["sudden_death"] = bool(_custom.get("sudden_death", false))
		base["level"] = String(_custom.get("level", "own"))
	return base


static func set_mode(mode: Dictionary) -> void:
	var id := String(mode.get("id", "standard"))
	_current_id = id
	if id == "custom":
		_custom["elixir"] = float(mode.get("elixir", 1.0))
		_custom["sudden_death"] = bool(mode.get("sudden_death", false))
		_custom["level"] = String(mode.get("level", "own"))


static func custom_config() -> Dictionary:
	return _custom.duplicate(true)


static func set_custom_config(cfg: Dictionary) -> void:
	_custom["elixir"] = float(cfg.get("elixir", 1.0))
	_custom["sudden_death"] = bool(cfg.get("sudden_death", false))
	_custom["level"] = String(cfg.get("level", "own"))


static func set_draft_decks(player: Array, enemy: Array) -> void:
	_draft_player = Array(player).duplicate()
	_draft_enemy = Array(enemy).duplicate()


static func set_swap_decks(player: Array, enemy: Array) -> void:
	_swap_player = Array(player).duplicate()
	_swap_enemy = Array(enemy).duplicate()


static func swap_decks() -> Dictionary:
	return {"player": _swap_player.duplicate(), "enemy": _swap_enemy.duplicate()}


# 每日特种兵：用日期做种子，返回稳定的数字种子（具体卡牌由 BattleManager 从卡表挑选）
static func commando_seed() -> int:
	var env_card := OS.get_environment("CR_COMMANDO_CARD")
	if env_card != "":
		return -int(env_card)   # 负数表示直接指定卡 id
	var d: Dictionary = Time.get_date_dict_from_system()
	return int(d.get("year", 2026)) * 10000 + int(d.get("month", 1)) * 100 + int(d.get("day", 1))


static func draft_decks() -> Dictionary:
	return {"player": _draft_player.duplicate(), "enemy": _draft_enemy.duplicate()}


static func clear_draft_decks() -> void:
	_draft_player.clear()
	_draft_enemy.clear()


static func start_duel(player_decks: Array, enemy_decks: Array) -> void:
	_duel = {
		"active": true,
		"round": 1,
		"wins": [0, 0],
		"player_decks": _norm_duel_decks(player_decks),
		"enemy_decks": _norm_duel_decks(enemy_decks),
	}


static func duel_state() -> Dictionary:
	return _duel.duplicate(true)


static func duel_advance(winner_team: int) -> Dictionary:
	if not bool(_duel.get("active", false)):
		return {"match_over": true, "match_winner": winner_team, "round": 1, "wins": [0, 0]}
	var wins: Array = Array(_duel.get("wins", [0, 0])).duplicate()
	wins[clampi(winner_team, 0, 1)] = int(wins[clampi(winner_team, 0, 1)]) + 1
	_duel["wins"] = wins
	var over: bool = int(wins[0]) >= 2 or int(wins[1]) >= 2
	if over:
		_duel["active"] = false
		return {
			"match_over": true,
			"match_winner": 0 if int(wins[0]) > int(wins[1]) else 1,
			"round": int(_duel.get("round", 1)),
			"wins": wins,
		}
	_duel["round"] = int(_duel.get("round", 1)) + 1
	return {
		"match_over": false,
		"match_winner": -1,
		"round": int(_duel["round"]),
		"wins": wins,
	}


static func reset_duel() -> void:
	_duel = {"active": false, "round": 1, "wins": [0, 0], "player_decks": [], "enemy_decks": []}


static func _norm_duel_decks(src: Array) -> Array:
	var out: Array = []
	for d in src:
		var arr: Array = []
		for cid in Array(d):
			arr.append(int(cid))
		out.append(arr)
	while out.size() < 3:
		out.append([])
	return out


static func classic_decks() -> Array:
	var out: Array = []
	for key in CLASSIC_DECKS.keys():
		out.append(Array(CLASSIC_DECKS[key]).duplicate())
	return out


static func mode_label(m: Dictionary) -> String:
	var parts: Array = []
	if float(m.get("elixir", 1.0)) != 1.0:
		parts.append("%s倍圣水" % _num_str(float(m.get("elixir", 1.0))))
	if bool(m.get("sudden_death", false)):
		parts.append("突然死亡")
	if String(m.get("level", "own")) == "fixed":
		parts.append("固定 11 级")
	if String(m.get("win_condition", "")) == "touchdown":
		parts.append("冲线得分")
	if String(m.get("win_condition", "")) == "duel":
		parts.append("三套卡组 Bo3")
	var deck_src := String(m.get("deck", "custom"))
	if deck_src == "classic":
		parts.append("经典卡组")
	elif deck_src == "draft":
		parts.append("选卡")
	elif deck_src == "mega":
		parts.append("18 卡")
	elif deck_src == "swap_draft":
		parts.append("双向选卡")
	elif deck_src == "mirror":
		parts.append("镜像卡组")
	if bool(m.get("commando", false)):
		parts.append("每日特种兵")
	return " · ".join(parts)


static func _num_str(v: float) -> String:
	if absf(v - roundf(v)) < 0.01:
		return str(int(roundf(v)))
	return "%.1f" % v
