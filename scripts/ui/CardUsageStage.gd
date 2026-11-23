# scripts/ui/CardUsageStage.gd
# 卡牌详情「玩法」页的微战场实战演示：小窗口 + 卡牌/单位居中 + 优势/被克制两段
extends Control

const CVC = preload("res://scripts/visuals/CardVisualCatalog.gd")
const UMK = preload("res://scripts/visuals/UnitModelKit.gd")
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const MUTED := Color(0.630, 0.680, 0.795)
const PARCHMENT := Color(0.930, 0.895, 0.790)

var card_name := ""
var card = null
var _font: Font
var _sub: SubViewport
var _world: Node3D
var _actors: Node3D
var _caption: Label
var _card_focus: TextureRect
var _tag: Label
var _btn_adv: Button
var _btn_weak: Button
var _selected := 0
var _gen := 0


func setup(name: String, config = null) -> void:
	card_name = name
	card = config


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	custom_minimum_size = Vector2(0, 390)
	_build()


func _build() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.030, 0.045, 0.090, 0.98)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.62)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := _label("实战演示", 17, GOLD_LIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_btn_adv = _tab_btn("优势 · 克制")
	_btn_weak = _tab_btn("劣势 · 被克制")
	head.add_child(_btn_adv)
	head.add_child(_btn_weak)
	_btn_adv.pressed.connect(func(): _select(0))
	_btn_weak.pressed.connect(func(): _select(1))

	var stage_frame := Panel.new()
	stage_frame.custom_minimum_size = Vector2(0, 286)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.010, 0.020, 0.050, 1.0)
	fsb.set_corner_radius_all(13)
	fsb.set_border_width_all(1)
	fsb.border_color = Color(1, 1, 1, 0.10)
	stage_frame.add_theme_stylebox_override("panel", fsb)
	v.add_child(stage_frame)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	stage_frame.add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(700, 286)
	_sub.transparent_bg = false
	_sub.own_world_3d = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)
	_build_world()
	_card_focus = TextureRect.new()
	_card_focus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_focus.offset_left = -48
	_card_focus.offset_right = 48
	_card_focus.offset_top = -58
	_card_focus.offset_bottom = 58
	_card_focus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_focus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_focus.pivot_offset = Vector2(48, 58)
	var art_path := "res://assets/cards_web/%s.png" % card_name
	if not ResourceLoader.exists(art_path):
		art_path = "res://assets/cards_rendered/%s.png" % card_name
	if ResourceLoader.exists(art_path):
		_card_focus.texture = load(art_path)
	stage_frame.add_child(_card_focus)

	_tag = _label("", 12, Color(0.62, 0.86, 0.64))
	v.add_child(_tag)
	_caption = _label("", 12, MUTED)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(0, 38)
	v.add_child(_caption)
	_style_tabs()
	_select(0)


func _build_world() -> void:
	_world = Node3D.new()
	_sub.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.018, 0.040, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.78, 0.92)
	e.ambient_light_energy = 0.8
	env.environment = e
	_world.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.6, 6.6)
	cam.fov = 46.0
	cam.current = true
	_world.add_child(cam)
	cam.look_at(Vector3(0, 0.65, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 1.15
	light.shadow_enabled = false
	_world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 145, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.55, 0.72, 1.0)
	_world.add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(11, 7)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.24, 0.12)
	gm.roughness = 1.0
	ground.material_override = gm
	_world.add_child(ground)
	# 场地金线
	for z in [-2.0, 0.0, 2.0]:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(9.6, 0.018, 0.035)
		line.mesh = bm
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(0.88, 0.72, 0.36, 0.36)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = lm
		line.position = Vector3(0, 0.012, z)
		_world.add_child(line)
	_actors = Node3D.new()
	_world.add_child(_actors)


func _select(i: int) -> void:
	_selected = i
	_style_tabs()
	_run_clip()


