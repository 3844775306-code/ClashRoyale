extends RefCounted
# ============================================================
# 卡牌 -> 视觉参数 映射表
# 119 张卡全部走关键词归类 + 手工覆写，保证风格统一
# ============================================================

const KIT := preload("res://scripts/visuals/UnitModelKit.gd")

static func accent_for(team: int) -> Color:
	return KIT.COL_TEAM_PLAYER if team == 0 else KIT.COL_TEAM_ENEMY

static func spec_for(card_name: String, team: int, attack_range: float = -1.0) -> Dictionary:
	var spec: Dictionary = _spec_for_impl(card_name, team)
	if attack_range >= 0.0:
		_adapt_weapon(spec, card_name, attack_range)
	if COLOR_OVERRIDES.has(card_name):
		var oc: Color = COLOR_OVERRIDES[card_name]
		spec["body"] = oc
		if spec.has("belly"):
			spec["belly"] = oc.lightened(0.22)
	if HAIR_OVERRIDES.has(card_name) and spec.has("hair_color"):
		spec["hair_color"] = HAIR_OVERRIDES[card_name]
	return spec

static func _adapt_weapon(spec: Dictionary, card_name: String, attack_range: float) -> void:
	if not spec.has("weapon"):
		return
	var w: String = String(spec["weapon"])
	# 远程单位不拿近战剑/锤/棒，换成对应远程武器
	if attack_range >= 2.0 and w in ["sword", "big_sword", "club", "hammer"]:
		if card_name.contains("火枪") or card_name.contains("猎人") or card_name.contains("炮手") or card_name.contains("枪手"):
			spec["weapon"] = "musket"
		elif card_name.contains("弓") or card_name.contains("箭") or card_name.contains("公主") or card_name.contains("游侠"):
			spec["weapon"] = "bow"
		elif card_name.contains("法") or card_name.contains("女巫") or card_name.contains("巫"):
			spec["weapon"] = "staff"
		elif card_name.contains("吹箭") or card_name.contains("投矛") or card_name.contains("标枪"):
			spec["weapon"] = "spear"
		else:
			spec["weapon"] = "bow"
	# 近战单位误配弓/枪时换回剑
	elif attack_range > 0.0 and attack_range <= 1.2 and w in ["bow", "musket"]:
		spec["weapon"] = "sword"

# 卡牌主色对照（来源：scbase.cn 卡牌图，人工校正）：仅覆盖原先使用默认占位色的单位
const COLOR_OVERRIDES := {
	"攻城炸弹人": Color(0.72, 0.68, 0.60),
	"哥布林投矛手": Color(0.32, 0.42, 0.10),
	"炸弹兵": Color(0.24, 0.55, 0.72),
	"皇家卫队": Color(0.16, 0.24, 0.32),
	"狂战士": Color(0.65, 0.30, 0.18),
	"幻影刺客": Color(0.36, 0.24, 0.44),
	"哥布林机甲": Color(0.28, 0.38, 0.12),
	"渔夫": Color(0.12, 0.42, 0.56),
	"皇家幽灵": Color(0.80, 0.92, 1.0),
	"绿林团伙": Color(0.24, 0.42, 0.45),
	"绿林小妹": Color(0.24, 0.42, 0.45),
	"可疑草丛": Color(0.20, 0.42, 0.15),
	"哥布林爆破手": Color(0.40, 0.32, 0.16),
	"迷你皮卡": Color(0.10, 0.14, 0.26),
	"皮卡超人": Color(0.16, 0.10, 0.26),
	"迫击炮": Color(0.28, 0.42, 0.18),
	"哥布林牢笼": Color(0.30, 0.45, 0.18),
	"雷电巨人": Color(0.32, 0.24, 0.42),
	"地狱之塔": Color(0.30, 0.22, 0.38),
	"弓箭手": Color(0.35, 0.42, 0.60),
	"雷电精灵": Color(0.55, 0.35, 0.85),
	"骷髅守卫": Color(0.55, 0.62, 0.70),
	"哥布林钻机": Color(0.26, 0.38, 0.16),
	"闪电法师": Color(0.78, 0.82, 0.88),
}
const HAIR_OVERRIDES := {
	"闪电法师": Color(0.98, 0.66, 0.78),
	"弓箭手": Color(0.92, 0.42, 0.66),
	"狂战士": Color(0.92, 0.48, 0.14),
	"神箭游侠": Color(0.90, 0.88, 0.82),
}

