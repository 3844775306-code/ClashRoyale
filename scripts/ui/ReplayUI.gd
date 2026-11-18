# scripts/ui/ReplayUI.gd
# 对局回放：轻量 action replay，重新模拟战斗；顶部/底部显示双方手牌与圣水。
extends Control
signal live_card_selected(card_id: int)
signal king_sequence_finished
var live_mode: bool = false
var live_selected_card: int = -1

const REPLAY_DIR := "user://replays"
const SPELL_VFX = preload("res://scripts/visuals/SpellVFX.gd")
const CARD_SCAN = preload("res://assets/shaders/card_scan.gdshader")
const EMOTES = preload("res://scripts/data/EmoteCatalog.gd")

var _bg: ColorRect
var _bg_layer: ColorRect
var _menu_backdrop: Control
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
var _info: Label
var _refresh_btn: Button
var _gen_btn: Button
var _gen_busy: bool = false
var _viewer: Control
var _battle
var _data: Dictionary = {}
var _emotes: Array = []
var _next_emote: int = 0
var _emote_layer: Control
var _actions: Array = []
var _snapshot_mode: bool = false
var _snapshots: Array = []
var _visual_units: Dictionary = {}
var _visual_bullets: Dictionary = {}
var _visual_spells: Dictionary = {}
var _visual_beams: Dictionary = {}
var _visual_chains: Dictionary = {}
var _dying_units: Dictionary = {}
var _destroyed_towers: Dictionary = {}
var _snap_elixir: Array = [7.0, 5.0]
var _play_t: float = 0.0
var _scrub_guard: bool = false
var _seeking: bool = false
var _king_seq: bool = false
var _levels := {0: {}, 1: {}}
var _next_action: int = 0
var _playing: bool = false
var _speed: float = 1.0
var _duration: float = 1.0
var _ended: bool = false

var _hands := {}
var _decks := {}
var _hand_boxes := {}
var _elixir_bars := {}
var _elixir_labels := {}
var _info_boxes := {}
var _progress: HSlider
var _track_fill: Panel
var _track_handle: Panel
var _time_lbl: Label
var _play_btn: Button
var _speed_btn: Button
var _tex_cache: Dictionary = {}

func _ready():
	_bg_layer = UiComponents.add_background(self)
	_menu_backdrop = get_node_or_null("MenuBackdrop")
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	UiComponents.make_header(self, "对局回放", _on_back_pressed, true)
	_build_list_view()
	_load_replays()
	UiComponents.fade_in(self)

func _build_list_view():
	_info = Label.new()
	_info.position = Vector2(40, 108)
	_info.size = Vector2(720, 28)
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	add_child(_info)
	_gen_btn = UiComponents.make_secondary_button("🤖 生成自对弈", _generate_selfplay, Vector2(170, 38))
	_gen_btn.position = Vector2(458, 100)
	add_child(_gen_btn)
	_refresh_btn = UiComponents.make_secondary_button("刷新", _load_replays, Vector2(110, 38))
	_refresh_btn.position = Vector2(650, 100)
	add_child(_refresh_btn)
	_list_scroll = UiComponents.make_content_scroll(self, 146)
	_list_box = UiComponents.make_content_vbox()
	_list_scroll.add_child(_list_box)

func _replay_dir() -> String:
	var env := OS.get_environment("CR_MATCH_REPLAY_DIR")
	return env if env != "" else REPLAY_DIR

func _load_replays():
	for c in _list_box.get_children():
		c.queue_free()
	var dir := _replay_dir()
	var files: Array = []
	var d := DirAccess.open(ProjectSettings.globalize_path(dir))
	if d:
		for f in d.get_files():
			if f.ends_with(".json") and f.begins_with("replay_"):
				files.append(f)
	files.sort()
	files.reverse()
	var player_items: Array = []
	var self_items: Array = []
	for f in files:
		var path := "%s/%s" % [dir, f]
		var fa := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
		if fa == null:
			continue
		if fa.get_length() > 16 * 1024 * 1024:
			fa.close()
			continue
		var parsed = JSON.parse_string(fa.get_as_text())
		fa.close()
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed
		data["_source_dir"] = dir
		var meta: Dictionary = data.get("meta", {})
		if int(meta.get("version", 0)) < 2:
			continue
		if bool(meta.get("self_play", false)):
			self_items.append([data, f])
		else:
			player_items.append([data, f])
	var total: int = player_items.size() + self_items.size()
	_info.text = "共 %d 局 · 玩家 %d / AI自对弈 %d" % [total, player_items.size(), self_items.size()]
	if total == 0:
		var empty := UiComponents.make_empty_state("🎞", "暂无对局录像", "在设置中开启本地录制后完成一局对战")
		empty.custom_minimum_size = Vector2(0, 400)
		_list_box.add_child(empty)
		return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	_list_box.add_child(columns)
	columns.add_child(_make_column("👤 玩家的回放", player_items))
	columns.add_child(_make_column("🤖 非玩家 · AI自对弈", self_items))
	if OS.get_environment("CR_REPLAY_AUTOPLAY") != "":
		var first: Array = player_items if not player_items.is_empty() else self_items
		if not first.is_empty():
			_open_replay(first[0][0])

func _make_column(title: String, items: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "%s  (%d)" % [title, items.size()]
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "暂无录像"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		empty.custom_minimum_size = Vector2(0, 70)
		col.add_child(empty)
		return col
	for item in items:
		col.add_child(_make_replay_row(item[0], item[1]))
	return col

func _make_replay_row(data: Dictionary, filename: String) -> Control:
	var meta: Dictionary = data.get("meta", {})
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 98)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.13, 0.95)
	var won := int(meta.get("winner", -1))
	sb.border_color = Color(0.55, 1.0, 0.62, 0.7) if won == 0 else (Color(1.0, 0.55, 0.52, 0.7) if won == 1 else Color(0.8, 0.75, 0.5, 0.5))
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8
	hbox.offset_right = -8
	hbox.offset_top = 6
	hbox.offset_bottom = -6
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vb)
	var crowns: Array = meta.get("crowns", [0, 0])
	var title := Label.new()
	title.text = "%s  %d-%d" % [
		_result_cn(won),
		int(crowns[0] if crowns.size() > 0 else 0),
		int(crowns[1] if crowns.size() > 1 else 0)
	]
	title.add_theme_font_size_override("font_size", 16)
	if won == 0:
		title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	elif won == 1:
		title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))
	vb.add_child(title)
	var sub := Label.new()
	var duration: float = float(meta.get("duration", 0.0))
	sub.text = "%s\n%s · %d:%02d · %d 手" % [
		String(meta.get("arena_name", "竞技场")),
		String(meta.get("started_at", filename)).replace("T", " ").substr(5, 11),
		int(duration) / 60, int(duration) % 60,
		data.get("actions", []).size()
	]
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible = 3
	vb.add_child(sub)
	var play := UiComponents.make_primary_button("▶", func(): _open_replay(data), Vector2(58, 40))
	play.add_theme_font_size_override("font_size", 15)
	hbox.add_child(play)
	return panel