func _style_tabs() -> void:
	for i in range(2):
		var b: Button = _btn_adv if i == 0 else _btn_weak
		var active: bool = i == _selected
		b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02) if active else PARCHMENT)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(1)
		sb.bg_color = Color(0.93, 0.71, 0.28) if active else Color(0.06, 0.09, 0.16, 0.95)
		sb.border_color = Color(1.0, 0.90, 0.60) if active else Color(1, 1, 1, 0.12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _run_clip() -> void:
	_gen += 1
	var g := _gen
	for c in _actors.get_children():
		c.queue_free()
	_actors.position = Vector3.ZERO
	var name := card_name
	_show_card_focus()
	if name == "法师":
		if _selected == 0:
			_tag.text = "优势 · 范围伤害清理人海"
			_caption.text = "法师的火焰能一次打掉聚集的小费群体，适合在坦克后面输出。"
			await _wizard_advantage(g)
		else:
			_tag.text = "劣势 · 被高血量近战贴脸"
			_caption.text = "法师血量低，被皮卡超人这类高血量近战突进后很难活下来。"
			await _wizard_weakness(g)
	elif name == "万箭齐发":
		if _selected == 0:
			_tag.text = "优势 · 低费清理人海"
			_caption.text = "万箭齐发覆盖范围大，能一次清掉骷髅军团/亡灵这类低血量群体。"
			await _arrows_advantage(g)
		else:
			_tag.text = "劣势 · 对高血量单体乏力"
			_caption.text = "面对皮卡超人等高血量单位，箭雨只能造成有限伤害。"
			await _arrows_weakness(g)
	elif name == "野猪骑士":
		if _selected == 0:
			_tag.text = "优势 · 只打建筑，直取核心"
			_caption.text = "野猪骑士会绕过防守单位直冲公主塔，适合快速偷塔。"
			await _hog_advantage(g)
		else:
			_tag.text = "劣势 · 被人海围杀"
			_caption.text = "没有法术掩护时，骷髅军团能把野猪骑士围住并拖住输出。"
			await _hog_weakness(g)
	else:
		if _selected == 0:
			_tag.text = "优势 · %s" % _generic_strength_tag()
			_caption.text = _generic_strength_caption()
			await _generic_advantage(g)
		else:
			_tag.text = "劣势 · %s" % _generic_weakness_tag()
			_caption.text = _generic_weakness_caption()
			await _generic_weakness(g)


func _show_card_focus() -> void:
	if _card_focus == null or _card_focus.texture == null:
		return
	_card_focus.visible = true
	_card_focus.modulate.a = 1.0
	_card_focus.scale = Vector2(1.0, 1.0)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_card_focus, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(_card_focus):
			_card_focus.visible = false)


func _wizard_advantage(g: int) -> void:
	var wizard := _spawn("法师", 0, Vector3(-1.8, 0, 0), 1.0)
	var skels: Array = []
	for i in range(6):
		var pos := Vector3(2.0, 0, -1.4 + i * 0.56)
		skels.append(_spawn("骷髅兵", 1, pos, 0.9))
	if not await _wait(g, 0.25): return
	for i in range(skels.size()):
		_move(skels[i], Vector3(0.2 + (i % 2) * 0.45, 0, -0.7 + (i / 3) * 0.5), 1.0 + i * 0.03)
	if not await _wait(g, 0.55): return
	_projectile(wizard.global_position + Vector3(0, 1.1, 0), Vector3(0.5, 0.6, -0.5), Color(1.0, 0.42, 0.12), 0.38)
	if not await _wait(g, 0.42): return
	_burst(Vector3(0.5, 0.5, -0.5), Color(1.0, 0.45, 0.12))
	_damage(Vector3(0.5, 1.1, -0.5), "-160", Color(1.0, 0.55, 0.25))
	for i in range(3):
		_defeat(skels[i])
	if not await _wait(g, 0.45): return
	_projectile(wizard.global_position + Vector3(0, 1.1, 0), Vector3(1.0, 0.5, 0.7), Color(1.0, 0.42, 0.12), 0.34)
	if not await _wait(g, 0.38): return
	_burst(Vector3(1.0, 0.5, 0.7), Color(1.0, 0.45, 0.12))
	for i in range(3, 6):
		_defeat(skels[i])
	if not await _wait(g, 0.7): return
	if g == _gen:
		_run_clip()


