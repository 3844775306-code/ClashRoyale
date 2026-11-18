extends Control

const CVC = preload("res://scripts/visuals/CardVisualCatalog.gd")
const UMK = preload("res://scripts/visuals/UnitModelKit.gd")
const PK = preload("res://scripts/visuals/ProjectileKit.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

var cfg: CardData
var on_changed: Callable = Callable()
var _wild_spin: SpinBox
var _sub: SubViewport
var _model_root: Node3D
var _content: VBoxContainer
var _status: Label
var _spin: float = 0.0

const SPELL_PROJECTILES := {
	"火球": "fireball", "万箭齐发": "arrow", "电击法术": "lightning", "雷电法术": "lightning",
	"大雪球": "snowball", "滚木": "log", "野蛮人滚桶": "barb_barrel", "哥布林飞桶": "barrel",
	"火箭": "rocket", "毒药法术": "potion", "冰冻法术": "ice", "狂暴法术": "energy",
	"飓风法术": "energy", "藤蔓法术": "potion", "虚空法术": "plasma", "地震法术": "boulder",
	"哥布林魔咒": "potion", "皇家速递": "barrel", "克隆法术": "energy", "镜像法术": "energy",
}

static func open(parent: Control, card_config: CardData, changed: Callable = Callable()) -> void:
	var dlg = load("res://scripts/ui/CardDetailDialog.gd").new()
	parent.add_child(dlg)
	dlg._build(card_config, changed)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _build(card_config: CardData, changed: Callable) -> void:
	cfg = card_config
	on_changed = changed
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			queue_free()
	)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -356
	panel.offset_right = 356
	panel.offset_top = -456
	panel.offset_bottom = 456
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.13, 0.98)
	sb.border_color = ThemeHelper.COLORS.gold
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_top = 14
	vbox.offset_right = -18
	vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s  详情" % cfg.card_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	# 左侧 3D 模型
	var model_panel := PanelContainer.new()
	model_panel.custom_minimum_size = Vector2(300, 430)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.06, 0.05, 0.10)
	msb.set_corner_radius_all(12)
	model_panel.add_theme_stylebox_override("panel", msb)
	hbox.add_child(model_panel)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(292, 422)
	svc.gui_input.connect(_on_model_input)
	model_panel.add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(292, 422)
	_sub.transparent_bg = true
	_sub.own_world_3d = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)

	var cam := Camera3D.new()
	cam.current = true
	_sub.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-38), deg_to_rad(35), 0)
	light.light_energy = 1.25
	_sub.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-12), deg_to_rad(-120), 0)
	fill.light_energy = 0.55
	_sub.add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.95)
	env.ambient_light_energy = 0.65
	we.environment = env
	_sub.add_child(we)
	_model_root = Node3D.new()
	_sub.add_child(_model_root)
	_build_model(cam)

	# 右侧信息
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(340, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(340, 0)
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_build_info()

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.35))
	vbox.add_child(_status)

	var close := UiComponents.make_secondary_button("关闭", func(): queue_free(), Vector2(0, 48))
	vbox.add_child(close)

func _spell_kind() -> String:
	return String(SPELL_PROJECTILES.get(cfg.card_name, ""))

func _build_model(cam: Camera3D) -> void:
	var spell_kind := _spell_kind()
	if spell_kind != "":
		var proj: Node3D = PK.create(spell_kind)
		proj.scale = Vector3.ONE * 5.5
		_model_root.add_child(proj)
		cam.position = Vector3(0, 0.8, 2.6)
		cam.look_at(Vector3(0, 0.25, 0))
		_model_root.position.y = 0.45
		return
	var spec: Dictionary = CVC.spec_for(cfg.card_name, Config.Team.PLAYER, cfg.attack_range)
	var model: Node3D = UMK.create_unit(spec)
	_model_root.add_child(model)
	var h: float = float(spec.get("height", 1.0)) * 1.5 * float(spec.get("scale_mul", 1.0))
	var cam_h: float = maxf(h, 0.8)
	cam.position = Vector3(0, cam_h * 0.58, maxf(2.5, cam_h * 1.55))
	cam.look_at(Vector3(0, cam_h * 0.48, 0))
	_model_root.position.y = 0.0

func _on_model_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_spin += ev.relative.x * 0.02

