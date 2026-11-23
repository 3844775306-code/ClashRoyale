# scripts/ui/TourTip.gd
# 进入模块后的细节提示：皇家顾问继续讲解，然后返回主菜单继续下一站
extends Control

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")

var _step := 0
var _title := ""
var _detail := ""
var _font: Font


func setup(step: int, data: Dictionary) -> void:
	_step = step
	_title = String(data.get("title", "模块"))
	_detail = String(data.get("detail", ""))


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 290
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.008, 0.025, 0.38)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var vp := get_viewport_rect().size
	var panel := Panel.new()
	panel.position = Vector2(30, vp.y - 560)
	panel.size = Vector2(vp.x - 60, 500)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.052, 0.105, 0.985)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.72)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var av_bg := Panel.new()
	av_bg.position = Vector2(24, 24)
	av_bg.size = Vector2(130, 130)
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.08, 0.10, 0.18, 1)
	asb.set_corner_radius_all(65)
	asb.set_border_width_all(3)
	asb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	av_bg.add_theme_stylebox_override("panel", asb)
	panel.add_child(av_bg)
	var av = AVATAR_ICON.new()
	av.position = Vector2(9, 9)
	av.size = Vector2(112, 112)
	av.custom_minimum_size = Vector2(112, 112)
	av.setup_local()
	av_bg.add_child(av)

	var name_lbl := _label("皇家顾问", 17, GOLD, true)
	name_lbl.position = Vector2(176, 28)
	panel.add_child(name_lbl)
	var icon = ICON.new()
	icon.kind = "star"
	icon.tint = GOLD
	icon.position = Vector2(176, 58)
	icon.size = Vector2(24, 24)
	icon.custom_minimum_size = Vector2(24, 24)
	panel.add_child(icon)
	var title := _label("正在了解：%s" % _title, 21, GOLD_LIGHT, true)
	title.position = Vector2(208, 54)
	title.size = Vector2(panel.size.x - 230, 34)
	panel.add_child(title)

	var text := _label(_detail, 16, PARCHMENT)
	text.position = Vector2(176, 100)
	text.size = Vector2(panel.size.x - 200, 210)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)

	var hint := _label("看完了就返回主菜单，我会继续带你认识下一个模块。", 12, MUTED)
	hint.position = Vector2(176, 320)
	hint.size = Vector2(panel.size.x - 200, 24)
	panel.add_child(hint)

	var skip := _btn("结束引导", TutorialTour.skip_tour, false, Vector2(150, 44))
	skip.position = Vector2(24, panel.size.y - 60)
	panel.add_child(skip)
	var ok := _btn("我明白了，返回主菜单", TutorialTour.finish_tip, true, Vector2(360, 52))
	ok.position = Vector2(panel.size.x - 390, panel.size.y - 66)
	panel.add_child(ok)


func _btn(text: String, cb: Callable, primary: bool, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	if _font:
		b.add_theme_font_override("font", _font)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(13)
	sb.set_border_width_all(2 if primary else 1)
	if primary:
		sb.bg_color = Color(0.93, 0.71, 0.28, 1)
		sb.border_color = Color(1.0, 0.90, 0.60, 0.9)
	else:
		sb.bg_color = Color(0.07, 0.10, 0.19, 0.96)
		sb.border_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.75)
	if not primary:
		hover.bg_color = Color(0.10, 0.14, 0.25, 1.0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02) if primary else PARCHMENT)
	b.pressed.connect(cb)
	return b


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