func _wizard_weakness(g: int) -> void:
	var wizard := _spawn("法师", 0, Vector3(-0.8, 0, 0), 1.0)
	var pekka := _spawn("皮卡超人", 1, Vector3(3.0, 0, 0), 1.0)
	if not await _wait(g, 0.25): return
	_move(pekka, Vector3(0.4, 0, 0), 1.45)
	if not await _wait(g, 0.55): return
	_projectile(wizard.global_position + Vector3(0, 1.1, 0), pekka.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.42, 0.12), 0.30)
	if not await _wait(g, 0.35): return
	_burst(pekka.global_position + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.12))
	_damage(pekka.global_position + Vector3(0, 1.5, 0), "-230", Color(1.0, 0.55, 0.25))
	if not await _wait(g, 0.5): return
	_attack_swing(pekka)
	if not await _wait(g, 0.18): return
	_defeat(wizard)
	if not await _wait(g, 1.1): return
	if g == _gen:
		_run_clip()


func _arrows_advantage(g: int) -> void:
	var skels: Array = []
	for i in range(6):
		var pos := Vector3(-1.0 + (i % 3) * 0.85, 0, -0.8 + (i / 3) * 0.8)
		skels.append(_spawn("骷髅兵", 1, pos, 0.9))
	if not await _wait(g, 0.35): return
	for i in range(6):
		var target: Vector3 = skels[i].global_position
		_projectile(Vector3(target.x, 4.2, target.z), target + Vector3(0, 0.35, 0), Color(0.95, 0.92, 0.68), 0.28 + i * 0.025, true)
	if not await _wait(g, 0.65): return
	for i in range(6):
		_burst(skels[i].global_position + Vector3(0, 0.35, 0), Color(0.95, 0.84, 0.48))
		_defeat(skels[i])
	if not await _wait(g, 1.0): return
	if g == _gen:
		_run_clip()


func _arrows_weakness(g: int) -> void:
	var pekka := _spawn("皮卡超人", 1, Vector3(0, 0, 0), 1.0)
	if not await _wait(g, 0.35): return
	for i in range(4):
		var off := Vector3(-0.45 + (i % 2) * 0.9, 0, -0.45 + (i / 2) * 0.9)
		_projectile(Vector3(off.x, 4.2, off.z), pekka.global_position + Vector3(off.x, 0.9, off.z), Color(0.95, 0.92, 0.68), 0.35 + i * 0.02, true)
	if not await _wait(g, 0.65): return
	for i in range(4):
		_burst(pekka.global_position + Vector3(0, 0.9, 0), Color(0.95, 0.84, 0.48))
	_damage(pekka.global_position + Vector3(0, 1.8, 0), "-18", Color(0.98, 0.82, 0.52))
	_attack_swing(pekka)
	if not await _wait(g, 1.1): return
	if g == _gen:
		_run_clip()


func _hog_advantage(g: int) -> void:
	var tower := _spawn("公主塔", 1, Vector3(2.1, 0, 0), 0.9)
	var hog := _spawn("野猪骑士", 0, Vector3(-2.5, 0, 0), 1.0)
	if not await _wait(g, 0.25): return
	_move(hog, Vector3(1.15, 0, 0), 1.25)
	if not await _wait(g, 1.25): return
	for i in range(3):
		_attack_swing(hog)
		_damage(tower.global_position + Vector3(0, 1.6, 0), "-160", Color(1.0, 0.55, 0.25))
		_shake(tower)
		if not await _wait(g, 0.42): return
	if not await _wait(g, 0.8): return
	if g == _gen:
		_run_clip()


