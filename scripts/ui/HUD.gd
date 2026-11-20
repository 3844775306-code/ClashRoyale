# scripts/ui/HUD.gd

class_name HUD
extends CanvasLayer
signal emote_sent(id: String, team: int)
var battle: BattleManager
var table_bg: ColorRect
var remote_mode: bool = false       # 是否工作在远程对战模式
# UI 控件
var elixir_cells: Array = []           # 10 个圣水点（Panel，样式在 _update_elixir_grid 中动态改写）
var elixir_value_label: Label          # 圣水数值（置于点条右侧）
var elixir_grid: HBoxContainer         # 圣水点容器
var elixir_icon: Label                 # 💧 圣水图标
var elixir_row: HBoxContainer          # 圣水整行（居中容器）
var elixir_bar: Control = null
var timer_label: Label
var _notice_panel: Panel
var _notice_flags: Dictionary = {}
var _last_r10_sec: int = -1
var _last_ot10_sec: int = -1                 # 计时药丸内的文字
var crowns_player_label: Label
var crowns_enemy_label: Label
var mode_label: Label                    # 当前对战模式徽标
var touchdown_overlay: Control = null
var _mini_tray: Control = null
var _mini_cards: HBoxContainer = null
var _mini_ids: Array = []
var _mini_scans: Array = []
var _mini_elixir: float = 5.0
var _td_break_left := 0.0
var _td_break_hint: Label = null
var double_elixir_label: Label         # ⚡双倍圣水 徽标
var card_container: HBoxContainer
const ShieldBadge := preload("res://scripts/ui/ShieldBadge.gd")
const EmoteCatalog = preload("res://scripts/data/EmoteCatalog.gd")
const ElixirBar := preload("res://scripts/ui/ElixirBar.gd")
var _tray_top: float = 0.0
var next_card_ui: Control = null
var next_label: Label = null
var _next_shown_id: int = -2
var elixir_highlight: Panel            # 选中卡牌费用高亮框

# 血条系统
var health_bar_container: Control
const HBAR := preload("res://scripts/ui/HealthBarBar.gd")
var unit_bars: Dictionary = {}  # Unit -> bar data
var show_names: bool = true     # L 键切换单位名字（默认显示）
const HB_TEAM := {0: Color(0.23, 0.55, 0.96), 1: Color(0.93, 0.27, 0.28)}
var game_over_panel: Control
var game_over_screen: Control
var game_over_label: Label
var top_bar_panel: Panel
var timer_pill_panel: Panel
var pause_button: Button
var emote_button: Button
var emote_panel: Control
var emote_list: VBoxContainer
var pause_panel: Control
var _enemy_profile_panel: Panel
var _ally_profile_panel: Panel
var _profile_signature: String = ""
var _profile_vertical: bool = false

var _game_over_paused: bool = false   # 结算后是否已暂停整棵树

# 布局常量（纵向 800×1600 设计稿）
const TRAY_H: int = 240
const PIP_W: int = 30
const PIP_H: int = 26
const PIP_SEP: int = 0

func _ready():
	_create_ui_elements()
	_apply_theme_recursive(self)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _apply_theme_recursive(n: Node) -> void:
	if ThemeHelper.ui_theme == null:
		return
	if n is Control:
		n.theme = ThemeHelper.ui_theme
	for c in n.get_children():
		_apply_theme_recursive(c)

