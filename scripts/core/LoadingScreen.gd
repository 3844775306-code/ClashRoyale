extends CanvasLayer

var _root: Control
var _message: Label
var _dots: Label
var _panel: Panel
var _t: float = 0.0
var _visible := false
var _back_btn: Button
var _nav_token := 0

func _ready():
	layer = 200
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	if ThemeHelper.ui_theme:
		_root.theme = ThemeHelper.ui_theme
	add_child(_root)

	var grad := Gradient.new()
	grad.set_color(0, Color(0.035, 0.055, 0.13))
	grad.set_color(1, Color(0.015, 0.018, 0.045))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.15, 0.97)
	sb.border_color = Color(0.95, 0.76, 0.34, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 34; v.offset_top = 26; v.offset_right = -34; v.offset_bottom = -26
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	var crown := TextureRect.new()
	crown.texture = load("res://icon.svg")
	crown.custom_minimum_size = Vector2(0, 118)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(crown)
	var title := Label.new()
	title.text = "皇 室 战 争"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.03))
	v.add_child(title)
	var line := ColorRect.new()
	line.color = Color(0.90, 0.70, 0.30, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	_message = Label.new()
	_message.text = "加载中"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	v.add_child(_message)
	_dots = Label.new()
	_dots.text = "..."
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.add_theme_font_size_override("font_size", 24)
	_dots.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	v.add_child(_dots)
	var hint := Label.new()
	hint.text = "正在准备对局资源"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.68, 0.84))
	v.add_child(hint)
	_back_btn = ThemeHelper.make_muted_button("返回主菜单", Vector2(0, 48))
	_back_btn.add_theme_font_size_override("font_size", 18)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.visible = false
	_back_btn.pressed.connect(go_main_menu)
	v.add_child(_back_btn)
	set_process(false)

func show_loading(text: String = "加载中…", show_back: bool = true) -> void:
	_message.text = text
	_back_btn.visible = show_back
	_root.visible = true
	_visible = true
	_t = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = Vector2(300, 230)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)
	_root.move_to_front()

func hide_loading() -> void:
	_visible = false
	_root.visible = false
	if _back_btn:
		_back_btn.visible = false
	set_process(false)


func go_main_menu() -> void:
	_nav_token += 1
	hide_loading()
	if NetworkManager and NetworkManager.has_method("reset_net"):
		NetworkManager.reset_net()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _process(delta):
	if not _visible:
		return
	_t += delta
	var n := int(_t * 2.6) % 4
	_dots.text = ".".repeat(n)
	_panel.offset_top = -230 + sin(_t * 1.4) * 3.0
	_panel.offset_bottom = 230 + sin(_t * 1.4) * 3.0

func change_scene(path: String, text: String = "加载中…") -> void:
	var token := _nav_token + 1
	_nav_token = token
	show_loading(text)
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _nav_token:
		return
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _nav_token:
		return
	hide_loading()
