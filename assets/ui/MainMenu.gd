# assets/ui/MainMenu.gd
# 主菜单：皇家沙盘舞台 + 卡牌展台 + 金色主行动按钮 + 功能磁贴
# 视觉方向：玩具沙盘低模 / Q 版皇室战争；全部程序化绘制，无外部 UI 位图依赖。
extends Control

const ProceduralAudio := preload("res://scripts/core/ProceduralAudio.gd")
const BACKDROP := preload("res://assets/ui/menu/MenuBackdrop.gd")
const CARD_PIECE := preload("res://assets/ui/menu/MenuCardPiece.gd")
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const CHEST3D := preload("res://scripts/ui/Chest3DPreview.gd")

const INK := Color(0.020, 0.030, 0.062)
const NAVY := Color(0.052, 0.078, 0.155)
const NAVY_2 := Color(0.075, 0.108, 0.220)
const ROYAL := Color(0.250, 0.420, 0.950)
const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const GOLD_DEEP := Color(0.520, 0.340, 0.090)
const BRONZE := Color(0.360, 0.230, 0.070)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const EMBER := Color(1.0, 0.590, 0.300)

var _font: Font
var _ui_root: Control
var _fan_holder: Control
var _fan_items: Array = []          # [{node, base, phase}]
var _intro_nodes: Array = []
var _fan_time := 0.0
var _chest_tile: Button
var _chest_badge: Panel
var _chest_count_lbl: Label

func _ready():
	if not AccountManager.is_authenticated and OS.get_environment("CR_SKIP_ACCOUNT") == "":
		print("[Account] 未登录，进入登录界面")
		call_deferred("_redirect_account_login")
		return
	GameSettings.apply_volumes()
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	set_process(true)
	PlayerData.ensure_daily_shop_offers()
	_build_ui()
	_build_friend_module()
	_build_notifier()
	FriendManager.invite_received.connect(_on_friend_invite)
	_play_intro()
	if PlayerData.trophies <= 0 and not PlayerData.tutorial_done:
		call_deferred("_auto_tutorial")
	if PlayerData.chest_reveal_pending:
		call_deferred("_play_chest_reveal")
	# 开场动画「王冠登场」：可轻触跳过；开启时不抢先播 BGM，等标题出现再进音乐
	if OS.has_environment("CR_SKIP_INTRO"):
		_start_bgm()
		UiComponents.ensure_player_name(self)
	else:
		var intro = (load("res://assets/ui/IntroAnimation.gd") as GDScript).new()
		intro.music_started.connect(_start_bgm, CONNECT_ONE_SHOT)
		intro.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
		add_child(intro)


func _on_friend_invite(invite: Dictionary) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "联机邀请"
	dlg.dialog_text = "好友 %s 邀请你加入房间 %s\nIP：%s\n\n确定后进入联机房间。" % [
		String(invite.get("from", "好友")), String(invite.get("code", "")), String(invite.get("ip", ""))]
	dlg.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/network_lobby.tscn"))
	dlg.canceled.connect(func(): FriendManager.pending_invite = {})
	add_child(dlg)
	dlg.popup_centered(Vector2i(680, 320))


var _friend_module_btn: Button
var _friend_online_lbl: Label
var _friend_req_badge: Panel
var _friend_req_lbl: Label