func _hog_weakness(g: int) -> void:
	var hog := _spawn("野猪骑士", 0, Vector3(0, 0, 0), 1.0)
	var skels: Array = []
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		skels.append(_spawn("骷髅兵", 1, Vector3(cos(ang) * 2.2, 0, sin(ang) * 1.5), 0.9))
	if not await _wait(g, 0.25): return
	for s in skels:
		_move(s, hog.global_position + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.35, 0.35)), 0.9)
	if not await _wait(g, 1.0): return
	_attack_swing(hog)
	_damage(hog.global_position + Vector3(0, 1.5, 0), "-35", Color(1.0, 0.55, 0.25))
	if not await _wait(g, 0.6): return
	_defeat(hog)
	if not await _wait(g, 1.1): return
	if g == _gen:
		_run_clip()



# ==================== 通用标签模板 ====================
func _is_spell() -> bool:
	if card != null:
		return int(card.attack_speed) <= 0 and int(card.type) != 1
	return card_name.contains("法术") or card_name.contains("箭") or card_name.contains("火球") or card_name.contains("火箭") or card_name.contains("滚木") or card_name.contains("毒药") or card_name.contains("冰冻") or card_name.contains("狂暴") or card_name.contains("飓风") or card_name.contains("克隆") or card_name.contains("镜像") or card_name.contains("地震")

func _is_air() -> bool:
	if card != null:
		return int(card.type) == 3
	return card_name.contains("亡灵") or card_name.contains("蝙蝠") or card_name.contains("飞龙") or card_name.contains("气球") or card_name.contains("猎犬") or card_name.contains("天使") or card_name.contains("凤凰")

func _is_building() -> bool:
	if card != null:
		return int(card.type) == 1
	return card_name.contains("塔") or card_name.contains("建筑") or card_name.contains("采集器") or card_name.contains("炸弹塔") or card_name.contains("墓碑") or card_name.contains("熔炉")

func _is_building_only() -> bool:
	if card != null:
		return int(card.target_type) == 1
	return card_name in ["野猪骑士", "皇家野猪", "气球兵", "巨人", "皇家巨人", "戈仑石人", "熔岩猎犬", "掘地矿工"]

func _is_splash() -> bool:
	if card != null:
		return float(card.damage_range) > 0.5
	return card_name in ["法师", "女武神", "飞龙宝宝", "地狱飞龙", "超级骑士", "炸弹人", "滚木", "火球", "万箭齐发", "雷电法术", "大雪球", "火箭", "毒药法术", "地震法术"]

func _is_ranged() -> bool:
	if card != null:
		return float(card.attack_range) >= 5.0 and float(card.attack_speed) > 0.0
	return card_name in ["法师", "火枪手", "弓箭手", "公主", "神箭游侠", "吹箭哥布林", "猎人", "炮手"]

func _is_tank() -> bool:
	if card != null:
		return float(card.max_health) >= 2500.0
	return card_name in ["巨人", "皇家巨人", "戈仑石人", "熔岩猎犬", "皮卡超人", "超级骑士", "骷髅巨人", "熔岩猎犬"]

func _is_swarm() -> bool:
	if card != null:
		return int(card.num) >= 3
	return card_name.contains("军团") or card_name.contains("团伙") or card_name.contains("亡灵") or card_name.contains("蝙蝠") or card_name.contains("哥布林")

func _card_name() -> String:
	if card != null:
		return String(card.card_name)
	return card_name

func _generic_strength_tag() -> String:
	if _is_spell(): return "范围/解场"
	if _is_building(): return "持续防守"
	if _is_air(): return "空中优势"
	if _is_tank(): return "吸收火力"
	if _is_building_only(): return "直取建筑"
	if _is_splash(): return "清理人海"
	if _is_swarm(): return "围杀单体"
	if _is_ranged(): return "远程消耗"
	return "单挑/防守"

