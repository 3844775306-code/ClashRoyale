# scripts/ui/CardAnimationStudio.gd
# 卡组配置 → 配置动画：在真实战场里暂停、自由放卡、录制/上传卡牌实战动画
extends Node

const BATTLE_SCENE = preload("res://scenes/battle.tscn")
const STORE = preload("res://scripts/data/CardAnimationStore.gd")
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)

var _battle: Node3D
var _canvas: CanvasLayer
var _font: Font
var _paused := true
var _recording := false
var _rec_time := 0.0
var _record_duration := 1.0
var _events: Array = []
var _target_name := ""
var _target_mode := "advantage"
var _selected_cfg = null
var _active_team := 0
var _card_buttons: Array = []
var _trays: Dictionary = {}

var _pause_btn: Button
var _record_lbl: Label
var _status_lbl: Label
var _selected_lbl: Label
var _start_btn: Button
var _stop_btn: Button
var _target_opt: OptionButton
var _mode_opt: OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.sfx_muted = true
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_battle = BATTLE_SCENE.instantiate()
	_battle.set_meta("showcase", true)
	add_child(_battle)
	_battle.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().process_frame
	await get_tree().process_frame
	_build_overlay()
	_paused = true
	get_tree().paused = true
	_update_status()
	call_deferred("_sync_animation_cloud")


func _exit_tree() -> void:
	AudioManager.sfx_muted = false
	if is_inside_tree():
		get_tree().paused = false


func _build_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 60
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)
	_build_top_controls(root)
	_build_tray(root, 1, true)
	_build_tray(root, 0, false)


func _build_top_controls(root: Control) -> void:
	var panel := Panel.new()
	panel.position = Vector2(12, 10)
	panel.size = Vector2(776, 118)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.085, 0.97), GOLD, 16))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 7
	v.offset_bottom = -7
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	v.add_child(row1)
	var back := _small_btn("← 返回", Color(0.35, 0.46, 0.68), Vector2(96, 36))
	back.pressed.connect(_on_back)
	row1.add_child(back)
	var title := _label("卡牌动画配置", 20, GOLD_LIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title)
	_pause_btn = _small_btn("▶ 继续", Color(0.92, 0.70, 0.28), Vector2(104, 36))
	_pause_btn.add_theme_font_size_override("font_size", 14)
	_pause_btn.pressed.connect(_toggle_pause)
	row1.add_child(_pause_btn)
	_record_lbl = _label("", 14, MUTED)
	row1.add_child(_record_lbl)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	v.add_child(row2)
	row2.add_child(_label("目标", 13, MUTED))
	_target_opt = OptionButton.new()
	_target_opt.custom_minimum_size = Vector2(130, 34)
	_target_opt.add_theme_font_size_override("font_size", 13)
	row2.add_child(_target_opt)
	_mode_opt = OptionButton.new()
	_mode_opt.custom_minimum_size = Vector2(74, 34)
	_mode_opt.add_theme_font_size_override("font_size", 13)
	_mode_opt.add_item("优势")
	_mode_opt.add_item("劣势")
	row2.add_child(_mode_opt)
	_start_btn = _small_btn("开始录制", Color(0.32, 0.72, 0.42), Vector2(88, 34))
	_stop_btn = _small_btn("结束录制", Color(0.86, 0.35, 0.30), Vector2(88, 34))
	var rerec := _small_btn("重新录制", Color(0.90, 0.62, 0.24), Vector2(88, 34))
	var upload := _small_btn("上传录制", Color(0.42, 0.62, 0.95), Vector2(88, 34))
	var clear_btn := _small_btn("清空战场", Color(0.55, 0.42, 0.30), Vector2(88, 34))
	for b in [_start_btn, _stop_btn, rerec, upload, clear_btn]:
		row2.add_child(b)
	_start_btn.pressed.connect(_start_recording)
	_stop_btn.pressed.connect(_stop_recording)
	rerec.pressed.connect(_rerecord)
	upload.pressed.connect(_upload)
	clear_btn.pressed.connect(_clear_battle)
	_target_opt.item_selected.connect(_on_target_selected)
	_mode_opt.item_selected.connect(_on_mode_selected)
	_fill_target_options()

	_status_lbl = _label("已暂停，可选择卡牌后点击战场放置；点「继续」开始战斗。", 13, Color(0.76, 0.84, 0.96))
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_status_lbl)


func _build_tray(root: Control, team: int, top: bool) -> void:
	var panel := Panel.new()
	panel.position = Vector2(12, 136 if top else 1420)
	panel.size = Vector2(776, 164)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.035, 0.075, 0.96), Color(0.72, 0.62, 0.38), 15))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	v.add_child(head)
	var title := _label("敌方卡牌桌（点击卡，再点战场）" if top else "我方卡牌桌（无需圣水）", 15, GOLD_LIGHT if not top else Color(1.0, 0.62, 0.55), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if team == 0:
		_selected_lbl = _label("未选卡", 13, MUTED)
		head.add_child(_selected_lbl)
	var search := LineEdit.new()
	search.placeholder_text = "🔍 搜索卡牌…"
	search.custom_minimum_size = Vector2(220, 32)
	search.add_theme_font_size_override("font_size", 14)
	head.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 116)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	v.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	scroll.add_child(row)
	_trays[team] = {"search": search, "row": row}
	search.text_changed.connect(func(_t): _fill_tray(team))
	_fill_tray(team)


