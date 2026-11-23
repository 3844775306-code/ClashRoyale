# assets/ui/NameDialog.gd
# 取名字弹窗：首次启动强制取名，也可从顶栏玩家名点击改名。
# 名字会用于排行榜 / 部落 / 联机对战。
extends Control

const INK := Color(0.020, 0.030, 0.062)
const GOLD := Color(0.945, 0.765, 0.360)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)

var _edit: LineEdit
var _hint: Label
var _confirm: Button
var _font: Font

const RANDOM_NAMES := [
	"皇家骑士", "公主殿下", "皮卡超人", "飞龙宝宝", "骷髅军团", "哥布林工匠",
	"国王之手", "部落酋长", "野猪骑士", "冰法师", "雷电法王", "矿工头子",
]


func _ready() -> void:
	add_to_group("name_dialog")
	z_index = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	_build()
	_edit.grab_focus()
	_edit.caret_column = _edit.text.length()


func _build() -> void:
	# 遮罩
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.008, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -182
	panel.offset_bottom = 182
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.065, 0.125, 0.98)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 34
	vbox.offset_right = -34
	vbox.offset_top = 28
	vbox.offset_bottom = -26
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := _label("给自己取个名字", 30, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := _label("这个名字会显示在 排行榜 · 部落 · 联机对战 中", 13, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 6)
	vbox.add_child(line)

	_edit = LineEdit.new()
	_edit.placeholder_text = "输入 2-12 个字符"
	_edit.max_length = 12
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size = Vector2(0, 58)
	_edit.add_theme_font_size_override("font_size", 24)
	_edit.add_theme_color_override("font_color", PARCHMENT)
	_edit.add_theme_color_override("caret_color", GOLD)
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color(0.02, 0.03, 0.065, 0.95)
	esb.set_corner_radius_all(14)
	esb.set_border_width_all(1)
	esb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
	esb.content_margin_left = 14
	esb.content_margin_right = 14
	_edit.add_theme_stylebox_override("normal", esb)
	var esb_f := esb.duplicate()
	esb_f.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.9)
	_edit.add_theme_stylebox_override("focus", esb_f)
	_edit.text = PlayerData.player_name if PlayerData.player_name != "玩家" else ""
	_edit.text_submitted.connect(func(_t): _on_confirm())
	vbox.add_child(_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var random_btn := Button.new()
	random_btn.text = "随机"
	random_btn.focus_mode = Control.FOCUS_NONE
	random_btn.custom_minimum_size = Vector2(120, 50)
	_style_secondary(random_btn)
	random_btn.pressed.connect(_on_random)
	row.add_child(random_btn)

	_confirm = Button.new()
	_confirm.text = "确定"
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.custom_minimum_size = Vector2(200, 50)
	_style_primary(_confirm)
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)

	_hint = _label("", 13, Color(1.0, 0.55, 0.35))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint)


func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if _font != null:
		l.add_theme_font_override("font", _font)
	return l


func _style_secondary(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.19, 0.95)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate()
	hv.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.5)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", PARCHMENT)


func _style_primary(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.71, 0.28, 1.0)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.90, 0.60, 0.9)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var pressed := sb.duplicate()
	pressed.bg_color = Color(0.80, 0.60, 0.22)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	if _font != null:
		btn.add_theme_font_override("font", _font)


func _on_random() -> void:
	var pool: Array = []
	for n in RANDOM_NAMES:
		if String(n) != PlayerData.player_name:
			pool.append(n)
	if pool.is_empty():
		pool = RANDOM_NAMES
	_edit.text = String(pool[randi() % pool.size()])
	_edit.caret_column = _edit.text.length()
	_hint.text = ""


func _on_confirm() -> void:
	var name := _edit.text.strip_edges()
	# 去掉内部连续空白，避免名字显示异常
	while name.contains("  "):
		name = name.replace("  ", " ")
	if name.length() < 2:
		_hint.text = "名字至少 2 个字符"
		return
	if name.length() > 12:
		_hint.text = "名字最多 12 个字符"
		return
	var was_new_account: bool = not PlayerData.name_chosen
	var old_name := PlayerData.player_name
	PlayerData.player_name = name
	PlayerData.name_chosen = true
	PlayerData.save_data()
	if old_name != name:
		LeaderboardAPI.submit_trophies(PlayerData.trophies, PlayerData.player_name)
		ClanManager.sync_my_profile()
	UiComponents.refresh_topbar()
	var scene := get_tree().current_scene
	queue_free()
	if was_new_account and scene != null:
		UiComponents.prompt_avatar(scene)
