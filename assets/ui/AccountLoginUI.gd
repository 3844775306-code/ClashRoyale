# assets/ui/AccountLoginUI.gd
# 账号登录：邮箱 + 密码；同一设备 30 天免登录；登录后按账号切换本地存档并同步云端。
extends Control

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const DANGER := Color(1.0, 0.45, 0.40)

var _font: Font
var _email: LineEdit
var _password: LineEdit
var _status: Label
var _login_btn: Button
var _register_btn: Button
var _form: VBoxContainer
var _busy := false
var _recent_buttons: Array = []


func _ready() -> void:
	if OS.get_environment("CR_SKIP_ACCOUNT") != "":
		call_deferred("_enter_game")
		return
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	print("[Account] 登录界面")
	UiComponents.add_background(self)
	_build()



func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -520
	panel.offset_bottom = 520
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.055, 0.115, 0.97)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_form = VBoxContainer.new()
	_form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_form.offset_left = 40
	_form.offset_right = -40
	_form.offset_top = 36
	_form.offset_bottom = -36
	_form.add_theme_constant_override("separation", 12)
	panel.add_child(_form)

	var title := _label("皇室战争", 34, GOLD_LIGHT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_form.add_child(title)
	var sub := _label("账号登录 · 云端存档", 15, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_form.add_child(sub)

	var tip := _label("同一设备登录后 30 天内免登录；所有进度按账号隔离并自动上传云端", 12, Color(0.58, 0.64, 0.74))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(tip)

	var recent: Array = AccountManager.recent_supabase_accounts(30)
	if not recent.is_empty():
		var recent_title := _label("最近登录的 Supabase 账号", 13, GOLD)
		_form.add_child(recent_title)
		var recent_note := _label("点击将恢复该账号的 Supabase 云存档", 11, MUTED)
		recent_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_form.add_child(recent_note)
		for acct in recent.slice(0, 8):
			var email := String(acct.get("email", ""))
			var uname := String(acct.get("username", ""))
			var label := uname if uname != "" else email
			var days := int(acct.get("days_ago", 0))
			var rb := Button.new()
			rb.text = "%s   ·   %s" % [label, "今天登录" if days <= 0 else "%d 天前登录" % days]
			rb.focus_mode = Control.FOCUS_NONE
			rb.custom_minimum_size = Vector2(0, 44)
			_style_secondary(rb)
			rb.pressed.connect(_on_recent_login.bind(email))
			_form.add_child(rb)
			_recent_buttons.append(rb)

	_form.add_child(_label("用户名 / 邮箱", 14, PARCHMENT))
	_email = LineEdit.new()
	_email.placeholder_text = "用户名，或已绑定邮箱"
	_email.custom_minimum_size = Vector2(0, 56)
	_email.add_theme_font_size_override("font_size", 18)
	_style_input(_email)
	_form.add_child(_email)

	_form.add_child(_label("密码", 14, PARCHMENT))
	_password = LineEdit.new()
	_password.placeholder_text = "至少 6 位"
	_password.secret = true
	_password.custom_minimum_size = Vector2(0, 56)
	_password.add_theme_font_size_override("font_size", 18)
	_style_input(_password)
	_form.add_child(_password)

	var remember := _label("登录后 30 天内可使用快捷登录", 12, MUTED)
	remember.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_form.add_child(remember)
	if AccountManager.has_saved_session():
		var quick := Button.new()
		quick.text = "快捷登录：%s（剩余 %d 天）" % [AccountManager.saved_session_name(), AccountManager.session_remaining_days()]
		quick.focus_mode = Control.FOCUS_NONE
		quick.custom_minimum_size = Vector2(0, 50)
		_style_secondary(quick)
		quick.add_theme_color_override("font_color", GOLD)
		quick.pressed.connect(func(): _on_recent_login(AccountManager.saved_session_email()))
		_form.add_child(quick)

	_login_btn = Button.new()
	_login_btn.text = "登录"
	_login_btn.focus_mode = Control.FOCUS_NONE
	_login_btn.custom_minimum_size = Vector2(0, 56)
	_style_primary(_login_btn)
	_login_btn.pressed.connect(_on_login)
	_form.add_child(_login_btn)

	_register_btn = Button.new()
	_register_btn.text = "注册新账号"
	_register_btn.focus_mode = Control.FOCUS_NONE
	_register_btn.custom_minimum_size = Vector2(0, 50)
	_style_secondary(_register_btn)
	_register_btn.pressed.connect(_on_register)
	_form.add_child(_register_btn)

	var otp_btn := Button.new()
	otp_btn.text = "邮箱验证码登录"
	otp_btn.focus_mode = Control.FOCUS_NONE
	otp_btn.custom_minimum_size = Vector2(0, 44)
	_style_secondary(otp_btn)
	otp_btn.pressed.connect(_show_otp_dialog)
	_form.add_child(otp_btn)

	_status = _label("", 13, MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(_status)

	var hint := _label("用户名+密码登录；登录后可绑定邮箱领取奖励。云端存档由 Supabase 提供\n构建：%s" % Config.BUILD_TAG, 11, Color(0.5, 0.56, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(hint)
	_password.text_submitted.connect(func(_t): _on_login())
	_email.text_submitted.connect(func(_t): _password.grab_focus())


func _on_recent_login(email: String) -> void:
	if _busy:
		return
	_set_busy(true)
	_status.text = "正在使用本机账号 %s 登录…" % email
	_status.add_theme_color_override("font_color", MUTED)
	var res: Dictionary = await AccountManager.login_recent(email)
	if bool(res.get("ok", false)):
		_status.text = "登录成功"
		await get_tree().create_timer(0.2).timeout
		_enter_game()
	else:
		_status.text = String(res.get("error", "登录失败"))
		_status.add_theme_color_override("font_color", DANGER)
		_set_busy(false)

func _on_login() -> void:
	if _busy:
		return
	_set_busy(true)
	_status.text = "正在登录…"
	_status.add_theme_color_override("font_color", MUTED)
	var ident := _email.text.strip_edges()
	var res: Dictionary = await AccountManager.login(ident, _password.text) if ident.contains("@") else await AccountManager.login_username(ident, _password.text)
	if bool(res.get("ok", false)):
		if bool(res.get("online", false)):
			_status.text = "云端登录成功"
		else:
			_status.text = "已登录本机账号，但云端连接失败：%s" % String(res.get("error", "未知原因"))
			_status.add_theme_color_override("font_color", DANGER)
			await get_tree().create_timer(1.0).timeout
		await get_tree().create_timer(0.25).timeout
		await _after_login()
		_maybe_bind_email()
	else:
		_status.text = String(res.get("error", "登录失败"))
		_status.add_theme_color_override("font_color", DANGER)
		_set_busy(false)


func _on_register() -> void:
	if _busy:
		return
	_set_busy(true)
	_status.text = "正在创建账号…"
	_status.add_theme_color_override("font_color", MUTED)
	var ident := _email.text.strip_edges()
	var reg: Dictionary = await AccountManager.register(ident, _password.text) if ident.contains("@") else await AccountManager.register_username(ident, _password.text)
	if bool(reg.get("ok", false)):
		_status.text = "账号已创建，正在登录…"
		var res: Dictionary = await AccountManager.login(ident, _password.text) if ident.contains("@") else await AccountManager.login_username(ident, _password.text)
		if bool(res.get("ok", false)):
			await _after_login()
			_maybe_bind_email()
		else:
			_status.text = "账号已创建，请返回登录"
			_set_busy(false)
	else:
		_status.text = String(reg.get("error", "注册失败"))
		_status.add_theme_color_override("font_color", DANGER)
		_set_busy(false)


func _after_login() -> void:
	if await AccountManager.try_claim_bind_reward():
		_status.text = "邮箱绑定奖励已领取：500 金币 + 10 宝石"
		_status.add_theme_color_override("font_color", GOLD)

func _maybe_bind_email() -> void:
	if not AccountManager.is_supabase_authenticated() or not AccountManager.account_email.ends_with("@login.clashroyale.local"):
		_enter_game()
		return
	var layer := CanvasLayer.new()
	layer.layer = 300
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	root.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(80, 430)
	panel.size = Vector2(640, 560)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.04, 0.06, 0.13, 0.99)
	psb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", psb)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26; v.offset_right = -26; v.offset_top = 24; v.offset_bottom = -24
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := _label("绑定邮箱", 28, GOLD_LIGHT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var notice := _label("完成绑定奖励：500 金币 + 10 宝石\n绑定后可用邮箱验证码登录，也可用于找回账号。", 15, PARCHMENT)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(notice)
	var em := LineEdit.new()
	em.placeholder_text = "you@example.com"
	em.custom_minimum_size = Vector2(0, 50)
	_style_input(em)
	v.add_child(em)
	var msg := _label("", 13, MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var send := Button.new()
	send.text = "发送确认邮件"
	send.custom_minimum_size = Vector2(0, 54)
	_style_primary(send)
	v.add_child(send)
	var skip := Button.new()
	skip.text = "暂不绑定，先进入游戏"
	skip.custom_minimum_size = Vector2(0, 46)
	_style_secondary(skip)
	v.add_child(skip)
	send.pressed.connect(func():
		send.disabled = true
		msg.text = "正在发送…"
		var r: Dictionary = await AccountManager.request_bind_email(em.text.strip_edges())
		if bool(r.get("ok", false)):
			msg.text = "确认邮件已发送，请到邮箱点击链接；确认后下次登录自动领取奖励。"
			await get_tree().create_timer(1.2).timeout
			layer.queue_free()
			_enter_game()
		else:
			msg.text = String(r.get("error", "发送失败"))
			send.disabled = false)
	skip.pressed.connect(func():
		layer.queue_free()
		_enter_game())

func _show_otp_dialog() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 300
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	root.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(80, 450)
	panel.size = Vector2(640, 520)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.04, 0.06, 0.13, 0.99)
	psb.border_color = Color(0.55, 0.80, 1.0, 0.9)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", psb)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26; v.offset_right = -26; v.offset_top = 24; v.offset_bottom = -24
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := _label("邮箱验证码登录", 26, Color(0.70, 0.88, 1.0), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var em := LineEdit.new()
	em.placeholder_text = "已绑定的邮箱"
	em.custom_minimum_size = Vector2(0, 50)
	_style_input(em)
	v.add_child(em)
	var code := LineEdit.new()
	code.placeholder_text = "6 位验证码"
	code.custom_minimum_size = Vector2(0, 50)
	_style_input(code)
	v.add_child(code)
	var msg := _label("", 13, MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	var send := Button.new()
	send.text = "发送验证码"
	send.custom_minimum_size = Vector2(0, 48)
	_style_secondary(send)
	v.add_child(send)
	var verify := Button.new()
	verify.text = "验证并登录"
	verify.custom_minimum_size = Vector2(0, 54)
	_style_primary(verify)
	v.add_child(verify)
	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(0, 42)
	_style_secondary(close)
	v.add_child(close)
	send.pressed.connect(func():
		send.disabled = true
		msg.text = "发送中…"
		var r: Dictionary = await AccountManager.send_email_otp(em.text.strip_edges())
		msg.text = "验证码已发送" if bool(r.get("ok", false)) else String(r.get("error", "发送失败"))
		send.disabled = false)
	verify.pressed.connect(func():
		verify.disabled = true
		msg.text = "验证中…"
		var r: Dictionary = await AccountManager.verify_email_otp(em.text.strip_edges(), code.text.strip_edges())
		if bool(r.get("ok", false)):
			layer.queue_free()
			_enter_game()
		else:
			msg.text = String(r.get("error", "验证失败"))
			verify.disabled = false)
	close.pressed.connect(func(): layer.queue_free())

func _enter_game() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _set_busy(v: bool) -> void:
	_busy = v
	if _login_btn:
		_login_btn.disabled = v
	if _register_btn:
		_register_btn.disabled = v
	if _email:
		_email.editable = not v
	if _password:
		_password.editable = not v
	for rb in _recent_buttons:
		if is_instance_valid(rb):
			rb.disabled = v


func _label(text: String, fs: int, color: Color, use_display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if use_display and _font != null:
		l.add_theme_font_override("font", _font)
	return l


func _style_input(le: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.04, 0.085, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	le.add_theme_stylebox_override("normal", sb)
	var focus := sb.duplicate()
	focus.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", PARCHMENT)
	le.add_theme_color_override("font_placeholder_color", Color(0.45, 0.50, 0.60))
	if _font != null:
		le.add_theme_font_override("font", _font)


func _style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.71, 0.28), 14, 2, GOLD_LIGHT, 6))
	btn.add_theme_stylebox_override("hover", _sb(Color(0.98, 0.78, 0.34), 14, 2, Color(1, 0.96, 0.80), 8))
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.80, 0.60, 0.22), 14, 2, GOLD_LIGHT, 4))
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	btn.add_theme_font_size_override("font_size", 20)
	if _font != null:
		btn.add_theme_font_override("font", _font)


func _style_secondary(btn: Button) -> void:
	var sb := _sb(Color(0.07, 0.10, 0.19, 0.95), 14, 1, Color(1, 1, 1, 0.18))
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate()
	hv.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), 14))
	btn.add_theme_color_override("font_color", PARCHMENT)
	btn.add_theme_font_size_override("font_size", 17)
	if _font != null:
		btn.add_theme_font_override("font", _font)


func _sb(bg: Color, radius: int, border := 0, border_col := Color(0, 0, 0, 0), shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	return s