func _result_cn(w: int) -> String:
	if w == 0:
		return "胜利"
	if w == 1:
		return "失败"
	return "平局"

# ==================== 播放 ====================

func _generate_selfplay():
	if _gen_busy:
		return
	_gen_busy = true
	_gen_btn.disabled = true
	_info.text = "正在生成 AI 自对弈回放…"
	var old_record := PlayerData.record_replays
	PlayerData.record_replays = true
	var tmp = load("res://scenes/battle.tscn").instantiate()
	tmp.suppress_game_over_ui = true
	add_child(tmp)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemy_ai = null
	for c in tmp.get_children():
		if c is AISystem and c.team == Config.Team.ENEMY:
			enemy_ai = c
			break
	if enemy_ai:
		enemy_ai.collect_mode = true
	var player_ai = AISystem.new()
	player_ai.team = Config.Team.PLAYER
	player_ai.collect_mode = true
	tmp.add_child(player_ai)
	await get_tree().process_frame
	for c in tmp.get_children():
		if c.has_method("refresh_meta"):
			c.bind_ai(player_ai)
			c.refresh_meta()
	Engine.time_scale = 8.0
	var start_ms := Time.get_ticks_msec()
	while not tmp.game_over and Time.get_ticks_msec() - start_ms < 30000:
		await get_tree().process_frame
	tmp.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = 1.0
	PlayerData.record_replays = old_record
	_gen_busy = false
	_gen_btn.disabled = false
	_load_replays()

func _open_replay(data: Dictionary):
	_data = data
	var meta: Dictionary = data.get("meta", {})
	_actions = data.get("actions", [])
	_emotes = data.get("emotes", [])
	_next_emote = 0
	_snapshots = data.get("snapshots", [])
	var snap_file_name := String(meta.get("snapshots_file", ""))
	if _snapshots.is_empty() and snap_file_name != "":
		var sdir := String(data.get("_source_dir", "user://replays"))
		var sfa := FileAccess.open(ProjectSettings.globalize_path("%s/%s" % [sdir, snap_file_name]), FileAccess.READ)
		if sfa:
			while not sfa.eof_reached():
				var line := sfa.get_line()
				if line.strip_edges() == "":
					continue
				var parsed_line = JSON.parse_string(line)
				if parsed_line is Dictionary:
					_snapshots.append(parsed_line)
			sfa.close()
	_snapshot_mode = _snapshots.size() > 0
	_visual_units.clear()
	_visual_bullets.clear()
	_visual_spells.clear()
	_visual_beams.clear()
	_visual_chains.clear()
	_dying_units.clear()
	_destroyed_towers.clear()
	_play_t = 0.0
	_levels = {
		0: meta.get("player_levels", {}),
		1: meta.get("enemy_levels", {}),
	}
	_duration = maxf(1.0, float(meta.get("duration", 0.0)))
	_next_action = 0
	_playing = false
	_ended = false
	_speed = 1.0
	Engine.time_scale = 1.0
	_list_scroll.visible = false
	_info.visible = false
	_refresh_btn.visible = false
	_gen_btn.visible = false
	_bg.visible = false
	if _bg_layer: _bg_layer.visible = false
	if _menu_backdrop: _menu_backdrop.visible = false
	_hands = {0: [], 1: []}
	_decks = {
		0: Array(meta.get("player_deck", [])).duplicate(),
		1: Array(meta.get("enemy_deck", [])).duplicate(),
	}
	if _snapshot_mode:
		var hs: Array = _snapshots[0].get("hands", [])
		for tt in [0, 1]:
			var hh: Array = hs[tt] if tt < hs.size() else []
			_hands[tt] = hh.duplicate()
			_snap_elixir[tt] = float(_snapshots[0].get("elixir", [7.0, 5.0])[tt])
	else:
		for tt in [0, 1]:
			var deck: Array = _decks[tt]
			for i in range(4):
				if deck.is_empty():
					break
				_hands[tt].append(deck.pop_front())
	_viewer = Control.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewer)
	_emote_layer = Control.new()
	_emote_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emote_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emote_layer.z_index = 20
	_viewer.add_child(_emote_layer)

	_build_battle(meta)
	_build_hands(meta)
	_build_controls(meta)
	_playing = true
	_play_btn.text = "⏸ 暂停"
	var seek_env := OS.get_environment("CR_REPLAY_SEEK")
	if seek_env != "" and _snapshot_mode:
		_play_t = clampf(float(seek_env), 0.0, _duration)
		_playing = false
		_play_btn.text = "▶ 播放"
		_apply_snapshot_at(_play_t)
	var seek2 := OS.get_environment("CR_REPLAY_SEEK2")
	if seek2 != "" and _snapshot_mode:
		_on_scrub(float(seek2))
	set_process(true)

func _build_battle(meta: Dictionary):
	_battle = load("res://scenes/battle.tscn").instantiate()
	_battle.replay_mode = true
	_battle.battle_mode = Dictionary(meta.get("mode", {})).duplicate(true)
	if _battle.battle_mode.is_empty():
		var rule := "standard"
		if NetworkManager.match_info.has("party_rule"):
			rule = String(NetworkManager.match_info.get("party_rule", "standard"))
		_battle.battle_mode = preload("res://scripts/core/BattleModes.gd").get_by_id(rule)
	_battle.replay_player_deck = Array(meta.get("player_deck", [])).duplicate()
	_battle.replay_towers = Array(meta.get("towers", [])).duplicate()
	_battle.replay_arena = int(meta.get("arena", 0))
	var bf = _battle.get_node_or_null("Battlefield")
	if bf:
		bf.forced_arena = int(meta.get("arena", 0))
	var has_tower_snapshot := false
	if not _snapshots.is_empty():
		for u in _snapshots[0].get("units", []):
			if int(u.get("card_id", 0)) <= 3:
				has_tower_snapshot = true
				break
	if has_tower_snapshot:
		_battle.replay_skip_towers = true
		_battle.replay_towers = []
	add_child(_battle)
	var ui = _battle.get_node_or_null("UI")
	if ui:
		ui.visible = true
		_hide_hud_except_bars()
	if _snapshot_mode:
		# 只停掉战斗模拟逻辑，保留 HUD 的血条/相机层继续刷新
		_battle.set_process(false)
		for u in _battle.units.get_children():
			if u is Unit:
				u.set_process(false)
				u.set_physics_process(false)
				u.deploy_cooldown = 0.0
				u.max_deploy_cooldown = 0.0
				_force_unit_shadow(u)

