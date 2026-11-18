# scripts/core/Challenges.gd
# 挑战 / 锦标赛结构：消耗宝石进入，达成指定胜场领取奖励；进度存于 PlayerData.challenge_state。
extends RefCounted

const DEFS := [
	{
		"id": "classic", "name": "经典挑战", "icon": "medal",
		"desc": "标准规则 8 胜挑战，输 3 场淘汰",
		"mode_id": "standard", "target": 8, "max_losses": 3,
		"entry_gems": 10, "reward_gold": 2000, "reward_gems": 20,
	},
	{
		"id": "double", "name": "双倍圣水挑战", "icon": "flask",
		"desc": "全程双倍圣水，6 胜领取奖励",
		"mode_id": "double_elixir", "target": 6, "max_losses": 3,
		"entry_gems": 20, "reward_gold": 3000, "reward_gems": 30,
	},
	{
		"id": "draft", "name": "选卡挑战", "icon": "deck",
		"desc": "每轮 4 选 1，5 胜领取奖励",
		"mode_id": "draft", "target": 5, "max_losses": 3,
		"entry_gems": 30, "reward_gold": 2500, "reward_gems": 50,
	},
	{
		"id": "touchdown", "name": "冲线挑战", "icon": "sword",
		"desc": "冲线 Touchdown，4 胜领取奖励",
		"mode_id": "touchdown", "target": 4, "max_losses": 3,
		"entry_gems": 15, "reward_gold": 1800, "reward_gems": 15,
	},
]


static func all() -> Array:
	var out: Array = []
	for d in DEFS:
		out.append((d as Dictionary).duplicate(true))
	return out


static func get_def(id: String) -> Dictionary:
	for d in DEFS:
		if String((d as Dictionary).get("id", "")) == id:
			return (d as Dictionary).duplicate(true)
	return {}


static func active() -> Dictionary:
	var a = PlayerData.challenge_state.get("active", {})
	return (a as Dictionary).duplicate(true) if a is Dictionary else {}


static func active_id() -> String:
	return String(active().get("id", ""))


static func active_def() -> Dictionary:
	var a := active()
	if a.is_empty():
		return {}
	return get_def(String(a.get("id", "")))


static func start(id: String) -> Dictionary:
	var def := get_def(id)
	if def.is_empty():
		return {"ok": false, "msg": "未知挑战"}
	if not active().is_empty():
		return {"ok": false, "msg": "已有进行中的挑战"}
	var cost: int = int(def.get("entry_gems", 0))
	if int(PlayerData.gems) < cost:
		return {"ok": false, "msg": "宝石不足（需要 %d）" % cost}
	PlayerData.gems = int(PlayerData.gems) - cost
	PlayerData.challenge_state["active"] = {"id": id, "wins": 0, "losses": 0}
	PlayerData.save_data()
	return {"ok": true, "def": def}


static func abandon() -> void:
	PlayerData.challenge_state.erase("active")
	PlayerData.save_data()


static func report_result(win: bool) -> Dictionary:
	var a := active()
	if a.is_empty():
		return {"active": false}
	var def := get_def(String(a.get("id", "")))
	if def.is_empty():
		return {"active": false}
	if win:
		a["wins"] = int(a.get("wins", 0)) + 1
	else:
		a["losses"] = int(a.get("losses", 0)) + 1
	var out := {
		"active": true,
		"id": String(def.id),
		"name": String(def.name),
		"wins": int(a.get("wins", 0)),
		"losses": int(a.get("losses", 0)),
		"target": int(def.get("target", 0)),
		"completed": false,
		"failed": false,
		"reward_gold": 0,
		"reward_gems": 0,
	}
	if int(a.get("wins", 0)) >= int(def.get("target", 0)):
		out["completed"] = true
		out["reward_gold"] = int(def.get("reward_gold", 0))
		out["reward_gems"] = int(def.get("reward_gems", 0))
		PlayerData.gold = int(PlayerData.gold) + int(out.reward_gold)
		PlayerData.gems = int(PlayerData.gems) + int(out.reward_gems)
		PlayerData.challenge_state.erase("active")
	elif int(a.get("losses", 0)) >= int(def.get("max_losses", 3)):
		out["failed"] = true
		PlayerData.challenge_state.erase("active")
	else:
		PlayerData.challenge_state["active"] = a
	PlayerData.save_data()
	return out
