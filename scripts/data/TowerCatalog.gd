# scripts/data/TowerCatalog.gd
# 可选皇家塔数据：1 公主塔 / 2 王子塔 / 3 厨师塔 / 4 飞刀塔
extends RefCounted

const TOWERS := {
	1: {
		"name": "公主塔", "base_id": 1, "hp": 3052, "damage": 109,
		"attack_speed": 800, "range": 7.0,
		"desc": "均衡的公主塔，稳定远程输出。", "special": "远程单体",
	},
	2: {
		"name": "王子塔", "base_id": 2, "hp": 2616, "damage": 320,
		"attack_speed": 2200, "range": 7.0,
		"desc": "高伤害、慢攻速，适合处理高血量目标。", "special": "高伤单体",
	},
	3: {
		"name": "厨师塔", "base_id": 1, "hp": 2703, "damage": 109,
		"attack_speed": 1000, "range": 7.5,
		"desc": "每隔 24 秒投出煎饼，让我方生命最高且未享用过的单位提升 1 级；攻击时烹饪速度降为 70%。",
		"special": "煎饼升级",
	},
	4: {
		"name": "飞刀塔", "base_id": 2, "hp": 2768, "damage": 107,
		"attack_speed": 500, "range": 7.5,
		"desc": "每次攻击消耗 1 枚飞刀；每 0.9 秒储存 1 枚，攻击后 0.5 秒内无法储存，最多 8 枚。",
		"special": "飞刀连射",
	},
}


static func get_tower(choice: int) -> Dictionary:
	return TOWERS.get(choice, TOWERS[1]).duplicate(true)


static func tower_name(choice: int) -> String:
	return String(get_tower(choice).get("name", "公主塔"))


static func has_choice(choice: int) -> bool:
	return TOWERS.has(choice)