func _build_hands(meta: Dictionary):
	_hand_boxes.clear()
	_elixir_bars.clear()
	_elixir_labels.clear()
	_build_hand_strip(Config.Team.ENEMY, 100, "对手")
	_build_hand_strip(Config.Team.PLAYER, 1428, "我方")
	var top_info: VBoxContainer = _info_boxes.get(1)
	if top_info:
		var rl := Label.new()
		var crowns: Array = meta.get("crowns", [0, 0])
		rl.text = "%s  %d-%d" % [_result_cn(int(meta.get("winner", -1))), int(crowns[0] if crowns.size() > 0 else 0), int(crowns[1] if crowns.size() > 1 else 0)]
		rl.add_theme_font_size_override("font_size", 12)
		rl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.54))
		top_info.add_child(rl)

func _build_hand_strip(team: int, y: float, title: String):
	var panel := Panel.new()
	panel.position = Vector2(16, y)
	panel.size = Vector2(768, 116)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.82)
	sb.border_color = Color(0.35, 0.66, 1.0, 0.75) if team == 0 else Color(1.0, 0.38, 0.36, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 6
	_viewer.add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.offset_top = 6
	hbox.offset_bottom = -6
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	var info_box := VBoxContainer.new()
	info_box.custom_minimum_size = Vector2(132, 0)
	info_box.add_theme_constant_override("separation", 3)
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_box)
	_info_boxes[team] = info_box
	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0) if team == 0 else Color(1.0, 0.6, 0.55))
	info_box.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(132, 14)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.12, 0.10, 0.22)
	bs.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bs)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.62, 0.36, 1.0)
	fs.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fs)
	info_box.add_child(bar)
	var el := Label.new()
	el.text = "圣水 7.0"
	el.add_theme_font_size_override("font_size", 13)
	el.add_theme_color_override("font_color", Color(0.82, 0.72, 1.0))
	info_box.add_child(el)
	_elixir_bars[team] = bar
	_elixir_labels[team] = el
	var cards := HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 5)
	hbox.add_child(cards)
	_hand_boxes[team] = cards

func _build_controls(meta: Dictionary):
	_progress = HSlider.new()
	_progress.position = Vector2(90, 1292)
	_progress.size = Vector2(620, 30)
	_progress.min_value = 0
	_progress.max_value = maxf(1.0, _duration)
	_progress.step = 0.01
	_progress.value = 0.0
	_progress.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.28, 0.24, 0.38, 0.98)
	track.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.78, 0.28)
	fill.set_corner_radius_all(7)
	var grab_img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	grab_img.fill(Color(1.0, 0.82, 0.34))
	_progress.add_theme_icon_override("grabber", ImageTexture.create_from_image(grab_img))
	_progress.add_theme_stylebox_override("slider", track)
	_progress.add_theme_stylebox_override("grabber_area", fill)
	_progress.add_theme_stylebox_override("grabber_area_highlight", fill)
	_progress.value_changed.connect(_on_scrub)
	_progress.modulate = Color(1, 1, 1, 0.0)
	_progress.z_index = 9
	_viewer.add_child(_progress)
	var track_bg := Panel.new()
	track_bg.position = Vector2(90, 1301)
	track_bg.size = Vector2(620, 14)
	var tbg_sb := StyleBoxFlat.new()
	tbg_sb.bg_color = Color(0.16, 0.14, 0.24, 0.95)
	tbg_sb.set_corner_radius_all(7)
	track_bg.add_theme_stylebox_override("panel", tbg_sb)
	track_bg.z_index = 7
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(track_bg)
	_track_fill = Panel.new()
	_track_fill.position = Vector2(90, 1301)
	_track_fill.size = Vector2(0, 14)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(1.0, 0.78, 0.28)
	fill_sb.set_corner_radius_all(7)
	_track_fill.add_theme_stylebox_override("panel", fill_sb)
	_track_fill.z_index = 8
	_track_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(_track_fill)
	_track_handle = Panel.new()
	_track_handle.position = Vector2(82, 1296)
	_track_handle.size = Vector2(18, 24)
	var handle_sb := StyleBoxFlat.new()
	handle_sb.bg_color = Color(1.0, 0.88, 0.48)
	handle_sb.set_corner_radius_all(9)
	_track_handle.add_theme_stylebox_override("panel", handle_sb)
	_track_handle.z_index = 9
	_track_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(_track_handle)
	_time_lbl = Label.new()
	_time_lbl.position = Vector2(90, 1316)
	_time_lbl.size = Vector2(620, 24)
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.add_theme_font_size_override("font_size", 14)
	_time_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_time_lbl.z_index = 7
	_viewer.add_child(_time_lbl)
	_play_btn = UiComponents.make_primary_button("⏸ 暂停", _toggle_play, Vector2(150, 50))
	_play_btn.position = Vector2(150, 1348)
	_play_btn.z_index = 8
	_viewer.add_child(_play_btn)
	_speed_btn = UiComponents.make_secondary_button("速度 1×", _cycle_speed, Vector2(130, 50))
	_speed_btn.position = Vector2(320, 1348)
	_speed_btn.z_index = 8
	_viewer.add_child(_speed_btn)
	var list_btn := UiComponents.make_secondary_button("← 列表", _close_viewer, Vector2(130, 50))
	list_btn.position = Vector2(470, 1348)
	list_btn.z_index = 8
	_viewer.add_child(list_btn)
	_update_hands()
	_update_elixir()
	_update_time()
	if _snapshot_mode:
		_apply_snapshot_at(0.0)

func _toggle_play():
	if _battle == null:
		return
	if _ended:
		_restart()
		return
	_playing = not _playing
	if not _snapshot_mode:
		_battle.process_mode = Node.PROCESS_MODE_INHERIT if _playing else Node.PROCESS_MODE_DISABLED
	_play_btn.text = "⏸ 暂停" if _playing else "▶ 播放"

func _restart():
	_close_viewer()
	_open_replay(_data)

func _on_scrub(v: float):
	if not _snapshot_mode or _scrub_guard:
		return
	_play_t = clampf(v, 0.0, _duration)
	_playing = false
	_play_btn.text = "▶ 播放"
	_seeking = true
	_next_emote = 0
	for ch in _emote_layer.get_children():
		ch.queue_free()
	_apply_snapshot_at(_play_t)
	_seeking = false

func _cycle_speed():
	var speeds: Array = [0.5, 1.0, 2.0, 4.0, 8.0]
	var idx: int = 1
	for i in range(speeds.size()):
		if is_equal_approx(float(speeds[i]), _speed):
			idx = i
			break
	idx = (idx + 1) % speeds.size()
	_speed = float(speeds[idx])
	if not _snapshot_mode:
		Engine.time_scale = _speed
	if _speed < 1.0:
		_speed_btn.text = "速度 %.1f×" % _speed
	else:
		_speed_btn.text = "速度 %d×" % int(_speed)

func _close_viewer():
	_playing = false
	Engine.time_scale = 1.0
	_visual_units.clear()
	_visual_bullets.clear()
	_visual_spells.clear()
	_visual_beams.clear()
	_visual_chains.clear()
	if _battle:
		_battle.queue_free()
		_battle = null
	if _viewer:
		_viewer.queue_free()
		_viewer = null
	_bg.visible = true
	if _bg_layer: _bg_layer.visible = true
	if _menu_backdrop: _menu_backdrop.visible = true
	_list_scroll.visible = true
	_info.visible = true
	_refresh_btn.visible = true
	_gen_btn.visible = true

