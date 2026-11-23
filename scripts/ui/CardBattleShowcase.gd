# scripts/ui/CardBattleShowcase.gd
# 卡牌详情「玩法」页：直接使用实际 battle.tscn 的小窗口战场
# 真实战场地面、真实单位/血条/子弹、真实相机；脚本只负责摆位和切换优劣势场景。
extends Control

const BATTLE_SCENE = preload("res://scenes/battle.tscn")
const STORE = preload("res://scripts/data/CardAnimationStore.gd")
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const MUTED := Color(0.630, 0.680, 0.795)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const DEFAULT_FOCUS := Vector3(-5.5, 0.0, 0.0)

const BASE := Vector3(-5.5, 0.0, 0.0)   # 左侧桥面，作为卡牌演示中心

var card_name := ""
var card = null
var _font: Font
var _battle: Node3D
var _sub: SubViewport
var _stage_frame: Panel
var _caption: Label
var _tag: Label
var _card_focus: TextureRect
var _btn_adv: Button
var _btn_weak: Button
var _selected := 0
var _gen := 0
var _demo_units: Array = []
var _ready_battle := false
var _cloud_synced := false
var _follow_label: Label
var _follow_cid: int = -1
var _following := false
var _battle_cam: Camera3D


func setup(name: String, config = null) -> void:
	card_name = name
	card = config


func _enter_tree() -> void:
	AudioManager.sfx_muted = true


func _exit_tree() -> void:
	AudioManager.sfx_muted = false
	_gen += 1
	if is_instance_valid(_battle):
		for u in _battle.units.get_children():
			if is_instance_valid(u):
				u.set_physics_process(false)
				u.set_process(false)
		for b in _battle.bullets.get_children():
			if is_instance_valid(b):
				b.set_physics_process(false)
				b.set_process(false)
		_battle.queue_free()


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	custom_minimum_size = Vector2(0, 475)
	_build()
	_init_battle()


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
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := _label("实战演示", 23, GOLD_LIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_btn_adv = _tab_btn("优势 · 克制")
	_btn_weak = _tab_btn("劣势 · 被克制")
	head.add_child(_btn_adv)
	head.add_child(_btn_weak)
	_btn_adv.pressed.connect(func(): _select(0))
	_btn_weak.pressed.connect(func(): _select(1))

	_stage_frame = Panel.new()
	_stage_frame.custom_minimum_size = Vector2(0, 300)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.010, 0.020, 0.050, 1.0)
	fsb.set_corner_radius_all(13)
	fsb.set_border_width_all(1)
	fsb.border_color = Color(1, 1, 1, 0.10)
	_stage_frame.add_theme_stylebox_override("panel", fsb)
	v.add_child(_stage_frame)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	_stage_frame.add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(1000, 430)
	_sub.transparent_bg = false
	_sub.own_world_3d = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)

	_card_focus = TextureRect.new()
	_card_focus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_focus.offset_left = -50
	_card_focus.offset_right = 50
	_card_focus.offset_top = -60
	_card_focus.offset_bottom = 60
	_card_focus.pivot_offset = Vector2(50, 60)
	_card_focus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_focus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := "res://assets/cards_web/%s.png" % card_name
	if not ResourceLoader.exists(art_path):
		art_path = "res://assets/cards_rendered/%s.png" % card_name
	if ResourceLoader.exists(art_path):
		_card_focus.texture = load(art_path)
	_stage_frame.add_child(_card_focus)
	_follow_label = _label("", 15, Color(1.0, 0.92, 0.62), true)
	_follow_label.position = Vector2(12, 10)
	_follow_label.size = Vector2(360, 28)
	_follow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_follow_label.add_theme_constant_override("outline_size", 5)
	_follow_label.visible = false
	_follow_label.z_index = 5
	_stage_frame.add_child(_follow_label)

	_tag = _label("", 17, Color(0.62, 0.86, 0.64))
	v.add_child(_tag)
	_caption = _label("正在加载实际战场…", 17, MUTED)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(0, 52)
	v.add_child(_caption)
	_style_tabs()


func _init_battle() -> void:
	_battle = BATTLE_SCENE.instantiate()
	_battle.set_meta("showcase", true)
	_sub.add_child(_battle)
	# battle 的 _ready 会建好真实战场、真实塔和 HUD；等两帧再隐藏 HUD 其它部分
	await get_tree().process_frame
	await get_tree().process_frame
	_ready_battle = true
	if _battle != null:
		_battle_cam = _battle.get_node_or_null("Camera3D") as Camera3D
		_snap_follow_camera(DEFAULT_FOCUS)
		var hud = _battle.get("hud")
		if hud != null and hud.health_bar_container != null:
			hud.health_bar_container.visible = true
	_select(0)