func _build_friend_module() -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(16, UiComponents.TOPBAR_H + 10)
	btn.size = Vector2(238, 64)
	btn.z_index = 40
	btn.tooltip_text = "好友中心"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.055, 0.115, 0.94)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(1)
	normal.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.065, 0.095, 0.19, 0.98)
	hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	hover.shadow_size = 12
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.025, 0.040, 0.085, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_open_friend_center)
	add_child(btn)
	_friend_module_btn = btn

	var icon_bg := Panel.new()
	icon_bg.position = Vector2(10, 12)
	icon_bg.size = Vector2(40, 40)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.13, 0.10, 0.04, 0.95)
	icon_sb.set_corner_radius_all(20)
	icon_sb.set_border_width_all(1)
	icon_sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	icon_bg.add_theme_stylebox_override("panel", icon_sb)
	btn.add_child(icon_bg)
	var ic = ICON.new()
	ic.kind = "medal"
	ic.tint = GOLD_LIGHT
	ic.size = Vector2(24, 24)
	ic.position = Vector2(8, 8)
	icon_bg.add_child(ic)

	var title := Label.new()
	title.text = "好友"
	title.position = Vector2(60, 7)
	title.size = Vector2(150, 26)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD_LIGHT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		title.add_theme_font_override("font", _font)
	btn.add_child(title)
	_friend_online_lbl = Label.new()
	_friend_online_lbl.position = Vector2(60, 33)
	_friend_online_lbl.size = Vector2(150, 20)
	_friend_online_lbl.add_theme_font_size_override("font_size", 11)
	_friend_online_lbl.add_theme_color_override("font_color", MUTED)
	_friend_online_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(_friend_online_lbl)

	_friend_req_badge = Panel.new()
	_friend_req_badge.position = Vector2(202, 10)
	_friend_req_badge.size = Vector2(24, 24)
	_friend_req_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.92, 0.24, 0.20, 0.98)
	badge_sb.set_corner_radius_all(12)
	badge_sb.set_border_width_all(1)
	badge_sb.border_color = Color(1.0, 0.82, 0.55)
	_friend_req_badge.add_theme_stylebox_override("panel", badge_sb)
	btn.add_child(_friend_req_badge)
	_friend_req_lbl = Label.new()
	_friend_req_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_friend_req_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_friend_req_lbl.add_theme_font_size_override("font_size", 12)
	_friend_req_lbl.add_theme_color_override("font_color", Color.WHITE)
	_friend_req_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_friend_req_badge.add_child(_friend_req_lbl)

	FriendManager.friends_changed.connect(_refresh_friend_module)
	FriendManager.presence_changed.connect(_refresh_friend_module)
	FriendManager.requests_changed.connect(_refresh_friend_module)
	FriendManager.friend_request_received.connect(_on_friend_request_received)
	_refresh_friend_module()


func _refresh_friend_module() -> void:
	var online := 0
	for f in FriendManager.all():
		if FriendManager.is_online(String(f.get("id", ""))):
			online += 1
	var req_n := FriendManager.incoming_list().size()
	if _friend_online_lbl != null:
		if FriendManager.all().is_empty():
			_friend_online_lbl.text = "搜索玩家添加好友"
		else:
			_friend_online_lbl.text = "● %d 人同局域网在线" % online
			_friend_online_lbl.add_theme_color_override("font_color", Color(0.52, 0.88, 0.60) if online > 0 else MUTED)
	if _friend_req_badge != null:
		_friend_req_badge.visible = req_n > 0
		if _friend_req_lbl != null:
			_friend_req_lbl.text = str(req_n)


func _on_friend_request_received(req: Dictionary) -> void:
	var prof: Dictionary = Dictionary(req.get("profile", {})).duplicate(true)
	var pid := String(prof.get("player_id", req.get("id", "")))
	var name := String(prof.get("name", "玩家"))
	var dlg := ConfirmationDialog.new()
	dlg.title = "好友请求"
	dlg.dialog_text = "%s 请求加你为好友，是否同意？" % name
	dlg.ok_button_text = "同意"
	dlg.cancel_button_text = "拒绝"
	dlg.confirmed.connect(func(): FriendManager.accept_request(pid))
	dlg.canceled.connect(func(): FriendManager.reject_request(pid))
	add_child(dlg)
	dlg.popup_centered(Vector2i(680, 300))


func _open_friend_center() -> void:
	var center = preload("res://assets/ui/FriendCenter.gd").new()
	add_child(center)


func _redirect_account_login() -> void:
	get_tree().change_scene_to_file("res://scenes/account_login.tscn")


func _on_intro_finished() -> void:
	print("[Intro] reveal menu, prompt name")
	UiComponents.ensure_player_name(self)


func _start_bgm() -> void:
	# 播放菜单背景音乐：优先使用你自己的资源 assets/audio/bgm/menu_theme.ogg
	var path := "res://assets/audio/bgm/menu_theme.ogg"
	var menu_bgm: AudioStream = null
	if ResourceLoader.exists(path):
		menu_bgm = load(path)
	if menu_bgm == null:
		menu_bgm = ProceduralAudio.get_sound("menu_theme")   # 兜底：程序化合成
	if menu_bgm:
		AudioManager.play_bgm(menu_bgm)

func _build_ui() -> void:
	var backdrop: Control = BACKDROP.new()
	add_child(backdrop)

	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_ui_root)

	UiComponents.make_header(_ui_root, "", Callable(), true)
	_build_title()
	_build_card_fan()
	_build_arena_panel()
	_build_primary_cta()
	_build_menu_grid()
	_build_season_panel()
	_build_bottom_row()

