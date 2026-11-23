extends Node
# Web 端（尤其是 iPad / iPhone Safari）软键盘修复：
# Godot 的 LineEdit 绘制在 Canvas 上，iOS 不会因为 Canvas 聚焦而弹出键盘。
# 因此在触摸 LineEdit 时，用 JavaScriptBridge 同步聚焦一个隐藏的 HTML input，
# 把浏览器输入同步回 LineEdit。

const JS := """
(function () {
	if (window._crWebKeyboardReady) return;
	window._crWebKeyboardReady = true;
	window._crWebKeyboardEl = null;

	function makeInput() {
		var old = window._crWebKeyboardEl;
		if (old) {
			try { old.blur(); } catch (e) {}
			try { old.remove(); } catch (e) {}
		}
		var el = document.createElement('input');
		el.type = 'text';
		el.autocomplete = 'off';
		el.autocapitalize = 'off';
		el.spellcheck = false;
		el.setAttribute('aria-hidden', 'true');
		el.style.cssText = 'position:fixed;left:0;top:0;width:2px;height:2px;' +
			'opacity:0.01;font-size:16px;z-index:2147483647;border:0;padding:0;margin:0;' +
			'background:transparent;color:transparent;caret-color:transparent;pointer-events:none;';
		el.addEventListener('input', function () {
			if (window._crWebKeyboardInput) window._crWebKeyboardInput(el.value);
		});
		el.addEventListener('keydown', function (e) {
			if (e.key === 'Enter') {
				e.preventDefault();
				if (window._crWebKeyboardInput) window._crWebKeyboardInput(el.value);
				if (window._crWebKeyboardSubmit) window._crWebKeyboardSubmit(el.value);
				el.blur();
			}
		});
		el.addEventListener('blur', function () {
			if (window._crWebKeyboardClose) window._crWebKeyboardClose();
		});
		document.body.appendChild(el);
		window._crWebKeyboardEl = el;
		return el;
	}

	window._crWebKeyboardOpen = function (text, mode, secret) {
		var el = makeInput();
		el.type = secret ? 'password' : 'text';
		el.inputMode = mode || 'text';
		el.value = text || '';
		try { el.focus({ preventScroll: true }); } catch (e) { el.focus(); }
		try {
			var n = el.value.length;
			el.setSelectionRange(n, n);
		} catch (e) {}
	};

})();
"""

var _js_input: JavaScriptObject
var _js_submit: JavaScriptObject
var _js_close: JavaScriptObject
var _active: LineEdit
var _scan_acc := 0.0
var _last_open_ms := 0
var _touch_device := false


func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	var win = JavaScriptBridge.get_interface("window")
	_js_input = JavaScriptBridge.create_callback(_on_js_input)
	_js_submit = JavaScriptBridge.create_callback(_on_js_submit)
	_js_close = JavaScriptBridge.create_callback(_on_js_close)
	win.set("_crWebKeyboardInput", _js_input)
	win.set("_crWebKeyboardSubmit", _js_submit)
	win.set("_crWebKeyboardClose", _js_close)
	JavaScriptBridge.eval(JS)
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
	field.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed:
			_open(field)
		elif _touch_device and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open(field)
	)


func _open(field: LineEdit) -> void:
	if not is_instance_valid(field) or not field.is_visible_in_tree() or field.editable == false:
		return
	var now := Time.get_ticks_msec()
	if now - _last_open_ms < 120:
		return
	_last_open_ms = now
	_active = field
	field.grab_focus()
	var mode := "text"
	var hint := (field.placeholder_text + " " + field.name).to_lower()
	if field.secret:
		mode = "text"
	elif hint.contains("邮箱") or hint.contains("email") or hint.contains("mail"):
		mode = "email"
	elif hint.contains("房间码") or hint.contains("ip") or hint.contains("端口") or hint.contains("数量") or hint.contains("代码"):
		mode = "numeric"
	var args := "%s,%s,%s" % [
		JSON.stringify(String(field.text)),
		JSON.stringify(mode),
		"true" if field.secret else "false",
	]
	JavaScriptBridge.eval("window._crWebKeyboardOpen(%s);" % args)


func _on_js_input(args: Array) -> void:
	if not is_instance_valid(_active):
		return
	var text := String(args[0]) if args.size() > 0 else ""
	_active.text = text
	_active.caret_column = text.length()


func _on_js_submit(args: Array) -> void:
	if not is_instance_valid(_active):
		return
	var text := String(args[0]) if args.size() > 0 else ""
	_active.text = text
	_active.caret_column = text.length()
	_active.text_submitted.emit(text)


func _on_js_close(_args: Array) -> void:
	# 不在这里清空 _active：新建输入框时旧输入框的 blur 可能晚于 _open 触发。
	# _open 会覆盖 _active，失效节点由 is_instance_valid 判断。
	pass