static func _spec_for_impl(card_name: String, team: int) -> Dictionary:
	var s: Dictionary = _special(card_name)
	if s.is_empty():
		s = _classify(card_name)
	s["accent"] = accent_for(team)
	return s

# ---------------- 默认值 ----------------
static func _humanoid(over: Dictionary) -> Dictionary:
	var d := {
		"archetype": "humanoid",
		"height": 1.10,
		"body": Color(0.44, 0.52, 0.66),
		"pants": Color(0.26, 0.29, 0.38),
		"skin": KIT.COL_SKIN,
		"metal": KIT.COL_STEEL,
		"leather": KIT.COL_LEATHER,
		"cloth": KIT.COL_CLOTH,
		"helmet": "none",
		"weapon": "sword",
		"shield": false,
		"cape_on": false,
		"robe": false,
		"wings": false,
		"armor": false,
		"pauldrons": false,
		"beard": false,
		"bare_arms": false,
		"tabard": false,
		"fur_collar": false,
		"fly": false,
		"head_scale": 1.0,
		"limb_scale": 1.0,
		"torso_scale": 1.0,
		"glow": Color(1.0, 0.62, 0.25),
		"hair_color": Color(0.30, 0.22, 0.17),
		"beard_color": Color(0.92, 0.90, 0.86),
	}
	d.merge(over, true)
	return d

static func _dragon(over: Dictionary) -> Dictionary:
	var d := {
		"archetype": "dragon",
		"height": 1.25,
		"body": Color(0.32, 0.55, 0.34),
		"belly": Color(0.70, 0.78, 0.50),
		"horn": KIT.COL_BONE,
		"eye": Color(1.0, 0.82, 0.25),
		"fly": true,
	}
	d.merge(over, true)
	return d

static func _building(over: Dictionary) -> Dictionary:
	var d := {
		"archetype": "building",
		"height": 1.55,
		"kind": "tower",
		"body": KIT.COL_STONE,
		"stone_dark": KIT.COL_STONE_DARK,
		"roof": Color(0.34, 0.40, 0.54),
		"wood": KIT.COL_WOOD,
		"metal": KIT.COL_IRON,
		"fly": false,
	}
	d.merge(over, true)
	return d

static func _spirit(col: Color) -> Dictionary:
	return {"archetype": "spirit", "height": 0.60, "glow": col, "body": col.lightened(0.25), "fly": true}