func _hide_hud_except_bars():
	if _battle == null or _battle.hud == null:
		return
	var hb = _battle.hud.health_bar_container
	for ch in _battle.hud.get_children():
		ch.visible = (ch == hb)


func _process(_delta):
	if _viewer == null or _battle == null:
		return
	_hide_hud_except_bars()
	if not _playing:
		return
	if _snapshot_mode:
		_process_snapshot(_delta)
		return
	var now := float(_battle.game_time / 1000.0)
	while _next_action < _actions.size():
		var a: Dictionary = _actions[_next_action]
		if float(a.get("t", 0.0)) > now:
			break
		_apply_action(a)
		_next_action += 1
	_update_elixir()
	_update_time()
	_sync_emotes(now)
	if _battle.game_over or now >= _duration:
		_ended = true
		_playing = false
		_play_btn.text = "▶ 重播"
		_progress.set_value_no_signal(minf(_duration, now))
		_battle.process_mode = Node.PROCESS_MODE_DISABLED

func _process_snapshot(delta: float) -> void:
	_play_t += delta * _speed
	if _play_t >= _duration:
		_play_t = _duration
		_playing = false
		_ended = true
		_play_btn.text = "▶ 重播"
	_apply_snapshot_at(_play_t)

func _apply_snapshot_at(t: float) -> void:
	if _snapshots.is_empty():
		return
	var before: Dictionary = _snapshots[0]
	var after: Dictionary = _snapshots[_snapshots.size() - 1]
	for i in range(_snapshots.size() - 1):
		var a: Dictionary = _snapshots[i]
		var b: Dictionary = _snapshots[i + 1]
		if t >= float(a.get("t", 0.0)) and t <= float(b.get("t", 0.0)):
			before = a
			after = b
			break
	var ta: float = float(before.get("t", 0.0))
	var tb: float = float(after.get("t", 0.0))
	var alpha: float = 0.0 if tb <= ta else clampf((t - ta) / (tb - ta), 0.0, 1.0)
	# 手牌（取前一帧，避免瞬移）
	var hs: Array = before.get("hands", [])
	for team in [0, 1]:
		if team < hs.size():
			var hh: Array = hs[team]
			if hh != _hands[team]:
				_hands[team] = hh.duplicate()
				_update_hands()
	# 圣水
	var e0: Array = before.get("elixir", [7.0, 5.0])
	var e1: Array = after.get("elixir", e0)
	for team in [0, 1]:
		_snap_elixir[team] = lerpf(float(e0[team] if team < e0.size() else 7.0), float(e1[team] if team < e1.size() else 7.0), alpha)
	_update_elixir()
	# 塔血
	var tw0: Array = before.get("towers", [])
	var tw1: Array = after.get("towers", tw0)
	_sync_towers(tw0, tw1, alpha)
	# 单位
	var pu: Dictionary = {}
	var nu: Dictionary = {}
	for u in before.get("units", []):
		pu[int(u.get("id", 0))] = u
	for u in after.get("units", []):
		nu[int(u.get("id", 0))] = u
	var ids: Dictionary = {}
	for id in pu.keys(): ids[id] = true
	for id in nu.keys(): ids[id] = true
	for id in ids.keys():
		var a: Dictionary = pu.get(id, nu.get(id))
		var b: Dictionary = nu.get(id, a)
		var u = _visual_units.get(id)
		if u == null or not is_instance_valid(u):
			u = _spawn_snapshot_unit(b)
			if u:
				_visual_units[id] = u
		if u:
			var ax: float = float(a.get("x", 0.0)); var bx: float = float(b.get("x", 0.0))
			var ay: float = float(a.get("y", 0.0)); var by: float = float(b.get("y", 0.0))
			var az: float = float(a.get("z", 0.0)); var bz: float = float(b.get("z", 0.0))
			u.global_position = Vector3(lerpf(ax, bx, alpha), lerpf(ay, by, alpha), lerpf(az, bz, alpha))
			var h0: float = float(a.get("hp", 1.0)); var h1: float = float(b.get("hp", h0))
			u.health = lerpf(h0, h1, alpha)
			u.max_health = maxf(1.0, float(b.get("max_hp", u.max_health)))
			_apply_visual_state(u, a, b, alpha)
	for id in _visual_units.keys():
		if not ids.has(id):
			var u = _visual_units[id]
			if is_instance_valid(u):
				if _seeking:
					_remove_replay_shadow(u)
					if _battle.hud:
						_battle.hud.remove_health_bar(u)
					u.queue_free()
				else:
					_play_unit_death(u)
			var bd = u.get_meta("beam_target", null) if is_instance_valid(u) else null
			if bd and is_instance_valid(bd):
				bd.free()
			_visual_units.erase(id)
	_sync_effects(before, after, alpha)
	_sync_native_effects(before, after, alpha)
	_sync_emotes(t)
	_update_time()

