extends Node
# Web / iPad 软键盘：参考 honor-king 的 UiKit.bind_mobile_text_edit 做法。
# iOS Safari 对 Canvas 内 LineEdit 的焦点支持不稳定，直接在该触摸手势里调用
# window.prompt() 最可靠：系统会弹出原生键盘，确认后再把文本写回 LineEdit。

var _scan_acc := 0.0
var _touch_device := false
var _busy := false


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	var ua := String(JavaScriptBridge.eval("navigator.userAgent"))
	var touch_points := int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0"))
	_touch_device = ua.contains("iPad") or ua.contains("iPhone") or ua.contains("iPod") or touch_points > 0
	call_deferred("_scan_tree")


func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_scan_acc += delta
	if _scan_acc < 0.25:
		return
	_scan_acc = 0.0
	_scan_tree()


func _scan_tree() -> void:
	_walk(get_tree().root)


func _walk(n: Node) -> void:
	if n is LineEdit and not n.has_meta("web_keyboard_attached"):
		_attach(n as LineEdit)
	for c in n.get_children():
		_walk(c)


func _attach(field: LineEdit) -> void:
	field.set_meta("web_keyboard_attached", true)
	field.gui_input.connect(func(event: InputEvent) -> void:
		if _busy or not is_instance_valid(field) or not field.is_visible_in_tree() or not field.editable:
			return
		if event is InputEventScreenTouch and event.pressed:
			_prompt(field)
		elif _touch_device and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_prompt(field)
	)


func _prompt(field: LineEdit) -> void:
	_busy = true
	var title := field.placeholder_text.strip_edges()
	if title == "":
		title = "请输入"
	title = title.replace("…", "").replace("...", "")
	var res = JavaScriptBridge.eval(
		"window.prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(String(field.text))],
		true)
	_busy = false
	field.accept_event()
	if res == null:
		return
	var text := String(res)
	if field.max_length > 0:
		text = text.left(field.max_length)
	field.text = text
	field.caret_column = field.text.length()