# ============================================================
# 基础控件工具
# ============================================================
func _label(text: String, font_size: int, color: Color, use_display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if use_display and _font != null:
		l.add_theme_font_override("font", _font)
	return l

func _sb(bg: Color, radius: int, border := 0, border_col := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	return s

func _shadow_sb(bg: Color, radius: int, border: int, border_col: Color,
		shadow_size: int, shadow_alpha := 0.45) -> StyleBoxFlat:
	var s := _sb(bg, radius, border, border_col)
	s.shadow_color = Color(0, 0, 0, shadow_alpha)
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0, 5)
	return s

func _icon(kind: String, px: float, tint := GOLD, deep := BRONZE) -> Control:
	var ic = ICON.new()
	ic.kind = kind
	ic.tint = tint
	ic.deep = deep
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	return ic

func _center_block(top_anchor: float, height: float, width: float) -> Control:
	var c := Control.new()
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = top_anchor
	c.anchor_bottom = top_anchor
	c.offset_left = -width * 0.5
	c.offset_right = width * 0.5
	c.offset_top = 0.0
	c.offset_bottom = height
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_root.add_child(c)
	return c

# ============================================================
# 标题
# ============================================================
func _build_title() -> void:
	var block := _center_block(0.095, 216.0, 760.0)
	_intro_nodes.append(block)

	var eyebrow := HBoxContainer.new()
	eyebrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	eyebrow.offset_top = 4
	eyebrow.offset_bottom = 30
	eyebrow.alignment = BoxContainer.ALIGNMENT_CENTER
	eyebrow.add_theme_constant_override("separation", 12)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(eyebrow)
	eyebrow.add_child(_icon("star", 16.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.75)))
	var latin := _label("C L A S H   R O Y A L E", 15, Color(PARCHMENT.r, PARCHMENT.g, PARCHMENT.b, 0.62))
	eyebrow.add_child(latin)
	eyebrow.add_child(_icon("star", 16.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.75)))

	# 立体标题：暗铜底层 + 金色面层 + 高光层
	var back := _label("皇室战争", 92, Color(0.30, 0.18, 0.05, 1.0), true)
	back.add_theme_constant_override("outline_size", 14)
	back.add_theme_color_override("font_outline_color", INK)
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	back.offset_top = 40
	back.offset_bottom = 168
	block.add_child(back)

	var main := _label("皇室战争", 92, GOLD, true)
	main.add_theme_constant_override("outline_size", 14)
	main.add_theme_color_override("font_outline_color", INK)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	main.offset_top = 34
	main.offset_bottom = 162
	block.add_child(main)

	var hi := _label("皇室战争", 92, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.26), true)
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hi.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hi.offset_top = 32
	hi.offset_bottom = 160
	block.add_child(hi)

	var sub_row := HBoxContainer.new()
	sub_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub_row.offset_top = 172
	sub_row.offset_bottom = 206
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 14)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(sub_row)
	sub_row.add_child(_hr(70))
	var sub := _label("玩具沙盘 · 卡牌对决", 18, Color(PARCHMENT.r, PARCHMENT.g, PARCHMENT.b, 0.78))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	sub_row.add_child(sub)
	sub_row.add_child(_hr(70))