func _process(delta: float) -> void:
	if _model_root:
		_model_root.rotation.y += delta * 0.55 + _spin
		_spin = 0.0

func _type_cn(v: int) -> String:
	match v:
		Config.UnitType.BUILDING: return "建筑"
		Config.UnitType.GROUND: return "地面单位"
		Config.UnitType.AIR: return "空中单位"
	return "未知"

func _target_cn(v: int) -> String:
	match v:
		Config.TargetType.ALL: return "所有目标（含空中）"
		Config.TargetType.GROUND_ONLY: return "仅地面"
		Config.TargetType.BUILDING_ONLY: return "仅建筑"
	return "未知"

func _attack_cn(v: int) -> String:
	match v:
		1: return "普通"
		2: return "电击"
		3: return "冰冻"
		4: return "灼烧"
		5: return "充能"
		7: return "诅咒"
	return "类型 %d" % v

func _move_cn(v: int) -> String:
	match v:
		1: return "步行"
		2: return "冲锋"
		3: return "跳跃"
		4: return "飞行"
		5: return "超级跳跃"
	return "方式 %d" % v

func _fmt_arr(arr: Array) -> String:
	if arr.is_empty():
		return "无"
	var parts: Array = []
	for v in arr:
		parts.append(str(v))
	return "、".join(parts)

func _icon_for_label(label: String) -> String:
	match label:
		"卡牌 ID": return "🆔"
		"稀有度": return "💎"
		"类型": return "🏷"
		"目标": return "🎯"
		"圣水": return "💧"
		"部署数量": return "👥"
		"生命": return "❤"
		"伤害": return "⚔"
		"攻击间隔": return "⏱"
		"DPS": return "📈"
		"攻击距离": return "📏"
		"溅射半径": return "💥"
		"移动速度": return "🏃"
		"移动方式": return "🚶"
		"视野": return "👁"
		"碰撞半径": return "⭕"
		"护盾": return "🛡"
		"攻击类型": return "✨"
		"解锁竞技场": return "🏟"
		"拥有数量": return "🃏"
	return "▸"

func _should_show_stat(value: String) -> bool:
	var s: String = value.strip_edges()
	if s == "" or s in ["—", "-", "无", "0", "0.0", "0 ms", "0 格", "0.0 格"]:
		return false
	if s.begins_with("0 →") or s.begins_with("0.0 ") or s.begins_with("0 "):
		return false
	return true

func _stat_row(label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var icon := Label.new()
	icon.text = _icon_for_label(label)
	icon.custom_minimum_size = Vector2(22, 0)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 13)
	row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(92, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.58, 0.64, 0.76))
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98))
	row.add_child(val_lbl)
	row.custom_minimum_size = Vector2(0, 22)
	return row

func _is_spell_like() -> bool:
	return cfg.attack_speed <= 0 and cfg.damage > 0.0 and cfg.damage_range > 0.0 and cfg.type != Config.UnitType.BUILDING

