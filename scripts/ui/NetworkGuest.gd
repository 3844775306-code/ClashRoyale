extends Control

const CardVisualCatalog = preload("res://scripts/visuals/CardVisualCatalog.gd")
const UnitModelKit = preload("res://scripts/visuals/UnitModelKit.gd")

const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")

var _ru
var _opened := false
var _selected_card := -1
var _ghost: Node3D = null
var _ghost_red := false
var _pending: Array = []
var _status: Label
var _wait_t := 0.0
var _shot_taken := false
var _last_t := -1.0
var _spec_request_t := 0.0
var _result_layer: Control
var _emote_connected := false
var _result_active := false
var _guest_rec
var _live_snaps: Array = []
var _pending_result: Dictionary = {}
var _last_tower_hp: Array = []
var _entry_pending := false
var _stats_recorded := false
var _spectator := false
var _chat_log: RichTextLabel
var _chat_edit: LineEdit
var _spec_count_lbl: Label
var _chat_panel: Panel
var _chat_log_row: HBoxContainer
var _chat_emotes: HBoxContainer
var _chat_toggle: Button
var _chat_collapsed := false
var _chat_exit_btn: Button

func _ready():
	_spectator = NetworkManager.spectator_mode
	_status = Label.new()
	_status.position = Vector2(40, 40)
	_status.size = Vector2(720, 40)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_status.z_index = 50
	add_child(_status)
	if _spectator:
		LoadingScreen.show_loading("正在进入观战…")
		_chat_exit_btn = UiComponents.make_secondary_button("退出观战", func():
			NetworkManager.leave_spectate()
			NetworkManager.reset_net()
			get_tree().change_scene_to_file("res://scenes/network_lobby.tscn"), Vector2(150, 40))
		_chat_exit_btn.position = Vector2(610, 34)
		_chat_exit_btn.z_index = 60
		add_child(_chat_exit_btn)
		_build_spectator_chat()
	_ru = load("res://scenes/replay_ui.tscn").instantiate()
	_ru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ru)
	# 观战聊天必须压在回放 UI 之上，否则 ReplayUI 的全屏根节点会吞掉触摸
	if _chat_panel: _chat_panel.move_to_front()
	if _chat_exit_btn: _chat_exit_btn.move_to_front()
	await get_tree().process_frame
	_ru.live_mode = true
	_ru.live_card_selected.connect(_on_card_selected)
	NetworkManager.snapshot_received.connect(_on_snapshot)
	if PlayerData.record_replays and not _spectator:
		_guest_rec = preload("res://scripts/core/GuestReplayWriter.gd").new()
		add_child(_guest_rec)
		_guest_rec.start(NetworkManager.match_info)
	if not NetworkManager.last_snapshot.is_empty():
		_on_snapshot(NetworkManager.last_snapshot)
	NetworkManager.deploy_rejected.connect(func(reason): _status.text = "部署失败：%s" % reason)
	NetworkManager.disconnected.connect(_on_net_disconnected)
	NetworkManager.match_ended.connect(_on_match_ended)
	NetworkManager.match_started.connect(_on_rematch_start)
	NetworkManager.emote_received.connect(_on_net_emote)
	NetworkManager.countdown_received.connect(_on_countdown)
	NetworkManager.touchdown_break_received.connect(_on_touchdown_break)
	NetworkManager.touchdown_break_ended.connect(_on_touchdown_break_end)
	NetworkManager.entry_started.connect(_on_entry_started)
	_ru.king_sequence_finished.connect(_on_king_sequence_finished)
	set_process(true)

