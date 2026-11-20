# scripts/ui/CardUI.gd
extends Panel
class_name CardUI
const CARD_BG_SHADER := preload("res://assets/shaders/card_bg.gdshader")
const MENU_ICON := preload("res://assets/ui/menu/MenuIcon.gd")

var config: CardData
var index: int = 0
var battle: BattleManager

var cost_label: Label
var _cost_value: int = 1
var _cost_badge = null
var _mirror_source_id: int = -1
var name_label: Label
var cooldown_overlay: ColorRect
var _icon_rect: TextureRect
var _load_overlay: CardLoadOverlay
var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _scan_mat: ShaderMaterial
var _was_ready: bool = false
var _ready_glow: Panel
var _face_sb: StyleBoxFlat

# 拖拽相关
var mouse_down_pos: Vector2 = Vector2.ZERO
var drag_started: bool = false
var is_dragging: bool = false
const DRAG_THRESHOLD: float = 10.0

const CARD_W: float = 128
const CARD_H: float = 164

var _sel_frame: Panel
var _stat_panel: Panel = null

func setup(cfg: CardData, idx: int, bm: BattleManager):
	config = cfg
	index = idx
	battle = bm
	if not is_inside_tree():
		await ready
	name_label.text = cfg.card_name
	_cost_value = cfg.cost
	if cost_label:
		cost_label.text = str(cfg.cost)

func _ready():
	var config_display_name: String = ""
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var accent: Color = ThemeHelper.cost_rarity(config.cost)
	var face := ThemeHelper.make_card_face(accent)
	face.set_border_width_all(2)
	face.border_color = Color(0.93, 0.94, 0.97, 0.92)
	_face_sb = face
	face.shadow_size = 7
	face.shadow_color = Color(0, 0, 0, 0.32)
	add_theme_stylebox_override("panel", face)

	# 卡牌背景（着色器创意背景 + 随扫描变灰/彩色）
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = CARD_BG_SHADER
	_bg_mat.set_shader_parameter("seed", float(config.card_id if config else 0))
	_bg_mat.set_shader_parameter("accent", accent)
	_apply_bg_theme()
	_bg.material = _bg_mat
	add_child(_bg)
	# 真实模型图标（离线渲染的卡面图），没有则回退 emoji
	if config.card_id == 123 and battle and battle.last_played_card_id >= 0:
		var mc = battle.get_config(battle.last_played_card_id)
		if mc:
			_mirror_source_id = battle.last_played_card_id
			config_display_name = mc.card_name
	if config_display_name == "":
		config_display_name = config.card_name
	var img_path: String = "res://assets/cards_web/%s.png" % _safe_card_name(config_display_name)
	if not ResourceLoader.exists(img_path):
		img_path = "res://assets/cards_rendered/%s.png" % _safe_card_name(config_display_name)
	if ResourceLoader.exists(img_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(img_path)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 2.0
		icon_rect.offset_top = 4.0
		icon_rect.offset_right = -2.0
		icon_rect.offset_bottom = -36.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scan_mat = ShaderMaterial.new()
		_scan_mat.shader = load("res://assets/shaders/card_scan.gdshader")
		_scan_mat.set_shader_parameter("progress", 1.0)
		icon_rect.material = _scan_mat
		add_child(icon_rect)
		_icon_rect = icon_rect
	else:
		var emoji := UiComponents.make_emoji_icon(ThemeHelper.card_emoji(config), 44)
		emoji.position = Vector2(0, 24)
		emoji.size = Vector2(CARD_W, 66)
		add_child(emoji)

	# 费用徽章（左上圆形）
	var cost_badge = preload("res://scripts/ui/ElixirBadge.gd").new()
	_cost_badge = cost_badge
	cost_badge.cost = battle.card_cost(config) if battle else config.cost
	cost_badge.position = Vector2(5, 5)
	cost_badge.size = Vector2(40, 44)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost_badge)

	# 名称条（底部）
	var name_strip := Panel.new()
	name_strip.position = Vector2(0, CARD_H - 30)
	name_strip.size = Vector2(CARD_W, 30)
	var strip_sb := StyleBoxFlat.new()
	strip_sb.bg_color = Color(0, 0, 0, 0.45)
	strip_sb.corner_radius_bottom_left = 10
	strip_sb.corner_radius_bottom_right = 10
	strip_sb.border_width_top = 1
	strip_sb.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	name_strip.add_theme_stylebox_override("panel", strip_sb)
	name_label = Label.new()
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.text = config.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_strip.add_child(name_label)
	add_child(name_strip)

	# 冷却遮罩（旧版，保持隐藏）
	cooldown_overlay = ColorRect.new()
	cooldown_overlay.size = size
	cooldown_overlay.color = Color(0, 0, 0, 0.0)
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.visible = false
	add_child(cooldown_overlay)

	# 选中描边框
	_sel_frame = Panel.new()
	_sel_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color.TRANSPARENT
	frame_sb.set_corner_radius_all(10)
	frame_sb.set_border_width_all(3)
	frame_sb.border_color = Color(1, 0.85, 0.35)
	_sel_frame.add_theme_stylebox_override("panel", frame_sb)
	_sel_frame.visible = false
	_sel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sel_frame)
	# 卡牌就绪高亮（费用够时闪一下）
	_ready_glow = Panel.new()
	_ready_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rg_sb := StyleBoxFlat.new()
	rg_sb.bg_color = Color(1.0, 0.88, 0.45, 0.0)
	rg_sb.set_corner_radius_all(10)
	rg_sb.set_border_width_all(3)
	rg_sb.border_color = Color(1.0, 0.92, 0.55, 1.0)
	_ready_glow.add_theme_stylebox_override("panel", rg_sb)
	_ready_glow.visible = false
	_ready_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ready_glow)