# ---------------- 重点卡牌手工配置 ----------------
static func _special(n: String) -> Dictionary:
	match n:
		"骑士":
			return _humanoid({"height": 1.14, "body": Color(0.30, 0.44, 0.66), "pants": Color(0.24, 0.28, 0.38), "helmet": "helm", "shield": true, "cape_on": true, "armor": true, "pauldrons": true, "tabard": true})
		"野蛮人":
			return _humanoid({"height": 1.18, "body": Color(0.52, 0.36, 0.24), "pants": Color(0.34, 0.25, 0.18), "helmet": "horns", "weapon": "axe", "bare_arms": true, "pauldrons": true, "beard": true, "hair_color": Color(0.35, 0.22, 0.13)})
		"野蛮人精锐":
			return _humanoid({"height": 1.22, "body": Color(0.36, 0.28, 0.24), "pants": Color(0.26, 0.20, 0.16), "helmet": "horns", "weapon": "axe", "bare_arms": true, "metal": KIT.COL_STEEL_DARK, "pauldrons": true, "cape_on": true, "beard": true, "hair_color": Color(0.25, 0.16, 0.10)})
		"王子":
			return _humanoid({"height": 1.20, "body": Color(0.56, 0.60, 0.72), "pants": Color(0.28, 0.30, 0.40), "helmet": "crown", "weapon": "spear", "shield": true, "cape_on": true, "armor": true, "pauldrons": true, "tabard": true, "hair_color": Color(0.62, 0.44, 0.20)})
		"黑暗王子":
			return _humanoid({"height": 1.20, "body": Color(0.22, 0.23, 0.31), "pants": Color(0.16, 0.17, 0.23), "helmet": "crown", "weapon": "hammer", "shield": true, "cape_on": true, "metal": KIT.COL_IRON, "armor": true, "pauldrons": true, "tabard": true})
		"迷你皮卡":
			return _humanoid({"height": 1.16, "body": KIT.COL_IRON, "pants": Color(0.24, 0.25, 0.31), "helmet": "horns", "weapon": "big_sword", "metal": KIT.COL_STEEL_DARK, "head_scale": 1.02, "torso_scale": 1.10})
		"皮卡超人":
			return _humanoid({"height": 1.58, "body": KIT.COL_IRON, "pants": Color(0.24, 0.25, 0.31), "helmet": "horns", "weapon": "big_sword", "metal": KIT.COL_STEEL_DARK, "head_scale": 0.86, "torso_scale": 1.25, "limb_scale": 1.30})
		"超级骑士":
			return _humanoid({"height": 1.56, "body": Color(0.30, 0.34, 0.46), "pants": Color(0.22, 0.24, 0.31), "helmet": "horns", "weapon": "hammer", "metal": KIT.COL_STEEL, "armor": true, "pauldrons": true, "cape_on": true, "head_scale": 0.88, "torso_scale": 1.20, "limb_scale": 1.25})
		"女武神":
			return _humanoid({"height": 1.16, "body": Color(0.58, 0.28, 0.26), "pants": Color(0.30, 0.22, 0.18), "helmet": "hair", "weapon": "axe", "shield": true, "armor": true, "pauldrons": true, "hair_color": Color(0.90, 0.72, 0.30)})
		"瓦基丽武神":
			return _humanoid({"height": 1.16, "body": Color(0.58, 0.28, 0.26), "pants": Color(0.30, 0.22, 0.18), "helmet": "hair", "weapon": "axe", "shield": true, "armor": true, "pauldrons": true, "hair_color": Color(0.90, 0.72, 0.30)})
		"圣水收集器":
			return _building({"height": 1.15, "kind": "elixir_pump", "body": Color(0.56, 0.36, 0.62), "roof": Color(0.30, 0.20, 0.42), "tower_w": 0.85})
		"巨人":
			return _humanoid({"height": 1.56, "scale_mul": 1.20, "body": KIT.COL_SKIN_DARK, "pants": KIT.COL_LEATHER, "helmet": "hair", "weapon": "club", "bare_arms": true, "head_scale": 0.80, "torso_scale": 1.28, "limb_scale": 1.35, "hair_color": Color(0.34, 0.22, 0.14), "beard": true, "beard_color": Color(0.30, 0.20, 0.12)})
		"皇家巨人":
			return _humanoid({"height": 1.58, "scale_mul": 1.23, "body": Color(0.70, 0.50, 0.34), "pants": Color(0.42, 0.31, 0.22), "helmet": "hair", "weapon": "cannon", "metal": KIT.COL_IRON, "bare_arms": true, "head_scale": 0.80, "torso_scale": 1.28, "limb_scale": 1.35, "hair_color": Color(0.55, 0.36, 0.18)})
		"戈仑石人", "戈仑冰人":
			var ice := n == "戈仑冰人"
			return _humanoid({"height": 1.60, "scale_mul": 1.20 if ice else 1.17, "body": Color(0.46, 0.52, 0.58), "pants": Color(0.38, 0.43, 0.50), "skin": Color(0.54, 0.58, 0.64), "helmet": "none", "weapon": "club", "head_scale": 0.80, "torso_scale": 1.34, "limb_scale": 1.42, "glow": Color(0.5, 0.85, 1.0) if ice else Color(1.0, 0.55, 0.2)})
		"圣水戈仑":
			return _humanoid({"height": 1.62, "scale_mul": 1.18, "body": Color(0.56, 0.30, 0.84), "pants": Color(0.34, 0.18, 0.52), "skin": Color(0.66, 0.40, 0.92), "helmet": "none", "weapon": "club", "bare_arms": true, "head_scale": 0.82, "torso_scale": 1.30, "limb_scale": 1.36, "glow": Color(0.72, 0.42, 1.0)})
		"圣水小戈仑":
			return _humanoid({"height": 1.05, "scale_mul": 0.95, "body": Color(0.58, 0.32, 0.86), "pants": Color(0.36, 0.20, 0.54), "skin": Color(0.68, 0.42, 0.94), "helmet": "none", "weapon": "club", "bare_arms": true, "head_scale": 0.9, "torso_scale": 1.18, "limb_scale": 1.2, "glow": Color(0.72, 0.42, 1.0)})
		"圣水泡泡":
			return _humanoid({"height": 0.55, "body": Color(0.62, 0.36, 0.92), "pants": Color(0.46, 0.24, 0.70), "skin": Color(0.72, 0.46, 1.0), "helmet": "none", "head_scale": 1.25, "torso_scale": 1.1, "glow": Color(0.78, 0.52, 1.0)})
		"哥布林钻机":
			return _building({"height": 1.30, "kind": "drill", "body": Color(0.46, 0.38, 0.26), "roof": Color(0.28, 0.24, 0.18), "accent": Color(0.36, 0.56, 0.20), "tower_w": 0.9, "metal": KIT.COL_STEEL_DARK})
		"绿林小妹":
			return _humanoid({"height": 1.02, "scale_mul": 0.9, "body": Color(0.34, 0.50, 0.30), "pants": Color(0.26, 0.28, 0.22), "helmet": "hood", "cloth": Color(0.48, 0.28, 0.42), "weapon": "bow", "hair_color": Color(0.88, 0.46, 0.66)})
		"绿林团伙":
			return _humanoid({"height": 1.10, "scale_mul": 2.0, "body": Color(0.42, 0.44, 0.30), "pants": Color(0.28, 0.26, 0.20), "helmet": "horns", "weapon": "club", "bare_arms": true})
		"符文巨人":
			return _humanoid({"height": 1.52, "scale_mul": 1.23, "body": Color(0.84, 0.46, 0.16), "pants": Color(0.42, 0.26, 0.14), "helmet": "horns", "weapon": "club", "bare_arms": true, "head_scale": 0.84, "torso_scale": 1.24, "limb_scale": 1.28, "glow": Color(1.0, 0.58, 0.18)})
		"哥布林巨人", "雷电巨人", "圣水戈仑", "符文巨人", "小戈仑石人":
			return _humanoid({"height": 1.52, "scale_mul": 1.23, "body": KIT.COL_SKIN_DARK, "helmet": "hair", "weapon": "club", "bare_arms": true, "head_scale": 0.84, "torso_scale": 1.24, "limb_scale": 1.28})
		"亡灵巨人":
			return {"archetype": "winged", "height": 1.85, "scale_mul": 0.56, "body": Color(0.44, 0.52, 0.68), "wing": Color(0.56, 0.62, 0.76), "wing_membrane": Color(0.70, 0.76, 0.88), "fly": true}
		"浪人":
			return _humanoid({"height": 1.18, "body": Color(0.24, 0.20, 0.26), "helmet": "hood", "cloth": Color(0.36, 0.16, 0.18), "weapon": "club"})
		"可疑草丛":
			return {"archetype": "bush", "height": 0.75}
		"哥布林牢笼":
			return _building({"height": 1.25, "kind": "cage", "body": Color(0.42, 0.34, 0.24), "roof": Color(0.24, 0.20, 0.16), "accent": Color(0.42, 0.62, 0.20), "tower_w": 0.9})
		"骷髅巨人":
			return _humanoid({"height": 1.52, "scale_mul": 1.23, "body": KIT.COL_BONE, "pants": Color(0.28, 0.27, 0.26), "skin": KIT.COL_BONE, "helmet": "skull", "weapon": "club", "bare_arms": true, "head_scale": 0.84, "torso_scale": 1.28, "limb_scale": 1.28})
		"骷髅军团", "骷髅兵":
			return _humanoid({"height": 0.90, "scale_mul": 0.63, "body": KIT.COL_BONE, "pants": Color(0.28, 0.28, 0.32), "skin": KIT.COL_BONE, "helmet": "skull", "weapon": "sword", "metal": KIT.COL_STEEL_DARK, "bare_arms": true})
		"哥布林":
			return _humanoid({"height": 0.92, "scale_mul": 0.87, "body": Color(0.36, 0.44, 0.26), "pants": KIT.COL_LEATHER, "skin": Color(0.46, 0.64, 0.30), "helmet": "hood", "cloth": Color(0.32, 0.40, 0.24), "weapon": "sword", "head_scale": 1.12, "bare_arms": true})
		"吹箭哥布林":
			return _humanoid({"height": 0.94, "body": Color(0.36, 0.44, 0.26), "pants": KIT.COL_LEATHER, "skin": Color(0.46, 0.64, 0.30), "helmet": "hood", "cloth": Color(0.32, 0.40, 0.24), "weapon": "spear", "head_scale": 1.12, "bare_arms": true})
		"弓箭手":
			return _humanoid({"height": 1.08, "body": Color(0.72, 0.40, 0.82), "pants": Color(0.44, 0.28, 0.54), "helmet": "hood", "cloth": Color(0.78, 0.46, 0.88), "weapon": "bow", "hair_color": Color(0.86, 0.68, 0.92)})
		"火枪手":
			return _humanoid({"height": 1.10, "body": Color(0.28, 0.34, 0.48), "pants": Color(0.22, 0.24, 0.30), "helmet": "hood", "cloth": Color(0.26, 0.32, 0.44), "weapon": "musket", "hair_color": Color(0.55, 0.35, 0.18)})
		"公主":
			return _humanoid({"height": 1.08, "body": Color(0.78, 0.16, 0.20), "pants": Color(0.38, 0.12, 0.14), "helmet": "crown", "cloth": Color(0.88, 0.22, 0.26), "weapon": "bow", "robe": true})
		"法师":
			return _humanoid({"height": 1.16, "body": Color(0.22, 0.34, 0.72), "robe": true, "helmet": "wizard", "cloth": Color(0.24, 0.36, 0.76), "weapon": "staff", "glow": Color(1.0, 0.55, 0.20), "beard": true})
		"寒冰法师":
			return _humanoid({"height": 1.16, "body": Color(0.24, 0.52, 0.78), "robe": true, "helmet": "hood", "cloth": Color(0.22, 0.46, 0.72), "weapon": "staff", "glow": Color(0.40, 0.86, 1.0), "beard": true})
		"闪电法师":
			return _humanoid({"height": 1.16, "body": Color(0.20, 0.40, 0.68), "robe": true, "helmet": "hood", "cloth": Color(0.18, 0.36, 0.62), "weapon": "staff", "glow": Color(0.50, 0.82, 1.0), "beard": true})
		"女巫":
			return _humanoid({"height": 1.14, "body": Color(0.32, 0.22, 0.44), "robe": true, "helmet": "hood", "cloth": Color(0.28, 0.18, 0.38), "weapon": "staff", "glow": Color(0.72, 0.45, 1.0)})
		"暗夜女巫":
			return _humanoid({"height": 1.14, "body": Color(0.20, 0.19, 0.32), "robe": true, "helmet": "hood", "cloth": Color(0.17, 0.15, 0.28), "weapon": "staff", "glow": Color(0.55, 0.35, 0.95)})
		"气球兵":
			return {"archetype": "balloon", "height": 1.64, "skin": KIT.COL_SKIN, "fly": true}
		"骷髅气球":
			return {"archetype": "balloon", "height": 1.23, "skin": KIT.COL_BONE, "fly": true}
		"公主塔":
			return _building({"height": 1.12, "scale_mul": 0.8, "kind": "tower_princess", "body": Color(0.74, 0.71, 0.64), "roof": Color(0.34, 0.42, 0.60), "tower_w": 1.02})
		"王子塔":
			return _building({"height": 1.16, "scale_mul": 0.8, "kind": "tower_cannon", "body": Color(0.74, 0.70, 0.62), "roof": Color(0.44, 0.32, 0.40), "turret": true, "turret_y": 1.34, "turret_off_z": 0.55, "tower_w": 1.02})
		"国王塔":
			return _building({"height": 1.365, "scale_mul": 0.8, "kind": "tower_king", "roof": Color(0.50, 0.36, 0.22), "body": Color(0.72, 0.68, 0.60), "turret": true, "turret_y": 1.74, "turret_off_z": 0.62, "tower_w": 1.139})
		"厨师塔":
			return _building({"height": 1.16, "scale_mul": 0.8, "kind": "tower_chef", "body": Color(0.68, 0.38, 0.20), "roof": Color(0.94, 0.86, 0.70), "wood": Color(0.52, 0.30, 0.16), "tower_w": 1.02})
		"飞刀塔":
			return _building({"height": 1.16, "scale_mul": 0.8, "kind": "tower_knife", "body": Color(0.38, 0.40, 0.46), "roof": Color(0.24, 0.30, 0.38), "metal": Color(0.72, 0.76, 0.82), "tower_w": 1.02})
		"加农炮战车":
			return {"archetype": "cannon_cart", "height": 1.10, "fly": false}
		"十字连弩":
			return {"archetype": "crossbow", "height": 1.35, "fly": false, "kind": "crossbow", "turret": true, "turret_y": 0.66}
		"电磁炮":
			return {"archetype": "sparky", "height": 1.30, "fly": false}
		"野蛮人攻城槌":
			return {"archetype": "ram", "height": 1.20, "fly": false}
		"野蛮人攻城锤":
			return {"archetype": "ram", "height": 1.20, "fly": false}
		"飞行机器":
			return {"archetype": "flying_machine", "height": 1.10, "fly": true}
		"加农炮":
			return _building({"height": 1.02, "kind": "cannon", "turret": true, "turret_y": 0.45})
		"炸弹塔":
			return _building({"height": 1.52, "kind": "bomb_tower", "roof": Color(0.28, 0.28, 0.34), "body": Color(0.58, 0.54, 0.48)})
		"迫击炮":
			return _building({"height": 1.15, "kind": "mortar", "turret": true, "turret_y": 0.34})
		"特斯拉电磁塔":
			return _building({"height": 1.42, "kind": "tesla"})
		"地狱之塔":
			return _building({"height": 1.46, "kind": "inferno_tower", "metal": Color(0.36, 0.28, 0.30)})
		"骷髅墓碑":
			return _building({"height": 0.98, "kind": "tomb"})
		"野蛮人小屋":
			return _building({"height": 1.28, "kind": "spawner", "roof": Color(0.42, 0.30, 0.22)})
		"哥布林小屋":
			return _building({"height": 1.28, "kind": "spawner", "roof": Color(0.30, 0.40, 0.26)})
		"凤凰蛋":
			return {"archetype": "egg", "height": 0.55, "fly": false}
		"烈焰熔炉":
			return _building({"height": 1.30, "kind": "furnace"})
		"冰雪精灵":
			return _spirit(Color(0.40, 0.85, 1.0))
		"雷电精灵":
			return _spirit(Color(0.55, 0.80, 1.0))
		"治疗精灵":
			return _spirit(Color(0.55, 0.95, 0.55))
		"烈焰精灵":
			return _spirit(Color(1.0, 0.55, 0.20))
		"冰精灵":
			return _spirit(Color(0.45, 0.85, 1.0))
		"火精灵":
			return _spirit(Color(1.0, 0.50, 0.22))
		"野猪骑士":
			return {"archetype": "boar_rider", "height": 1.22, "fly": false}
		"皇家野猪":
			return {"archetype": "boar", "height": 0.92, "fly": false}
		"小猪":
			return {"archetype": "boar", "height": 0.58, "fly": false, "body": Color(0.96, 0.72, 0.72), "accent": Color(0.98, 0.85, 0.88)}
		"电击车小队":
			return {"archetype": "zappy", "height": 0.86, "fly": false}
		"蛮羊骑士":
			return {"archetype": "ram_rider", "height": 1.25, "fly": false}
		"狂暴樵夫":
			return _humanoid({"height": 1.18, "body": Color(0.58, 0.16, 0.14), "pants": Color(0.28, 0.22, 0.18), "helmet": "hair", "weapon": "axe", "beard": true, "bare_arms": true})
		"猎人":
			return _humanoid({"height": 1.10, "body": Color(0.38, 0.30, 0.24), "helmet": "hood", "cloth": Color(0.30, 0.26, 0.22), "weapon": "musket", "beard": true})
		"巨石投手":
			return _humanoid({"height": 2.2, "body": Color(0.52, 0.42, 0.30), "pants": Color(0.32, 0.26, 0.20), "helmet": "horns", "bare_arms": true, "beard": true, "held_boulder": true, "head_scale": 0.92, "torso_scale": 1.2, "limb_scale": 1.25})
		"飞斧屠夫":
			return _humanoid({"height": 1.40, "body": Color(0.56, 0.32, 0.30), "pants": Color(0.30, 0.24, 0.22), "helmet": "hair", "weapon": "axe", "bare_arms": true, "beard": true, "torso_scale": 1.2, "limb_scale": 1.15})
		"飞龙宝宝":
			return _dragon({"height": 1.25, "body": Color(0.32, 0.62, 0.34), "belly": Color(0.68, 0.80, 0.48)})
		"雷电飞龙":
			return _dragon({"height": 1.30, "body": Color(0.26, 0.46, 0.86), "belly": Color(0.62, 0.78, 1.0), "eye": Color(0.90, 0.95, 1.0)})
		"骷髅飞龙":
			return _dragon({"height": 1.05, "body": Color(0.86, 0.86, 0.78), "belly": Color(0.95, 0.95, 0.88), "horn": Color(0.75, 0.72, 0.62)})
		"凤凰":
			return _dragon({"height": 1.20, "body": Color(0.86, 0.26, 0.16), "belly": Color(1.0, 0.62, 0.25), "eye": Color(1.0, 0.90, 0.40)})
		"熔岩猎犬":
			return _dragon({"height": 1.45, "body": Color(0.70, 0.38, 0.14), "belly": Color(0.95, 0.55, 0.20), "eye": Color(1.0, 0.70, 0.20)})
		"蝙蝠":
			return _dragon({"height": 0.82, "scale_mul": 0.87, "body": Color(0.55, 0.30, 0.75), "belly": Color(0.72, 0.52, 0.90)})
		"亡灵":
			return _dragon({"height": 0.85, "scale_mul": 1.19, "body": Color(0.40, 0.52, 0.86), "belly": Color(0.65, 0.75, 1.0)})
		"亡灵大军":
			return _dragon({"height": 0.85, "body": Color(0.40, 0.52, 0.86), "belly": Color(0.65, 0.75, 1.0)})
		"地狱飞龙":
			return _dragon({"height": 1.30, "body": Color(0.62, 0.74, 0.24), "belly": Color(0.85, 0.92, 0.40), "eye": Color(1.0, 0.85, 0.20)})
		"重甲亡灵":
			return {"archetype": "winged", "height": 1.15, "body": Color(0.55, 0.62, 0.72), "wing": Color(0.62, 0.68, 0.78), "wing_membrane": Color(0.72, 0.78, 0.88), "fly": true}
		"精灵女王":
			return {"archetype": "winged", "height": 1.25, "body": Color(0.30, 0.46, 0.86), "wing": Color(0.45, 0.62, 0.95), "wing_membrane": Color(0.60, 0.76, 1.0), "robe": true, "helmet": "hair", "fly": true}
		"掘地矿工":
			return _humanoid({"height": 1.10, "body": Color(0.46, 0.38, 0.30), "pants": KIT.COL_LEATHER, "helmet": "helm", "weapon": "spear"})
		_:
			return {}