func _hr(width: float) -> Control:
	var line := Panel.new()
	line.custom_minimum_size = Vector2(width, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_theme_stylebox_override("panel", _sb(Color(GOLD.r, GOLD.g, GOLD.b, 0.45), 1))
	return line

# ============================================================
# 卡牌展台
# ============================================================
func _build_card_fan() -> void:
	_fan_holder = _center_block(0.225, 360.0, 780.0)
	_fan_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cards := [
		{"name": "火球", "rot": -14.0, "x": -238.0, "y": 46.0, "w": 172.0, "h": 200.0, "hero": false},
		{"name": "公主", "rot": -7.0, "x": -122.0, "y": 18.0, "w": 176.0, "h": 206.0, "hero": false},
		{"name": "骑士", "rot": 0.0, "x": 0.0, "y": 0.0, "w": 214.0, "h": 248.0, "hero": true},
		{"name": "飞龙宝宝", "rot": 7.0, "x": 122.0, "y": 18.0, "w": 176.0, "h": 206.0, "hero": false},
		{"name": "皮卡超人", "rot": 14.0, "x": 238.0, "y": 46.0, "w": 172.0, "h": 200.0, "hero": false},
	]
	var center := Vector2(_fan_holder.size.x * 0.5, 168.0)
	for i in cards.size():
		var d: Dictionary = cards[i]
		var piece = CARD_PIECE.new()
		piece.card_name = d.name
		piece.hero = d.hero
		piece.size = Vector2(d.w, d.h)
		piece.pivot_offset = piece.size * 0.5
		var base_pos: Vector2 = center + Vector2(d.x, d.y) - piece.size * 0.5
		piece.position = base_pos
		piece.rotation = deg_to_rad(d.rot)
		piece.z_index = 3 - absi(i - 2)
		_fan_holder.add_child(piece)
		_fan_items.append({"node": piece, "base": base_pos, "phase": float(i) * 0.85})
		_intro_nodes.append(piece)
# ============================================================
# 竞技场进度面板（可点击进入皇室征程，显示未领取奖励数）
# ============================================================
func _unclaimed_count() -> int:
	var n := 0
	for a in PlayerData.get_achievements():
		if bool(a.get("claimable", false)):
			n += 1
	return n

func _build_arena_panel() -> void:
	var panel := Button.new()
	panel.focus_mode = Control.FOCUS_NONE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.445
	panel.anchor_bottom = 0.445
	panel.offset_left = -356
	panel.offset_right = 356
	panel.offset_top = 0
	panel.offset_bottom = 104
	panel.add_theme_stylebox_override("normal", _shadow_sb(Color(0.04, 0.06, 0.12, 0.78), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 10, 0.35))
	panel.add_theme_stylebox_override("hover", _shadow_sb(Color(0.07, 0.10, 0.19, 0.88), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 12, 0.4))
	panel.add_theme_stylebox_override("pressed", _sb(Color(0.03, 0.045, 0.09, 0.95), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.4)))
	panel.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 20))
	panel.pressed.connect(_on_achievements_pressed)
	_ui_root.add_child(panel)
	_intro_nodes.append(panel)
	var arena_pending := _unclaimed_count()
	if arena_pending > 0:
		_add_count_badge(panel, arena_pending, Vector2(672, 6))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 7)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	left.add_child(top_row)
	var arena_idx: int = PlayerData._arena_index_for_trophies(PlayerData.trophies)
	var arena_name := _label(PlayerData.get_arena_name_at(arena_idx), 19, PARCHMENT, true)
	top_row.add_child(arena_name)
	var arena_tag := _label("竞技场", 13, MUTED)
	arena_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(arena_tag)

	var prog_lbl := _label("", 13, MUTED)
	prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(prog_lbl)

	# 未领取里程碑数量徽标（放在进度文字右侧）
	var unclaimed := _unclaimed_count()
	if unclaimed > 0:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := _sb(Color(0.36, 0.16, 0.05, 0.94), 11, 1, Color(1.0, 0.62, 0.26, 0.8))
		bsb.content_margin_left = 8
		bsb.content_margin_right = 10
		bsb.content_margin_top = 2
		bsb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bsb)
		var bh := HBoxContainer.new()
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_theme_constant_override("separation", 5)
		bh.alignment = BoxContainer.ALIGNMENT_CENTER
		badge.add_child(bh)
		bh.add_child(_icon("medal", 15.0, EMBER))
		bh.add_child(_label("%d 个奖励可领" % unclaimed, 12, Color(1.0, 0.90, 0.72)))
		top_row.add_child(badge)

	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", _sb(Color(0.02, 0.03, 0.06, 0.9), 7, 1,
		Color(1, 1, 1, 0.10)))
	bar.add_theme_stylebox_override("fill", _sb(Color(0.93, 0.72, 0.30), 7))
	left.add_child(bar)

	var start_t: int = PlayerData.get_arena_trophies_at(arena_idx)
	var is_max: bool = arena_idx >= PlayerData.ARENA_DATA.size()
	var next_t: int = 14000 if is_max else PlayerData.get_arena_trophies_at(arena_idx + 1)
	var have: int = PlayerData.trophies - start_t
	var need: int = maxi(1, next_t - start_t)
	if is_max:
		bar.max_value = 1.0
		bar.value = 1.0
		prog_lbl.text = "最终竞技场 · MAX"
	else:
		bar.max_value = float(need)
		bar.value = clampf(float(have), 0.0, float(need))
		prog_lbl.text = "%d / %d 杯 · 距下一竞技场 %d" % [have, need, maxi(0, need - have)]

	# 右侧奖杯数（测试模式按钮改为独立控件，避免挡点击）
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right_col)
	var trophy_row := HBoxContainer.new()
	trophy_row.add_theme_constant_override("separation", 8)
	trophy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trophy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(trophy_row)
	trophy_row.add_child(_icon("trophy", 24.0, GOLD))
	trophy_row.add_child(_label(str(PlayerData.trophies), 20, GOLD))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(158, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# 测试模式开关：作为独立顶层按钮，放在面板右下角
	var on: bool = PlayerData.test_mode
	var test_btn := Button.new()
	test_btn.focus_mode = Control.FOCUS_NONE
	test_btn.anchor_left = 0.5
	test_btn.anchor_right = 0.5
	test_btn.anchor_top = 0.445
	test_btn.anchor_bottom = 0.445
	test_btn.offset_left = 182
	test_btn.offset_right = 340
	test_btn.offset_top = 52
	test_btn.offset_bottom = 92
	var tsb := _sb(Color(0.10, 0.055, 0.20, 0.92) if on else Color(0.05, 0.07, 0.13, 0.92), 20, 1,
		Color(EMBER.r, EMBER.g, EMBER.b, 0.6) if on else Color(1, 1, 1, 0.18))
	tsb.shadow_color = Color(0, 0, 0, 0.35)
	tsb.shadow_size = 4
	test_btn.add_theme_stylebox_override("normal", tsb)
	test_btn.add_theme_stylebox_override("hover", tsb)
	test_btn.add_theme_stylebox_override("pressed", tsb)
	test_btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 20))
	test_btn.pressed.connect(_on_test_mode_pressed)
	var test_row := HBoxContainer.new()
	test_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	test_row.alignment = BoxContainer.ALIGNMENT_CENTER
	test_row.add_theme_constant_override("separation", 6)
	test_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	test_row.add_child(_icon("flask", 20.0, EMBER if on else MUTED))
	test_row.add_child(_label("测试模式 " + ("开" if on else "关"), 13, EMBER if on else MUTED))
	test_btn.add_child(test_row)
	_ui_root.add_child(test_btn)