func _create_ui_elements():
	var screen_size = get_viewport().get_visible_rect().size
	var center_x = screen_size.x / 2.0
	var tray_y = screen_size.y - TRAY_H

	# ================= 牌桌区（不可见，仅作为拖拽取消判定区） =================
	table_bg = ColorRect.new()
	table_bg.position = Vector2(0, tray_y)
	table_bg.size = Vector2(screen_size.x, TRAY_H)
	table_bg.color = Color(0, 0, 0, 0)
	table_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(table_bg)

	# ================= 顶部皇家条 =================
	var top_trim := ColorRect.new()
	top_trim.position = Vector2(0, 0)
	top_trim.size = Vector2(screen_size.x, 6)
	top_trim.color = ThemeHelper.COLORS.gold_dim
	top_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_trim)

	top_bar_panel = Panel.new()
	top_bar_panel.position = Vector2(0, 0)
	top_bar_panel.size = Vector2(screen_size.x, 84)
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.07, 0.1, 0.19, 0.92)
	top_sb.set_corner_radius_all(0)
	top_sb.corner_radius_bottom_left = 16
	top_sb.corner_radius_bottom_right = 16
	top_sb.set_border_width_all(1)
	top_sb.border_width_bottom = 2
	top_sb.border_color = ThemeHelper.COLORS.gold_dim
	top_bar_panel.add_theme_stylebox_override("panel", top_sb)
	top_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar_panel)

	# 玩家皇冠（左）
	crowns_player_label = Label.new()
	crowns_player_label.text = "你 0"
	crowns_player_label.position = Vector2(18, 20)
	crowns_player_label.size = Vector2(220, 44)
	crowns_player_label.add_theme_font_size_override("font_size", 22)
	crowns_player_label.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	crowns_player_label.add_theme_constant_override("shadow_offset_x", 1)
	crowns_player_label.add_theme_constant_override("shadow_offset_y", 1)
	crowns_player_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	crowns_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crowns_player_label.visible = false
	add_child(crowns_player_label)

	# 敌方皇冠（右）
	crowns_enemy_label = Label.new()
	crowns_enemy_label.text = "敌 0"
	crowns_enemy_label.position = Vector2(screen_size.x - 320, 20)
	crowns_enemy_label.size = Vector2(220, 44)
	crowns_enemy_label.add_theme_font_size_override("font_size", 22)
	crowns_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.33, 0.264))
	crowns_enemy_label.add_theme_constant_override("shadow_offset_x", 1)
	crowns_enemy_label.add_theme_constant_override("shadow_offset_y", 1)
	crowns_enemy_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	crowns_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crowns_enemy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crowns_enemy_label.visible = false
	add_child(crowns_enemy_label)

	# 模式徽标（计时药丸下方，标准模式隐藏）
	mode_label = Label.new()
	mode_label.position = Vector2(center_x - 200, 66)
	mode_label.size = Vector2(400, 20)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 13)
	mode_label.add_theme_color_override("font_color", ThemeHelper.COLORS.gold_bright)
	mode_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	mode_label.add_theme_constant_override("shadow_offset_x", 1)
	mode_label.add_theme_constant_override("shadow_offset_y", 1)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_label.text = ""
	add_child(mode_label)

	# 计时药丸（中）
	timer_pill_panel = Panel.new()
	timer_pill_panel.position = Vector2(center_x - 80, 19)
	timer_pill_panel.size = Vector2(160, 46)
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.09, 0.12, 0.22, 0.95)
	pill_sb.set_corner_radius_all(23)
	pill_sb.set_border_width_all(2)
	pill_sb.border_color = ThemeHelper.COLORS.gold_dim
	timer_pill_panel.add_theme_stylebox_override("panel", pill_sb)
	timer_pill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_pill_panel)

	timer_label = Label.new()
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_label.text = "⏱ 0:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_pill_panel.add_child(timer_label)

	# ================= 底部皇家托盘 =================
	var tray := Panel.new()
	tray.position = Vector2(0, tray_y)
	tray.size = Vector2(screen_size.x, TRAY_H)
	var tray_sb := StyleBoxFlat.new()
	tray_sb.bg_color = Color(0.06, 0.08, 0.15, 0.9)
	tray_sb.set_corner_radius_all(0)
	tray_sb.corner_radius_top_left = 22
	tray_sb.corner_radius_top_right = 22
	tray_sb.set_border_width_all(1)
	tray_sb.border_width_top = 3
	tray_sb.border_color = ThemeHelper.COLORS.gold_dim
	tray.add_theme_stylebox_override("panel", tray_sb)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)

	var tray_line := ColorRect.new()
	tray_line.position = Vector2(0, tray_y + 6)
	tray_line.size = Vector2(screen_size.x, 1)
	tray_line.color = Color(1, 0.85, 0.35, 0.25)
	tray_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_line)

	# 手牌（4 张居中：128*4 + 14*3 = 554）
	card_container = HBoxContainer.new()
	card_container.add_theme_constant_override("separation", 14)
	card_container.position = Vector2((screen_size.x - 554.0) / 2.0, tray_y + 14)
	add_child(card_container)
	# 下一张卡预览（完整卡牌 UI，从左侧滑入）
	next_label = Label.new()
	next_label.text = "下一张"
	next_label.position = Vector2(card_container.position.x - 88.0, tray_y - 2)
	next_label.add_theme_font_size_override("font_size", 13)
	next_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(next_label)
	_tray_top = tray_y
	var elixir_y: float = tray_y + 188.0
	elixir_row = HBoxContainer.new()
	elixir_row.anchor_left = 0.5
	elixir_row.anchor_right = 0.5
	elixir_row.anchor_top = 0
	elixir_row.anchor_bottom = 0
	elixir_row.offset_top = elixir_y
	elixir_row.offset_bottom = elixir_y + 26
	elixir_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elixir_row.add_theme_constant_override("separation", 12)
	elixir_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(elixir_row)

	elixir_icon = Label.new()
	elixir_icon.text = "圣水"
	elixir_icon.custom_minimum_size = Vector2(26, 26)
	elixir_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elixir_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elixir_icon.add_theme_font_size_override("font_size", 24)
	elixir_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_row.add_child(elixir_icon)

	elixir_grid = HBoxContainer.new()
	elixir_grid.add_theme_constant_override("separation", 0)
	elixir_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_row.add_child(elixir_grid)
	_build_elixir_grid(elixir_grid)

	elixir_value_label = Label.new()
	elixir_value_label.text = "0.0"
	elixir_value_label.custom_minimum_size = Vector2(54, 26)
	elixir_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elixir_value_label.add_theme_font_size_override("font_size", 22)
	elixir_value_label.add_theme_color_override("font_color", Color.WHITE)
	elixir_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_row.add_child(elixir_value_label)

	# 双倍圣水徽标（平时隐藏；出现时整行自动重新居中）
	double_elixir_label = Label.new()
	double_elixir_label.text = "双倍圣水"
	double_elixir_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	double_elixir_label.add_theme_font_size_override("font_size", 19)
	double_elixir_label.add_theme_color_override("font_color", ThemeHelper.COLORS.gold_bright)
	double_elixir_label.add_theme_constant_override("shadow_offset_x", 1)
	double_elixir_label.add_theme_constant_override("shadow_offset_y", 1)
	double_elixir_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	double_elixir_label.visible = false
	double_elixir_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_row.add_child(double_elixir_label)
	# 新版圣水条：占 80% 屏宽
	elixir_icon.visible = false
	elixir_grid.visible = false
	elixir_value_label.visible = false
	elixir_bar = ElixirBar.new()
	elixir_bar.custom_minimum_size = Vector2(screen_size.x * 0.8, 34.0)
	elixir_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_row.add_child(elixir_bar)

	# 费用高亮框（金色描边，覆盖选中卡的费用点条）
	elixir_highlight = Panel.new()
	elixir_highlight.visible = false
	elixir_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elixir_highlight.z_index = 10
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.set_corner_radius_all(9)
	hl_style.set_border_width_all(3)
	hl_style.border_color = Color(1, 0.85, 0.35)
	elixir_highlight.add_theme_stylebox_override("panel", hl_style)
	add_child(elixir_highlight)

	# ========== 血条容器 ==========
	health_bar_container = Control.new()
	health_bar_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_bar_container)

	# ========== 游戏结束面板（新版紫金结算，初始隐藏） ==========
	game_over_screen = preload("res://scripts/ui/GameOverScreen.gd").new()
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.visible = false
	game_over_screen.z_index = 30
	if game_over_screen.has_signal("restart_pressed"):
		game_over_screen.connect("restart_pressed", Callable(self, "_on_restart_pressed"))
		game_over_screen.connect("menu_pressed", Callable(self, "_on_quit_to_menu_pressed"))
	add_child(game_over_screen)
	game_over_panel = game_over_screen
	# ========== 暂停按钮（右上角） ==========
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(screen_size.x - 72, 12)
	pause_button.size = Vector2(56, 56)
	pause_button.pressed.connect(_on_pause_pressed)
	ThemeHelper.apply_button_style(pause_button)
	add_child(pause_button)
	# ========== 表情按钮 ==========
	emote_button = Button.new()
	emote_button.text = "表情"
	emote_button.position = Vector2(screen_size.x - 140, 12)
	emote_button.size = Vector2(56, 56)
	ThemeHelper.apply_button_style(emote_button)
	emote_button.pressed.connect(_on_emote_pressed)
	add_child(emote_button)
	_build_emote_panel(screen_size)

	# ========== 暂停面板（初始隐藏） ==========
	pause_panel = Control.new()
	pause_panel.visible = false
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.z_index = 40
	add_child(pause_panel)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(shade)

	var pause_card := UiComponents.make_card(ThemeHelper.COLORS.gold)
	pause_card.size = Vector2(380, 340)
	pause_card.position = Vector2(center_x - 190, screen_size.y / 2 - 170)
	pause_panel.add_child(pause_card)

	var pvbox := VBoxContainer.new()
	pvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pvbox.offset_left = 24
	pvbox.offset_top = 20
	pvbox.offset_right = -24
	pvbox.offset_bottom = -20
	pvbox.add_theme_constant_override("separation", 14)
	pause_card.add_child(pvbox)

	var pause_title := Label.new()
	pause_title.text = "已暂停"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	pause_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pvbox.add_child(pause_title)

	var resume_btn := UiComponents.make_primary_button("继续游戏", _on_resume_pressed, Vector2(0, 54))
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvbox.add_child(resume_btn)
	var settings_btn := UiComponents.make_secondary_button("设置", _on_settings_pressed, Vector2(0, 54))
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvbox.add_child(settings_btn)
	var quit_btn := UiComponents.make_danger_button("返回主菜单", _on_quit_to_menu_pressed, Vector2(0, 54))
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvbox.add_child(quit_btn)

	_setup_match_profiles(screen_size, tray_y)