# ---------------- 关键词归类（兜底，覆盖剩余全部卡） ----------------
static func _classify(n: String) -> Dictionary:
	var team_ish: Color = Color(0.38, 0.44, 0.56)
	if n.contains("塔") or n.contains("小屋") or n.contains("熔炉") or n.contains("牢笼") or n.contains("墓碑") or n.contains("钻机") or n.contains("连弩") or n.contains("迫击炮") or n.contains("加农炮"):
		return _building({"height": 1.5})
	if n.contains("气球"):
		return {"archetype": "balloon", "height": 0.82, "skin": KIT.COL_SKIN, "fly": true}
	if n.contains("龙") or n.contains("亡灵") or n.contains("蝙蝠") or n.contains("凤凰") or n.contains("飞行机器") or n.contains("猎犬") or n.contains("幼犬"):
		return _dragon({})
	if n.contains("精灵"):
		return _spirit(Color(0.70, 0.60, 1.0))
	if n.contains("骷髅") or n.contains("骨"):
		return _humanoid({"height": 0.98, "body": KIT.COL_BONE, "skin": KIT.COL_BONE, "helmet": "skull", "pants": Color(0.28, 0.28, 0.32), "bare_arms": true})
	if n.contains("巨人") or n.contains("石人") or n.contains("戈仑") or n.contains("皮卡"):
		return _humanoid({"height": 1.52, "body": KIT.COL_SKIN_DARK, "helmet": "hair", "weapon": "club", "bare_arms": true, "head_scale": 0.84, "torso_scale": 1.24, "limb_scale": 1.28})
	if n.contains("法师") or n.contains("女巫") or n.contains("天使") or n.contains("女王"):
		return _humanoid({"height": 1.16, "body": Color(0.30, 0.32, 0.62), "robe": true, "helmet": "hood", "cloth": Color(0.26, 0.28, 0.56), "weapon": "staff", "glow": Color(0.70, 0.55, 1.0)})
	if n.contains("弓箭手") or n.contains("火枪手") or n.contains("公主") or n.contains("吹箭") or n.contains("炮手") or n.contains("猎人") or n.contains("游侠"):
		return _humanoid({"height": 1.08, "body": Color(0.28, 0.42, 0.34), "helmet": "hood", "cloth": Color(0.30, 0.42, 0.38), "weapon": "bow"})
	if n.contains("桶") or n.contains("滚木") or n.contains("滚桶"):
		return {"archetype": "barrel", "height": 0.70}
	return _humanoid({"height": 1.10, "body": team_ish})