# ============================================================
# 主行动按钮
# ============================================================
func _build_primary_cta() -> void:
	var holder := Control.new()
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 0.515
	holder.anchor_bottom = 0.515
	holder.offset_left = -360
	holder.offset_right = 360
	holder.offset_top = 0
	holder.offset_bottom = 124
	_ui_root.add_child(holder)
	_intro_nodes.append(holder)

	var bezel := Panel.new()
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_theme_stylebox_override("panel", _shadow_sb(Color(0.36, 0.23, 0.07, 1.0), 26, 2,
		GOLD_LIGHT, 14, 0.5))
	holder.add_child(bezel)

	var face := Panel.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 5
	face.offset_right = -5
	face.offset_top = 4
	face.offset_bottom = -6
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_sb := _sb(Color(0.93, 0.71, 0.28, 1.0), 22, 1, Color(1.0, 0.90, 0.60, 0.9))
	face.add_theme_stylebox_override("panel", face_sb)
	bezel.add_child(face)

	var sheen := Panel.new()
	sheen.anchor_right = 1.0
	sheen.offset_left = 7
	sheen.offset_right = -7
	sheen.offset_top = 8
	sheen.offset_bottom = 50
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.add_theme_stylebox_override("panel", _sb(Color(1.0, 0.94, 0.76, 0.30), 18))
	face.add_child(sheen)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 30
	content.offset_right = -26
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(content)

	content.add_child(_icon("sword", 52.0, Color(0.24, 0.14, 0.03), Color(0.55, 0.36, 0.10)))
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	content.add_child(vbox)
	var t := _label("开始对战", 36, Color(0.19, 0.11, 0.02), true)
	vbox.add_child(t)
	vbox.add_child(_label("使用当前卡组 · 随机对手", 13, Color(0.36, 0.22, 0.05, 0.95)))
	content.add_child(_icon("chevron", 26.0, Color(0.30, 0.18, 0.04)))

	# 斜向流光
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(clip)
	var shine := TextureRect.new()
	shine.texture = _sheen_texture()
	shine.size = Vector2(150, 220)
	shine.rotation = deg_to_rad(-22.0)
	shine.position = Vector2(-260, -40)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shine)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_callback(func(): shine.position = Vector2(-280, -40))
	tw.tween_interval(1.6)
	tw.tween_property(shine, "position", Vector2(900, -40), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 按钮放在最上层接收点击（透明）
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_start_pressed)
	holder.add_child(btn)
	UiComponents.hover_scale(holder, 1.02)

