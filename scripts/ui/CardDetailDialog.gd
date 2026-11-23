extends Control
# 全屏卡牌详情：稀有度氛围 + 3D 展示 + 属性/升级/玩法三页签

const CVC = preload("res://scripts/visuals/CardVisualCatalog.gd")
const UMK = preload("res://scripts/visuals/UnitModelKit.gd")
const PK = preload("res://scripts/visuals/ProjectileKit.gd")
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const LORE = preload("res://scripts/data/CardLore.gd")
const USAGE_STAGE = preload("res://scripts/ui/CardBattleShowcase.gd")

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const INK := Color(0.012, 0.018, 0.045)

const SPELL_PROJECTILES := {
	"火球": "fireball", "万箭齐发": "arrow", "电击法术": "lightning", "雷电法术": "lightning",
	"大雪球": "snowball", "滚木": "log", "野蛮人滚桶": "barb_barrel", "哥布林飞桶": "barrel",
	"火箭": "rocket", "毒药法术": "potion", "冰冻法术": "ice", "狂暴法术": "energy",
	"飓风法术": "energy", "藤蔓法术": "potion", "虚空法术": "plasma", "地震法术": "boulder",
	"哥布林魔咒": "potion", "皇家速递": "barrel", "克隆法术": "energy", "镜像法术": "energy",
}

var cfg: CardData
var on_changed: Callable = Callable()
var _wild_spin: SpinBox
var _sub: SubViewport
var _model_root: Node3D
var _scroll: ScrollContainer
var _body: VBoxContainer
var _status: Label
var _spin := 0.0
var _tab := 0
var _tab_buttons: Array = []
var _font: Font
var _hero_name: Label


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
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_build_background()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_build_header(root)
	_build_hero(root)
	_build_tabs(root)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 24
	_scroll.follow_focus = true
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	_status = _label("", 16, Color(0.90, 0.72, 0.48))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(0, 28)
	root.add_child(_status)
	_switch_tab(0)


func _build_background() -> void:
	var rc := _rarity_color()
	var grad := Gradient.new()
	grad.set_color(0, Color(rc.r * 0.20 + 0.02, rc.g * 0.20 + 0.02, rc.b * 0.20 + 0.05, 1.0))
	grad.set_color(1, INK)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.008, 0.020, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_header(root: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 78)
	h.add_theme_constant_override("separation", 12)
	root.add_child(h)
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(64, 64)
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_color_override("font_color", PARCHMENT)
	close.add_theme_stylebox_override("normal", _style(Color(0.035, 0.05, 0.11, 0.92), Color(1, 1, 1, 0.16), 14))
	close.add_theme_stylebox_override("hover", _style(Color(0.08, 0.11, 0.20, 0.98), Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 14))
	close.add_theme_stylebox_override("pressed", _style(Color(0.02, 0.03, 0.07, 0.98), Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 14))
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): queue_free())
	h.add_child(close)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	var title := _label(cfg.card_name, 34, _rarity_color().lightened(0.20), true)
	title.name = "CardTitle"
	info.add_child(title)
	var sub := _label("%s · %s" % [_rarity_cn(), _type_cn(cfg.type)], 16, MUTED)
	info.add_child(sub)
	var lv := _label("Lv.%d" % _level(), 24, GOLD_LIGHT, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lv)