func _build_emote_panel(screen_size: Vector2):
	emote_panel = Control.new()
	emote_panel.visible = false
	emote_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emote_panel.z_index = 35
	add_child(emote_panel)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	emote_panel.add_child(shade)
	var card := UiComponents.make_card(Color(0.55, 0.82, 1.0))
	card.size = Vector2(500, 620)
	card.position = Vector2(screen_size.x * 0.5 - 250, screen_size.y * 0.5 - 310)
	emote_panel.add_child(card)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 18
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var title := Label.new()
	title.text = "选择表情"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	emote_list = VBoxContainer.new()
	emote_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emote_list.add_theme_constant_override("separation", 8)
	scroll.add_child(emote_list)
	var close := UiComponents.make_secondary_button("关闭", func(): emote_panel.visible = false, Vector2(0, 52))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(close)

func _on_emote_pressed():
	emote_panel.visible = not emote_panel.visible
	if not emote_panel.visible:
		return
	for ch in emote_list.get_children():
		ch.queue_free()
	var emotes: Array = PlayerData.owned_emotes
	if emotes.is_empty():
		var l := Label.new()
		l.text = "还没有表情\n去皇室征程领取表情奖励吧"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
		emote_list.add_child(l)
		return
	for eid in emotes:
		var b := Button.new()
		var id: String = String(eid)
		b.text = "       %s" % EmoteCatalog.name_of(id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		ThemeHelper.apply_card_button_style(b)
		var badge = preload("res://scripts/ui/EmoteIcon.gd").new()
		badge.emote_id = id
		badge.position = Vector2(10, 8)
		badge.size = Vector2(48, 48)
		b.add_child(badge)
		b.pressed.connect(func(): _send_emote(id))
		emote_list.add_child(b)

func _emote_glyph(id: String) -> String:
	return EmoteCatalog.glyph(id)

func _send_emote(id: String):
	show_emote(id, Config.Team.PLAYER)

func show_emote(id: String, team: int = Config.Team.PLAYER):
	emote_sent.emit(id, team)
	if team == Config.Team.PLAYER:
		emote_panel.visible = false
	var is_enemy: bool = team == Config.Team.ENEMY
	var l = preload("res://scripts/ui/EmoteIcon.gd").new()
	l.emote_id = id
	l.size = Vector2(120, 120)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	l.position = Vector2(vp.x * 0.5 - 60, 290) if not is_enemy else Vector2(vp.x - 230, 220)
	l.z_index = 60
	if is_enemy:
		l.modulate = Color(1.0, 0.78, 0.78)
	add_child(l)
	var tag := Label.new()
	tag.text = "对手" if is_enemy else "你"
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55) if is_enemy else Color(0.7, 0.9, 1.0))
	tag.position = l.position + Vector2(35, 122)
	tag.z_index = 60
	add_child(tag)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.25, 1.25), 0.16).from(Vector2(0.3, 0.3))
	tw.parallel().tween_property(tag, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(tag, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): l.queue_free(); tag.queue_free())

func _on_pause_pressed():
	get_tree().paused = true
	pause_panel.visible = true
	pause_button.visible = false

func _on_resume_pressed():
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.visible = true