func _tip_for_card() -> String:
	var n := cfg.card_name
	var tips := {
		"火球": "对方后排聚集时再交火球，能同时打掉多个远程单位。",
		"万箭齐发": "留给骷髅军团、亡灵大军这类小费群体，别用来单解坦克。",
		"电击法术": "打断冲锋/蓄力单位，或收掉残血群体；不要空放。",
		"火箭": "优先砸采集器或高价值后排，命中 2 个以上才划算。",
		"滚木": "清理地面小费群体，也能把进攻单位推离塔。",
		"毒药法术": "放在对方防守建筑和后排之间，持续伤害比瞬间爆发更赚。",
		"冰冻法术": "配合野猪/气球使用，冻住塔和防守单位争取输出时间。",
		"狂暴法术": "放在己方推进单位身上，别丢在空地上。",
		"飓风法术": "把对方单位拉进塔和溅射范围，或拉开骷髅军团。",
		"克隆法术": "配合高血量推进单位，克隆体只继承部分生命，注意时机。",
		"镜像法术": "用来复制关键法术或制胜卡，费用会 +1。",
		"哥布林魔咒": "命中后死亡单位会变成哥布林，适合清理小费群体。",
		"地震法术": "克制建筑和地面群体，也能减速；对空无效。",
		"超级骑士": "跳劈落地有范围伤害，别让他一直追远程单位。",
		"皮卡超人": "高单体伤害，适合防守坦克；怕群体拉扯。",
		"迷你皮卡": "高 DPS 反坦，防守后可以桥头反打。",
		"野猪骑士": "只打建筑，桥头速攻或配合冰冻/地震。",
		"皇家野猪": "分路施压，逼对方分散防守。",
		"巨人": "坦克推进核心，先下巨人再跟后排。",
		"皇家巨人": "桥头远程磨塔，注意保护他别被近战贴脸。",
		"戈仑石人": "死亡分裂小石人，适合打一套重推进。",
		"气球兵": "只打建筑，配合冰冻/狂暴直取公主塔。",
		"熔岩猎犬": "空中坦克，死亡分裂小狗，配合空中后排。",
		"骷髅召唤": "在塔附近持续出兵，适合配合坦克或防守反击。",
		"骷髅军团": "围杀单体高伤单位，怕法术。",
		"亡灵": "低费空中群体，解地面单位或被法术吃。",
		"亡灵大军": "高 DPS 空中群体，别和万箭/火球硬拼。",
		"蝙蝠": "极低费空中骚扰，适合补刀和过牌。",
		"飞龙宝宝": "空中 AOE，解群体和后排都不错。",
		"地狱飞龙": "持续光束克坦克，但怕电击/冰冻打断。",
		"法师": "高 AOE 后排，放在坦克后面输出。",
		"火枪手": "稳定远程对空，防守后可以反打。",
		"弓箭手": "低费对空后排，分路放置能逼对方处理。",
		"女武神": "旋转 AOE 清地面群体，适合防守反击。",
		"骑士": "低费小坦克，拉扯和防守都灵活。",
		"野蛮人": "地面群体高 DPS，怕 AOE 法术。",
		"哥布林": "低费小费单位，适合过牌和围杀。",
		"哥布林团伙": "人海围杀，怕万箭/滚木。",
		"掘地矿工": "可钻到塔边消耗，配合小费单位拉扯。",
		"公主": "超远射程消耗，桥头放置能逼对方交法术。",
		"神箭游侠": "穿透箭可打后排，注意站位别被切。",
			}
	if tips.has(n):
		return tips[n]
	if cfg.type == Config.UnitType.BUILDING:
		return "建筑用来拉扯和防守，别贴公主塔放，避免被法术连带消耗。"
	if cfg.attack_speed <= 0 and cfg.cost>0:
		return "法术不要空放；等对方单位聚集或进入关键位置再交。"
	if cfg.type == Config.UnitType.AIR:
		return "空中单位怕对空火力和法术，进攻时先用坦克或地面单位吸引火力。"
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		return "只打建筑，适合桥头偷塔；需要法术或后排掩护。"
	if cfg.max_health >= 2500:
		return "坦克要先用其他单位吸收火力，再跟进后排输出。"
	if cfg.cost <= 2:
		return "低费卡主要用于过牌和拉扯，不要单独送进对方半场。"
	if cfg.attack_range >= 5:
		return "远程单位放塔后输出，前面需要有坦克或建筑保护。"
	return "先看清对方核心威胁，再决定这张卡是解场还是反打。"