func _apply_visual_state(u, a: Dictionary, b: Dictionary, alpha: float) -> void:
	if u.visual_root == null:
		return
	var ra: Array = a.get("rot", [0.0, 0.0, 0.0])
	var rb: Array = b.get("rot", ra)
	var pa: Array = a.get("vpos", [0.0, 0.0, 0.0])
	var pb: Array = b.get("vpos", pa)
	var sa: Array = a.get("vscale", [1.0, 1.0, 1.0])
	var sb: Array = b.get("vscale", sa)
	u.visual_root.rotation = Vector3(
		lerpf(float(ra[0]), float(rb[0]), alpha),
		lerp_angle(float(ra[1]), float(rb[1]), alpha),
		lerpf(float(ra[2]), float(rb[2]), alpha))
	u.visual_root.position = Vector3(
		lerpf(float(pa[0]), float(pb[0]), alpha),
		lerpf(float(pa[1]), float(pb[1]), alpha),
		lerpf(float(pa[2]), float(pb[2]), alpha))
	u.visual_root.scale = Vector3(
		lerpf(float(sa[0]), float(sb[0]), alpha),
		lerpf(float(sa[1]), float(sb[1]), alpha),
		lerpf(float(sa[2]), float(sb[2]), alpha))
	_force_unit_shadow(u)
	if u.body_mesh:
		var bp0: Array = a.get("body_pos", [0.0, 0.0, 0.0])
		var bp1: Array = b.get("body_pos", bp0)
		var br0: Array = a.get("body_rot", [0.0, 0.0, 0.0])
		var br1: Array = b.get("body_rot", br0)
		var bs0: Array = a.get("body_scale", [1.0, 1.0, 1.0])
		var bs1: Array = b.get("body_scale", bs0)
		u.body_mesh.position = Vector3(lerpf(float(bp0[0]), float(bp1[0]), alpha), lerpf(float(bp0[1]), float(bp1[1]), alpha), lerpf(float(bp0[2]), float(bp1[2]), alpha))
		u.body_mesh.rotation = Vector3(lerpf(float(br0[0]), float(br1[0]), alpha), lerpf(float(br0[1]), float(br1[1]), alpha), lerpf(float(br0[2]), float(br1[2]), alpha))
		u.body_mesh.scale = Vector3(lerpf(float(bs0[0]), float(bs1[0]), alpha), lerpf(float(bs0[1]), float(bs1[1]), alpha), lerpf(float(bs0[2]), float(bs1[2]), alpha))
		for leg_name in ["LegL", "LegR", "Weapon"]:
			var leg = u.body_mesh.get_node_or_null(leg_name) as Node3D
			if leg:
				var lr0: Array = a.get("%s_rot" % leg_name, [0.0, 0.0, 0.0])
				var lr1: Array = b.get("%s_rot" % leg_name, lr0)
				leg.rotation = Vector3(lerpf(float(lr0[0]), float(lr1[0]), alpha), lerpf(float(lr0[1]), float(lr1[1]), alpha), lerpf(float(lr0[2]), float(lr1[2]), alpha))
		var turret = u.body_mesh.get_node_or_null("Turret") as Node3D
		if turret:
			if b.has("turret_pos"):
				var tp0: Array = a.get("turret_pos", b.get("turret_pos", [0,0,0]))
				var tp1: Array = b.get("turret_pos", tp0)
				turret.position = Vector3(lerpf(float(tp0[0]),float(tp1[0]),alpha), lerpf(float(tp0[1]),float(tp1[1]),alpha), lerpf(float(tp0[2]),float(tp1[2]),alpha))
			if b.has("turret_rot"):
				var tr0: Array = a.get("turret_rot", b.get("turret_rot", [0,0,0]))
				var tr1: Array = b.get("turret_rot", tr0)
				turret.rotation = Vector3(lerpf(float(tr0[0]),float(tr1[0]),alpha), lerpf(float(tr0[1]),float(tr1[1]),alpha), lerpf(float(tr0[2]),float(tr1[2]),alpha))
			if b.has("turret_scale"):
				var ts0: Array = a.get("turret_scale", b.get("turret_scale", [1,1,1]))
				var ts1: Array = b.get("turret_scale", ts0)
				turret.scale = Vector3(lerpf(float(ts0[0]),float(ts1[0]),alpha), lerpf(float(ts0[1]),float(ts1[1]),alpha), lerpf(float(ts0[2]),float(ts1[2]),alpha))
			if b.has("turret_visible"):
				turret.visible = bool(b.get("turret_visible", true))
		for pname in ["u_flash", "u_freeze", "u_poison", "u_dark", "u_curse", "u_rage", "u_slow"]:
			if b.has(pname):
				var v: float = lerpf(float(a.get(pname, 0.0)), float(b.get(pname, 0.0)), alpha)
				u.body_mesh.set_instance_shader_parameter(pname, v)

func _sync_effects(before: Dictionary, after: Dictionary, alpha: float) -> void:
	var b0: Dictionary = {}
	var b1: Dictionary = {}
	for e in before.get("bullets", []): b0[int(e.get("id", 0))] = e
	for e in after.get("bullets", []): b1[int(e.get("id", 0))] = e
	var bids: Dictionary = {}
	for id in b0.keys(): bids[id] = true
	for id in b1.keys(): bids[id] = true
	for id in bids.keys():
		var e: Dictionary = b1.get(id, b0.get(id))
		var vb = _visual_bullets.get(id)
		if vb == null or not is_instance_valid(vb):
			vb = _spawn_visual_bullet(e)
			if vb:
				_visual_bullets[id] = vb
		if vb:
			var a: Dictionary = b0.get(id, e)
			vb.global_position = Vector3(
				lerpf(float(a.get("x", 0)), float(e.get("x", 0)), alpha),
				lerpf(float(a.get("y", 0)), float(e.get("y", 0)), alpha),
				lerpf(float(a.get("z", 0)), float(e.get("z", 0)), alpha))
			var r0: Array = a.get("rot", [0, 0, 0])
			var r1: Array = e.get("rot", r0)
			if vb.model_mesh:
				vb.model_mesh.rotation = Vector3(lerpf(float(r0[0]), float(r1[0]), alpha), lerpf(float(r0[1]), float(r1[1]), alpha), lerpf(float(r0[2]), float(r1[2]), alpha))
			if vb._shadow:
				vb._shadow.visible = true
				vb._update_visual_grounding()
	for id in _visual_bullets.keys():
		if not bids.has(id):
			var vb = _visual_bullets[id]
			if is_instance_valid(vb):
				_remove_replay_shadow(vb)
				vb.queue_free()
			_visual_bullets.erase(id)
	# spells
	var s0: Dictionary = {}
	var s1: Dictionary = {}
	for e in before.get("spells", []): s0[int(e.get("id", 0))] = e
	for e in after.get("spells", []): s1[int(e.get("id", 0))] = e
	var sids: Dictionary = {}
	for id in s0.keys(): sids[id] = true
	for id in s1.keys(): sids[id] = true
	for id in sids.keys():
		var e: Dictionary = s1.get(id, s0.get(id))
		var vs = _visual_spells.get(id)
		if vs == null or not is_instance_valid(vs):
			vs = _spawn_visual_spell(e)
			if vs:
				_visual_spells[id] = vs
		if vs:
			var a: Dictionary = s0.get(id, e)
			vs.global_position = Vector3(
				lerpf(float(a.get("x", 0)), float(e.get("x", 0)), alpha),
				lerpf(float(a.get("y", 0)), float(e.get("y", 0)), alpha),
				lerpf(float(a.get("z", 0)), float(e.get("z", 0)), alpha))
			var prog: float = lerpf(float(a.get("progress", 0)), float(e.get("progress", 0)), alpha)
			vs.elapsed_time = prog * maxf(0.05, float(vs.max_duration) / 50.0)
			if vs.vfx:
				SPELL_VFX.animate(vs.vfx, prog, vs.elapsed_time)
	for id in _visual_spells.keys():
		if not sids.has(id):
			var vs = _visual_spells[id]
			if is_instance_valid(vs): vs.queue_free()
			_visual_spells.erase(id)

func _spawn_visual_bullet(d: Dictionary):
	var cfg = _battle.get_config(int(d.get("card_id", -1))) if _battle else null
	if cfg == null: return null
	var b = Bullet.new()
	b.config = cfg
	b.team = int(d.get("team", 0))
	var kind := String(d.get("kind", ""))
	if kind == "" or kind == "normal":
		match String(d.get("weapon", "")):
			"bow": kind = "arrow"
			"musket": kind = "musket"
			"staff": kind = "fireball"
			"cannon", "mortar": kind = "cannonball"
			"crossbow": kind = "arrow"
			"spear": kind = "spear"
			"flask": kind = "potion"
			_: kind = "arrow"
	b.force_bullet_kind = kind
	b.position = Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
	_battle.bullets.add_child(b)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.set_process(false)
	b.set_physics_process(false)
	return b