# ============================================================
# 功能磁贴
# ============================================================
func _build_menu_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.anchor_left = 0.5
	grid.anchor_right = 0.5
	grid.anchor_top = 0.60
	grid.anchor_bottom = 0.60
	grid.offset_left = -360
	grid.offset_right = 360
	grid.offset_top = 0
	grid.offset_bottom = 430
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_ui_root.add_child(grid)
	_intro_nodes.append(grid)

	var entries := [
		{"icon": "coin", "title": "商店", "sub": "购买卡牌与宝箱", "act": _on_shop_pressed},
		{"icon": "chest", "title": "宝箱", "sub": "开启你的宝箱", "act": _on_chest_pressed},
		{"icon": "deck", "title": "卡组配置", "sub": "配置出战卡组", "act": _on_deck_pressed},
		{"icon": "globe", "title": "联机", "sub": "局域网对战", "act": _on_network_pressed},
		{"icon": "replay", "title": "回放", "sub": "查看往期对局", "act": _on_replay_pressed},
		{"icon": "palette", "title": "收藏", "sub": "表情与万能卡", "act": _on_collection_pressed},
		{"icon": "trophy", "title": "排行榜", "sub": "全球玩家排名", "act": _on_leaderboard_pressed},
		{"icon": "shield", "title": "部落", "sub": "与伙伴并肩作战", "act": _on_clan_pressed},
	]
	for e in entries:
		var tile := _make_tile(e.icon, e.title, e.sub, e.act)
		grid.add_child(tile)
		if String(e.title) == "宝箱":
			_chest_tile = tile
		var pending := _pending_count_for(String(e.title))
		if pending > 0:
			_add_count_badge(tile, pending, Vector2(292, 6), String(e.title) == "宝箱")

func _pending_count_for(title: String) -> int:
	match title:
		"商店":
			return PlayerData.get_shop_free_pending_count()
		"宝箱":
			return PlayerData.chests.size()
		"收藏":
			return PlayerData.get_collection_reward_pending_count() + PlayerData.get_mastery_claimable_count()
	return 0

func _add_count_badge(tile: Control, count: int, pos: Vector2, is_chest: bool = false) -> void:
	var badge := Panel.new()
	badge.position = pos
	badge.size = Vector2(44, 34)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.20, 0.18, 0.98)
	sb.border_color = Color(1.0, 0.86, 0.42, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("panel", sb)
	tile.add_child(badge)
	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.03))
	lbl.text = str(mini(count, 99))
	badge.add_child(lbl)
	if is_chest:
		_chest_badge = badge
		_chest_count_lbl = lbl

func _refresh_chest_badge() -> void:
	if _chest_badge == null or _chest_count_lbl == null:
		return
	var n: int = PlayerData.chests.size()
	_chest_badge.visible = n > 0
	_chest_count_lbl.text = str(mini(n, 99))

func _play_chest_reveal() -> void:
	PlayerData.chest_reveal_pending = false
	PlayerData.save_data()
	await get_tree().create_timer(0.8).timeout
	if _ui_root == null or _chest_tile == null:
		return
	var chest = CHEST3D.new()
	chest.rarity = "silver"
	chest.size = Vector2(240, 240)
	chest.custom_minimum_size = Vector2(240, 240)
	chest.position = Vector2(280, 680)
	chest.z_index = 80
	_ui_root.add_child(chest)
	var target: Vector2 = _ui_root.to_local(_chest_tile.get_global_rect().get_center()) - Vector2(44, 44)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(chest, "position", target, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(chest, "scale", Vector2(0.32, 0.32), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	chest.queue_free()
	_refresh_chest_badge()
	if _chest_tile:
		var tw2 := create_tween()
		tw2.tween_property(_chest_tile, "scale", Vector2(1.05, 1.05), 0.12)
		tw2.tween_property(_chest_tile, "scale", Vector2.ONE, 0.16)

func _make_tile(icon_kind: String, title: String, subtitle: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(353, 98)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	btn.add_theme_stylebox_override("normal", _shadow_sb(Color(0.045, 0.065, 0.13, 0.82), 18, 1,
		Color(1, 1, 1, 0.10), 8, 0.35))
	btn.add_theme_stylebox_override("hover", _shadow_sb(Color(0.075, 0.105, 0.21, 0.92), 18, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 10, 0.4))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.03, 0.045, 0.09, 0.95), 18, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.35)))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 18))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -14
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(58, 58)
	badge.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.035, 0.075, 0.95), 29, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.35)))
	hbox.add_child(badge)
	var ic := _icon(icon_kind, 32.0, GOLD)
	ic.position = Vector2(13, 13)
	badge.add_child(ic)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(texts)
	texts.add_child(_label(title, 21, PARCHMENT, true))
	texts.add_child(_label(subtitle, 12, MUTED))

	hbox.add_child(_icon("chevron", 16.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.55)))
	UiComponents.hover_scale(btn, 1.02)
	return btn