func _generic_weakness_tag() -> String:
	if _is_spell(): return "高血量单体"
	if _is_building(): return "被法术拆除"
	if _is_air(): return "怕对空火力"
	if _is_tank(): return "怕人海围杀"
	if _is_building_only(): return "怕拉扯人海"
	if _is_splash(): return "怕高血量近战"
	if _is_swarm(): return "怕范围法术"
	if _is_ranged(): return "怕近身突袭"
	return "怕更强单体"

func _generic_strength_caption() -> String:
	if _is_spell(): return "这张法术适合处理聚集的低血量单位或关键建筑；等对方站位集中再交，收益更高。"
	if _is_building(): return "建筑可以持续输出并拉扯进攻单位，为塔和后排争取时间。"
	if _is_air(): return "空中单位让多数地面近战无法还手，可以安全输出；先解决对空火力。"
	if _is_tank(): return "高血量坦克可以吸收火力，掩护后排推进；先下坦克再跟输出。"
	if _is_building_only(): return "只打建筑的单位会绕过防守直取公主塔，适合桥头速攻。"
	if _is_splash(): return "范围伤害能一次清理聚集的小费群体，是防守人海的关键。"
	if _is_swarm(): return "人海单位可以围杀单体高伤目标，逼对方交法术。"
	if _is_ranged(): return "远程单位在塔后稳定输出，前面有坦克或建筑保护时更强。"
	return "这张卡适合防守反击，利用存活单位桥头反打。"

func _generic_weakness_caption() -> String:
	if _is_spell(): return "面对高血量单体，法术伤害有限；空放还会亏费。"
	if _is_building(): return "建筑会被火球/火箭等法术直接拆除，注意不要和塔贴太近。"
	if _is_air(): return "对空远程和法术能快速处理空中单位，别在没有掩护时单独进攻。"
	if _is_tank(): return "坦克怕人海围杀和高 DPS 单体，需要法术或后排掩护。"
	if _is_building_only(): return "拉扯建筑或人海能让只打建筑的单位偏离目标，拖住进攻。"
	if _is_splash(): return "范围单位通常单体 DPS 不高，被皮卡超人这类高血量近战贴脸会很难受。"
	if _is_swarm(): return "人海最怕范围法术；分散站位可以降低被一发清场的风险。"
	if _is_ranged(): return "远程单位血量低，被矿工/皮卡等近身突袭时容易阵亡。"
	return "被更强单体或人海围杀时，这张卡很难发挥。"

func _generic_advantage(g: int) -> void:
	if _is_spell():
		await _generic_spell(g, true)
	elif _is_building():
		await _generic_building(g, true)
	elif _is_air():
		await _generic_air(g, true)
	elif _is_tank():
		await _generic_tank(g, true)
	elif _is_building_only():
		await _generic_building_only(g, true)
	elif _is_splash():
		await _generic_splash(g, true)
	elif _is_swarm():
		await _generic_swarm(g, true)
	elif _is_ranged():
		await _generic_ranged(g, true)
	else:
		await _generic_duel(g, true)

func _generic_weakness(g: int) -> void:
	if _is_spell():
		await _generic_spell(g, false)
	elif _is_building():
		await _generic_building(g, false)
	elif _is_air():
		await _generic_air(g, false)
	elif _is_tank():
		await _generic_tank(g, false)
	elif _is_building_only():
		await _generic_building_only(g, false)
	elif _is_splash():
		await _generic_splash(g, false)
	elif _is_swarm():
		await _generic_swarm(g, false)
	elif _is_ranged():
		await _generic_ranged(g, false)
	else:
		await _generic_duel(g, false)