func _build_hero(root: VBoxContainer) -> void:
	var hero := Panel.new()
	hero.custom_minimum_size = Vector2(0, 500)
	var rc := _rarity_color()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.050, 0.100, 0.90)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(rc.r, rc.g, rc.b, 0.72)
	sb.shadow_color = Color(rc.r, rc.g, rc.b, 0.18)
	sb.shadow_size = 16
	hero.add_theme_stylebox_override("panel", sb)
	root.add_child(hero)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.offset_top = 12
	content.offset_bottom = -12
	content.add_theme_constant_override("separation", 10)
	hero.add_child(content)

	var model_panel := Panel.new()
	model_panel.custom_minimum_size = Vector2(330, 0)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.015, 0.025, 0.060, 0.88)
	msb.set_corner_radius_all(18)
	msb.set_border_width_all(1)
	msb.border_color = Color(1, 1, 1, 0.08)
	model_panel.add_theme_stylebox_override("panel", msb)
	content.add_child(model_panel)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.gui_input.connect(_on_model_input)
	model_panel.add_child(svc)
	_sub = SubViewport.new()
	_sub.size = Vector2i(350, 426)
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
	env.ambient_light_color = Color(0.80, 0.82, 0.95)
	env.ambient_light_energy = 0.65
	we.environment = env
	_sub.add_child(we)
	_model_root = Node3D.new()
	_sub.add_child(_model_root)
	_build_model(cam)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	content.add_child(info)
	var hero_title := _label("卡牌档案", 17, MUTED)
	info.add_child(hero_title)
	_hero_name = _label(cfg.card_name, 30, GOLD_LIGHT, true)
	info.add_child(_hero_name)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	info.add_child(chips)
	chips.add_child(_chip("💧 %d" % _cost(), Color(0.72, 0.52, 1.0)))
	chips.add_child(_chip("Lv.%d" % _level(), GOLD))
	chips.add_child(_chip(_rarity_cn(), rc))
	var key_head := _label("核心属性", 17, MUTED)
	info.add_child(key_head)
	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 6)
	quick.add_theme_constant_override("v_separation", 4)
	info.add_child(quick)
	for s in _hero_stats():
		quick.add_child(_chip(s, Color(0.82, 0.86, 0.96)))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 5)
	tags.add_theme_constant_override("v_separation", 5)
	info.add_child(tags)
	for t in _role_tags():
		tags.add_child(_chip(t, Color(0.46, 0.72, 0.95)))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	var hint := _label("拖动卡面模型可旋转查看", 14, Color(0.50, 0.58, 0.72))
	info.add_child(hint)


func _build_tabs(root: VBoxContainer) -> void:
	_tab_buttons.clear()
	var tabs := HBoxContainer.new()
	tabs.custom_minimum_size = Vector2(0, 60)
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	var names := ["动画", "属性", "简介"]
	for i in range(names.size()):
		var b := Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(func(): _switch_tab(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_style_tabs()


func _switch_tab(index: int) -> void:
	_tab = index
	_style_tabs()
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	if _tab == 0:
		_build_play()
	elif _tab == 1:
		_build_stats()
	else:
		_build_lore()
	if _scroll:
		_scroll.scroll_vertical = 0


func _style_tabs() -> void:
	for i in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[i]
		var active := i == _tab
		b.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02) if active else PARCHMENT)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(2 if active else 1)
		sb.bg_color = Color(0.93, 0.71, 0.28, 1.0) if active else Color(0.055, 0.08, 0.15, 0.92)
		sb.border_color = Color(1.0, 0.90, 0.60, 0.9) if active else Color(1, 1, 1, 0.10)
		b.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate()
		hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
		if not active:
			hover.bg_color = Color(0.09, 0.13, 0.23, 0.98)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ==================== 属性页 ====================