func _on_restart_pressed():
	get_tree().paused = false
	if NetworkManager.role == NetworkManager.Role.HOST:
		NetworkManager.start_match()
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	if NetworkManager.role != NetworkManager.Role.NONE:
		NetworkManager.reset_net()
		get_tree().change_scene_to_file("res://scenes/network_lobby.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

## 结算暂停前，把 AudioManager 的播放器设为 ALWAYS，
## 让胜利/失败音效继续在冻结的画面上播完。
func _free_audio_from_pause():
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_settings_pressed():
	var settings = preload("res://scenes/settings_menu.tscn").instantiate()
	pause_panel.add_child(settings)   # 在暂停面板上叠加

func _on_quit_to_menu_pressed():
	get_tree().paused = false
	if NetworkManager.role != NetworkManager.Role.NONE:
		NetworkManager.reset_net()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ================= 圣水点条 =================

func _build_elixir_grid(grid: HBoxContainer):
	for i in range(10):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(PIP_W, PIP_H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.13, 0.2)
		sb.set_border_width_all(0)
		sb.border_color = Color(0.95, 0.76, 0.3, 0.4)
		# 矩形格子：仅最左/最右格子做高度 20% 的圆角
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_right = 0
		if i == 0:
			sb.corner_radius_top_left = int(PIP_H * 0.2)
			sb.corner_radius_bottom_left = int(PIP_H * 0.2)
		if i == 9:
			sb.corner_radius_top_right = int(PIP_H * 0.2)
			sb.corner_radius_bottom_right = int(PIP_H * 0.2)
		pip.add_theme_stylebox_override("panel", sb)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 短竖线分割（除第一格外，每格左边缘一根，居中 60% 高）
		if i > 0:
			var sep := ColorRect.new()
			sep.size = Vector2(2, PIP_H * 0.6)
			sep.position = Vector2(0, PIP_H * 0.2)
			sep.color = Color(0.06, 0.07, 0.12, 0.9)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.add_child(sep)
		grid.add_child(pip)
		elixir_cells.append(pip)

func set_replay_layout() -> void:
	_profile_vertical = true
	if _enemy_profile_panel:
		_enemy_profile_panel.size = Vector2(112, 84)
	if _ally_profile_panel:
		_ally_profile_panel.size = Vector2(112, 84)

func set_match_profiles(profs: Array) -> void:
	if _enemy_profile_panel == null or _ally_profile_panel == null:
		return
	var enemy: Array = []
	var ally: Array = []
	for p in profs:
		if not (p is Dictionary): continue
		if int(p.get("team", 0)) == 1: enemy.append(p)
		else: ally.append(p)
	_fill_profile_panel(_enemy_profile_panel, enemy, "敌方")
	_fill_profile_panel(_ally_profile_panel, ally, "我方")

func _setup_match_profiles(screen_size: Vector2, tray_y: float) -> void:
	_enemy_profile_panel = Panel.new()
	_enemy_profile_panel.position = Vector2(screen_size.x - 308, 46)
	_enemy_profile_panel.size = Vector2(300, 34)
	_enemy_profile_panel.z_index = 20
	_enemy_profile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_profile_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_enemy_profile_panel)
	_ally_profile_panel = Panel.new()
	_ally_profile_panel.position = Vector2(8, 46)
	_ally_profile_panel.size = Vector2(300, 34)
	_ally_profile_panel.z_index = 20
	_ally_profile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ally_profile_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_ally_profile_panel)

func _profile_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.06, 0.12, 0.72)
	sb.border_color = Color(1.0, 0.78, 0.3, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	return sb

func _refresh_match_profiles() -> void:
	if battle == null or bool(battle.get("replay_mode")):
		return
	var profs: Array = battle.get_battle_player_profiles() if battle.has_method("get_battle_player_profiles") else []
	var sig := JSON.stringify(profs)
	if sig == _profile_signature:
		return
	_profile_signature = sig
	var enemy: Array = []
	var ally: Array = []
	var crowns0: int = int(battle.player_crowns) if battle != null else 0
	var crowns1: int = int(battle.enemy_crowns) if battle != null else 0
	for p in profs:
		p["crowns"] = crowns1 if int(p.get("team", 0)) == 1 else crowns0
		if int(p.get("team", 0)) == 1:
			enemy.append(p)
		else:
			ally.append(p)
	_fill_profile_panel(_enemy_profile_panel, enemy, "敌方")
	_fill_profile_panel(_ally_profile_panel, ally, "我方")
	_enemy_profile_panel.size.y = 84
	_ally_profile_panel.size.y = 84

func _fill_profile_panel(panel: Panel, profiles: Array, side: String) -> void:
	for c in panel.get_children():
		c.queue_free()
	var row: BoxContainer = VBoxContainer.new() if _profile_vertical else HBoxContainer.new()
	row.position = Vector2(2 if _profile_vertical else 6, 2)
	row.size = Vector2(panel.size.x - (4 if _profile_vertical else 12), panel.size.y - 4)
	row.add_theme_constant_override("separation", 2 if _profile_vertical else 4)
	panel.add_child(row)
	if not _profile_vertical:
		var tag := Label.new()
		tag.text = side
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3) if side == "我方" else Color(1.0, 0.55, 0.52))
		row.add_child(tag)
	for p in profiles:
		row.add_child(_make_profile_chip(p, profiles.size() > 1 or _profile_vertical))
	if profiles.is_empty():
		var l := Label.new()
		l.text = "等待玩家…"
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		row.add_child(l)

func _make_profile_chip(p: Dictionary, compact: bool = false) -> Control:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(112 if compact else 136, 34)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 2)
	b.add_child(h)
	var av = preload("res://scripts/ui/AvatarIcon.gd").new()
	av.custom_minimum_size = Vector2(28 if compact else 30, 28 if compact else 30)
	av.size = Vector2(28 if compact else 30, 28 if compact else 30)
	av.setup(String(p.get("name", "玩家")), int(p.get("avatar_seed", 0)), int(p.get("avatar_index", 0)))
	h.add_child(av)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	h.add_child(vb)
	var nm := Label.new()
	nm.text = String(p.get("name", "玩家"))
	nm.add_theme_font_size_override("font_size", 11 if compact else 13)
	nm.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(nm)
	var tr := Label.new()
	tr.text = "🏆 %d   👑 %d" % [int(p.get("trophies", 0)), int(p.get("crowns", 0))]
	tr.add_theme_font_size_override("font_size", 9 if compact else 10)
	tr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	vb.add_child(tr)
	b.pressed.connect(func(): _open_match_profile(p))
	return b

func _open_match_profile(p: Dictionary) -> void:
	var dlg = (load("res://scripts/ui/PlayerProfileDialog.gd") as GDScript).new()
	dlg.profile = p
	add_child(dlg)