func _generic_spell(g: int, good: bool) -> void:
	if good:
		var skels: Array = []
		for i in range(6):
			skels.append(_spawn("骷髅兵", 1, Vector3(-1.0 + (i % 3) * 0.85, 0, -0.8 + (i / 3) * 0.8), 0.9))
		if not await _wait(g, 0.35): return
		_projectile(Vector3(0, 4.0, 0), Vector3(0, 0.4, 0), Color(0.95, 0.78, 0.42), 0.45)
		if not await _wait(g, 0.45): return
		_burst(Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.20))
		for s in skels: _defeat(s)
		if not await _wait(g, 1.0): return
	else:
		var pekka := _spawn("皮卡超人", 1, Vector3(0, 0, 0), 1.0)
		if not await _wait(g, 0.35): return
		_projectile(Vector3(0, 4.0, 0), pekka.global_position + Vector3(0, 0.8, 0), Color(0.95, 0.78, 0.42), 0.45)
		if not await _wait(g, 0.45): return
		_burst(pekka.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.20))
		_damage(pekka.global_position + Vector3(0, 1.7, 0), "-40", Color(0.98, 0.82, 0.52))
		_attack_swing(pekka)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_building(g: int, good: bool) -> void:
	var building := _spawn(_card_name(), 0, Vector3(1.9, 0, 0), 0.95)
	if good:
		var knight := _spawn("骑士", 1, Vector3(-2.5, 0, 0), 1.0)
		if not await _wait(g, 0.25): return
		_move(knight, Vector3(0.8, 0, 0), 1.2)
		if not await _wait(g, 0.8): return
		_projectile(building.global_position + Vector3(0, 1.0, 0), knight.global_position + Vector3(0, 0.7, 0), Color(0.70, 0.86, 1.0), 0.3)
		if not await _wait(g, 0.35): return
		_burst(knight.global_position + Vector3(0, 0.6, 0), Color(0.70, 0.86, 1.0))
		_defeat(knight)
		if not await _wait(g, 0.9): return
	else:
		_move(building, Vector3(0.6, 0, 0), 0.0)
		if not await _wait(g, 0.3): return
		_burst(building.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.45, 0.15))
		_defeat(building)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_air(g: int, good: bool) -> void:
	var air := _spawn(_card_name(), 0, Vector3(-0.8, 0.8, 0), 0.9)
	if good:
		var knight := _spawn("骑士", 1, Vector3(2.2, 0, 0), 1.0)
		_move(knight, Vector3(0.4, 0, 0), 1.0)
		if not await _wait(g, 0.6): return
		_projectile(air.global_position + Vector3(0, 0.8, 0), knight.global_position + Vector3(0, 0.7, 0), Color(0.65, 0.85, 1.0), 0.3)
		if not await _wait(g, 0.35): return
		_burst(knight.global_position + Vector3(0, 0.6, 0), Color(0.65, 0.85, 1.0))
		_defeat(knight)
		if not await _wait(g, 0.9): return
	else:
		var archer := _spawn("火枪手", 1, Vector3(2.0, 0, 0), 1.0)
		if not await _wait(g, 0.3): return
		_projectile(archer.global_position + Vector3(0, 1.1, 0), air.global_position + Vector3(0, 0.5, 0), Color(0.9, 0.8, 0.5), 0.35)
		if not await _wait(g, 0.4): return
		_burst(air.global_position + Vector3(0, 0.5, 0), Color(0.9, 0.8, 0.5))
		_defeat(air)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_tank(g: int, good: bool) -> void:
	var tank := _spawn(_card_name(), 0, Vector3(-1.0, 0, 0), 1.0)
	if good:
		var tower := _spawn("公主塔", 1, Vector3(2.0, 0, 0), 0.9)
		_move(tank, Vector3(1.1, 0, 0), 1.1)
		if not await _wait(g, 1.1): return
		_attack_swing(tank)
		_damage(tower.global_position + Vector3(0, 1.6, 0), "-200", Color(1.0, 0.55, 0.25))
		_shake(tower)
		if not await _wait(g, 1.0): return
	else:
		var skels: Array = []
		for i in range(6):
			var ang := TAU * float(i) / 6.0
			skels.append(_spawn("骷髅兵", 1, Vector3(cos(ang) * 2.2, 0, sin(ang) * 1.5), 0.9))
		if not await _wait(g, 0.2): return
		for s in skels: _move(s, tank.global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.4, 0.4)), 0.8)
		if not await _wait(g, 1.0): return
		_defeat(tank)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_building_only(g: int, good: bool) -> void:
	var unit := _spawn(_card_name(), 0, Vector3(-1.8, 0, 0), 1.0)
	if good:
		var tower := _spawn("公主塔", 1, Vector3(2.0, 0, 0), 0.9)
		_move(unit, Vector3(1.0, 0, 0), 1.2)
		if not await _wait(g, 1.2): return
		_attack_swing(unit)
		_damage(tower.global_position + Vector3(0, 1.6, 0), "-180", Color(1.0, 0.55, 0.25))
		_shake(tower)
		if not await _wait(g, 1.0): return
	else:
		var skels: Array = []
		for i in range(5):
			var ang := TAU * float(i) / 5.0
			skels.append(_spawn("骷髅兵", 1, Vector3(cos(ang) * 2.0, 0, sin(ang) * 1.4), 0.9))
		if not await _wait(g, 0.25): return
		for s in skels: _move(s, unit.global_position + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.35, 0.35)), 0.8)
		if not await _wait(g, 1.0): return
		_defeat(unit)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_splash(g: int, good: bool) -> void:
	var unit := _spawn(_card_name(), 0, Vector3(-1.6, 0, 0), 1.0)
	if good:
		var skels: Array = []
		for i in range(6):
			skels.append(_spawn("骷髅兵", 1, Vector3(0.8 + (i % 3) * 0.45, 0, -0.8 + (i / 3) * 0.8), 0.9))
		if not await _wait(g, 0.3): return
		_projectile(unit.global_position + Vector3(0, 1.1, 0), Vector3(1.3, 0.5, 0.0), Color(1.0, 0.50, 0.15), 0.35)
		if not await _wait(g, 0.4): return
		_burst(Vector3(1.3, 0.5, 0.0), Color(1.0, 0.55, 0.2))
		for s in skels: _defeat(s)
		if not await _wait(g, 1.0): return
	else:
		var pekka := _spawn("皮卡超人", 1, Vector3(2.8, 0, 0), 1.0)
		_move(pekka, Vector3(0.2, 0, 0), 1.2)
		if not await _wait(g, 1.2): return
		_attack_swing(pekka)
		_defeat(unit)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_swarm(g: int, good: bool) -> void:
	var swarm: Array = []
	var n: int = 4 if card == null else clampi(int(card.num), 3, 6)
	for i in range(n):
		swarm.append(_spawn(_card_name(), 0, Vector3(-1.8 + (i % 2) * 0.55, 0, -0.8 + (i / 2) * 0.6), 0.85))
	if good:
		var pekka := _spawn("皮卡超人", 1, Vector3(2.0, 0, 0), 1.0)
		if not await _wait(g, 0.2): return
		for s in swarm: _move(s, pekka.global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.4, 0.4)), 0.9)
		if not await _wait(g, 1.0): return
		_defeat(pekka)
		if not await _wait(g, 1.0): return
	else:
		var mage := _spawn("法师", 1, Vector3(2.0, 0, 0), 1.0)
		if not await _wait(g, 0.35): return
		_projectile(mage.global_position + Vector3(0, 1.1, 0), Vector3(0.0, 0.4, 0.0), Color(1.0, 0.5, 0.2), 0.4)
		if not await _wait(g, 0.45): return
		_burst(Vector3(0.0, 0.4, 0.0), Color(1.0, 0.55, 0.2))
		for s in swarm: _defeat(s)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_ranged(g: int, good: bool) -> void:
	var ranged := _spawn(_card_name(), 0, Vector3(-1.6, 0, 0), 1.0)
	if good:
		var knight := _spawn("骑士", 1, Vector3(2.6, 0, 0), 1.0)
		_move(knight, Vector3(0.6, 0, 0), 1.2)
		if not await _wait(g, 0.5): return
		for i in range(2):
			_projectile(ranged.global_position + Vector3(0, 1.1, 0), knight.global_position + Vector3(0, 0.7, 0), Color(0.9, 0.8, 0.5), 0.35)
			if not await _wait(g, 0.45): return
		_burst(knight.global_position + Vector3(0, 0.6, 0), Color(0.9, 0.8, 0.5))
		_defeat(knight)
		if not await _wait(g, 1.0): return
	else:
		var pekka := _spawn("皮卡超人", 1, Vector3(3.0, 0, 0), 1.0)
		_move(pekka, Vector3(0.2, 0, 0), 1.3)
		if not await _wait(g, 1.3): return
		_attack_swing(pekka)
		_defeat(ranged)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