func _select(i: int) -> void:
	_selected = i
	_style_tabs()
	if _ready_battle:
		_run_clip()


func _style_tabs() -> void:
	for i in range(2):
		var b: Button = _btn_adv if i == 0 else _btn_weak
		var active: bool = i == _selected
		b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02) if active else PARCHMENT)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(11)
		sb.set_border_width_all(1)
		sb.bg_color = Color(0.93, 0.71, 0.28) if active else Color(0.06, 0.09, 0.16, 0.95)
		sb.border_color = Color(1.0, 0.90, 0.60) if active else Color(1, 1, 1, 0.12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _run_clip() -> void:
	_stop_follow(false)
	_gen += 1
	var g := _gen
	_clear_demo()
	if _battle == null:
		return
	_show_card_focus()
	var mode := "advantage" if _selected == 0 else "weakness"
	if not _cloud_synced:
		_cloud_synced = true
		_sync_cloud_background()
	var rec: Dictionary = STORE.get_recording(card_name, mode)
	if not rec.is_empty() and not (rec.get("events", []) as Array).is_empty():
		_tag.text = "实战录制 · %s" % ("优势" if _selected == 0 else "劣势")
		_caption.text = "使用已上传的录制指令回放：共 %d 个放置指令。" % (rec.get("events", []) as Array).size()
		await _play_recording(g, rec)
		return
	_snap_follow_camera(DEFAULT_FOCUS)
	if card_name == "法师":
		_tag.text = "优势 · 范围伤害清理人海" if _selected == 0 else "劣势 · 被高血量近战贴脸"
		_caption.text = "实际战场：法师用范围火焰清理聚集的小费群体。" if _selected == 0 else "实际战场：法师血量低，被皮卡超人贴脸后很难活下来。"
		if _selected == 0:
			_spawn_own(Vector3(-2.0, 0, -1.0))
			_spawn_enemy("骷髅军团", Vector3(1.6, 0, 0.0))
		else:
			_spawn_own(Vector3(-1.8, 0, 0.0))
			_spawn_enemy("皮卡超人", Vector3(2.4, 0, 0.0))
	elif card_name == "万箭齐发":
		_tag.text = "优势 · 低费清理人海" if _selected == 0 else "劣势 · 对高血量单体乏力"
		_caption.text = "实际战场：箭雨覆盖范围大，一次清掉低血量群体。" if _selected == 0 else "实际战场：箭雨打在皮卡超人身上只能造成有限伤害。"
		if _selected == 0:
			_spawn_enemy("骷髅军团", Vector3(0.6, 0, 0.0))
		else:
			_spawn_enemy("皮卡超人", Vector3(0.8, 0, 0.0))
		await get_tree().create_timer(0.35).timeout
		if g != _gen: return
		_battle.deploy_spell(card, 0, BASE)
	elif card_name == "野猪骑士":
		_tag.text = "优势 · 只打建筑，直取核心" if _selected == 0 else "劣势 · 被人海围杀"
		_caption.text = "实际战场：野猪骑士绕过防守直冲公主塔。" if _selected == 0 else "实际战场：没有法术掩护时，骷髅军团会拖住野猪骑士。"
		if _selected == 0:
			_spawn_own(Vector3(-2.0, 0, 0.0))
			_spawn_enemy("公主塔", Vector3(2.2, 0, 0.0))
		else:
			_spawn_own(Vector3(0.0, 0, 0.0))
			_spawn_enemy("骷髅军团", Vector3(1.2, 0, -0.8))
	else:
		_spawn_generic(g)
	await get_tree().create_timer(4.2).timeout
	if g == _gen:
		_run_clip()


func _sync_cloud_background() -> void:
	var gen := _gen
	await STORE.sync_from_cloud()
	await STORE.upload_all_local_to_cloud()
	if _battle == null or not is_inside_tree():
		return
	# 云端在本地/默认演示之后才返回时，若用户未切换页签则自动切到云端录制
	if _gen == gen and _ready_battle:
		_run_clip()


func _play_recording(g: int, rec: Dictionary) -> void:
	_follow_cid = int(card.card_id) if card != null else -1
	_following = true
	if _follow_label:
		_follow_label.visible = true
		_follow_label.text = "跟随：等待录制单位…"
	var events: Array = (rec.get("events", []) as Array).duplicate()
	events.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
	if not events.is_empty():
		_snap_follow_camera(Vector3(float(events[0].get("x", DEFAULT_FOCUS.x)), 0.0, float(events[0].get("z", DEFAULT_FOCUS.z))))
	var elapsed := 0.0
	for ev in events:
		var t := maxf(0.0, float(ev.get("time", 0.0)))
		if t > elapsed:
			await get_tree().create_timer(t - elapsed).timeout
			if g != _gen: return
			elapsed = t
		var cfg = _battle.get_config(int(ev.get("card_id", 0)))
		if cfg == null:
			continue
		var y := float(ev.get("y", 0.0))
		if not bool(ev.get("spell", false)) and int(cfg.type) == 3 and y <= 0.05:
			y = 1.8
		var pos := Vector3(float(ev.get("x", 0.0)), y, float(ev.get("z", 0.0)))
		if bool(ev.get("spell", false)):
			_battle.deploy_spell(cfg, int(ev.get("team", 0)), Vector3(pos.x, 0.0, pos.z))
		else:
			_spawn_absolute(cfg, int(ev.get("team", 0)), pos)
	var duration := maxf(float(rec.get("duration", 1.0)), elapsed)
	if duration > elapsed:
		await get_tree().create_timer(duration - elapsed).timeout
		if g != _gen: return
	_stop_follow(false)
	await get_tree().create_timer(2.0).timeout
	if g == _gen:
		_run_clip()


func _process(delta: float) -> void:
	if not _following or _battle_cam == null:
		return
	var target = _current_follow_unit()
	if target == null:
		return
	var name := String(target.config.card_name) if target.config != null else "单位"
	if _follow_label and _follow_label.text != "跟随：" + name:
		_follow_label.text = "跟随：" + name
	var focus: Vector3 = target.global_position + Vector3(0, 0.8, 0)
	var desired: Vector3 = focus + Vector3(0, 11.0, 7.0)
	_battle_cam.global_position = _battle_cam.global_position.lerp(desired, clampf(delta * 4.0, 0.0, 1.0))
	_battle_cam.look_at(focus, Vector3.UP)
	_battle_cam.size = lerpf(_battle_cam.size, 10.5, clampf(delta * 3.0, 0.0, 1.0))


func _current_follow_unit():
	var target = null
	if _follow_cid > 0:
		for u in _demo_units:
			if is_instance_valid(u) and u.health > 0 and u.config != null and int(u.config.card_id) == _follow_cid:
				target = u
				break
	if target == null:
		for u in _demo_units:
			if is_instance_valid(u) and u.health > 0 and u.config != null and int(u.config.card_id) > 3:
				target = u
				break
	return target


func _snap_follow_camera(focus: Vector3) -> void:
	if _battle_cam == null:
		return
	_battle_cam.size = 10.5
	_battle_cam.global_position = focus + Vector3(0, 11.0, 7.0)
	_battle_cam.look_at(focus + Vector3(0, 0.8, 0), Vector3.UP)


func _stop_follow(restore_camera := true) -> void:
	_following = false
	if _follow_label:
		_follow_label.visible = false
	if restore_camera and _battle_cam != null:
		_battle_cam.size = 36.5
		_battle_cam.near = 10.0
		_battle_cam.far = 400.0
		_battle_cam.global_position = Vector3(0, 30, 18)
		_battle_cam.look_at(Vector3.ZERO, Vector3.UP)


func _spawn_absolute(cfg, team: int, pos: Vector3) -> void:
	if _battle == null:
		return
	var before: int = _battle.units.get_child_count()
	_battle.spawn_unit(cfg, team, pos, -1, 11)
	for i in range(before, _battle.units.get_child_count()):
		_demo_units.append(_battle.units.get_child(i))


func _spawn_generic(g: int) -> void:
	var strong := _selected == 0
	_tag.text = "优势 · %s" % _generic_strength_tag() if strong else "劣势 · %s" % _generic_weakness_tag()
	_caption.text = _generic_strength_caption() if strong else _generic_weakness_caption()
	if _is_spell():
		if strong:
			_spawn_enemy("骷髅军团", Vector3(0.6, 0, 0.0))
		else:
			_spawn_enemy("皮卡超人", Vector3(0.8, 0, 0.0))
		await get_tree().create_timer(0.4).timeout
		if g != _gen: return
		_battle.deploy_spell(card, 0, BASE)
		return
	_spawn_own(Vector3(-2.0, 0, -0.8))
	if strong:
		if _is_building_only():
			_spawn_enemy("公主塔", Vector3(2.0, 0, 0.0))
		elif _is_air():
			_spawn_enemy("骑士", Vector3(1.8, 0, 0.0))
		elif _is_ranged() or _is_tank() or _is_splash():
			_spawn_enemy("骷髅军团", Vector3(1.2, 0, 0.0), 5)
		elif _is_building():
			_spawn_enemy("骑士", Vector3(1.8, 0, 0.0))
		else:
			_spawn_enemy("骑士", Vector3(1.8, 0, 0.0))
	else:
		if _is_air():
			_spawn_enemy("火枪手", Vector3(1.8, 0, 0.0))
		elif _is_building():
			_battle.deploy_spell(_cfg("火球"), 1, BASE)
		elif _is_building_only() or _is_tank() or _is_splash() or _is_swarm():
			_spawn_enemy("骷髅军团", Vector3(1.2, 0, -0.8), 6)
		else:
			_spawn_enemy("皮卡超人", Vector3(2.2, 0, 0.0))


func _spawn_own(offset: Vector3, count := -1) -> Array:
	return _spawn_cfg(card, 0, offset, count)


func _spawn_enemy(name: String, offset: Vector3, count := -1) -> Array:
	var cfg = _cfg(name)
	if cfg == null:
		return []
	return _spawn_cfg(cfg, 1, offset, count)


func _spawn_cfg(cfg, team: int, offset: Vector3, count := -1) -> Array:
	if cfg == null:
		return []
	var before: int = _battle.units.get_child_count()
	var n: int = count if count > 0 else int(cfg.num)
	n = mini(n, 8)
	_battle.spawn_unit(cfg, team, BASE + offset, n, 11)
	var out: Array = []
	for i in range(before, _battle.units.get_child_count()):
		out.append(_battle.units.get_child(i))
	_demo_units.append_array(out)
	return out


func _clear_demo() -> void:
	for u in _demo_units:
		if is_instance_valid(u):
			u.queue_free()
	_demo_units.clear()
	if _battle == null:
		return
	for b in _battle.bullets.get_children():
		b.queue_free()
	for s in _battle.spells.get_children():
		s.queue_free()


func _cfg(name: String):
	if _battle == null:
		return null
	for cfg in _battle.configs:
		if String(cfg.card_name) == name:
			return cfg
	return null


func _show_card_focus() -> void:
	if _card_focus == null or _card_focus.texture == null:
		return
	_card_focus.visible = true
	_card_focus.modulate.a = 1.0
	_card_focus.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_card_focus, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(_card_focus):
			_card_focus.visible = false)


