extends PanelContainer
class_name DeckCardTile

const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const GRAY_SHADER = preload("res://assets/shaders/grayscale_card.gdshader")
const ELIXIR_BADGE = preload("res://scripts/ui/ElixirBadge.gd")
const XP_BAR = preload("res://scripts/ui/DeckXpBar.gd")

signal clicked(tile)

var config: CardData
var mode: String = "pool"
var _level_lbl: Label
var _lv_badge: Label
var _bar
var _arrow: Label
var _in_deck_mark: Label
var _new_badge: Label
var _locked: bool = false
static var party_preview: bool = false
var _arrow_tween: Tween = null

func setup(cfg: CardData, tile_mode: String, compact: bool = false) -> void:
	config = cfg
	mode = tile_mode
	custom_minimum_size = Vector2(150, 206) if compact else Vector2(168, 232)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.075, 0.12, 0.97)
	sb.set_border_width_all(5)
	var rarity_col: Color = CARD_RARITY.rarity_color_by_id(config.card_id)
	sb.border_color = rarity_col
	sb.set_corner_radius_all(15)
	sb.shadow_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.38)
	sb.shadow_size = 7
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	# 图像区：铺满宽度，不露两侧缝
	var img_panel := Panel.new()
	img_panel.clip_contents = true
	img_panel.custom_minimum_size = Vector2(0, 128) if compact else Vector2(0, 142)
	img_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img_sb := StyleBoxFlat.new()
	img_sb.bg_color = Color(0.15, 0.13, 0.19)
	img_sb.set_corner_radius_all(10)
	img_panel.add_theme_stylebox_override("panel", img_sb)
	vb.add_child(img_panel)

	var path := "res://assets/cards_web/%s.png" % _safe(config.card_name)
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % _safe(config.card_name)
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	# 背景：拉伸铺满，避免两侧留缝
	var bg_tr := TextureRect.new()
	bg_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tr.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tr.modulate = Color(0.28, 0.28, 0.34, 1.0)
	bg_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_tr.texture = tex
	img_panel.add_child(bg_tr)
	# 前景：完整显示卡图（不裁掉上部）
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = tex
	_locked = not PlayerData.is_card_owned(config.card_id)
	if party_preview:
		_locked = false
	if _locked:
		var mat := ShaderMaterial.new()
		mat.shader = GRAY_SHADER
		tr.material = mat
		var bgmat := ShaderMaterial.new()
		bgmat.shader = GRAY_SHADER
		bg_tr.material = bgmat
	img_panel.add_child(tr)

	# 圣水徽章（与对战卡牌一致的水滴图标）
	var badge = ELIXIR_BADGE.new()
	badge.cost = config.cost
	if config.card_id == 123:
		badge.display_text = "?"
	badge.custom_minimum_size = Vector2(32, 36)
	badge.position = Vector2(2, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_panel.add_child(badge)

	var lv_box := Panel.new()
	lv_box.anchor_left = 1.0
	lv_box.anchor_right = 1.0
	lv_box.offset_left = -64
	lv_box.offset_right = -4
	lv_box.offset_top = 2
	lv_box.offset_bottom = 30
	lv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvsb := StyleBoxFlat.new()
	lvsb.bg_color = Color(0.06, 0.05, 0.09, 0.88)
	lvsb.border_color = Color(1.0, 0.82, 0.36)
	lvsb.set_border_width_all(1)
	lvsb.set_corner_radius_all(9)
	lv_box.add_theme_stylebox_override("panel", lvsb)
	img_panel.add_child(lv_box)
	_lv_badge = Label.new()
	_lv_badge.text = "Lv.11" if party_preview else "Lv.%d" % PlayerData.get_card_level(config.card_id)
	_lv_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lv_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lv_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lv_badge.add_theme_font_size_override("font_size", 16)
	_lv_badge.add_theme_constant_override("outline_size", 3)
	_lv_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_lv_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_lv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv_box.add_child(_lv_badge)

	_in_deck_mark = Label.new()
	_in_deck_mark.text = "✓ 已选"
	_in_deck_mark.position = Vector2(6, 146 if not compact else 130)
	_in_deck_mark.add_theme_font_size_override("font_size", 11)
	_in_deck_mark.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	_in_deck_mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_in_deck_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_in_deck_mark.visible = false
	img_panel.add_child(_in_deck_mark)
	_new_badge = Label.new()
	_new_badge.text = "新"
	_new_badge.position = Vector2(6, 38)
	_new_badge.size = Vector2(30, 24)
	_new_badge.add_theme_font_size_override("font_size", 16)
	_new_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_new_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_new_badge.add_theme_constant_override("shadow_offset_x", 1)
	_new_badge.add_theme_constant_override("shadow_offset_y", 1)
	_new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_badge.visible = PlayerData.is_new_card(config.card_id) and not _locked
	img_panel.add_child(_new_badge)

	if _locked:
		modulate = Color(0.60, 0.60, 0.66, 0.92)
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 未解锁"
		lock_lbl.position = Vector2(48, 66)
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
		lock_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_panel.add_child(lock_lbl)
		var unlock_lbl := Label.new()
		unlock_lbl.text = "解锁于 " + PlayerData.card_unlock_arena_name(config.card_id)
		unlock_lbl.position = Vector2(4, 84)
		unlock_lbl.size = Vector2(140, 34)
		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlock_lbl.add_theme_font_size_override("font_size", 9)
		unlock_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.58))
		unlock_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
		unlock_lbl.add_theme_constant_override("outline_size", 3)
		unlock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_panel.add_child(unlock_lbl)

	# 名称（带描边/阴影，提升可读性）
	var name_lbl := Label.new()
	name_lbl.text = config.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_res := load("res://assets/fonts/STZHONGS.TTF")
	if font_res:
		var fv := FontVariation.new()
		fv.base_font = font_res
		fv.variation_embolden = 1.0
		name_lbl.add_theme_font_override("font", fv)
	name_lbl.add_theme_font_size_override("font_size", 16 if compact else 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.04, 1.0))
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	# 进度条行：左侧升级箭头 + 高质量进度条
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 3)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(prow)
	_arrow = Label.new()
	_arrow.text = "⬆"
	_arrow.custom_minimum_size = Vector2(16, 0)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.add_theme_font_size_override("font_size", 30)
	_arrow.add_theme_color_override("font_outline_color", Color(0.02, 0.10, 0.03))
	_arrow.add_theme_constant_override("outline_size", 4)
	_arrow.custom_minimum_size = Vector2(30, 0)
	_arrow.add_theme_color_override("font_color", Color(0.40, 1.0, 0.52))
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	prow.add_child(_arrow)
	_bar = XP_BAR.new()
	_bar.custom_minimum_size = Vector2(0, 36)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(_bar)

	gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
	)
	mouse_entered.connect(func():
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.025, 1.025), 0.08)
	)
	mouse_exited.connect(func():
		var tw2 := create_tween()
		tw2.tween_property(self, "scale", Vector2.ONE, 0.10)
	)
	refresh()