func _build_spectator_chat() -> void:
	_chat_panel = Panel.new()
	_chat_panel.position = Vector2(558, 92)
	_chat_panel.size = Vector2(232, 430)
	_chat_panel.z_index = 70
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.04, 0.08, 0.88)
	sb.border_color = Color(0.45, 0.65, 0.95, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	_chat_panel.add_theme_stylebox_override("panel", sb)
	add_child(_chat_panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 4)
	_chat_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	v.add_child(head)
	var title := UiComponents.make_section_title("观战聊天")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_spec_count_lbl = Label.new()
	_spec_count_lbl.text = "0人"
	_spec_count_lbl.add_theme_font_size_override("font_size", 11)
	_spec_count_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	head.add_child(_spec_count_lbl)
	_chat_toggle = UiComponents.make_secondary_button("收起", _toggle_spec_chat, Vector2(56, 28))
	head.add_child(_chat_toggle)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(0, 260)
	_chat_log.add_theme_font_size_override("normal_font_size", 11)
	v.add_child(_chat_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_chat_log_row = row
	v.add_child(row)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "说点什么…"
	_chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_edit.custom_minimum_size = Vector2(0, 30)
	_chat_edit.add_theme_font_size_override("font_size", 11)
	_chat_edit.text_submitted.connect(func(_t): _send_spec_chat())
	row.add_child(_chat_edit)
	row.add_child(UiComponents.make_secondary_button("发送", _send_spec_chat, Vector2(52, 30)))
	var emotes := HBoxContainer.new()
	emotes.add_theme_constant_override("separation", 3)
	_chat_emotes = emotes
	v.add_child(emotes)
	var catalog = preload("res://scripts/data/EmoteCatalog.gd")
	for i in range(mini(4, catalog.all().size())):
		var e: Dictionary = catalog.all()[i]
		var eid := String(e.id)
		var b := UiComponents.make_secondary_button(String(e.glyph), func(): NetworkManager.send_spectator_emote(eid), Vector2(46, 28))
		emotes.add_child(b)
	NetworkManager.spectator_chat.connect(_on_spec_chat)
	NetworkManager.spectator_emote.connect(_on_spec_emote)
	NetworkManager.spectator_count_changed.connect(_refresh_spec_count)
	_refresh_spec_count()


func _toggle_spec_chat() -> void:
	_chat_collapsed = not _chat_collapsed
	if _chat_log:
		_chat_log.visible = not _chat_collapsed
	if _chat_log_row:
		_chat_log_row.visible = not _chat_collapsed
	if _chat_emotes:
		_chat_emotes.visible = not _chat_collapsed
	if _chat_panel:
		_chat_panel.size.y = 48.0 if _chat_collapsed else 430.0
	if _chat_toggle:
		_chat_toggle.text = "展开" if _chat_collapsed else "收起"


func _send_spec_chat() -> void:
	if _chat_edit == null:
		return
	var text := _chat_edit.text.strip_edges()
	if text == "":
		return
	NetworkManager.send_spectator_chat(text)
	_chat_edit.text = ""


func _on_spec_chat(from_name: String, text: String) -> void:
	if _chat_log == null:
		return
	_chat_log.append_text("[color=#8fd6ff]%s[/color]：%s\n" % [from_name, text])


func _on_spec_emote(from_name: String, id: String) -> void:
	if _chat_log == null:
		return
	var glyph := String(preload("res://scripts/data/EmoteCatalog.gd").glyph(id))
	_chat_log.append_text("[color=#ffd45a]%s %s[/color]\n" % [from_name, glyph])
	var lbl := Label.new()
	lbl.text = glyph
	lbl.position = Vector2(420, 700)
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.z_index = 80
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", 560, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)


func _refresh_spec_count() -> void:
	if _spec_count_lbl:
		_spec_count_lbl.text = "%d人" % NetworkManager.spectator_count


func _process(delta):
	if not _opened:
		_wait_t += delta
		if _spectator:
			_spec_request_t += delta
			if _spec_request_t >= 2.5:
				_spec_request_t = 0.0
				NetworkManager.resend_spectate_request()
		if _wait_t > 5.0:
			_status.text = "等待房主发送对局…"
			if _wait_t > 8.0:
				LoadingScreen.hide_loading()
	else:
		if _last_t < 3.0:
			_status.text = "准备中… %d" % int(ceil(3.0 - _last_t))
		elif _spectator:
			_status.text = "观战中 · 仅观看，无法操作"
		else:
			_status.text = "拖动底部卡牌到战场部署"
		if OS.get_environment("CR_NET_GUEST_SHOT") != "" and not _shot_taken:
			_shot_taken = true
			await get_tree().create_timer(2.5).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png(OS.get_environment("CR_NET_GUEST_SHOT").get_basename() + "_a.png")
			print("NET guest screenshot saved")
			get_tree().quit()

func _on_snapshot(snap: Dictionary):
	if _guest_rec:
		_guest_rec.push(snap)
	if _result_active:
		return
	if _ru and _ru._king_seq:
		return
	var snap_t := float(snap.get("t", 0.0))
	if snap_t <= _last_t:
		return
	_last_t = snap_t
	if OS.get_environment("CR_NET_DEBUG") != "":
		print("NET guest snapshot t=", snap.get("t",0), " opened=", _opened)
	if not _opened:
		_opened = true
		LoadingScreen.hide_loading()
		var m0 := _mirror(snap)
		var data := _make_data(m0)
		_ru.live_mode = true
		_ru._open_replay(data)
		_ru.set_process(false)
		_ru._playing = false
		if _ru._play_btn:
			_ru._play_btn.visible = false
		if _ru._speed_btn:
			_ru._speed_btn.visible = false
		if _ru._time_lbl:
			_ru._time_lbl.visible = false
		_ru._play_t = 0.0
		_ru._snapshots = [m0]
		_live_snaps = [m0]
		_ru._apply_snapshot_at(0.0)
		_ru._sync_emotes(0.0)
		get_viewport().scaling_3d_scale = 0.72 if OS.has_feature("mobile") else 0.82
		_ru._battle.network_guest_mode = true
		_ru._battle.network_guest_mirrored = NetworkManager.local_team == 1
		_show_battle_hud()
		if not _emote_connected and _ru._battle.hud:
			_emote_connected = true
			var hud = _ru._battle.hud
			if hud.has_signal("emote_sent"):
				hud.emote_sent.connect(func(id, _t): NetworkManager.send_emote(id, NetworkManager.local_team))
		for ch in _ru.get_children():
			if ch is Control and ch != _ru._viewer:
				ch.visible = false
		for ch in _ru._viewer.get_children():
			if ch is Control:
				ch.visible = false
		_sync_guest_state(m0)
		if OS.get_environment("CR_NET_TEST_GUEST_DEPLOY") != "":
			call_deferred("_guest_test_deploy")
		NetworkManager.client_ready()
		LoadingScreen.hide_loading()
		if _entry_pending:
			call_deferred("_on_entry_started")
		if OS.get_environment("CR_NET_TEST_CLICK") != "":
			call_deferred("_guest_test_click")
		return
	var m := _mirror(snap)
	_live_snaps.append(m)
	while _live_snaps.size() > 4:
		_live_snaps.pop_front()
	_ru._snapshots = _live_snaps.duplicate()
	_ru._duration = maxf(_ru._duration, float(m.get("t", 0.0)) + 1.0)
	var target_t: float = maxf(0.0, float(m.get("t", 0.0)) - 0.10)
	if not _live_snaps.is_empty():
		target_t = maxf(target_t, float(_live_snaps[0].get("t", 0.0)))
	_ru._play_t = target_t
	_ru._apply_snapshot_at(target_t)
	_sync_guest_state(m)

func _on_entry_started() -> void:
	if not _opened:
		_entry_pending = true
		return
	LoadingScreen.hide_loading()
	if _ru and _ru._battle:
		await _ru._battle.play_entry_intro()

func _guest_test_click() -> void:
	print("NET guest test click start")
	await get_tree().create_timer(2.0).timeout
	var b = _ru._battle if _ru else null
	print("NET guest test click b=", b, " hand=", (b.player_hand.size() if b else -1))
	if b == null or b.player_hand.is_empty():
		return
	var card = b.player_hand[0]
	b.selected_card = card
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(400, 850)
	b._input(ev)
	print("NET guest test click card=", card.config.card_id)

func _guest_test_deploy() -> void:
	await get_tree().create_timer(1.5).timeout
	if _ru == null or _ru._hands.is_empty():
		return
	var hand: Array = _ru._hands.get(0, [])
	print("NET guest test deploy hands=", hand)
	if hand.is_empty():
		return
	var cz: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	var view_z := Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.72
	NetworkManager.request_deploy(int(hand[0]), 0.0, cz * 2.0 - view_z)
	_status.text = "测试部署 card=%d" % int(hand[0])

func _show_battle_hud() -> void:
	if _ru == null or _ru._battle == null or _ru._battle.hud == null:
		return
	var hud = _ru._battle.hud
	for ch in hud.get_children():
		if ch == hud.game_over_panel or ch == hud.pause_panel or ch == hud.emote_panel:
			ch.visible = false
		else:
			ch.visible = true
	if hud.card_container:
		hud.card_container.visible = true

func _sync_guest_state(m: Dictionary) -> void:
	var b = _ru._battle
	if b == null:
		return
	var slot := NetworkManager.local_slot
	b.game_time = float(m.get("t", 0.0)) * 1000.0
	b.overtime = bool(m.get("overtime", false))
	b.tower_bleed_active = bool(m.get("tower_bleed_active", false))
	b.match_draw = bool(m.get("match_draw", false))
	var ph: Array = m.get("player_hands", [])
	var pe: Array = m.get("player_elixirs", [])
	var ex: Array = m.get("elixir", [5.0, 5.0])
	var pm: Array = m.get("player_max_elixirs", [])
	if slot < pm.size():
		b.player_max_elixir = float(pm[slot])
	if slot < pe.size():
		b.player_elixir = float(pe[slot])
	elif ex.size() >= 2:
		b.player_elixir = float(ex[0])
	var desired: Array = []
	if slot < ph.size():
		desired = Array(ph[slot]).duplicate()
	else:
		var hs0: Array = m.get("hands", [])
		if hs0.size() >= 1:
			desired = Array(hs0[NetworkManager.local_team if NetworkManager.local_team < hs0.size() else 0]).duplicate()
	# 空手牌兜底：若该快照为空但本地已有手牌，保留旧手牌，避免下一轮突然空牌
	if desired.is_empty():
		var hs1: Array = m.get("hands", [])
		var team_idx: int = NetworkManager.local_team
		if team_idx < hs1.size() and not Array(hs1[team_idx]).is_empty():
			desired = Array(hs1[team_idx]).duplicate()
	if _selected_card >= 0 and _ghost:
		_refresh_guest_ghost_red()
	if not desired.is_empty() or b.player_hand.is_empty():
		b.network_guest_sync_hand(desired)
	# 联机多人：给玩家卡桌上方显示队友手牌（精简版）
	if b.hud and b.hud.has_method("set_teammate_hand"):
		var team := NetworkManager.local_team
		var mate_slot: int = team * 2 + (1 - (int(NetworkManager.local_slot) % 2))
		if mate_slot < ph.size():
			var mate_elixir: float = float(pe[mate_slot]) if mate_slot < pe.size() else 5.0
			b.hud.set_teammate_hand(Array(ph[mate_slot]), mate_elixir)
		else:
			b.hud.set_teammate_hand([])
	var cs: Array = m.get("crowns", [0, 0])
	if cs.size() >= 2:
		b.player_crowns = int(cs[0])
		b.enemy_crowns = int(cs[1])
	var thp: Array = Array(m.get("towers", []))
	if thp.size() >= 6 and _last_tower_hp.size() >= 6 and not _ru._king_seq:
		for idx in [2, 5]:
			if float(_last_tower_hp[idx]) > 0.0 and float(thp[idx]) <= 0.0:
				var king_team: int = 0 if idx < 3 else 1
				for u in b.units.get_children():
					if u is Unit and u.config and int(u.config.card_id) == 3 and int(u.team) == king_team:
						_ru._play_client_king_sequence(u)
						break
	_last_tower_hp = thp.duplicate()
	b.touchdown_round = int(m.get("touchdown_round", 1))
	var ts: Array = m.get("touchdown_scores", [])
	if ts.size() >= 2:
		b.touchdown_score = [int(ts[0]), int(ts[1])]
		if b.hud and b.hud.has_method("set_touchdown_score"):
			b.hud.set_touchdown_score(int(ts[0]), int(ts[1]), 3)
	_ru._update_elixir()

func _on_rematch_start(_info: Dictionary) -> void:
	if NetworkManager.role == NetworkManager.Role.GUEST:
		get_tree().change_scene_to_file("res://scenes/network_guest.tscn")

func _on_touchdown_break(round_no: int, score_a: int, score_b: int) -> void:
	if _ru == null or _ru._battle == null or _ru._battle.hud == null:
		return
	var sa := score_a
	var sb := score_b
	if NetworkManager.local_team == 1:
		sa = score_b
		sb = score_a
	var b = _ru._battle
	b.touchdown_round = round_no
	b.touchdown_score = [sa, sb]
	b.touchdown_resetting = true
	if b.hud.has_method("set_touchdown_score"):
		b.hud.set_touchdown_score(sa, sb, 3)
	if b.hud.has_method("show_touchdown_round_break"):
		b.hud.show_touchdown_round_break(round_no, sa, sb)


func _on_touchdown_break_end() -> void:
	if _ru == null or _ru._battle == null or _ru._battle.hud == null:
		return
	_ru._battle.touchdown_resetting = false
	if _ru._battle.hud.has_method("hide_touchdown_round_break"):
		_ru._battle.hud.hide_touchdown_round_break()


func _on_countdown(seconds: float) -> void:
	if _ru == null or _ru._battle == null or _ru._battle.hud == null:
		return
	var ov = preload("res://scripts/ui/CountdownOverlay.gd").new()
	_ru._battle.hud.add_child(ov)
	ov.start(seconds)

func _on_net_emote(id: String, team: int) -> void:
	if _guest_rec:
		_guest_rec.add_emote(id, team)
	if _ru and _opened and _ru._battle and _ru._battle.hud:
		_ru._battle.hud.show_emote(id, 1 - team)

func _on_net_disconnected(reason: String) -> void:
	_show_result("连接断开", reason, false)

func _on_match_ended(info: Dictionary) -> void:
	if _ru and _ru._king_seq:
		_result_active = true
		_pending_result = info
		return
	_show_match_result(info)

func _on_king_sequence_finished() -> void:
	if not _pending_result.is_empty():
		var info: Dictionary = _pending_result
		_pending_result = {}
		_show_match_result(info)

func _show_match_result(info: Dictionary) -> void:
	if _guest_rec:
		_guest_rec.finish()
	if not _spectator and not _stats_recorded and not PlayerData.test_mode:
		_stats_recorded = true
		var w := int(info.get("winner", -1))
		var win: bool = w == NetworkManager.local_team
		var draw: bool = w < 0
		var cs: Array = info.get("crowns", [0, 0])
		var my_c := int(cs[NetworkManager.local_team]) if cs.size() > NetworkManager.local_team else 0
		var en_c := int(cs[1 - NetworkManager.local_team]) if cs.size() > 1 - NetworkManager.local_team else 0
		var extra: Dictionary = {}
		if _ru and _ru._battle and _ru._battle.has_method("_history_extra"):
			extra = _ru._battle._history_extra()
		PlayerData.record_battle_result(win and not draw, draw, my_c, en_c, String(_ru._battle.mode_name) if _ru and _ru._battle else "联机对战", float(info.get("duration", 0.0)), "对手", extra)
		if ProfileAPI:
			ProfileAPI.publish_self()
	_result_active = true
	if _ru and _ru._battle:
		var cam = _ru._battle.get_node_or_null("Camera3D")
		if cam is Camera3D and not _ru._king_seq:
			var tw := create_tween()
			tw.tween_property(cam, "size", cam.size + 9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var w := int(info.get("winner", -1))
	var cs: Array = info.get("crowns", [0, 0])
	if _ru and _ru._battle and _ru._battle.has_method("show_network_result"):
		_ru._battle.show_network_result(w, cs, NetworkManager.local_team, float(info.get("duration", -1.0)), info)

func _show_result(title: String, sub: String, win: bool) -> void:
	if _result_layer != null and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	_result_layer = Control.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.z_index = 100
	add_child(_result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)
	var panel := Panel.new()
	panel.size = Vector2(560, 300)
	panel.position = Vector2(120, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.16, 0.98)
	sb.border_color = Color(1.0, 0.78, 0.3) if win else Color(0.8, 0.35, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	_result_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20; vb.offset_top = 22; vb.offset_right = -20; vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 42)
	tl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4) if win else Color(1.0, 0.55, 0.55))
	vb.add_child(tl)
	var sl := Label.new()
	sl.text = sub
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.add_theme_font_size_override("font_size", 20)
	sl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vb.add_child(sl)
	var btn := Button.new()
	btn.text = "返回主菜单"
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 24)
	ThemeHelper.apply_primary_button(btn)
	btn.pressed.connect(func():
		NetworkManager.reset_net()
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	vb.add_child(btn)

func _on_card_selected(cid: int):
	if _spectator:
		return
	_selected_card = cid
	_status.text = "已选卡 %d，点击战场部署" % cid
	_show_guest_ghost(cid)


func _show_guest_ghost(cid: int) -> void:
	_clear_guest_ghost()
	if _ru == null or _ru._battle == null:
		return
	var b = _ru._battle
	var cfg = b.get_config(cid)
	if cfg == null or b.SPELL_IDS.has(cid) or cid == 110 or cid == 109:
		return   # 法术没有单位模型预览
	var spec: Dictionary = CardVisualCatalog.spec_for(cfg.card_name, Config.Team.PLAYER, cfg.attack_range)
	var vis := UnitModelKit.create_unit(spec)
	_ghost = Node3D.new()
	_ghost.add_child(vis)
	var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (0.75 if NetworkManager.local_team == 0 else 0.25)
	_ghost.position = Vector3(0, 1.0, z)
	b.add_child(_ghost)
	_refresh_guest_ghost_red()


func _refresh_guest_ghost_red() -> void:
	if _ghost == null or _ru == null or _ru._battle == null or _selected_card < 0:
		return
	var b = _ru._battle
	var cfg = b.get_config(_selected_card)
	if cfg == null:
		return
	_ghost_red = b.player_elixir < b.card_cost(cfg)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.18, 0.14, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_set_ghost_overlay(_ghost, mat if _ghost_red else null)


func _set_ghost_overlay(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		_set_ghost_overlay(c, mat)


func _clear_guest_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _move_guest_ghost(screen_pos: Vector2) -> void:
	if _ghost == null or _ru == null or _ru._battle == null:
		return
	var b = _ru._battle
	var cam = b.get_viewport().get_camera_3d()
	if cam == null:
		return
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * 100.0
	var hit = b.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit and hit.collider and hit.collider.name == "GroundPlane":
		_ghost.position = Vector3(hit.position.x, 1.0, hit.position.z)


func _input(event):
	if not _opened or _selected_card < 0 or _ru == null or _ru._battle == null:
		return
	if event is InputEventScreenDrag:
		_move_guest_ghost(event.position)
		return
	if event is InputEventMouseMotion:
		_move_guest_ghost(event.position)
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		pos = event.position
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	if not pressed:
		return
	# 避开底部手牌/按钮区域
	if pos.y > 1260 or pos.y < 150:
		return
	var cam = _ru._battle.get_viewport().get_camera_3d()
	if cam == null:
		return
	var from = cam.project_ray_origin(pos)
	var to = from + cam.project_ray_normal(pos) * 100.0
	var hit = _ru._battle.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit and hit.collider and hit.collider.name == "GroundPlane":
		var wp: Vector3 = hit.position
		var cfg = _ru._battle.get_config(_selected_card)
		if cfg == null or _ru._battle.player_elixir < _ru._battle.card_cost(cfg):
			_status.text = "圣水不足"
			_clear_guest_ghost()
			return
		var center_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
		var center_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
		NetworkManager.request_deploy(_selected_card, center_x * 2.0 - wp.x, center_z * 2.0 - wp.z)
		_selected_card = -1
		_ru.live_selected_card = -1
		_clear_guest_ghost()

func _mirror(snap: Dictionary) -> Dictionary:
	if NetworkManager.local_team == 0:
		return snap.duplicate(true)
	var out: Dictionary = snap.duplicate(true)
	var cx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	var cz: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	for key in ["units", "bullets", "spells"]:
		for e in out.get(key, []):
			e["team"] = 1 - int(e.get("team", 0))
			var z := float(e.get("z", 0.0))
			var x := float(e.get("x", 0.0))
			e["z"] = cz * 2.0 - z
			e["x"] = cx * 2.0 - x
			if e.has("rot") and e["rot"] is Array and e["rot"].size() >= 3:
				e["rot"][1] = float(e["rot"][1]) + PI
			if e.has("beam"):
				var b = e["beam"]
				if b.has("from") and b["from"].size() >= 3:
					b["from"][0] = cx * 2.0 - float(b["from"][0]); b["from"][2] = cz * 2.0 - float(b["from"][2])
				if b.has("to") and b["to"].size() >= 3:
					b["to"][0] = cx * 2.0 - float(b["to"][0]); b["to"][2] = cz * 2.0 - float(b["to"][2])
			if e.has("chain"):
				for p2 in e["chain"]:
					if p2.size() >= 3:
						p2[0] = cx * 2.0 - float(p2[0]); p2[2] = cz * 2.0 - float(p2[2])
	var tw: Array = out.get("towers", [])
	if tw.size() >= 6:
		# 180°视角：队内左右互换
		out["towers"] = [tw[4], tw[3], tw[5], tw[1], tw[0], tw[2]]
	var ex: Array = out.get("elixir", [7.0, 5.0])
	out["elixir"] = [ex[1], ex[0]] if ex.size() >= 2 else ex
	var hs: Array = out.get("hands", [])
	out["hands"] = [hs[1], hs[0]] if hs.size() >= 2 else hs
	var cs: Array = out.get("crowns", [0, 0])
	out["crowns"] = [cs[1], cs[0]] if cs.size() >= 2 else cs
	var td: Array = out.get("touchdown_scores", [])
	if td.size() >= 2:
		out["touchdown_scores"] = [td[1], td[0]]
	return out

func _make_data(first: Dictionary) -> Dictionary:
	var info: Dictionary = NetworkManager.match_info
	var own_deck: Array = PlayerData.get_active_deck().duplicate()
	var own_levels := {}
	for cid in own_deck:
		own_levels[str(int(cid))] = PlayerData.get_card_level(int(cid))
	var opp_deck: Array = []
	var opp_levels := {}
	for seat in info.get("seats", []):
		var st: int = int(seat.get("team", 0))
		var si: int = int(seat.get("idx", 0))
		if st * 2 + si == NetworkManager.local_slot:
			own_deck = Array(seat.get("deck", own_deck)).duplicate()
			own_levels = Dictionary(seat.get("levels", own_levels)).duplicate()
		elif st != NetworkManager.local_team and opp_deck.is_empty():
			opp_deck = Array(seat.get("deck", [])).duplicate()
			opp_levels = Dictionary(seat.get("levels", {})).duplicate()
	var rule := String(info.get("party_rule", "standard"))
	var rule_mode := BATTLE_MODES.current() if rule == "custom" else BATTLE_MODES.get_by_id(rule)
	var party_fixed := bool(rule_mode.get("party", false)) or String(rule_mode.get("level", "own")) == "fixed"
	# 联机模式统一 11 级：无论派对规则，观战/对战镜像都用 11 级
	for k in own_levels.keys():
		own_levels[k] = 11
	for k in opp_levels.keys():
		opp_levels[k] = 11
	var is_td := String(rule_mode.get("win_condition", "")) == "touchdown" or rule == "touchdown"
	var meta := {
		"version": 4,
		"duration": 360.0,
		"arena": int(info.get("arena", 1)),
		"mode": preload("res://scripts/core/BattleModes.gd").get_by_id(rule),
		"player_deck": own_deck,
		"enemy_deck": opp_deck,
		"player_levels": own_levels,
		"enemy_levels": opp_levels,
		"towers": [] if is_td else _guest_towers(first),
		"winner": -1,
		"crowns": [0, 0]
	}
	return {"meta": meta, "actions": [], "snapshots": [first], "emotes": []}

func _guest_towers(snap: Dictionary = {}) -> Array:
	# 优先使用首帧里的真实塔类型（厨师塔/飞刀塔），不能再硬编码公主塔
	var exact: Array = []
	for u in snap.get("units", []):
		if int(u.get("card_id", 99)) <= 3:
			exact.append({
				"team": int(u.get("team", 0)), "card_id": int(u.get("card_id", 1)),
				"name": String(u.get("name", "")),
				"x": float(u.get("x", 0.0)), "z": float(u.get("z", 0.0)),
				"max_health": float(u.get("max_hp", 1.0)), "level": int(u.get("level", 1)),
			})
	if exact.size() >= 6:
		return exact
	var o: Vector3 = Config.ARENA_ORIGIN
	var rule_id := String(NetworkManager.match_info.get("party_rule", "standard"))
	var gm := BATTLE_MODES.current() if rule_id == "custom" else BATTLE_MODES.get_by_id(rule_id)
	var is_party := bool(gm.get("party", false)) or String(gm.get("level", "own")) == "fixed"
	var w: float = Config.ARENA_WIDTH
	var h: float = Config.ARENA_HEIGHT
	var lv: int = 11 if is_party else PlayerData.get_tower_level()
	var left0 := o.x + w * 3.5 / 18.0
	var right0 := o.x + w * 14.5 / 18.0
	var mid0 := o.x + w * 9.0 / 18.0
	var cx: float = o.x + w * 0.5
	var left := left0
	var right := right0
	var mid := mid0
	var bottom_z := o.z + h * 25.5 / 32.0
	var bottom_king := o.z + h * 29.0 / 32.0
	var top_z := o.z + h * 6.5 / 32.0
	var top_king := o.z + h * 3.0 / 32.0
	return [
		{"team":0,"card_id":1,"x":left,"z":bottom_z,"max_health":3052.0,"level":lv},
		{"team":0,"card_id":1,"x":right,"z":bottom_z,"max_health":3052.0,"level":lv},
		{"team":0,"card_id":3,"x":mid,"z":bottom_king,"max_health":4824.0,"level":lv},
		{"team":1,"card_id":1,"x":left,"z":top_z,"max_health":3052.0,"level":lv},
		{"team":1,"card_id":1,"x":right,"z":top_z,"max_health":3052.0,"level":lv},
		{"team":1,"card_id":3,"x":mid,"z":top_king,"max_health":4824.0,"level":lv},
	]