func _build_stats() -> void:
	var lv := _level()
	var m0 := Config.level_mult(lv)
	var m1 := Config.level_mult(mini(lv + 1, 16))
	_body.add_child(_section("核心数值", "当前等级与下一级对比"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	var spell := _is_spell_card()
	var hp0 := cfg.max_health * m0
	var hp1 := cfg.max_health * m1
	var dmg0 := cfg.damage * m0
	var dmg1 := cfg.damage * m1
	if cfg.max_health > 0.0 and not spell:
		grid.add_child(_stat_card("生命", "shield", _i(hp0), _i(hp1), Color(0.95, 0.45, 0.45)))
	grid.add_child(_stat_card("伤害", "sword", _i(dmg0), _i(dmg1), Color(1.0, 0.70, 0.36)))
	if cfg.attack_speed > 0:
		grid.add_child(_stat_card("DPS", "flame", _i(_dps(m0)), _i(_dps(m1)), Color(0.95, 0.55, 0.25)))
		grid.add_child(_stat_card("攻击间隔", "clock", "%.1fs" % (cfg.attack_speed / 1000.0), "", MUTED))
	grid.add_child(_stat_card("攻击距离", "range", "%.1f 格" % cfg.attack_range, "", Color(0.55, 0.80, 1.0)))
	if cfg.damage_range > 0.0:
		grid.add_child(_stat_card("范围", "globe", "%.1f 格" % cfg.damage_range, "", Color(0.70, 0.62, 1.0)))
	grid.add_child(_stat_card("目标", "target", _target_cn(cfg.target_type), "", Color(0.66, 0.86, 0.70)))
	grid.add_child(_stat_card("圣水", "drop", "%d" % _cost(), "", Color(0.72, 0.52, 1.0)))
	if cfg.type != Config.UnitType.BUILDING:
		grid.add_child(_stat_card("移动速度", "boot", "%.1f 格/秒" % (cfg.move_speed / 24.0) if cfg.move_speed > 0 else "—", "", MUTED))
		grid.add_child(_stat_card("部署数量", "cards", "%d" % cfg.num, "", Color(0.86, 0.82, 0.70)))
	if cfg.shield != 0.0:
		grid.add_child(_stat_card("护盾", "shield", "攻击即死" if cfg.shield < 0.0 else _i(cfg.shield), "", Color(0.70, 0.85, 1.0)))

	_body.add_child(_section("机制与定位", "这张卡在对局中的职责"))
	var mech := PanelContainer.new()
	mech.add_theme_stylebox_override("panel", _card_style())
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mech.add_child(mv)
	var role := HFlowContainer.new()
	role.add_theme_constant_override("h_separation", 5)
	role.add_theme_constant_override("v_separation", 5)
	for t in _role_tags():
		role.add_child(_chip(t, Color(0.52, 0.72, 0.96)))
	mv.add_child(role)
	var extra := _mechanism_text()
	if extra != "":
		var ex := _label(extra, 17, Color(0.72, 0.78, 0.90))
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(ex)
	_body.add_child(mech)


# ==================== 升级页 ====================
func _build_upgrade() -> void:
	var level := _level()
	var owned := PlayerData.is_card_owned(cfg.card_id)
	var own := PlayerData.get_card_quantity(cfg.card_id)
	var need := PlayerData.calculate_upgrade_cards_needed(cfg.card_id, level)
	var cost_gold := PlayerData.calculate_upgrade_gold(cfg.card_id, level)
	var at_max := level >= 16
	if not owned:
		var locked := PanelContainer.new()
		locked.add_theme_stylebox_override("panel", _card_style())
		var lv := VBoxContainer.new()
		lv.add_theme_constant_override("separation", 10)
		locked.add_child(lv)
		lv.add_child(_label("🔒 尚未获得该卡", 27, GOLD_LIGHT, true))
		lv.add_child(_label("解锁于：%s" % PlayerData.card_unlock_arena_name(cfg.card_id), 18, MUTED))
		_body.add_child(locked)
		return

	_body.add_child(_section("升级进度", "提升等级会同步增加生命与伤害"))
	var progress_panel := PanelContainer.new()
	progress_panel.add_theme_stylebox_override("panel", _card_style())
	_body.add_child(progress_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	progress_panel.add_child(pv)
	var lrow := HBoxContainer.new()
	var ll := _label("Lv.%d" % level, 29, GOLD_LIGHT, true)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(ll)
	var next_txt := "已满级" if at_max else "→ Lv.%d" % (level + 1)
	lrow.add_child(_label(next_txt, 22, MUTED))
	pv.add_child(lrow)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.add_theme_stylebox_override("background", _style(Color(0.02, 0.03, 0.07, 0.95), Color(1, 1, 1, 0.10), 8))
	bar.add_theme_stylebox_override("fill", _style(Color(0.94, 0.72, 0.28), Color(1.0, 0.90, 0.58), 8))
	if at_max:
		bar.max_value = 1
		bar.value = 1
	else:
		bar.max_value = maxf(1, float(need))
		bar.value = mini(own, need)
	pv.add_child(bar)
	var inventory := _label("卡牌 %d / %d · 金币 %d / %d" % [own, need, PlayerData.gold, cost_gold], 17, Color(0.74, 0.82, 0.94))
	pv.add_child(inventory)

	var preview := GridContainer.new()
	preview.columns = 2
	preview.add_theme_constant_override("h_separation", 8)
	preview.add_theme_constant_override("v_separation", 8)
	_body.add_child(preview)
	var m0 := Config.level_mult(level)
	var m1 := Config.level_mult(mini(level + 1, 16))
	preview.add_child(_stat_card("生命变化", "shield", _i(cfg.max_health * m0), _i(cfg.max_health * m1), Color(0.95, 0.45, 0.45)))
	preview.add_child(_stat_card("伤害变化", "sword", _i(cfg.damage * m0), _i(cfg.damage * m1), Color(1.0, 0.70, 0.36)))

	if at_max:
		var max_panel := Panel.new()
		max_panel.add_theme_stylebox_override("panel", _card_style())
		var ml := _label("👑 已满级 · 该卡已达到最高等级", 21, GOLD_LIGHT, true)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		max_panel.custom_minimum_size = Vector2(0, 84)
		max_panel.add_child(ml)
		_body.add_child(max_panel)
	else:
		var up_btn := Button.new()
		up_btn.text = "升级到 Lv.%d" % (level + 1)
		up_btn.focus_mode = Control.FOCUS_NONE
		up_btn.custom_minimum_size = Vector2(0, 66)
		up_btn.add_theme_font_size_override("font_size", 23)
		_style_primary(up_btn)
		up_btn.disabled = own < need or PlayerData.gold < cost_gold
		up_btn.pressed.connect(_on_upgrade)
		_body.add_child(up_btn)

	var wild_n := PlayerData.get_wildcard_for_card(cfg.card_id)
	if wild_n > 0:
		var wild_panel := PanelContainer.new()
		wild_panel.add_theme_stylebox_override("panel", _card_style())
		_body.add_child(wild_panel)
		var wv := VBoxContainer.new()
		wv.add_theme_constant_override("separation", 8)
		wild_panel.add_child(wv)
		wv.add_child(_label("🃏 万能卡库存：%d 张（%s）" % [wild_n, _rarity_cn()], 17, Color(0.72, 0.86, 1.0)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		wv.add_child(row)
		var minus := _small_btn("−", Color(0.80, 0.35, 0.32))
		row.add_child(minus)
		_wild_spin = SpinBox.new()
		_wild_spin.min_value = 1
		_wild_spin.max_value = maxf(1, float(wild_n))
		_wild_spin.step = 1
		_wild_spin.value = 1
		_wild_spin.custom_minimum_size = Vector2(130, 50)
		_wild_spin.add_theme_font_size_override("font_size", 19)
		row.add_child(_wild_spin)
		var plus := _small_btn("+", Color(0.30, 0.70, 0.95))
		row.add_child(plus)
		var use_wild := _small_btn("使用万能卡", Color(0.66, 0.52, 0.96))
		use_wild.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(use_wild)
		minus.pressed.connect(func(): _wild_spin.value = maxf(1.0, _wild_spin.value - 1))
		plus.pressed.connect(func(): _wild_spin.value = minf(float(wild_n), _wild_spin.value + 1))
		use_wild.pressed.connect(_on_use_wildcard)


# ==================== 玩法页 ====================
func _build_play() -> void:
	_body.add_child(_section("定位", "先理解这张卡在对局中的角色"))
	var role_panel := PanelContainer.new()
	role_panel.add_theme_stylebox_override("panel", _card_style())
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	role_panel.add_child(rv)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 5)
	tags.add_theme_constant_override("v_separation", 5)
	for t in _role_tags():
		tags.add_child(_chip(t, Color(0.52, 0.72, 0.96)))
	rv.add_child(tags)
	var tip := _label(_tip_for_card(), 18, Color(0.86, 0.90, 0.98))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(tip)
	_body.add_child(role_panel)

	var stage = USAGE_STAGE.new()
	stage.setup(cfg.card_name, cfg)
	_body.add_child(stage)

	_body.add_child(_section("优缺点", "用一句话记住克制关系"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	grid.add_child(_advice_card("优势 · 克制", _strengths(), Color(0.42, 0.86, 0.52)))
	grid.add_child(_advice_card("劣势 · 被克制", _weaknesses(), Color(0.95, 0.42, 0.40)))

	_body.add_child(_section("搭配建议", "围绕这张卡构建卡组"))
	var combo := PanelContainer.new()
	combo.add_theme_stylebox_override("panel", _card_style())
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	combo.add_child(cv)
	for t in _synergy_tips():
		cv.add_child(_label("• " + t, 17, Color(0.78, 0.84, 0.94)))
	_body.add_child(combo)


# ==================== 简介页 ====================
func _build_lore() -> void:
	_body.add_child(_section("卡牌简介", "官方简短描述"))
	var p := PanelContainer.new()
	var sb := _card_style()
	p.add_theme_stylebox_override("panel", sb)
	_body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 5)
	chips.add_child(_chip(_rarity_cn(), _rarity_color()))
	chips.add_child(_chip(_type_cn(cfg.type), Color(0.56, 0.78, 0.96)))
	chips.add_child(_chip("圣水 %d" % _cost(), Color(0.72, 0.52, 1.0)))
	v.add_child(chips)
	var quote := _label(LORE.description_for(cfg), 21, Color(0.94, 0.91, 0.82), true)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)
	var divider := ColorRect.new()
	divider.color = Color(0.94, 0.72, 0.30, 0.55)
	divider.custom_minimum_size = Vector2(0, 2)
	v.add_child(divider)
	var role := _label("定位：%s" % "、".join(_role_tags()), 16, Color(0.72, 0.80, 0.94))
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(role)


# ==================== helpers ====================
func _advice_card(title: String, items: Array, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _card_style()
	sb.bg_color = Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.08, 0.92)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	v.add_child(_label(title, 20, accent, true))
	for t in items:
		var l := _label("• " + String(t), 16, Color(0.84, 0.88, 0.96))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return p


func _section(title: String, subtitle: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.custom_minimum_size = Vector2(4, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(_label(title, 22, GOLD_LIGHT, true))
	var s := _label(subtitle, 14, MUTED)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(s)
	v.add_child(h)
	return v


func _stat_card(label: String, icon_kind: String, cur: String, next: String, accent: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 90)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _card_style()
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ic = preload("res://assets/ui/menu/MenuIcon.gd").new()
	ic.kind = icon_kind
	ic.tint = accent
	ic.custom_minimum_size = Vector2(32, 32)
	ic.size = Vector2(32, 32)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(_label(label, 15, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var val := _label(cur, 27, PARCHMENT, true)
	row.add_child(val)
	if next != "" and next != cur:
		row.add_child(_label("→", 19, Color(0.58, 0.64, 0.76)))
		row.add_child(_label(next, 25, Color(0.56, 0.94, 0.62), true))
	v.add_child(row)
	return p


func _hero_stats() -> Array:
	var out: Array = []
	if cfg.max_health > 0.0 and not _is_spell_card():
		out.append("❤ %s" % _i(cfg.max_health * Config.level_mult(_level())))
	out.append("⚔ %s" % _i(cfg.damage * Config.level_mult(_level())))
	if cfg.damage_range > 0.0:
		out.append("范围 %.1f" % cfg.damage_range)
	elif cfg.attack_range > 0.0:
		out.append("射程 %.1f" % cfg.attack_range)
	return out


func _role_tags() -> Array:
	var out: Array = []
	if _is_spell_card():
		out.append("法术")
		if cfg.damage_range >= 2.0:
			out.append("范围伤害")
		if cfg.cost <= 3:
			out.append("低费解场")
	elif cfg.type == Config.UnitType.BUILDING:
		out.append("建筑")
		out.append("拉扯/防守")
	elif cfg.max_health >= 2500.0:
		out.append("坦克")
		out.append("推进核心")
	elif cfg.attack_range >= 5.0:
		out.append("远程")
		out.append("后排输出")
	else:
		out.append("近战")
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		out.append("只打建筑")
	if cfg.type == Config.UnitType.AIR:
		out.append("空中")
	if cfg.damage_range > 0.0 and not _is_spell_card():
		out.append("群体伤害")
	if cfg.cost <= 2:
		out.append("低费")
	return out


func _strengths() -> Array:
	var out: Array = []
	if _is_spell_card():
		out.append("聚集的低血量单位/人海")
		if cfg.damage_range >= 2.0:
			out.append("后排与建筑密集站位")
		if cfg.card_id in [11, 10, 20, 48]:
			out.append("可打断或清理关键小费单位")
		return out
	if cfg.damage_range > 0.0:
		out.append("骷髅军团、亡灵等群体")
	if cfg.target_type == Config.TargetType.BUILDING_ONLY:
		out.append("公主塔/建筑，直取核心")
	if cfg.max_health >= 2500.0:
		out.append("吸收火力，掩护后排推进")
	if cfg.attack_range >= 5.0:
		out.append("塔后远程消耗与防守")
	if cfg.type == Config.UnitType.AIR:
		out.append("地面近战无法攻击你")
	if cfg.cost <= 2:
		out.append("低费过牌、拉扯")
	if out.is_empty():
		out.append("单挑与防守反击")
	return out


func _weaknesses() -> Array:
	var out: Array = []
	if _is_spell_card():
		out.append("分散站位时命中价值低")
		out.append("高血量单体/坦克")
		return out
	if cfg.max_health < 900.0:
		out.append("火球、万箭等范围法术")
	if cfg.target_type == Config.TargetType.GROUND_ONLY:
		out.append("空中单位无法处理")
	if cfg.attack_range >= 5.0:
		out.append("被近身突袭/矿工切后排")
	if cfg.damage_range > 0.0:
		out.append("高血量单体不如单体 DPS")
	if cfg.cost >= 5:
		out.append("费用高，被快速节奏惩罚")
	if out.is_empty():
		out.append("被更强单体或人海围杀")
	return out


func _synergy_tips() -> Array:
	var out: Array = []
	if _is_spell_card():
		out.append("搭配高血量推进单位，等对方防守单位聚集再交。")
		out.append("不要空放；优先换掉对方的关键后排或建筑。")
	elif cfg.type == Config.UnitType.BUILDING:
		out.append("放在公主塔前拉扯，为后排争取输出时间。")
		out.append("避免和公主塔贴太近，减少被法术连带。")
	elif cfg.max_health >= 2500.0:
		out.append("先下坦克，再跟远程/群体输出。")
		out.append("配合治疗/冰冻/狂暴提升推进成功率。")
	elif cfg.attack_range >= 5.0:
		out.append("前面放坦克或建筑，保护后排输出。")
		out.append("注意对方法术和矿工，不要裸放。")
	else:
		out.append("防守后利用存活单位桥头反打。")
		out.append("配合小费过牌，保持卡组循环。")
	return out


func _mechanism_text() -> String:
	var parts: Array = []
	if not cfg.extra_spell.is_empty(): parts.append("附加效果：%s" % _fmt_arr(cfg.extra_spell))
	if not cfg.spawn_unit.is_empty(): parts.append("持续召唤：%s" % _fmt_arr(cfg.spawn_unit))
	if not cfg.multiple_targets.is_empty(): parts.append("多目标：%s" % _fmt_arr(cfg.multiple_targets))
	if not cfg.multiple_process.is_empty(): parts.append("多段处理：%s" % _fmt_arr(cfg.multiple_process))
	return "\n".join(parts)


func _build_model(cam: Camera3D) -> void:
	var spell_kind := String(SPELL_PROJECTILES.get(cfg.card_name, ""))
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
		_model_root.rotation.y += delta * 0.35 + _spin
		_spin = 0.0


func _on_use_wildcard() -> void:
	var n: int = int(_wild_spin.value) if _wild_spin else 1
	if PlayerData.use_wildcard_on_card(cfg.card_id, n):
		if on_changed.is_valid(): on_changed.call(cfg.card_id)
		_rebuild("已使用 %d 张万能卡，卡牌数量 +%d" % [n, n])
	else:
		_status.text = "万能卡不足或没有匹配稀有度"


func _on_upgrade() -> void:
	if PlayerData.upgrade_card(cfg.card_id):
		if on_changed.is_valid(): on_changed.call(cfg.card_id)
		_rebuild("升级成功！")
	else:
		_status.text = "升级失败：金币或卡牌不足"


func _rebuild(message: String = "") -> void:
	if not is_inside_tree():
		return
	# 清空旧界面，保留 cfg/on_changed 后重建，避免重复叠加
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_tab = 0
	_build(cfg, on_changed)
	_switch_tab(1)
	if message != "" and _status:
		_status.text = message


func _level() -> int: return PlayerData.get_card_level(cfg.card_id)
func _cost() -> int: return cfg.cost
func _rarity_color() -> Color: return CARD_RARITY.rarity_color_by_id(cfg.card_id)
func _rarity_cn() -> String: return CARD_RARITY.rarity_cn_by_id(cfg.card_id)
func _i(v: float) -> String: return str(int(round(v)))
func _is_spell_card() -> bool: return cfg.attack_speed <= 0 and cfg.type != Config.UnitType.BUILDING
func _dps(mult: float) -> float:
	if cfg.attack_speed <= 0: return 0.0
	return cfg.damage * mult / (float(cfg.attack_speed) / 1000.0) * float(cfg.num)
func _target_cn(v: int) -> String:
	match v:
		Config.TargetType.ALL: return "所有目标"
		Config.TargetType.GROUND_ONLY: return "仅地面"
		Config.TargetType.BUILDING_ONLY: return "仅建筑"
	return "未知"
func _type_cn(v: int) -> String:
	match v:
		Config.UnitType.BUILDING: return "建筑"
		Config.UnitType.GROUND: return "地面单位"
		Config.UnitType.AIR: return "空中单位"
	return "未知"
func _fmt_arr(arr: Array) -> String:
	var p: Array = []
	for v in arr: p.append(str(v))
	return "、".join(p)
func _chip(text: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 15, accent.lightened(0.18))
	p.add_child(l)
	return p
func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.062, 0.120, 0.94)
	sb.set_corner_radius_all(15)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	return sb
func _style_primary(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	btn.add_theme_stylebox_override("normal", _style(Color(0.93, 0.71, 0.28), Color(1.0, 0.90, 0.60), 14))
	btn.add_theme_stylebox_override("hover", _style(Color(1.0, 0.80, 0.38), Color(1.0, 0.94, 0.74), 14))
	btn.add_theme_stylebox_override("pressed", _style(Color(0.80, 0.60, 0.22), Color(1.0, 0.84, 0.50), 14))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
func _small_btn(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(62, 50)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.20, 0.12, 0.03))
	b.add_theme_stylebox_override("normal", _style(accent, accent.lightened(0.25), 11))
	b.add_theme_stylebox_override("hover", _style(accent.lightened(0.12), accent.lightened(0.35), 11))
	b.add_theme_stylebox_override("pressed", _style(accent.darkened(0.12), accent, 11))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b
func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l


# 卡牌专属提示
func _tip_for_card() -> String:
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
	if tips.has(cfg.card_name): return tips[cfg.card_name]
	if cfg.type == Config.UnitType.BUILDING: return "建筑用来拉扯和防守，别贴公主塔放，避免被法术连带消耗。"
	if _is_spell_card(): return "法术不要空放；等对方单位聚集或进入关键位置再交。"
	if cfg.type == Config.UnitType.AIR: return "空中单位怕对空火力和法术，进攻时先用坦克或地面单位吸引火力。"
	if cfg.target_type == Config.TargetType.BUILDING_ONLY: return "只打建筑，适合桥头偷塔；需要法术或后排掩护。"
	if cfg.max_health >= 2500: return "坦克要先用其他单位吸收火力，再跟进后排输出。"
	if cfg.cost <= 2: return "低费卡主要用于过牌和拉扯，不要单独送进对方半场。"
	if cfg.attack_range >= 5: return "远程单位放塔后输出，前面需要有坦克或建筑保护。"
	return "先看清对方核心威胁，再决定这张卡是解场还是反打。"