func _safe(n: String) -> String:
	return n.replace("/", "_").replace("\\", "_").replace(":", "_").replace("*", "_").replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")

func clear_new_badge() -> void:
	if _new_badge:
		_new_badge.visible = false
	PlayerData.mark_card_seen(config.card_id)

func set_in_deck(v: bool) -> void:
	if _in_deck_mark:
		_in_deck_mark.visible = v

func refresh() -> void:
	if config == null:
		return
	if _arrow_tween != null and _arrow_tween.is_valid():
		_arrow_tween.kill()
	_arrow_tween = null
	_arrow.position.y = 0.0
	var lv: int = PlayerData.get_card_level(config.card_id)
	if _lv_badge:
		_lv_badge.text = "Lv.11" if party_preview else "Lv.%d" % lv
	var own: int = PlayerData.get_card_quantity(config.card_id)
	var need: int = PlayerData.calculate_upgrade_cards_needed(config.card_id, lv)
	var maxed: bool = lv >= 16
	if _locked:
		_arrow.visible = false
		_bar.set_data(0, 1, Color(0.42, 0.42, 0.48), "未解锁")
		return
	if maxed:
		_arrow.visible = false
		_bar.set_data(1, 1, Color(0.88, 0.68, 0.28), "MAX")
		return
	_bar.set_data(own, max(need, 1), Color(0.30, 0.92, 0.42) if own >= need else Color(0.25, 0.62, 1.0), "%d/%d" % [own, need])
	var cards_ok: bool = own >= need
	var gold_ok: bool = PlayerData.gold >= PlayerData.calculate_upgrade_gold(config.card_id, lv)
	_arrow.visible = cards_ok
	if cards_ok:
		_arrow.add_theme_color_override("font_color", Color(0.35, 1.0, 0.50))
		if gold_ok:
			_arrow_tween = create_tween().set_loops()
			_arrow_tween.tween_property(_arrow, "position:y", -4.0, 0.45).set_trans(Tween.TRANS_SINE)
			_arrow_tween.tween_property(_arrow, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