func _spawn_visual_spell(d: Dictionary):
	var cfg = _battle.get_config(int(d.get("card_id", -1))) if _battle else null
	if cfg == null: return null
	var s = Spell.create(Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0))), int(d.get("team", 0)), 0.0, maxf(0.5, cfg.damage_range), 1, cfg.attack_type, cfg.target_type)
	s.card_id = int(d.get("card_id", -1))
	_battle.spells.add_child(s)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	s.set_process(false)
	s.set_physics_process(false)
	return s

func _play_unit_death(u) -> void:
	if _battle == null or not is_instance_valid(u):
		return
	if u.config and u.config.card_id <= 3:
		_play_tower_death(u)
		return
	_remove_replay_shadow(u)
	if _battle.hud:
		_battle.hud.remove_health_bar(u)
	# 允许死亡 tween 运行，但仍禁止单位逻辑更新
	u.process_mode = Node.PROCESS_MODE_INHERIT
	u.set_process(false)
	u.set_physics_process(false)
	if u.config and u.config.damage_range >= 0.5:
		u._play_death_explosion()
	u._play_elixir_death()

func _play_tower_death(u) -> void:
	if not is_instance_valid(u):
		return
	_remove_replay_shadow(u)
	if _battle.hud:
		_battle.hud.remove_health_bar(u)
	u._play_tower_destruction()
	if u.visual_root:
		u.visual_root.visible = false
	u.visible = false
	if u.config and u.config.card_id == 3 and _battle.network_guest_mode:
		_play_client_king_sequence(u)

func _play_client_king_sequence(king) -> void:
	if _king_seq or _battle == null:
		return
	_king_seq = true
	var tower_team: int = int(king.team)
	var winner: int = 1 - tower_team
	var crowns: Array = []
	if _battle.hud:
		_battle.hud.hide_card_tray()
	for other in _battle.units.get_children():
		if not (other is Unit) or other.team != tower_team:
			continue
		if other.config and (int(other.config.card_id) == 1 or int(other.config.card_id) == 2) and other.health > 0.0:
			other._play_tower_destruction()
			if other.visual_root:
				other.visual_root.visible = false
			other.visible = false
			if _battle.hud:
				_battle.hud.remove_health_bar(other)
			crowns.append(other.global_position + Vector3.UP * 1.2)
	crowns.append(king.global_position + Vector3.UP * 0.6)
	await get_tree().create_timer(0.9).timeout
	var cam = _battle.get_node_or_null("Camera3D") if _battle else null
	if cam is Camera3D:
		var tw := create_tween()
		tw.tween_property(cam, "size", cam.size + 9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if _battle.hud:
		for cp in crowns:
			_battle.hud.fly_crown(cp, winner)
		var c0: int = 3 if winner == 0 else 0
		var c1: int = 3 if winner == 1 else 0
		_battle.hud.update_crown_labels(c0, c1)
	await get_tree().create_timer(0.5).timeout
	_king_seq = false
	king_sequence_finished.emit()

func _force_unit_shadow(u) -> void:
	if u == null or not is_instance_valid(u):
		return
	if u.contact_shadow:
		u.contact_shadow.visible = u.health > 0.0
		u.contact_shadow.global_position = Vector3(u.global_position.x - 0.30, 0.025, u.global_position.z + 0.36)

func _remove_replay_shadow(_node) -> void:
	pass

func _beam_mat(lightning: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.82, 1.0, 0.9) if lightning else Color(1.0, 0.42, 0.10, 0.9)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.82, 1.0) if lightning else Color(1.0, 0.45, 0.10)
	m.emission_energy_multiplier = 2.3
	return m

func _set_segment(node: MeshInstance3D, from: Vector3, to: Vector3, radius: float) -> void:
	var d: Vector3 = to - from
	var ln: float = d.length()
	if ln < 0.02:
		node.visible = false
		return
	node.visible = true
	var y: Vector3 = d.normalized()
	var axis: Vector3 = Vector3.UP.cross(y)
	var basis := Basis.IDENTITY
	if axis.length() > 0.0001:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(y))
	node.global_transform = Transform3D(basis, (from + to) * 0.5)
	node.scale = Vector3(radius, ln, radius)

func _make_beam_root(lightning: bool) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	_battle.add_child(root)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = _beam_mat(lightning)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.set_meta("segments", [mi])
	return root

func _sync_native_effects(before: Dictionary, after: Dictionary, alpha: float) -> void:
	var bu: Dictionary = {}
	var au: Dictionary = {}
	for u in before.get("units", []): bu[int(u.get("id", 0))] = u
	for u in after.get("units", []): au[int(u.get("id", 0))] = u
	var ids: Dictionary = {}
	for id in bu.keys(): ids[id] = true
	for id in au.keys(): ids[id] = true
	for id in ids.keys():
		var u = _visual_units.get(id)
		if u == null or not is_instance_valid(u) or u.inferno_beam == null:
			continue
		var a: Dictionary = bu.get(id, au.get(id))
		var b: Dictionary = au.get(id, a)
		var bd = b.get("beam", a.get("beam"))
		var cp = b.get("chain", a.get("chain"))
		if bd or cp:
			var dummy = u.get_meta("beam_target", null)
			if dummy == null or not is_instance_valid(dummy):
				dummy = Unit.new()
				dummy.config = u.config
				dummy.team = u.team
				u.set_meta("beam_target", dummy)
			var to: Vector3 = u.global_position
			if bd:
				var f0: Array = a.get("beam", {}).get("from", bd.get("from", [0,0,0]))
				var t0: Array = a.get("beam", {}).get("to", bd.get("to", [0,0,0]))
				var f1: Array = b.get("beam", {}).get("from", f0)
				var t1: Array = b.get("beam", {}).get("to", t0)
				to = Vector3(lerpf(float(t0[0]), float(t1[0]), alpha), lerpf(float(t0[1]), float(t1[1]), alpha), lerpf(float(t0[2]), float(t1[2]), alpha))
			elif cp and cp.size() >= 2:
				var last: Array = cp[cp.size() - 1]
				to = Vector3(float(last[0]), float(last[1]), float(last[2]))
			dummy.global_position = to - Vector3.UP * 0.55
			if cp:
				if u._chain_fx == null:
					u._ensure_chain_fx()
				var pts: Array = []
				for p2 in cp:
					pts.append(Vector3(float(p2[0]), float(p2[1]), float(p2[2])))
				u._chain_points = pts
				u._chain_until = Time.get_ticks_msec() + 350
				u.inferno_beam.visible = false
				u._update_chain_fx()
			else:
				u.target = dummy
				u._chain_points = []
				u._update_beam()
		else:
			u.inferno_beam.visible = false
			if u._chain_fx:
				u._chain_fx.visible = false