func _process(_delta):
	if battle != null:
		_refresh_match_profiles()
	if battle and battle.network_host_mode and not battle.network_guest_mode:
		_update_teammate_tray()
	_update_mini_scans()
	if _td_break_left > 0.0:
		_td_break_left = maxf(0.0, _td_break_left - _delta)
		if _td_break_hint != null:
			_td_break_hint.text = "第 %d 轮准备…  %d 秒" % [int(round(battle.touchdown_round)) if battle else 0, int(ceil(_td_break_left))]
	if not battle: return
	# 结算后：冻结计时与圣水显示，暂停整棵树让所有单位/子弹/计时器停下
	if battle.game_over:
		pause_button.visible = false
		if not _game_over_paused and game_over_panel.visible:
			_game_over_paused = true
			_free_audio_from_pause()
			get_tree().paused = true
		return
	_update_next_card_preview()
	if elixir_bar:
		elixir_bar.max_value = float(battle.player_max_elixir)
		elixir_bar.value = battle.player_elixir
		elixir_bar.overflowing = battle.player_elixir >= float(battle.player_max_elixir) - 0.001
		if battle.selected_card and battle.card_cost(battle.selected_card.config) > 0:
			elixir_bar.highlight_cost = battle.card_cost(battle.selected_card.config)
		else:
			elixir_bar.highlight_cost = 0
	_update_timer()
	if String(battle.win_condition) == "touchdown":
		crowns_player_label.text = "触地 %d/%d" % [int(battle.touchdown_score[0]), int(battle.touchdown_goal)]
		crowns_enemy_label.text = "触地 %d/%d" % [int(battle.touchdown_score[1]), int(battle.touchdown_goal)]
	else:
		crowns_player_label.text = "你 %d" % battle.player_crowns
		crowns_enemy_label.text = "敌 %d" % battle.enemy_crowns
	double_elixir_label.visible = battle.elixir_rate >= 1.5
	if double_elixir_label.visible:
		if battle.elixir_rate >= 5.0:
			double_elixir_label.text = "七倍圣水"
		elif battle.elixir_rate >= 2.5:
			double_elixir_label.text = "三倍圣水"
		else:
			double_elixir_label.text = "双倍圣水"
	if mode_label:
		if bool(battle.get("commando_mode")):
			var remain: int = int(maxf(0.0, 15.0 - float(battle.commando_timer) + 0.999))
			mode_label.text = "主题特种兵 · %s · 下次 %d 秒" % [String(battle.commando_card_name), remain]
		elif String(battle.win_condition) == "touchdown":
			mode_label.text = "冲线 · 第 %d 轮" % int(battle.touchdown_round)
		elif String(battle.win_condition) == "duel":
			mode_label.text = "决斗 · 第 %d 回合 · %d : %d" % [int(battle.duel_round), int(battle.duel_wins[0]), int(battle.duel_wins[1])]
		else:
			mode_label.text = battle.mode_name if (battle.mode_name != "" and battle.mode_name != "标准对战") else ""
		var CH := preload("res://scripts/core/Challenges.gd")
		if CH.active_id() != "":
			var def := CH.active_def()
			var a := CH.active()
			if not def.is_empty():
				mode_label.text = "%s · 挑战 %d/%d" % [String(def.get("name", "挑战")), int(a.get("wins", 0)), int(def.get("target", 0))]
		mode_label.visible = mode_label.text != ""
	# 更新所有血条
	_update_health_bars()

func show_touchdown_round_break(round_no: int, a: int, b: int) -> void:
	if touchdown_overlay != null:
		touchdown_overlay.queue_free()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 120
	add_child(layer)
	touchdown_overlay = layer
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -130
	panel.offset_bottom = 130
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.10, 0.96)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.945, 0.765, 0.36, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var font: Font = load(ThemeHelper.DEFAULT_FONT_PATH)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_right = -24
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "冲线得分！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.945, 0.765, 0.36))
	if font != null:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)
	var score := Label.new()
	score.text = "%d : %d" % [a, b]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 40)
	score.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	if font != null:
		score.add_theme_font_override("font", font)
	vbox.add_child(score)
	var hint := Label.new()
	hint.text = "第 %d 轮准备…（2 秒后双方圣水重置为 5）" % round_no
	_td_break_left = 2.0
	_td_break_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86))
	if font != null:
		hint.add_theme_font_override("font", font)
	vbox.add_child(hint)


func hide_touchdown_round_break() -> void:
	_td_break_left = 0.0
	_td_break_hint = null
	if touchdown_overlay != null:
		touchdown_overlay.queue_free()
		touchdown_overlay = null


func set_touchdown_score(a: int, b: int, goal: int) -> void:
	if crowns_player_label:
		crowns_player_label.text = "触地 %d/%d" % [a, goal]
	if crowns_enemy_label:
		crowns_enemy_label.text = "触地 %d/%d" % [b, goal]


func _update_timer():
	var elapsed: float = maxf(0.0, float(battle.game_time) / 1000.0)
	if battle.tower_bleed_active:
		timer_label.text = "⏱ 决胜时刻"
		timer_label.add_theme_color_override("font_color", ThemeHelper.COLORS.gold_bright)
	elif battle.overtime:
		var remain: float = maxf(0.0, 120.0 - maxf(0.0, elapsed - 180.0))
		timer_label.text = "⏱ 加时 %d:%02d" % [int(remain / 60.0), int(remain) % 60]
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if remain <= 10.0 else ThemeHelper.COLORS.gold_bright)
	else:
		var remain2: float = maxf(0.0, 180.0 - elapsed)
		timer_label.text = "⏱ %d:%02d" % [int(remain2 / 60.0), int(remain2) % 60]
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if remain2 <= 10.0 else Color.WHITE)
	if not battle.overtime and not battle.tower_bleed_active and not battle.game_over:
		var remain3: float = 180.0 - elapsed
		if remain3 <= 60.0 and remain3 > 0.0 and not _notice_flags.has("r60"):
			_notice_flags["r60"] = true
			show_battle_notice("60 秒", "常规时间剩余 1 分钟", 1.6)
		if remain3 <= 10.0 and remain3 > 0.0:
			var sec10: int = int(ceil(remain3))
			if sec10 != _last_r10_sec:
				_last_r10_sec = sec10
				show_battle_notice(str(sec10), "常规时间倒计时", 0.72)
	elif battle.overtime and not battle.tower_bleed_active and not battle.game_over:
		var orr: float = 120.0 - maxf(0.0, elapsed - 180.0)
		if not _notice_flags.has("ot"):
			_notice_flags["ot"] = true
			show_battle_notice("加时赛", "2 分钟内打破平局立即获胜", 2.0)
		if orr <= 10.0 and orr > 0.0:
			var osec: int = int(ceil(orr))
			if osec != _last_ot10_sec:
				_last_ot10_sec = osec
				show_battle_notice(str(osec), "加时赛倒计时", 0.72)
	elif battle.tower_bleed_active and not _notice_flags.has("bleed"):
		_notice_flags["bleed"] = true
		show_battle_notice("决胜时刻 谁将获胜？", "皇家塔持续损失生命值", 2.6)