# ============================================================
# 主题赛季进度条（部落按钮下方，仿皇室征程样式）
# ============================================================
func _build_season_panel() -> void:
	var theme: Dictionary = PlayerData.get_season_theme()
	var crowns: int = PlayerData.get_season_crowns()
	var pending: int = PlayerData.get_season_pending_count()
	var panel := Button.new()
	panel.focus_mode = Control.FOCUS_NONE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.60
	panel.anchor_bottom = 0.60
	panel.offset_left = -356
	panel.offset_right = 356
	panel.offset_top = 444
	panel.offset_bottom = 538
	panel.add_theme_stylebox_override("normal", _shadow_sb(Color(0.04, 0.06, 0.12, 0.82), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.30), 10, 0.35))
	panel.add_theme_stylebox_override("hover", _shadow_sb(Color(0.07, 0.10, 0.19, 0.90), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.58), 12, 0.4))
	panel.add_theme_stylebox_override("pressed", _sb(Color(0.03, 0.045, 0.09, 0.95), 20, 1,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.42)))
	panel.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 20))
	panel.pressed.connect(_on_season_pressed)
	_ui_root.add_child(panel)
	_intro_nodes.append(panel)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	pad.add_child(hb)
	hb.add_child(_icon("trophy", 38.0, Color(1.0, 0.82, 0.30)))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 3)
	hb.add_child(mid)
	var title := _label("主题赛季 · %s" % String(theme.get("name", "主题赛季")), 18, GOLD_LIGHT, true)
	mid.add_child(title)
	var next_need: int = 10 - (crowns % 10)
	var sub_text: String = "距下一档还差 %d 皇冠" % next_need if PlayerData.season_claimed.size() < PlayerData.get_season_tier_count() else "本赛季已全部领取"
	var sub := _label(sub_text, 12, MUTED)
	mid.add_child(sub)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 9)
	bar.show_percentage = false
	bar.max_value = 10.0
	bar.value = float(crowns % 10)
	ThemeHelper.apply_progress_gold(bar)
	mid.add_child(bar)
	var crown_lbl := _label("%d 皇冠" % crowns, 13, Color(1.0, 0.85, 0.40))
	crown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(crown_lbl)
	if pending > 0:
		_add_count_badge(panel, pending, Vector2(672, 6))

# ============================================================
# 底部工具行
# ============================================================
func _build_bottom_row() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -84
	row.offset_bottom = -30
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	_ui_root.add_child(row)
	row.add_child(_text_action("star", "新手教程", _on_tutorial_pressed))
	row.add_child(_dot_sep())
	row.add_child(_text_action("flask", "派对", _on_party_pressed))
	row.add_child(_dot_sep())
	row.add_child(_text_action("medal", "挑战", _on_challenges_pressed))
	row.add_child(_dot_sep())
	row.add_child(_text_action("quit", "退出", _on_quit_pressed))