func _sync_special_effects(before: Dictionary, after: Dictionary, alpha: float) -> void:
	var bu: Dictionary = {}
	var au: Dictionary = {}
	for u in before.get("units", []): bu[int(u.get("id", 0))] = u
	for u in after.get("units", []): au[int(u.get("id", 0))] = u
	var ids: Dictionary = {}
	for id in bu.keys(): ids[id] = true
	for id in au.keys(): ids[id] = true
	for id in ids.keys():
		var a: Dictionary = bu.get(id, au.get(id))
		var b: Dictionary = au.get(id, a)
		var bd = b.get("beam", a.get("beam"))
		if bd:
			var root = _visual_beams.get(id)
			if root == null or not is_instance_valid(root):
				root = _make_beam_root(bool(bd.get("lightning", false)))
				_visual_beams[id] = root
			var f0: Array = a.get("beam", {}).get("from", bd.get("from", [0,0,0]))
			var t0: Array = a.get("beam", {}).get("to", bd.get("to", [0,0,0]))
			var f1: Array = b.get("beam", {}).get("from", f0)
			var t1: Array = b.get("beam", {}).get("to", t0)
			var from := Vector3(lerpf(float(f0[0]), float(f1[0]), alpha), lerpf(float(f0[1]), float(f1[1]), alpha), lerpf(float(f0[2]), float(f1[2]), alpha))
			var to := Vector3(lerpf(float(t0[0]), float(t1[0]), alpha), lerpf(float(t0[1]), float(t1[1]), alpha), lerpf(float(t0[2]), float(t1[2]), alpha))
			var segs: Array = root.get_meta("segments")
			if segs.size() > 0:
				_set_segment(segs[0], from, to, 0.075)
		else:
			var root = _visual_beams.get(id)
			if root:
				if is_instance_valid(root): root.queue_free()
				_visual_beams.erase(id)
		var cp = b.get("chain", a.get("chain"))
		if cp and cp.size() >= 2:
			var cr = _visual_chains.get(id)
			if cr == null or not is_instance_valid(cr) or int(cr.get_meta("point_count", 0)) != cp.size():
				if cr and is_instance_valid(cr): cr.queue_free()
				cr = Node3D.new()
				cr.top_level = true
				cr.set_meta("point_count", cp.size())
				_battle.add_child(cr)
				var segs: Array = []
				for i in range(cp.size() - 1):
					var mi := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = 1.0
					cyl.bottom_radius = 1.0
					cyl.height = 1.0
					cyl.radial_segments = 8
					mi.mesh = cyl
					mi.material_override = _beam_mat(true)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					cr.add_child(mi)
					segs.append(mi)
				cr.set_meta("segments", segs)
				_visual_chains[id] = cr
			var segs2: Array = cr.get_meta("segments")
			for i in range(segs2.size()):
				var p0: Array = cp[i]
				var p1: Array = cp[i + 1]
				_set_segment(segs2[i], Vector3(float(p0[0]), float(p0[1]), float(p0[2])), Vector3(float(p1[0]), float(p1[1]), float(p1[2])), 0.045)
		else:
			var cr = _visual_chains.get(id)
			if cr:
				if is_instance_valid(cr): cr.queue_free()
				_visual_chains.erase(id)
	for id in _visual_beams.keys():
		if not ids.has(id):
			var root = _visual_beams[id]
			if is_instance_valid(root): root.queue_free()
			_visual_beams.erase(id)
	for id in _visual_chains.keys():
		if not ids.has(id):
			var cr = _visual_chains[id]
			if is_instance_valid(cr): cr.queue_free()
			_visual_chains.erase(id)

func _spawn_snapshot_unit(d: Dictionary):
	var cfg = _battle.get_config(int(d.get("card_id", -1))) if _battle else null
	if cfg == null:
		return null
	var team: int = int(d.get("team", 0))
	var lv: int = int(d.get("level", 0))
	var pos := Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	var u = _battle.spawn_unit(cfg, team, pos, 1, lv, null, false, true)
	if u:
		u.process_mode = Node.PROCESS_MODE_DISABLED
		if u._spawn_tween:
			u._spawn_tween.kill()
		u.deploy_cooldown = 0.0
		u.max_deploy_cooldown = 0.0
		u.health = float(d.get("hp", u.health))
		u.max_health = maxf(1.0, float(d.get("max_hp", u.max_health)))
		if bool(d.get("king_duo", false)):
			u.king_duo = true
			u.apply_king_duo_visual()
	return u

func _sync_towers(t0: Array, t1: Array, alpha: float) -> void:
	if _battle == null:
		return
	var mid_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	var max_hp := {}
	for tw in _battle.replay_towers:
		max_hp["%d_%d" % [int(tw.get("team", 0)), int(tw.get("card_id", 1))]] = float(tw.get("max_health", 7000.0))
	for u in _battle.units.get_children():
		if not (u is Unit) or u.config == null or u.config.card_id > 3:
			continue
		var team: int = int(u.team)
		var cid: int = int(u.config.card_id)
		var slot: int = 2 if cid == 3 else (0 if u.global_position.x < mid_x else 1)
		var idx: int = team * 3 + slot
		var h0: float = float(t0[idx]) if idx < t0.size() else u.health
		var h1: float = float(t1[idx]) if idx < t1.size() else h0
		u.health = lerpf(h0, h1, alpha)
		var key := "%d_%d" % [team, cid]
		if max_hp.has(key):
			u.max_health = max_hp[key]
		if _battle.healths.size() > idx:
			_battle.healths[idx] = u.health
		_force_unit_shadow(u)
		if h1 > 0.0:
			if not u.visible or (u.visual_root and not u.visual_root.visible):
				u.visible = true
				if u.visual_root:
					u.visual_root.visible = true
				if _battle.hud:
					_battle.hud.add_health_bar(u)
			_destroyed_towers.erase(idx)
			_force_unit_shadow(u)
		elif h1 <= 0.0:
			if u.visible:
				if not _seeking and h0 > 0.0:
					_destroyed_towers[idx] = true
					_play_tower_death(u)
				else:
					u.visible = false
					if u.visual_root:
						u.visual_root.visible = false
					if _battle.hud:
						_battle.hud.remove_health_bar(u)
			_destroyed_towers[idx] = true

func _apply_action(a: Dictionary):
	var team: int = int(a.get("team", 1))
	var card_id: int = int(a.get("card_id", -1))
	var cfg = _battle.get_config(card_id)
	if cfg == null:
		return
	var pos := Vector3(float(a.get("x", 0.0)), 0.0, float(a.get("z", 0.0)))
	var lv: int = int(_levels.get(team, {}).get(str(card_id), 0))
	if lv <= 0:
		lv = PlayerData.get_card_level(card_id) if team == Config.Team.PLAYER else PlayerData.ai_level(card_id)
	if _battle.SPELL_IDS.has(card_id):
		_battle.deploy_spell(cfg, team, pos, lv)
	elif card_id == 109:
		_battle._deploy_miner_tunnel(cfg, team, pos)
	elif card_id == 110:
		_battle._deploy_log_like(cfg, team, pos, lv)
	else:
		_battle.spawn_unit(cfg, team, pos, -1, lv)
	var cost: int = _battle.card_cost(cfg)
	if team == Config.Team.PLAYER:
		_battle.player_elixir = maxf(0.0, _battle.player_elixir - cost)
	else:
		_battle.enemy_elixir = maxf(0.0, _battle.enemy_elixir - cost)
	if card_id != 123:
		_battle.last_played_card_id = card_id
	_cycle_hand(team, card_id)
	_update_hands()