func show_battle_notice(title: String, sub: String = "", duration: float = 2.0) -> void:
	if not is_inside_tree():
		return
	if _notice_panel != null and is_instance_valid(_notice_panel):
		_notice_panel.queue_free()
	var panel := Panel.new()
	panel.position = Vector2(100, 210)
	panel.size = Vector2(600, 118)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 90
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.055, 0.12, 0.94)
	sb.border_color = Color(1.0, 0.78, 0.32, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12; v.offset_right = -12; v.offset_top = 10; v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
		v.add_child(s)
	_notice_panel = panel
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free())

func set_overtime_ui(_active: bool) -> void:
	pass

func set_tower_bleed_ui(_active: bool) -> void:
	pass

func _update_elixir_grid():
	return
func _unused_update_elixir_grid():
	if not battle: return
	var elixir = battle.player_elixir
	if elixir_value_label:
		elixir_value_label.text = "%.1f" % elixir

	for i in range(10):
		var pip: Panel = elixir_cells[i]
		var sb: StyleBoxFlat = pip.get_theme_stylebox("panel")
		var fill_ratio = 0.0
		if elixir >= i + 1:
			fill_ratio = 1.0
		elif elixir > i:
			fill_ratio = elixir - i
		if fill_ratio >= 1.0:
			sb.bg_color = Color(0.62, 0.42, 0.85)
			sb.border_color = ThemeHelper.COLORS.gold_bright
		elif fill_ratio > 0.0:
			sb.bg_color = Color(0.36, 0.26, 0.52)
			sb.border_color = Color(1, 0.85, 0.35, 0.7)
		else:
			sb.bg_color = Color(0.12, 0.13, 0.2)
			sb.border_color = Color(0.95, 0.76, 0.3, 0.4)

	# 选中卡牌的费用高亮框
	if battle.selected_card and battle.selected_card.config.cost > 0:
		var cost: int = battle.selected_card.config.cost
		elixir_highlight.visible = true
		elixir_highlight.position = elixir_grid.global_position - Vector2(3, 3)
		elixir_highlight.size = Vector2(cost * PIP_W + (cost - 1) * PIP_SEP + 6, PIP_H + 6)
	else:
		elixir_highlight.visible = false

# ---------- 血条管理 ----------



func add_health_bar(unit: Unit):
	if unit in unit_bars:
		return
	var is_building: bool = unit.config.type == Config.UnitType.BUILDING
	var bar_h: float = 15.75 if is_building else 11.55
	var bar_w: float = 0.0
	if unit.config.card_id <= 3:
		bar_w = clampf(60.0 + unit.max_health * 0.033, 96.0, 186.0)
	elif is_building:
		bar_w = clampf(45.0 + unit.max_health * 0.027, 69.0, 144.0)
	else:
		bar_w = clampf(27.0 + unit.max_health * 0.030, 45.0, 114.0)
	var bar = HBAR.new()
	bar.custom_minimum_size = Vector2(bar_w, bar_h)
	bar.size = Vector2(bar_w, bar_h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	bar.show_threshold = (unit.config.card_id == 105)
	health_bar_container.add_child(bar)

	# 等级徽章（圆形图标，满血时只显示它）
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(23.4, 23.4)
	badge.size = Vector2(23.4, 23.4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	bs.border_color = HB_TEAM.get(unit.team, Color.WHITE)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("panel", bs)
	health_bar_container.add_child(badge)
	var badge_lbl := Label.new()
	badge_lbl.text = str(unit.level)
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_lbl.add_theme_constant_override("outline_size", 2)
	badge_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_lbl)

	# 名字（血条正上方；L 键切换）
	var name_lbl := Label.new()
	name_lbl.text = unit.config.card_name if unit.config else "???"
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_constant_override("outline_size", 6)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.10))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.visible = show_names
	health_bar_container.add_child(name_lbl)

	# 血量数值：只有防御塔显示
	var hp_lbl := Label.new()
	hp_lbl.add_theme_font_size_override("font_size", 19)
	hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	hp_lbl.add_theme_constant_override("outline_size", 4)
	hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_lbl.visible = false
	health_bar_container.add_child(hp_lbl)

	# 护盾图标（盾牌形状，套在等级徽章上）
	var shield_ring = ShieldBadge.new()
	shield_ring.size = Vector2(30.0, 32.4)
	shield_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_ring.visible = false
	health_bar_container.add_child(shield_ring)
	# 部署冷却条
	var cooldown_bar = ProgressBar.new()
	cooldown_bar.custom_minimum_size = Vector2(bar_w, 6)
	cooldown_bar.max_value = 1.0
	cooldown_bar.value = 0
	cooldown_bar.show_percentage = false
	cooldown_bar.visible = false
	var cd_bg := StyleBoxFlat.new()
	cd_bg.bg_color = Color(0, 0, 0, 0.7)
	cd_bg.set_corner_radius_all(3)
	cooldown_bar.add_theme_stylebox_override("background", cd_bg)
	var cd_fill := StyleBoxFlat.new()
	cd_fill.bg_color = Color(1.0, 0.82, 0.35)
	cd_fill.set_corner_radius_all(3)
	cooldown_bar.add_theme_stylebox_override("fill", cd_fill)
	health_bar_container.add_child(cooldown_bar)

	unit_bars[unit] = {
		"bar": bar, "badge": badge, "name": name_lbl, "hp": hp_lbl,
		"cooldown_bar": cooldown_bar,
		"shield": shield_ring,
		"disp": unit.health / maxf(unit.max_health, 1.0),
	}

