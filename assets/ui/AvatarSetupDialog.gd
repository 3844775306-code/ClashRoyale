# assets/ui/AvatarSetupDialog.gd
# 新账号首次登录：在取名后引导玩家更换头像（上传图片自动居中裁剪为正方形）。
extends Control

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")

var _preview
var _hint: Label
var _file: FileDialog
var _font: Font


func _ready() -> void:
	add_to_group("avatar_setup_dialog")
	z_index = 210
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.008, 0.02, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -360
	panel.offset_bottom = 360
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.065, 0.125, 0.985)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.65)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 34
	v.offset_right = -34
	v.offset_top = 26
	v.offset_bottom = -26
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var title := _label("换个头像吧，国王", 28, GOLD_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("新账号可以上传自己的头像，或随机生成一个皇家头像", 13, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size = Vector2(0, 190)
	v.add_child(center)
	var ring := Panel.new()
	ring.custom_minimum_size = Vector2(176, 176)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.07, 0.09, 0.16, 1.0)
	rsb.set_corner_radius_all(88)
	rsb.set_border_width_all(3)
	rsb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	ring.add_theme_stylebox_override("panel", rsb)
	center.add_child(ring)
	_preview = AVATAR_ICON.new()
	_preview.position = Vector2(14, 14)
	_preview.size = Vector2(148, 148)
	_preview.custom_minimum_size = Vector2(148, 148)
	ring.add_child(_preview)
	_refresh()

	_hint = _label("上传图片会自动居中裁剪为正方形头像", 12, Color(0.72, 0.78, 0.90))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(_btn("上传图片", _choose_image, false, Vector2(180, 52)))
	row.add_child(_btn("随机头像", _random_avatar, false, Vector2(180, 52)))

	var done := _btn("使用这个头像", _finish, true, Vector2(0, 56))
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(done)
	var later := _btn("稍后再说", _finish, false, Vector2(0, 44))
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(later)


func _choose_image() -> void:
	if OS.has_feature("web"):
		_choose_web()
		return
	_file = FileDialog.new()
	_file.title = "选择头像图片"
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"])
	_file.use_native_dialog = true
	_file.file_selected.connect(_on_file_selected)
	add_child(_file)
	_file.popup_centered(Vector2i(700, 500))


func _choose_web() -> void:
	var cb = JavaScriptBridge.create_callback(_on_web_image)
	JavaScriptBridge.get_interface("window").set("_crAvatarSetupCb", cb)
	JavaScriptBridge.eval("""
		(function(){
			var old = document.getElementById('cr-avatar-setup-input');
			if (old) old.remove();
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/*';
			input.id = 'cr-avatar-setup-input';
			input.style.display = 'none';
			input.onchange = function(e){
				var f = e.target.files[0];
				if (!f) return;
				var reader = new FileReader();
				reader.onload = function(){ window._crAvatarSetupCb(reader.result); input.remove(); };
				reader.readAsDataURL(f);
			};
			document.body.appendChild(input);
			input.click();
		})();
	""")


func _on_web_image(args) -> void:
	if args.is_empty():
		return
	var data := String(args[0])
	var comma := data.find(",")
	if comma < 0:
		return
	var raw := Marshalls.base64_to_raw(data.substr(comma + 1))
	var img := Image.new()
	if img.load_png_from_buffer(raw) != OK and img.load_jpg_from_buffer(raw) != OK:
		_hint.text = "图片格式不支持"
		return
	if PlayerData.set_custom_avatar_image(img):
		_refresh()
		_hint.text = "头像已更新（已自动裁剪为正方形）"
	else:
		_hint.text = "头像保存失败"


func _on_file_selected(path: String) -> void:
	if PlayerData.set_custom_avatar(path):
		_refresh()
		_hint.text = "头像已更新（已自动裁剪为正方形）"
	else:
		_hint.text = "图片读取失败"


func _random_avatar() -> void:
	PlayerData.randomize_avatar()
	_refresh()
	_hint.text = "已随机生成皇家头像"


func _refresh() -> void:
	if _preview:
		_preview.setup_local()
		_preview.queue_redraw()


func _finish() -> void:
	UiComponents.refresh_topbar()
	queue_free()


func _btn(text: String, cb: Callable, primary: bool, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 18)
	if _font:
		b.add_theme_font_override("font", _font)
	var sb := StyleBoxFlat.new()
	if primary:
		sb.bg_color = Color(0.93, 0.71, 0.28, 1.0)
		sb.border_color = Color(1.0, 0.90, 0.60, 0.9)
	else:
		sb.bg_color = Color(0.07, 0.10, 0.19, 0.96)
		sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(15)
	sb.set_border_width_all(2 if primary else 1)
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


func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	return l