func _build_info() -> void:
	for ch in _content.get_children():
		ch.queue_free()
	var level: int = PlayerData.get_card_level(cfg.card_id)
	var own: int = PlayerData.get_card_quantity(cfg.card_id)
	var need: int = PlayerData.calculate_upgrade_cards_needed(cfg.card_id, level)
	var cost_gold: int = PlayerData.calculate_upgrade_gold(cfg.card_id, level)
	var at_max: bool = level >= 16
	var cur_hp: float = cfg.max_health * Config.level_mult(level)
	var cur_dmg: float = cfg.damage * Config.level_mult(level)
	var next_hp: float = cfg.max_health * Config.level_mult(level + 1)
	var next_dmg: float = cfg.damage * Config.level_mult(level + 1)

	var head := Label.new()
	head.text = "%s  Lv.%d" % [cfg.card_name, level]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	_content.add_child(head)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	var cost_txt := "💧 ?" if cfg.card_id == 123 else "💧 %d" % cfg.cost
	chips.add_child(_chip(cost_txt, Color(0.72, 0.52, 1.0)))
	chips.add_child(_chip("Lv.%d" % level, ThemeHelper.COLORS.gold))
	chips.add_child(_chip(CARD_RARITY.rarity_cn_by_id(cfg.card_id), CARD_RARITY.rarity_color_by_id(cfg.card_id)))
	if cfg.max_health > 0.0:
		chips.add_child(_chip("❤ %.0f" % cur_hp, Color(0.95, 0.45, 0.45)))
	_content.add_child(chips)

	var attr_head := Label.new()
	attr_head.text = "▎完整属性"
	attr_head.add_theme_font_size_override("font_size", 16)
	attr_head.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_content.add_child(attr_head)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 2)
	_content.add_child(grid)
	var dps: float = 0.0
	if cfg.attack_speed > 0:
		dps = cfg.damage / (float(cfg.attack_speed) / 1000.0) * float(cfg.num)
	var rows: Array = [
		["卡牌 ID", str(cfg.card_id)],
		["稀有度", CARD_RARITY.rarity_cn_by_id(cfg.card_id)],
		["类型", "法术" if _is_spell_like() else _type_cn(cfg.type)],
		["目标", _target_cn(cfg.target_type)],
		["圣水", "💧 %d" % cfg.cost],
		["部署数量", str(cfg.num)],
		["生命", "%.0f → %.0f" % [cur_hp, next_hp]],
		["伤害", "%.0f → %.0f" % [cur_dmg, next_dmg]],
		["攻击间隔", "—" if cfg.attack_speed <= 0 else "%d ms" % cfg.attack_speed],
		["DPS", "%.0f" % dps if dps > 0.0 else "—"],
		["攻击距离", "%.1f 格" % cfg.attack_range],
		["溅射半径", "%.1f 格" % cfg.damage_range],
		["移动速度", "—" if cfg.move_speed <= 0 else "%.1f 格/秒" % (cfg.move_speed / 24.0)],
		["移动方式", "—" if cfg.move_type <= 0 else _move_cn(cfg.move_type)],
		["视野", "%.1f 格" % cfg.horizon],
		["碰撞半径", "%.2f" % cfg.size],
		["护盾", "攻击即死" if cfg.shield < 0 else ("%.0f" % cfg.shield if cfg.shield > 0.0 else "无")],
		["攻击类型", "法术" if _is_spell_like() else _attack_cn(cfg.attack_type)],
		["解锁竞技场", PlayerData.card_unlock_arena_name(cfg.card_id)],
		["拥有数量", "%d 张" % own],
	]
	for r in rows:
		if not _should_show_stat(String(r[1])):
			continue
		grid.add_child(_stat_row(String(r[0]), String(r[1])))
	var extra_parts: Array = []
	if not cfg.extra_spell.is_empty():
		extra_parts.append("附加效果：%s" % _fmt_arr(cfg.extra_spell))
	if not cfg.spawn_unit.is_empty():
		extra_parts.append("持续召唤：%s" % _fmt_arr(cfg.spawn_unit))
	if not cfg.multiple_targets.is_empty():
		extra_parts.append("多目标：%s" % _fmt_arr(cfg.multiple_targets))
	if not cfg.multiple_process.is_empty():
		extra_parts.append("多段处理：%s" % _fmt_arr(cfg.multiple_process))
	if cfg.base_health > 0.0 or cfg.base_damage > 0.0:
		extra_parts.append("养成基础：生命 %.0f（×%.2f）/ 伤害 %.0f（×%.2f）" % [cfg.base_health, cfg.health_growth, cfg.base_damage, cfg.damage_growth])
	if not extra_parts.is_empty():
		var extra := Label.new()
		extra.text = "⚙ 特殊机制：\n" + "\n".join(extra_parts)
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		extra.add_theme_font_size_override("font_size", 13)
		extra.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(extra)

	var sep := HSeparator.new()
	_content.add_child(sep)
	var up_lbl := Label.new()
	up_lbl.add_theme_font_size_override("font_size", 14)
	up_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.92))
	var owned: bool = PlayerData.is_card_owned(cfg.card_id)
	if not owned:
		up_lbl.text = "🔒 尚未获得该卡 · 解锁于 %s" % PlayerData.card_unlock_arena_name(cfg.card_id)
	elif at_max:
		up_lbl.text = "已满级"
	else:
		up_lbl.text = "升级需要：%d 张卡 + %d 金币（拥有 %d 张 / %d 金币）" % [need, cost_gold, own, PlayerData.gold]
	_content.add_child(up_lbl)

	var up_btn := UiComponents.make_primary_button("升级", _on_upgrade, Vector2(0, 52))
	up_btn.disabled = (not owned) or at_max or own < need or PlayerData.gold < cost_gold
	_content.add_child(up_btn)

	var tip_panel := PanelContainer.new()
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.10, 0.20, 0.14, 0.85)
	tip_sb.border_color = Color(0.42, 0.82, 0.48)
	tip_sb.set_border_width_all(1)
	tip_sb.set_corner_radius_all(10)
	tip_sb.content_margin_left = 12
	tip_sb.content_margin_right = 12
	tip_sb.content_margin_top = 8
	tip_sb.content_margin_bottom = 8
	tip_panel.add_theme_stylebox_override("panel", tip_sb)
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 4)
	tip_panel.add_child(tip_box)
	var tip_title := Label.new()
	tip_title.text = "💡 一局小提示"
	tip_title.add_theme_font_size_override("font_size", 15)
	tip_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	tip_box.add_child(tip_title)
	var tip_lbl := Label.new()
	tip_lbl.text = _tip_for_card()
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.add_theme_font_size_override("font_size", 14)
	tip_lbl.add_theme_color_override("font_color", Color(0.88, 0.95, 0.90))
	tip_box.add_child(tip_lbl)
	_content.add_child(tip_panel)

	var wild_n: int = PlayerData.get_wildcard_for_card(cfg.card_id)
	var wild_head := Label.new()
	wild_head.text = "🃏 万能卡库存：%d 张（%s）" % [wild_n, CARD_RARITY.rarity_cn_by_id(cfg.card_id)]
	wild_head.add_theme_font_size_override("font_size", 14)
	wild_head.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	_content.add_child(wild_head)
	var wild_row := HBoxContainer.new()
	wild_row.add_theme_constant_override("separation", 8)
	_content.add_child(wild_row)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(44, 46)
	minus.add_theme_font_size_override("font_size", 20)
	ThemeHelper.apply_card_button_style(minus)
	wild_row.add_child(minus)
	_wild_spin = SpinBox.new()
	_wild_spin.min_value = 1
	_wild_spin.max_value = maxf(1.0, float(wild_n))
	_wild_spin.step = 1
	_wild_spin.value = 1
	_wild_spin.custom_minimum_size = Vector2(120, 46)
	_wild_spin.add_theme_font_size_override("font_size", 18)
	wild_row.add_child(_wild_spin)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(44, 46)
	plus.add_theme_font_size_override("font_size", 20)
	ThemeHelper.apply_card_button_style(plus)
	wild_row.add_child(plus)
	minus.pressed.connect(func(): _wild_spin.value = maxf(1.0, _wild_spin.value - 1))
	plus.pressed.connect(func(): _wild_spin.value = minf(float(wild_n), _wild_spin.value + 1))
	var wild_btn := Button.new()
	wild_btn.text = "🃏 使用万能卡增加卡牌数量"
	wild_btn.custom_minimum_size = Vector2(0, 48)
	wild_btn.add_theme_font_size_override("font_size", 16)
	ThemeHelper.apply_card_button_style(wild_btn)
	wild_btn.disabled = (not owned) or wild_n <= 0
	wild_btn.pressed.connect(_on_use_wildcard)
	_content.add_child(wild_btn)

func _chip(text: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	sb.border_color = accent
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", accent.lightened(0.2))
	p.add_child(l)
	return p

func _on_use_wildcard() -> void:
	var n: int = int(_wild_spin.value) if _wild_spin else 1
	if PlayerData.use_wildcard_on_card(cfg.card_id, n):
		_status.text = "已使用 %d 张万能卡，卡牌数量 +%d" % [n, n]
		if on_changed.is_valid():
			on_changed.call(cfg.card_id)
		_build_info()
	else:
		_status.text = "万能卡不足或没有匹配稀有度"

func _on_upgrade() -> void:
	if PlayerData.upgrade_card(cfg.card_id):
		_status.text = "升级成功！"
		if on_changed.is_valid():
			on_changed.call(cfg.card_id)
		_build_info()
	else:
		_status.text = "升级失败：金币或卡牌不足"