func remove_health_bar(unit: Unit):
	_drop_health_bar_entry(unit)

func _drop_health_bar_entry(unit):
	if unit_bars.has(unit):
		var data = unit_bars[unit]
		for k in ["bar", "badge", "name", "hp", "cooldown_bar", "shield"]:
			var n = data.get(k)
			if n and is_instance_valid(n):
				n.queue_free()
		unit_bars.erase(unit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		show_names = not show_names
		for u in unit_bars:
			var d = unit_bars[u]
			if d.name:
				d.name.visible = show_names

func _update_health_bars():
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var to_remove = []
	for unit in unit_bars.keys():
		if not is_instance_valid(unit) or unit.health <= 0:
			to_remove.append(unit)
	for unit in to_remove:
		# unit 可能已被释放，不能再作为 Unit 参数传入
		_drop_health_bar_entry(unit)
	for unit in unit_bars.keys():
		if not is_instance_valid(unit):
			continue
		var data = unit_bars[unit]
		var bar = data.bar
		var badge: Control = data.badge
		var name_lbl: Label = data.name
		var hp_lbl: Label = data.hp
		var cd_bar: ProgressBar = data.cooldown_bar
		var shield_ui: Control = data.get("shield")

		var ratio: float = clampf(unit.health / maxf(unit.max_health, 1.0), 0.0, 1.0)
		var full: bool = ratio >= 0.999
		var top_off: float = 2.0
		if unit.visual_root:
			top_off = unit.visual_root.scale.y * 1.18 + 0.15
		var screen_pos: Vector2 = cam.unproject_position(unit.global_position + Vector3.UP * top_off)

		if unit.deploy_cooldown > 0.0:
			cd_bar.visible = true
			cd_bar.max_value = unit.max_deploy_cooldown
			cd_bar.value = unit.deploy_cooldown
			bar.visible = false
			badge.visible = false
			name_lbl.visible = false
			hp_lbl.visible = false
			cd_bar.position = screen_pos - cd_bar.custom_minimum_size / 2.0
			continue
		cd_bar.visible = false
		badge.visible = true
		if shield_ui:
			var has_shield: bool = unit.config.shield > 0 and not unit.shield_used
			shield_ui.visible = has_shield

		bar.set_ratio(ratio)
		bar.set_team(HB_TEAM.get(unit.team, Color.WHITE))

		var bar_w: float = bar.custom_minimum_size.x
		var bar_h: float = bar.custom_minimum_size.y
		var bar_top: Vector2 = screen_pos - Vector2(bar_w, bar_h) * 0.5
		var show_bar: bool = not full
		bar.visible = show_bar
		name_lbl.visible = show_names
		var badge_pos: Vector2
		if show_bar:
			bar.position = bar_top
			badge_pos = bar_top + Vector2(-23.4, (bar_h - 23.4) * 0.5)
			name_lbl.position = bar_top + Vector2(0.0, -36.0)
			name_lbl.size = Vector2(bar_w, 30.0)
			if unit.config.card_id <= 3:
				hp_lbl.visible = true
				hp_lbl.text = "%d/%d" % [int(unit.health), int(unit.max_health)]
				hp_lbl.position = bar_top + Vector2(0.0, 0.0)
				hp_lbl.size = Vector2(bar_w, bar_h)
			else:
				hp_lbl.visible = false
		else:
			badge_pos = screen_pos - Vector2(11.7, 11.7)
			name_lbl.position = badge_pos + Vector2(-120.0, -23.4)
			name_lbl.size = Vector2(279.0, 30.0)
			hp_lbl.visible = false
		badge.position = badge_pos
		if shield_ui:
			shield_ui.position = badge_pos + Vector2(-3.3, -4.5)
# ============================================================
# 皇冠动画（3D 塔位置 → 顶部皇冠计数）
# ============================================================
func update_crown_labels(pc: int, ec: int) -> void:
	crowns_player_label.text = "你 %d" % pc
	crowns_enemy_label.text = "敌 %d" % ec

func _update_teammate_tray() -> void:
	var hands: Array = battle.network_player_hands()
	var teammate_slot := -1
	for slot in range(1, 4):
		if battle.remote_players.has(slot) and int(battle.remote_players[slot].get("team", 1)) == 0:
			teammate_slot = slot
			break
	if teammate_slot < 0 or teammate_slot >= hands.size() or battle.team_size(0) < 2:
		set_teammate_hand([])
		return
	var elixirs: Array = battle.network_player_elixirs()
	var mate_elixir: float = float(elixirs[teammate_slot]) if teammate_slot < elixirs.size() else 5.0
	set_teammate_hand(Array(hands[teammate_slot]), mate_elixir)


func set_teammate_hand(ids: Array, elixir: float = -1.0) -> void:
	if elixir >= 0.0:
		_mini_elixir = elixir
		_update_mini_scans()
	if ids == _mini_ids:
		return
	_mini_ids = ids.duplicate()
	_mini_scans.clear()
	var needed: bool = not ids.is_empty()
	if not needed:
		if _mini_tray:
			_mini_tray.visible = false
		return
	if _mini_tray == null:
		_mini_tray = Control.new()
		_mini_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mini_tray.z_index = 6
		add_child(_mini_tray)
		var title := Label.new()
		title.text = "队友手牌"
		title.position = Vector2(0, 0)
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mini_tray.add_child(title)
		_mini_cards = HBoxContainer.new()
		_mini_cards.position = Vector2(0, 18)
		_mini_cards.add_theme_constant_override("separation", 8)
		_mini_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mini_tray.add_child(_mini_cards)
	_mini_tray.size = Vector2(4 * 64 + 3 * 8, 104)
	_mini_tray.position = Vector2((get_viewport().get_visible_rect().size.x - _mini_tray.size.x) * 0.5, _tray_top - 112.0)
	_mini_tray.visible = true
	for c in _mini_cards.get_children():
		c.queue_free()
	for cid in ids:
		var cfg = battle.get_config(int(cid)) if battle else null
		if cfg == null:
			continue
		var card := Panel.new()
		card.custom_minimum_size = Vector2(64, 84)
		card.size = Vector2(64, 84)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.035, 0.055, 0.11, 0.94)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.945, 0.765, 0.36, 0.55)
		card.add_theme_stylebox_override("panel", sb)
		var art_path := "res://assets/cards_web/%s.png" % String(cfg.card_name)
		if not ResourceLoader.exists(art_path):
			art_path = "res://assets/cards_rendered/%s.png" % String(cfg.card_name)
		var tex := TextureRect.new()
		tex.position = Vector2(3, 3)
		tex.size = Vector2(58, 58)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(art_path):
			tex.texture = load(art_path)
		var scan := ShaderMaterial.new()
		scan.shader = load("res://assets/shaders/card_scan.gdshader")
		scan.set_shader_parameter("progress", clampf(_mini_elixir / float(maxi(int(cfg.cost), 1)), 0.0, 1.0))
		tex.material = scan
		_mini_scans.append({"mat": scan, "cost": maxi(int(cfg.cost), 1)})
		card.add_child(tex)
		var cost := Label.new()
		cost.text = str(int(cfg.cost))
		cost.position = Vector2(4, 58)
		cost.add_theme_font_size_override("font_size", 11)
		cost.add_theme_color_override("font_color", Color(0.90, 0.80, 1.0))
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost)
		var nm := Label.new()
		nm.text = String(cfg.card_name)
		nm.position = Vector2(0, 68)
		nm.size = Vector2(64, 16)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 9)
		nm.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(nm)
		_mini_cards.add_child(card)
	_update_mini_scans()