func _gui_input(event):
	if index < 0:
		return   # 下一张卡预览不可操作
	if not battle: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down_pos = event.position
			drag_started = false
			is_dragging = false
			# 圣水不足也允许选中/拖拽：拖到战场会显示红色预览，但不会实际部署
			if battle.selected_card != self:
				battle.selected_card = self
			_show_stat_popup()
			accept_event()
		else:
			if is_dragging:
				battle.end_drag(get_global_mouse_position())
			else:
				_show_stat_popup()
			is_dragging = false
			drag_started = false
			accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not drag_started:
			if (event.position - mouse_down_pos).length() > DRAG_THRESHOLD:
				drag_started = true
				is_dragging = true
				_hide_stat_popup()
				battle.start_drag(self)
		if is_dragging:
			battle.update_drag(get_global_mouse_position())
			accept_event()

func _hide_stat_popup() -> void:
	if _stat_panel and is_instance_valid(_stat_panel):
		_stat_panel.visible = false


func _show_stat_popup() -> void:
	if battle == null or config == null or index < 0:
		return
	if battle.hud == null:
		return
	if _stat_panel == null or not is_instance_valid(_stat_panel):
		_build_stat_panel()
	if _stat_panel == null:
		return
	var is_spell: bool = battle.SPELL_IDS.has(config.card_id) or config.card_id == 110 or config.card_id == 109
	var lv: int = battle.mode_level(PlayerData.get_card_level(config.card_id))
	lv = maxi(1, lv)
	var hp: int = int(round(config.max_health * Config.level_mult(lv)))
	var atk: int = int(round(config.damage * Config.level_mult(lv)))
	var rng: float = config.damage_range if config.damage_range > 0.0 else config.attack_range
	var h: HBoxContainer = _stat_panel.get_node_or_null("Stats")
	if h == null:
		return
	for c in h.get_children():
		c.queue_free()
	if is_spell:
		h.add_child(_stat_entry("globe", Color(0.25, 0.48, 0.95), "范围", rng, false))
	else:
		h.add_child(_stat_entry("shield", Color(0.88, 0.28, 0.22), "生命", float(hp), true))
	h.add_child(_stat_entry("sword", Color(0.78, 0.52, 0.12), "攻击", float(atk), true))
	var vp: Vector2 = battle.hud.get_viewport().get_visible_rect().size
	var cr: Rect2 = get_global_rect()
	var px: float = clampf(cr.position.x + cr.size.x * 0.5 - 102.0, 8.0, vp.x - 212.0)
	var py: float = maxf(8.0, cr.position.y - 78.0)
	_stat_panel.position = Vector2(px, py)
	_stat_panel.visible = true


func _build_stat_panel() -> void:
	_stat_panel = Panel.new()
	_stat_panel.z_index = 90
	_stat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_panel.custom_minimum_size = Vector2(204, 66)
	_stat_panel.size = Vector2(204, 66)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.97)
	sb.set_corner_radius_all(13)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.92, 0.74, 0.36, 0.95)
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 8
	_stat_panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.name = "Stats"
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_panel.add_child(h)
	battle.hud.add_child(_stat_panel)
	_stat_panel.visible = false