func _fill_tray(team: int) -> void:
	if not _trays.has(team):
		return
	var tray: Dictionary = _trays[team]
	var row: HBoxContainer = tray.row
	for c in row.get_children():
		c.queue_free()
	var query := String((tray.search as LineEdit).text).strip_edges()
	var cards: Array = _all_cards()
	if query != "":
		var filtered: Array = []
		for cfg in cards:
			if String(cfg.card_name).contains(query):
				filtered.append(cfg)
		cards = filtered
	for cfg in cards:
		var b := _card_btn(cfg, team)
		row.add_child(b)
		_card_buttons.append(b)


func _card_btn(cfg, team: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(80, 108)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _card_btn_style(false, team))
	b.add_theme_stylebox_override("hover", _card_btn_style(false, team, true))
	b.add_theme_stylebox_override("pressed", _card_btn_style(true, team))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4
	v.offset_right = -4
	v.offset_top = 3
	v.offset_bottom = -3
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 68)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/cards_web/%s.png" % String(cfg.card_name)
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % String(cfg.card_name)
	if ResourceLoader.exists(path):
		art.texture = load(path)
	v.add_child(art)
	var name_lbl := Label.new()
	name_lbl.text = String(cfg.card_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", PARCHMENT)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
	var cost := Label.new()
	cost.text = "💧%d" % int(cfg.cost)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", Color(0.78, 0.70, 1.0))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cost)
	b.set_meta("cfg", cfg)
	b.set_meta("team", team)
	b.pressed.connect(func(): _on_card_picked(cfg, team, b))
	return b


func _on_card_picked(cfg, team: int, btn: Button) -> void:
	_selected_cfg = cfg
	_active_team = team
	for b in _card_buttons:
		if not is_instance_valid(b):
			continue
		b.add_theme_stylebox_override("normal", _card_btn_style(b == btn, int(b.get_meta("team", 0))))
		b.add_theme_stylebox_override("pressed", _card_btn_style(b == btn, int(b.get_meta("team", 0))))
	if _selected_lbl != null:
		_selected_lbl.text = "%s · %s" % ["我方" if team == 0 else "敌方", String(cfg.card_name)]
	_update_status()


func _start_recording() -> void:
	if _recording:
		return
	if String(_target_name) == "":
		_status_lbl.text = "请先选择录制目标卡牌。"
		return
	_events.clear()
	_rec_time = 0.0
	_record_duration = 1.0
	_recording = true
	_status_lbl.text = "开始录制：%s · %s。点「继续/暂停」按钮，暂停时可放卡。" % [_target_name, _mode_cn()]
	_update_status()


func _stop_recording() -> void:
	if not _recording:
		return
	_recording = false
	_record_duration = maxf(_rec_time, _last_event_time() + 1.0)
	_status_lbl.text = "录制结束：%d 个指令，时长 %.1fs。点「上传录制」保存。" % [_events.size(), _record_duration]
	_update_status()


func _rerecord() -> void:
	_recording = false
	_events.clear()
	_rec_time = 0.0
	_record_duration = 1.0
	_start_recording()


func _sync_animation_cloud() -> void:
	await STORE.sync_from_cloud()
	await STORE.upload_all_local_to_cloud()
	_fill_target_options()
	_update_status()


func _upload() -> void:
	if _recording:
		_stop_recording()
	if _events.is_empty():
		_status_lbl.text = "没有可上传的指令，请先开始录制并放卡。"
		return
	var ok := STORE.save_recording(_target_name, _target_mode, _events, _record_duration)
	if ok:
		var cloud_ok := await STORE.upload_recording_to_cloud(_target_name, _target_mode, _events, _record_duration)
		_fill_target_options()
		if cloud_ok:
			_status_lbl.text = "已上传到云端：%s · %s（%d 个指令）" % [_target_name, _mode_cn(), _events.size()]
		else:
			_status_lbl.text = "已保存到本地；云端上传失败：%s · %s" % [_target_name, _mode_cn()]
	else:
		_status_lbl.text = "上传失败：无法写入录制文件。"


func _clear_battle() -> void:
	if _battle == null:
		return
	for u in _battle.units.get_children():
		u.queue_free()
	for b in _battle.bullets.get_children():
		b.queue_free()
	for s in _battle.spells.get_children():
		s.queue_free()
	for i in range(_battle.healths.size()):
		_battle.healths[i] = 0.0
	_status_lbl.text = "正在恢复战场与皇家塔…"
	await get_tree().process_frame
	if _battle == null or not is_instance_valid(_battle):
		return
	_battle.spawn_initial_towers()
	_status_lbl.text = "已清空战场，皇家塔恢复满血（固定 11 级）。"


func _process(delta: float) -> void:
	if _recording and not _paused:
		_rec_time += delta
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _paused:
			return
		if _selected_cfg == null:
			_status_lbl.text = "先在上方/下方卡桌选择一张卡，再点击战场。"
			return
		var pos = _raycast_ground(event.position)
		if pos != null:
			_place_card(_selected_cfg, _active_team, pos)
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_update_status()


func _place_card(cfg, team: int, pos: Vector3) -> void:
	var p := pos
	var spell: bool = _battle._is_spell_like(int(cfg.card_id))
	if not spell and int(cfg.type) == 3:
		p.y = 1.8
	else:
		p.y = 0.02
	if spell:
		_battle.deploy_spell(cfg, team, p)
	else:
		_battle.spawn_unit(cfg, team, p, -1, 11)
	if _recording:
		_events.append({
			"time": _rec_time,
			"team": team,
			"card_id": int(cfg.card_id),
			"x": p.x,
			"y": p.y,
			"z": p.z,
			"spell": spell,
		})
		_status_lbl.text = "已录制第 %d 个指令：%s（%s）" % [_events.size(), String(cfg.card_name), "敌方" if team == 1 else "我方"]
	else:
		_status_lbl.text = "已放置：%s（未录制）" % String(cfg.card_name)


func _raycast_ground(screen_pos: Vector2):
	if _battle == null:
		return null
	var cam := _battle.get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var hit := _battle.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return null
	if hit.get("collider") == null or hit.collider.name != "GroundPlane":
		return null
	var p: Vector3 = hit.position
	p.x = clampf(p.x, Config.ARENA_ORIGIN.x + 0.4, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH - 0.4)
	p.z = clampf(p.z, Config.ARENA_ORIGIN.z + 0.4, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 0.4)
	return p


func _on_target_selected(index: int) -> void:
	if _recording:
		_stop_recording()
	if index >= 0 and index < _target_opt.item_count:
		var md = _target_opt.get_item_metadata(index)
		_target_name = String(md) if md != null else String(_target_opt.get_item_text(index)).replace("✓ ", "")
		if STORE.has_recording(_target_name, _target_mode):
			_status_lbl.text = "「%s · %s」已有录制，可直接继续录制覆盖。" % [_target_name, _mode_cn()]
		_update_status()


func _on_mode_selected(index: int) -> void:
	if _recording:
		_stop_recording()
	_target_mode = "advantage" if index == 0 else "weakness"
	_fill_target_options()
	_update_status()


func _update_status() -> void:
	if _pause_btn == null:
		return
	_pause_btn.text = "▶ 继续" if _paused else "⏸ 暂停"
	if _recording:
		_record_lbl.text = "● 录制中 %.1fs · %d 指令" % [_rec_time, _events.size()]
	else:
		_record_lbl.text = "已结束 %d 指令" % _events.size() if not _events.is_empty() else ""
	if _start_btn:
		_start_btn.disabled = _recording
	if _stop_btn:
		_stop_btn.disabled = not _recording


func _last_event_time() -> float:
	var t := 0.0
	for e in _events:
		t = maxf(t, float(e.get("time", 0.0)))
	return t


func _mode_cn() -> String:
	return "优势" if _target_mode == "advantage" else "劣势"


func _fill_target_options() -> void:
	var keep := _target_name
	_target_opt.clear()
	var cards := _all_cards()
	for cfg in cards:
		var n := String(cfg.card_name)
		var recorded := STORE.has_recording(n, _target_mode)
		_target_opt.add_item(("✓ " if recorded else "") + n)
		var idx := _target_opt.item_count - 1
		_target_opt.set_item_metadata(idx, n)
	var pick := 0
	for i in range(_target_opt.item_count):
		var md = _target_opt.get_item_metadata(i)
		if keep != "" and String(md) == keep:
			pick = i
			break
		if keep == "" and String(md) == "法师":
			pick = i
	if _target_opt.item_count > 0:
		_target_opt.select(pick)
		_target_name = String(_target_opt.get_item_metadata(pick))
	else:
		_target_name = ""


func _all_cards() -> Array:
	var out: Array = []
	if _battle == null:
		return out
	for cfg in _battle.configs:
		if int(cfg.card_id) >= 4:
			out.append(cfg)
	out.sort_custom(func(a, b): return int(a.cost) < int(b.cost))
	return out


func _on_back() -> void:
	get_tree().paused = false
	LoadingScreen.change_scene("res://scenes/deck_builder.tscn", "正在返回卡组配置…")


func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = Color(border.r, border.g, border.b, 0.62)
	return sb


func _card_btn_style(selected: bool, team: int, hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2 if selected else 1)
	var accent := Color(0.30, 0.62, 1.0) if team == 0 else Color(1.0, 0.40, 0.36)
	sb.bg_color = Color(0.06, 0.09, 0.16, 0.98)
	if hover:
		sb.bg_color = Color(0.10, 0.15, 0.26, 1.0)
	sb.border_color = Color(1.0, 0.82, 0.36) if selected else Color(accent.r, accent.g, accent.b, 0.45)
	return sb


func _small_btn(text: String, color: Color, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = color.lightened(0.3)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = color.lightened(0.10)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.16, 0.10, 0.03))
	return b


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
