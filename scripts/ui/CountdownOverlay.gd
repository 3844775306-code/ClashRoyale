extends Control
# 联机准备倒计时：金环+大数字，每秒弹跳

var _num: Label
var _sub: Label
var _time_left: float = 3.0
var _last_int: int = -1

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 900

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var ring := Panel.new()
	ring.position = Vector2(250, 600)
	ring.size = Vector2(300, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.14, 0.92)
	sb.border_color = Color(1.0, 0.80, 0.32)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(150)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	ring.add_theme_stylebox_override("panel", sb)
	add_child(ring)

	_num = Label.new()
	_num.text = "3"
	_num.position = Vector2(250, 640)
	_num.size = Vector2(300, 210)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num.add_theme_font_size_override("font_size", 150)
	_num.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	_num.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.02))
	_num.add_theme_constant_override("outline_size", 10)
	_num.pivot_offset = Vector2(150, 105)
	add_child(_num)

	_sub = Label.new()
	_sub.text = "准 备 战 斗"
	_sub.position = Vector2(200, 900)
	_sub.size = Vector2(400, 48)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	add_child(_sub)
	set_process(false)

func start(seconds: float = 3.0) -> void:
	_time_left = maxf(0.1, seconds)
	_last_int = -1
	visible = true
	set_process(true)
	_update_num()

func _process(delta):
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	_update_num()

func _update_num():
	var n := int(ceil(_time_left))
	if n == _last_int:
		return
	_last_int = n
	_num.text = str(n)
	_num.scale = Vector2(1.28, 1.28)
	var tw := create_tween()
	tw.tween_property(_num, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