# ---------- 标签与文案 ----------
func _card_name() -> String:
	return String(card.card_name) if card != null else card_name

func _is_spell() -> bool:
	return card != null and int(card.attack_speed) <= 0 and int(card.type) != 1
func _is_air() -> bool:
	return card != null and int(card.type) == 3
func _is_building() -> bool:
	return card != null and int(card.type) == 1
func _is_building_only() -> bool:
	return card != null and int(card.target_type) == 1
func _is_splash() -> bool:
	return card != null and float(card.damage_range) > 0.5
func _is_tank() -> bool:
	return card != null and float(card.max_health) >= 2500.0
func _is_swarm() -> bool:
	return card != null and int(card.num) >= 3
func _is_ranged() -> bool:
	return card != null and float(card.attack_range) >= 5.0 and float(card.attack_speed) > 0.0

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
	if _is_spell(): return "实际战场：这张法术适合处理聚集的低血量单位或关键建筑。"
	if _is_building(): return "实际战场：建筑持续输出并拉扯进攻单位，为塔和后排争取时间。"
	if _is_air(): return "实际战场：空中单位让多数地面近战无法还手。"
	if _is_tank(): return "实际战场：高血量坦克吸收火力，掩护后排推进。"
	if _is_building_only(): return "实际战场：只打建筑的单位绕过防守直取公主塔。"
	if _is_splash(): return "实际战场：范围伤害一次清理聚集的小费群体。"
	if _is_swarm(): return "实际战场：人海单位围杀单体高伤目标。"
	if _is_ranged(): return "实际战场：远程单位在塔后稳定输出。"
	return "实际战场：适合防守反击。"

func _generic_weakness_caption() -> String:
	if _is_spell(): return "实际战场：面对高血量单体，法术伤害有限。"
	if _is_building(): return "实际战场：建筑会被火球/火箭等法术直接拆除。"
	if _is_air(): return "实际战场：对空远程能快速处理空中单位。"
	if _is_tank(): return "实际战场：坦克怕人海围杀和高 DPS 单体。"
	if _is_building_only(): return "实际战场：拉扯建筑或人海会让只打建筑的单位偏离目标。"
	if _is_splash(): return "实际战场：范围单位被高血量近战贴脸会很难受。"
	if _is_swarm(): return "实际战场：人海最怕范围法术。"
	if _is_ranged(): return "实际战场：远程单位被近身突袭时容易阵亡。"
	return "实际战场：被更强单体或人海围杀时很难发挥。"


func _tab_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(165, 46)
	b.add_theme_font_size_override("font_size", 16)
	return b


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