func _stat_entry(kind: String, tint: Color, _label_text: String, value: float, as_int: bool, rng: float = 0.0) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = MENU_ICON.new()
	ic.kind = kind
	ic.tint = tint
	ic.custom_minimum_size = Vector2(30, 30)
	ic.size = Vector2(30, 30)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	var txt := Label.new()
	txt.text = str(int(round(value))) if as_int else ("%.1f" % value)
	txt.add_theme_font_size_override("font_size", 25)
	txt.add_theme_color_override("font_color", Color(0, 0, 0))
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(txt)
	return box


func _process(_delta):
	if not battle: return
	if _stat_panel and (battle.selected_card != self or battle.is_dragging):
		_hide_stat_popup()
	var dyn_cost: int = battle.card_cost(config) if battle else config.cost
	if config.card_id == 123 and _cost_badge:
		_cost_badge.set_cost(dyn_cost)
		if battle and battle.last_played_card_id != _mirror_source_id:
			_mirror_source_id = battle.last_played_card_id
			var mc = battle.get_config(battle.last_played_card_id) if battle.last_played_card_id >= 0 else null
			if mc and _icon_rect:
				var mp: String = "res://assets/cards_web/%s.png" % _safe_card_name(mc.card_name)
				if not ResourceLoader.exists(mp):
					mp = "res://assets/cards_rendered/%s.png" % _safe_card_name(mc.card_name)
				if ResourceLoader.exists(mp):
					_icon_rect.texture = load(mp)
	var ratio: float = clampf(battle.player_elixir / float(maxi(dyn_cost, 1)), 0.0, 1.0)
	var ready: bool = ratio >= 1.0
	if ready and not _was_ready:
		_play_ready_anim()
	_was_ready = ready
	if _scan_mat:
		_scan_mat.set_shader_parameter("progress", ratio)
	if _bg_mat:
		_bg_mat.set_shader_parameter("progress", ratio)
	if _icon_rect:
		_icon_rect.modulate = Color.WHITE

	# 选中弹起效果 + 金色描边
	var selected: bool = battle.selected_card == self
	_sel_frame.visible = selected
	if _face_sb:
		_face_sb.border_color = Color(1.0, 0.84, 0.35, 1.0) if selected else Color(0.93, 0.94, 0.97, 0.92)
	if selected:
		pivot_offset = Vector2(size.x / 2, size.y)
		scale = Vector2(1.06, 1.06)
	else:
		scale = Vector2.ONE
		modulate = Color.WHITE

func _exit_tree() -> void:
	if _stat_panel and is_instance_valid(_stat_panel):
		_stat_panel.queue_free()
		_stat_panel = null


static func _safe_card_name(n: String) -> String:
	return n.replace("/", "_").replace("\\", "_").replace(":", "_").replace("*", "_").replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")
func _apply_bg_theme() -> void:
	if _bg_mat == null or config == null:
		return
	var name_s: String = config.card_name
	var theme: int = 0
	var top := Color(0.20, 0.34, 0.22)
	var bot := Color(0.08, 0.13, 0.09)
	if config.type == Config.UnitType.AIR:
		theme = 1
		top = Color(0.32, 0.58, 0.92)
		bot = Color(0.68, 0.85, 0.98)
	elif name_s.contains("法术") or name_s.contains("诅咒") or name_s.contains("万箭齐发") or name_s.contains("火球") or name_s.contains("大雪球") or name_s.contains("滚木") or name_s.contains("飞桶") or name_s.contains("火箭") or name_s.contains("雷电") or name_s.contains("电击") or name_s.contains("冰冻") or name_s.contains("狂暴") or name_s.contains("毒药") or name_s.contains("治疗") or name_s.contains("藤蔓") or name_s.contains("虚空") or name_s.contains("飓风") or name_s.contains("地震") or name_s.contains("速递"):
		theme = 2
		top = Color(0.07, 0.06, 0.16)
		bot = Color(0.18, 0.13, 0.34)
	elif config.type == Config.UnitType.BUILDING:
		theme = 3
		top = Color(0.28, 0.22, 0.30)
		bot = Color(0.10, 0.09, 0.14)
	_bg_mat.set_shader_parameter("theme", theme)
	_bg_mat.set_shader_parameter("top_color", top)
	_bg_mat.set_shader_parameter("bottom_color", bot)
func _play_ready_anim() -> void:
	if _ready_glow == null:
		return
	_ready_glow.visible = true
	_ready_glow.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_ready_glow, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _ready_glow.visible = false)
	var tw2 := create_tween()
	tw2.tween_property(self, "scale", Vector2(1.10, 1.10), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)