func _generic_duel(g: int, good: bool) -> void:
	var unit := _spawn(_card_name(), 0, Vector3(-1.0, 0, 0), 1.0)
	var enemy := _spawn("骷髅兵", 1, Vector3(2.0, 0, 0), 0.95) if good else _spawn("皮卡超人", 1, Vector3(2.8, 0, 0), 1.0)
	if good:
		_move(unit, Vector3(0.5, 0, 0), 0.9)
		if not await _wait(g, 0.9): return
		_attack_swing(unit)
		_defeat(enemy)
		if not await _wait(g, 1.0): return
	else:
		_move(enemy, Vector3(0.2, 0, 0), 1.2)
		if not await _wait(g, 1.2): return
		_attack_swing(enemy)
		_defeat(unit)
		if not await _wait(g, 1.0): return
	if g == _gen: _run_clip()

# ==================== micro battle helpers ====================
func _spawn(unit_name: String, team: int, pos: Vector3, sc: float) -> Node3D:
	var spec: Dictionary = CVC.spec_for(unit_name, team, 1.0)
	var model: Node3D = UMK.create_unit(spec)
	model.position = pos
	model.scale = Vector3.ONE * sc
	_actors.add_child(model)
	return model


func _move(node: Node3D, target: Vector3, dur: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _projectile(from: Vector3, to: Vector3, color: Color, dur: float, arrow := false) -> void:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	if arrow:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.55)
		mesh = bm
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		mesh = sm
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.8
	mi.material_override = m
	mi.position = from
	_actors.add_child(mi)
	if arrow:
		var dir := (to - from).normalized()
		var up := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
		mi.look_at(to, up)
	var tw := create_tween()
	tw.tween_property(mi, "position", to, dur)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			mi.queue_free())