func _update_mini_scans() -> void:
	for item in _mini_scans:
		var mat: ShaderMaterial = item.get("mat", null)
		if mat != null:
			mat.set_shader_parameter("progress", clampf(_mini_elixir / float(maxi(int(item.get("cost", 1)), 1)), 0.0, 1.0))


func hide_card_tray() -> void:
	if table_bg:
		table_bg.visible = false
	if card_container:
		card_container.visible = false
	if elixir_row:
		elixir_row.visible = false
	if _mini_tray:
		_mini_tray.visible = false

func fly_crown(from_world: Vector3, team: int) -> void:
	var cam := get_viewport().get_camera_3d()
	var start := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 200.0)
	if cam:
		start = cam.unproject_position(from_world)
	var lbl: Label = crowns_player_label if team == Config.Team.PLAYER else crowns_enemy_label
	var target: Vector2 = lbl.get_global_rect().get_center()
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-20, 20), Vector2(20, 20), Vector2(20, -3), Vector2(10, 5),
		Vector2(0, -13), Vector2(-10, 5), Vector2(-20, -3)])
	shadow.color = Color(0.15, 0.10, 0.02)
	var crown := Polygon2D.new()
	crown.polygon = PackedVector2Array([
		Vector2(-16, 16), Vector2(16, 16), Vector2(16, -2), Vector2(8, 4),
		Vector2(0, -10), Vector2(-8, 4), Vector2(-16, -2)])
	crown.color = Color(1.0, 0.82, 0.24)
	var root := Node2D.new()
	root.position = start
	root.modulate.a = 0.0
	add_child(root)
	root.add_child(shadow)
	root.add_child(crown)
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.12)
	tw.tween_property(root, "position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(root, "scale", Vector2(0.55, 0.55), 0.55)
	tw.parallel().tween_property(root, "rotation", TAU * 0.6, 0.55)
	await tw.finished
	root.queue_free()
	var tw2 := create_tween()
	lbl.scale = Vector2(1.0, 1.0)
	tw2.tween_property(lbl, "scale", Vector2(1.35, 1.35), 0.10)
	tw2.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.18)
func _update_next_card_preview() -> void:
	if battle == null:
		return
	var nid: int = battle.next_card_id()
	if nid == _next_shown_id:
		return
	_next_shown_id = nid
	if next_card_ui:
		next_card_ui.queue_free()
		next_card_ui = null
	if nid < 0:
		return
	var cfg: CardData = battle.get_config(nid)
	if cfg == null:
		return
	var cu := CardUI.new()
	cu.setup(cfg, -1, battle)
	add_child(cu)
	cu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cu.scale = Vector2(0.62, 0.62)
	cu.position = Vector2(6.0, _tray_top + 20.0)
	next_card_ui = cu
func play_next_card_fly(slot_index: int) -> void:
	if battle == null or card_container == null or next_card_ui == null:
		return
	await get_tree().process_frame
	if slot_index < 0 or slot_index >= card_container.get_child_count():
		return
	var slot: Control = card_container.get_child(slot_index) as Control
	if slot == null:
		return
	next_card_ui.z_index = 20
	slot.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next_card_ui, "global_position", slot.global_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(next_card_ui, "scale", Vector2(1.0, 1.0), 0.28)
	await tw.finished
	slot.modulate = Color(1, 1, 1, 1)
	if next_card_ui:
		next_card_ui.queue_free()
		next_card_ui = null
	_next_shown_id = -2
# 供单位直接控制自己的 HUD 显隐（特斯拉遁地/上浮）
func set_unit_hud_visible(unit: Unit, vis: bool) -> void:
	if not unit_bars.has(unit):
		return
	var d = unit_bars[unit]
	for key in ["bar", "badge", "name", "hp", "cooldown_bar", "shield"]:
		var c: Control = d.get(key)
		if c:
			if vis:
				c.visible = false
			else:
				c.visible = false
	# 具体显示交给 _update_health_bars 重新计算；这里只在需要隐藏时立即隐藏
	if not vis:
		return
func hide_battle_hud_for_result() -> void:
	if health_bar_container:
		health_bar_container.visible = false
	if crowns_player_label:
		crowns_player_label.visible = false
	if crowns_enemy_label:
		crowns_enemy_label.visible = false
	if timer_label:
		timer_label.visible = false
	if pause_button:
		pause_button.visible = false
	if top_bar_panel:
		top_bar_panel.visible = false
	if timer_pill_panel:
		timer_pill_panel.visible = false