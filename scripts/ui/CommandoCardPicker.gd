# scripts/ui/CommandoCardPicker.gd
# 自定义特种兵卡牌选择：顶部搜索栏 + 一排 4 张官方卡图
extends Control

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")

var _cards: Array = []
var _selected_id: int = 0
var _callback: Callable
var _search: LineEdit
var _grid: GridContainer
var _status: Label
var _font: Font


func setup(cards: Array, selected_id: int, callback: Callable) -> void:
	_cards = cards.duplicate(true)
	_selected_id = selected_id
	_callback = callback


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 220
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -620
	panel.offset_bottom = 620
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.030, 0.048, 0.098, 0.99)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var title := _label("选择特种兵", 25, GOLD_LIGHT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(100, 46)
	close.add_theme_font_size_override("font_size", 15)
	close.add_theme_color_override("font_color", PARCHMENT)
	close.add_theme_stylebox_override("normal", _btn_style(Color(0.08, 0.10, 0.19, 0.98), Color(1, 1, 1, 0.16)))
	close.add_theme_stylebox_override("hover", _btn_style(Color(0.13, 0.16, 0.28, 1.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.7)))
	close.add_theme_stylebox_override("pressed", _btn_style(Color(0.05, 0.07, 0.13, 1.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.5)))
	close.pressed.connect(func(): queue_free())
	head.add_child(close)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	v.add_child(search_row)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索卡牌名字 / ID"
	_search.custom_minimum_size = Vector2(0, 50)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", 16)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.02, 0.035, 0.075, 0.98)
	lsb.set_corner_radius_all(12)
	lsb.set_border_width_all(1)
	lsb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	lsb.content_margin_left = 14
	lsb.content_margin_right = 14
	_search.add_theme_stylebox_override("normal", lsb)
	_search.add_theme_color_override("font_color", PARCHMENT)
	_search.add_theme_color_override("font_placeholder_color", MUTED)
	_search.text_changed.connect(func(_t): _rebuild_grid())
	search_row.add_child(_search)

	_status = _label("", 12, MUTED)
	v.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	_rebuild_grid()
	_search.grab_focus()


func _rebuild_grid() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower() if _search else ""
	var shown := 0
	# 随机选项
	if q == "" or "随机".contains(q):
		_grid.add_child(_random_tile())
	for c in _cards:
		var nm := String(c.get("name", ""))
		var cid := int(c.get("id", 0))
		if q != "" and not (nm.to_lower().contains(q) or str(cid) == q):
			continue
		_grid.add_child(_card_tile(cid, nm))
		shown += 1
	if _status:
		_status.text = "共 %d 个可选兵种%s" % [shown, (" · 搜索：%s" % q) if q != "" else ""]


func _card_tile(cid: int, cname: String) -> Control:
	var selected := cid == _selected_id
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(166, 224)
	btn.add_theme_stylebox_override("normal", _tile_style(selected))
	btn.add_theme_stylebox_override("hover", _tile_style(true))
	btn.add_theme_stylebox_override("pressed", _tile_style(true))
	btn.pressed.connect(func(): _pick(cid))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 5
	v.offset_right = -5
	v.offset_top = 5
	v.offset_bottom = -5
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(0, 172)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/cards_web/%s.png" % cname
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % cname
	if ResourceLoader.exists(path):
		img.texture = load(path)
	v.add_child(img)
	var nl := _label(cname, 13, PARCHMENT, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(nl)
	var idl := _label("ID %d" % cid, 10, MUTED)
	idl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(idl)
	return btn


func _random_tile() -> Control:
	var selected := _selected_id == 0
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(166, 224)
	btn.add_theme_stylebox_override("normal", _tile_style(selected))
	btn.add_theme_stylebox_override("hover", _tile_style(true))
	btn.add_theme_stylebox_override("pressed", _tile_style(true))
	btn.pressed.connect(func(): _pick(0))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var ic = ICON.new()
	ic.kind = "star"
	ic.tint = GOLD
	ic.custom_minimum_size = Vector2(64, 64)
	ic.size = Vector2(64, 64)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var nl := _label("随机（每局）", 15, GOLD_LIGHT, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	var sub := _label("每局从全部兵种随机", 10, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	return btn


func _pick(cid: int) -> void:
	if _callback.is_valid():
		_callback.call(cid)
	queue_free()


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l


func _tile_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.040, 0.98) if selected else Color(0.040, 0.058, 0.110, 0.96)
	sb.set_corner_radius_all(13)
	sb.set_border_width_all(2 if selected else 1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95) if selected else Color(1, 1, 1, 0.12)
	return sb


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = border
	return sb