func _burst(pos: Vector3, color: Color) -> void:
	for i in range(7):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.04, 0.10)
		sm.height = sm.radius * 2.0
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(color.r, color.g, color.b, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_actors.add_child(mi)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", pos + Vector3(randf_range(-0.6, 0.6), randf_range(0.15, 0.8), randf_range(-0.6, 0.6)), 0.42)
		tw.tween_property(mi, "scale", Vector3(2.0, 2.0, 2.0), 0.42)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.42)
		tw.chain().tween_callback(func():
			if is_instance_valid(mi):
				mi.queue_free())


func _damage(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 34
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	_actors.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.8, 0.75)
	tw.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.15)
	tw.chain().tween_callback(func():
		if is_instance_valid(l):
			l.queue_free())


func _attack_swing(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", base * Vector3(1.12, 0.92, 1.12), 0.08)
	tw.tween_property(node, "scale", base, 0.12)


func _defeat(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.30)
	tw.tween_property(node, "rotation:y", node.rotation.y + PI, 0.30)
	tw.chain().tween_callback(func():
		if is_instance_valid(node):
			node.queue_free())


func _shake(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.position
	var tw := create_tween()
	tw.tween_property(node, "position:x", base.x + 0.08, 0.06)
	tw.tween_property(node, "position:x", base.x, 0.06)


func _wait(g: int, seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return g == _gen


func _tab_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 36)
	b.add_theme_font_size_override("font_size", 13)
	return b


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