func _dot_sep() -> Control:
	var lbl := _label("·", 18, Color(GOLD.r, GOLD.g, GOLD.b, 0.35))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _text_action(icon_kind: String, text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	btn.custom_minimum_size = Vector2(112, 44)
	var flat := _sb(Color(0, 0, 0, 0), 14, 0)
	var hov := _sb(Color(1, 1, 1, 0.06), 14, 1, Color(GOLD.r, GOLD.g, GOLD.b, 0.25))
	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", flat)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 7)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	hbox.add_child(_icon(icon_kind, 18.0, Color(0.75, 0.79, 0.88)))
	hbox.add_child(_label(text, 15, Color(0.75, 0.79, 0.88)))
	return btn

# ============================================================
# 通知条
# ============================================================
func _build_notifier() -> void:
	var notifier: Label = (load("res://assets/ui/UiNotifier.gd") as GDScript).new()
	notifier.text = ""
	notifier.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notifier.offset_top = -128
	notifier.offset_bottom = -84
	notifier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notifier.add_theme_font_size_override("font_size", 18)
	notifier.add_theme_color_override("font_color", GOLD)
	notifier.add_theme_constant_override("outline_size", 6)
	notifier.add_theme_color_override("font_outline_color", INK)
	notifier.add_to_group("ui_notifier")
	add_child(notifier)
	notifier.move_to_front()

# ============================================================
# 入场动画 / 呼吸动画
# ============================================================
func _play_intro() -> void:
	for node in _intro_nodes:
		node.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	for i in _intro_nodes.size():
		var node: Control = _intro_nodes[i]
		tw.parallel().tween_property(node, "modulate:a", 1.0, 0.35).set_delay(0.05 + 0.1 * i)
	for i in _fan_items.size():
		var piece: Control = _fan_items[i].node
		piece.scale = Vector2(0.86, 0.86)
		var tw2 := create_tween()
		tw2.tween_interval(0.18 + 0.09 * i)
		tw2.tween_property(piece, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_fan_time += delta
	if _fan_holder == null:
		return
	_fan_holder.rotation = sin(_fan_time * 0.55) * 0.005
	for item in _fan_items:
		var piece: Control = item.node
		piece.position = item.base + Vector2(0, sin(_fan_time * 1.15 + float(item.phase)) * 3.2)

# ============================================================
# 纹理工具
# ============================================================
func _sheen_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 8
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t

# ============================================================
# 信号处理
# ============================================================
func _auto_tutorial():
	# 先等名字弹窗结束，避免在场景/节点添加过程中切换场景
	await get_tree().create_timer(0.4).timeout
	var waited := 0.0
	while not PlayerData.name_chosen and waited < 20.0:
		await get_tree().create_timer(0.3).timeout
		waited += 0.3
	LoadingScreen.change_scene("res://scenes/tutorial.tscn", "正在打开新手训练营…")

func _on_tutorial_pressed():
	LoadingScreen.change_scene("res://scenes/tutorial.tscn", "正在打开新手训练营…")

func _on_start_pressed():
	LoadingScreen.change_scene("res://scenes/battle.tscn", "正在进入战场…")

func _on_settings_pressed():
	var settings = preload("res://scenes/settings_menu.tscn").instantiate()
	add_child(settings)

func _on_network_pressed():
	get_tree().change_scene_to_file("res://scenes/network_lobby.tscn")

func _on_replay_pressed():
	get_tree().change_scene_to_file("res://scenes/replay_ui.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_test_mode_pressed():
	PlayerData.test_mode = not PlayerData.test_mode
	PlayerData.save_data()
	get_tree().reload_current_scene()

func _on_chest_pressed():
	get_tree().change_scene_to_file("res://scenes/chest_ui.tscn")

func _on_shop_pressed():
	LoadingScreen.change_scene("res://scenes/shop_ui.tscn", "正在加载商店…")

func _on_upgrade_pressed():
	get_tree().change_scene_to_file("res://scenes/card_upgrade.tscn")

func _on_deck_pressed():
	LoadingScreen.change_scene("res://scenes/deck_builder.tscn", "正在加载卡组配置…")

func _on_leaderboard_pressed():
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")

func _on_achievements_pressed():
	LoadingScreen.change_scene("res://scenes/achievements.tscn", "正在加载皇室征程…")

func _on_collection_pressed():
	LoadingScreen.change_scene("res://scenes/collection.tscn", "正在加载收藏…")

func _on_party_pressed():
	get_tree().change_scene_to_file("res://scenes/party_select.tscn")


func _on_challenges_pressed():
	get_tree().change_scene_to_file("res://scenes/challenges.tscn")


func _on_season_pressed():
	get_tree().change_scene_to_file("res://scenes/season.tscn")

func _on_clan_pressed():
	# 先拉取部落/成员/聊天数据，再进入界面，避免空白或旧数据
	LoadingScreen.show_loading("正在从云端加载部落…")
	ClanManager.invalidate_cache()
	ClanManager.get_my_clan(func(_ok, _clan):
		ClanManager.search_clans(func(_sok, _clans):
			LoadingScreen.change_scene("res://scenes/clan_ui.tscn", "正在打开部落…")
		, "")
	)