func _cycle_hand(team: int, card_id: int):
	var hand: Array = _hands[team]
	var deck: Array = _decks[team]
	var idx := -1
	for i in range(hand.size()):
		if int(hand[i]) == card_id:
			idx = i
			break
	if idx < 0:
		return
	hand.remove_at(idx)
	deck.append(card_id)
	if not deck.is_empty():
		hand.append(deck.pop_front())
	_update_hands()

func _update_hands():
	for t in [0, 1]:
		var box: HBoxContainer = _hand_boxes.get(t)
		if box == null:
			continue
		for ch in box.get_children():
			ch.queue_free()
		var hand: Array = _hands[t]
		for i in range(4):
			var cid: int = int(hand[i]) if i < hand.size() else -1
			box.add_child(_mini_card(cid, t))
	_update_hand_scan()

func _mini_card(cid: int, team: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(88, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.14)
	sb.border_color = Color(0.35, 0.66, 1.0, 0.8) if team == 0 else Color(1.0, 0.38, 0.36, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	if cid > 0:
		var cfg = _battle.get_config(cid) if _battle else null
		if cfg:
			var name := String(cfg.card_name)
			var tex := _portrait(name)
			if tex:
				var img := TextureRect.new()
				img.texture = tex
				var scan := ShaderMaterial.new()
				scan.shader = CARD_SCAN
				scan.set_shader_parameter("progress", 1.0)
				img.material = scan
				p.set_meta("scan_mat", scan)
				p.set_meta("scan_cost", maxi(1, int(cfg.cost)))
				p.set_meta("scan_team", team)
				img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				img.offset_left = 3
				img.offset_top = 3
				img.offset_right = -3
				img.offset_bottom = -20
				img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				img.mouse_filter = Control.MOUSE_FILTER_IGNORE
				p.add_child(img)
			var lbl := Label.new()
			lbl.text = name
			lbl.position = Vector2(3, 76)
			lbl.size = Vector2(82, 18)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
			lbl.clip_text = true
			p.add_child(lbl)
			var lv: int = int(_levels.get(team, {}).get(str(cid), 0))
			if lv > 0:
				var lv_lbl := Label.new()
				lv_lbl.text = "Lv.%d" % lv
				lv_lbl.position = Vector2(48, 2)
				lv_lbl.size = Vector2(38, 16)
				lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lv_lbl.add_theme_font_size_override("font_size", 10)
				lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
				lv_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
				lv_lbl.add_theme_constant_override("shadow_offset_x", 1)
				lv_lbl.add_theme_constant_override("shadow_offset_y", 1)
				p.add_child(lv_lbl)
	p.set_meta("replay_card_id", cid)
	if live_mode and cid >= 0:
		p.gui_input.connect(_on_live_card_input.bind(cid))
	return p

func _portrait(card_name: String) -> Texture2D:
	if _tex_cache.has(card_name):
		return _tex_cache[card_name]
	var path := "res://assets/cards_web/%s.png" % card_name
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % card_name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[card_name] = tex
	return tex

func _update_elixir():
	if _battle == null:
		return
	for t in [0, 1]:
		var v: float = _snap_elixir[t] if _snapshot_mode else (_battle.player_elixir if t == 0 else _battle.enemy_elixir)
		var bar = _elixir_bars.get(t)
		if bar:
			bar.value = v
		var l = _elixir_labels.get(t)
		if l:
			l.text = "圣水 %.1f" % v
	_update_hand_scan()

func _on_live_card_input(event: InputEvent, cid: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		live_selected_card = cid
		live_card_selected.emit(cid)

func _update_hand_scan() -> void:
	for team in [0, 1]:
		var box: HBoxContainer = _hand_boxes.get(team)
		if box == null:
			continue
		var elixir: float = _snap_elixir[team] if _snapshot_mode else (_battle.player_elixir if team == 0 and _battle else (_battle.enemy_elixir if _battle else 0.0))
		for card_panel in box.get_children():
			var mat = card_panel.get_meta("scan_mat", null)
			if mat == null:
				continue
			var cost: int = int(card_panel.get_meta("scan_cost", 1))
			var ratio: float = clampf(elixir / float(maxi(cost, 1)), 0.0, 1.0)
			mat.set_shader_parameter("progress", ratio)

func _sync_emotes(t: float) -> void:
	if _emote_layer == null:
		return
	while _next_emote < _emotes.size():
		var e: Dictionary = _emotes[_next_emote]
		if float(e.get("t", 0.0)) > t:
			break
		_next_emote += 1
		_show_replay_emote(String(e.get("id", "")), int(e.get("team", 0)))

func _show_replay_emote(id: String, team: int) -> void:
	if _emote_layer == null or id == "":
		return
	var is_enemy: bool = team == Config.Team.ENEMY
	var glyph: String = EMOTES.glyph(id)
	var l := Label.new()
	l.text = glyph
	l.add_theme_font_size_override("font_size", 72)
	var vp := get_viewport().get_visible_rect().size
	l.position = Vector2(vp.x * 0.5 - 44, 690) if not is_enemy else Vector2(vp.x - 210, 250)
	l.modulate = Color(1.0, 0.72, 0.72) if is_enemy else Color(1, 1, 1)
	l.z_index = 21
	_emote_layer.add_child(l)
	var tag := Label.new()
	tag.text = "对手" if is_enemy else "你"
	tag.position = l.position + Vector2(26, 78)
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55) if is_enemy else Color(0.7, 0.9, 1.0))
	tag.z_index = 21
	_emote_layer.add_child(tag)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.18, 1.18), 0.14).from(Vector2(0.3, 0.3))
	tw.parallel().tween_property(tag, "modulate:a", 1.0, 0.1)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(tag, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): l.queue_free(); tag.queue_free())

func _update_time():
	if _battle == null:
		return
	var now := minf(_play_t if _snapshot_mode else float(_battle.game_time / 1000.0), _duration)
	_time_lbl.text = "%d:%02d / %d:%02d" % [int(now) / 60, int(now) % 60, int(_duration) / 60, int(_duration) % 60]
	_scrub_guard = true
	_progress.set_value_no_signal(now)
	_scrub_guard = false
	var ratio: float = clampf(now / maxf(0.01, _duration), 0.0, 1.0)
	if _track_fill:
		_track_fill.size.x = 620.0 * ratio
	if _track_handle:
		_track_handle.position.x = 90.0 + 620.0 * ratio - 9.0

func _on_back_pressed():
	if _viewer:
		_close_viewer()
		return
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _exit_tree():
	Engine.time_scale = 1.0
