# assets/ui/TutorialGuide.gd
# 完成新手教程后，以皇家顾问对话的方式介绍主菜单各模块
extends Control

signal finished

const GOLD := Color(0.945, 0.765, 0.360)
const GOLD_LIGHT := Color(1.0, 0.935, 0.730)
const PARCHMENT := Color(0.930, 0.895, 0.790)
const MUTED := Color(0.630, 0.680, 0.795)
const ICON := preload("res://assets/ui/menu/MenuIcon.gd")
const AVATAR_ICON := preload("res://scripts/ui/AvatarIcon.gd")

const STEPS := [
	{"icon": "crown", "title": "训练结束", "text": "干得漂亮，国王！从今天起，你就要真正统治这座竞技场了。花一点时间，让我带你认识王国的各个角落。"},
	{"icon": "sword", "title": "开始对战", "text": "主菜单中央的金色按钮「开始对战」会进入标准 1v1。想换规则时，可以去「派对」选择双倍圣水、选卡、冲线等玩法。"},
	{"icon": "deck", "title": "卡组配置", "scene": "res://scenes/deck_builder.tscn", "text": "「卡组配置」管理你的 8 张出战卡。每张卡都能升级，升级后会变强；记得把费用曲线搭配好。"},
	{"icon": "chest", "title": "宝箱与商店", "scene": "res://scenes/chest_ui.tscn", "text": "「宝箱」存放对局奖励，每天前 4 场胜利才会获得宝箱；「商店」可以购买卡牌、宝箱和每日免费卡。"},
	{"icon": "globe", "title": "联机与好友", "scene": "res://scenes/network_lobby.tscn", "text": "「联机」可以创建或加入房间；主菜单左上角的好友模块能找到同局域网好友，并邀请他们加入你的房间。"},
	{"icon": "shield", "title": "部落", "scene": "res://scenes/clan_ui.tscn", "text": "「部落」里可以和伙伴聊天、请求和捐赠卡牌。没读过的部落消息会显示在部落按钮的红点上。"},
	{"icon": "palette", "title": "收藏与排行", "scene": "res://scenes/collection.tscn", "text": "「收藏」展示你的表情和万能卡；「排行榜」看全球玩家；「回放」可以重新观看自己的精彩对局。"},
	{"icon": "star", "title": "出发吧", "text": "现在你已经了解主菜单的所有模块。去赢得你的第一场胜利吧，国王！"},
]

var _step := 0
var _typing := false
var _shown := 0.0
var _full_text := ""
var _font: Font
var _text_lbl: Label
var _title_lbl: Label
var _icon
var _next_btn: Button
var _go_btn: Button
var _step_lbl: Label
var _dots: HBoxContainer
var _done := false


func _ready() -> void:
	_font = load(ThemeHelper.DEFAULT_FONT_PATH)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var start_step := TutorialTour.resume_step() if TutorialTour.active else 0
	_set_step(start_step)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.010, 0.030, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var vp := get_viewport_rect().size
	var skip := Button.new()
	skip.text = "跳过引导"
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(122, 44)
	skip.position = Vector2(vp.x - 170, 76)
	skip.add_theme_font_size_override("font_size", 14)
	skip.add_theme_color_override("font_color", PARCHMENT)
	skip.add_theme_stylebox_override("normal", _style(Color(0.04, 0.06, 0.12, 0.92), Color(1, 1, 1, 0.16)))
	skip.add_theme_stylebox_override("hover", _style(Color(0.09, 0.12, 0.22, 0.98), Color(GOLD.r, GOLD.g, GOLD.b, 0.6)))
	skip.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.04, 0.09, 0.98), Color(GOLD.r, GOLD.g, GOLD.b, 0.4)))
	skip.pressed.connect(_finish)
	add_child(skip)

	var panel := Panel.new()
	panel.position = Vector2(30, vp.y - 650)
	panel.size = Vector2(vp.x - 60, 590)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.052, 0.105, 0.985)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.72)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# 顾问头像
	var portrait_bg := Panel.new()
	portrait_bg.position = Vector2(24, 24)
	portrait_bg.size = Vector2(150, 150)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.10, 0.18, 1.0)
	psb.set_corner_radius_all(75)
	psb.set_border_width_all(3)
	psb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
	portrait_bg.add_theme_stylebox_override("panel", psb)
	panel.add_child(portrait_bg)
	var av = AVATAR_ICON.new()
	av.position = Vector2(10, 10)
	av.size = Vector2(130, 130)
	av.custom_minimum_size = Vector2(130, 130)
	av.setup_local()
	portrait_bg.add_child(av)

	var advisor := _label("皇家顾问", 17, GOLD, true)
	advisor.position = Vector2(196, 30)
	advisor.size = Vector2(400, 28)
	panel.add_child(advisor)

	# 对话气泡
	var bubble := Panel.new()
	bubble.position = Vector2(196, 64)
	bubble.size = Vector2(vp.x - 60 - 196 - 24, 300)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.075, 0.10, 0.18, 0.96)
	bsb.set_corner_radius_all(18)
	bsb.set_border_width_all(1)
	bsb.border_color = Color(1, 1, 1, 0.13)
	bubble.add_theme_stylebox_override("panel", bsb)
	panel.add_child(bubble)
	_icon = ICON.new()
	_icon.position = Vector2(18, 18)
	_icon.size = Vector2(30, 30)
	_icon.custom_minimum_size = Vector2(30, 30)
	_icon.tint = GOLD
	bubble.add_child(_icon)
	_title_lbl = _label("", 21, GOLD_LIGHT, true)
	_title_lbl.position = Vector2(58, 16)
	_title_lbl.size = Vector2(bubble.size.x - 80, 32)
	bubble.add_child(_title_lbl)
	_text_lbl = _label("", 16, PARCHMENT)
	_text_lbl.position = Vector2(22, 62)
	_text_lbl.size = Vector2(bubble.size.x - 44, 220)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bubble.add_child(_text_lbl)

	# 底部步骤与按钮
	_dots = HBoxContainer.new()
	_dots.position = Vector2(196, 390)
	_dots.add_theme_constant_override("separation", 7)
	panel.add_child(_dots)
	for i in range(STEPS.size()):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0.24, 0.30, 0.42)
		dsb.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", dsb)
		_dots.add_child(dot)
	_step_lbl = _label("", 13, MUTED)
	_step_lbl.position = Vector2(30, 386)
	_step_lbl.size = Vector2(150, 24)
	panel.add_child(_step_lbl)

	_next_btn = Button.new()
	_next_btn.text = "继续"
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.custom_minimum_size = Vector2(230, 58)
	_next_btn.position = Vector2(panel.size.x - 260, panel.size.y - 82)
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.add_theme_color_override("font_color", Color(0.19, 0.11, 0.02))
	_next_btn.add_theme_stylebox_override("normal", _style(Color(0.93, 0.71, 0.28, 1.0), Color(1.0, 0.90, 0.60, 0.9)))
	_next_btn.add_theme_stylebox_override("hover", _style(Color(1.0, 0.80, 0.38, 1.0), Color(1.0, 0.94, 0.74, 1.0)))
	_next_btn.add_theme_stylebox_override("pressed", _style(Color(0.80, 0.60, 0.22, 1.0), Color(1.0, 0.84, 0.50, 1.0)))
	if _font:
		_next_btn.add_theme_font_override("font", _font)
	_next_btn.pressed.connect(_on_next)
	panel.add_child(_next_btn)

	_go_btn = Button.new()
	_go_btn.text = "带我去看看"
	_go_btn.focus_mode = Control.FOCUS_NONE
	_go_btn.custom_minimum_size = Vector2(250, 54)
	_go_btn.position = Vector2(panel.size.x - 540, panel.size.y - 76)
	_go_btn.add_theme_font_size_override("font_size", 18)
	_go_btn.add_theme_color_override("font_color", PARCHMENT)
	_go_btn.add_theme_stylebox_override("normal", _style(Color(0.075, 0.11, 0.21, 0.98), Color(GOLD.r, GOLD.g, GOLD.b, 0.6)))
	_go_btn.add_theme_stylebox_override("hover", _style(Color(0.12, 0.17, 0.30, 1.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.9)))
	_go_btn.add_theme_stylebox_override("pressed", _style(Color(0.05, 0.07, 0.14, 1.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.5)))
	_go_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _font:
		_go_btn.add_theme_font_override("font", _font)
	_go_btn.pressed.connect(_on_go)
	_go_btn.visible = false
	panel.add_child(_go_btn)


func _set_step(index: int) -> void:
	_step = index
	var d: Dictionary = STEPS[_step]
	_icon.kind = String(d.get("icon", "star"))
	_icon.tint = GOLD
	_title_lbl.text = String(d.get("title", ""))
	_full_text = String(d.get("text", ""))
	_text_lbl.text = ""
	_shown = 0.0
	_typing = true
	_step_lbl.text = "%d / %d" % [_step + 1, STEPS.size()]
	_next_btn.text = "显示全文" if _typing else ("开始探索" if _step == STEPS.size() - 1 else "继续")
	if _go_btn:
		_go_btn.visible = String(d.get("scene", "")) != ""
	for i in range(_dots.get_child_count()):
		var dot: Panel = _dots.get_child(i)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95) if i == _step else Color(0.24, 0.30, 0.42)
		dsb.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", dsb)


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * 48.0
	var n := mini(int(_shown), _full_text.length())
	_text_lbl.text = _full_text.substr(0, n)
	if n >= _full_text.length():
		_typing = false
		_next_btn.text = "开始探索" if _step == STEPS.size() - 1 else "继续"


func _on_go() -> void:
	var d: Dictionary = STEPS[_step]
	if String(d.get("scene", "")) == "":
		return
	_go_btn.visible = false
	TutorialTour.start_step(_step)


func _on_next() -> void:
	if _typing:
		_typing = false
		_text_lbl.text = _full_text
		_next_btn.text = "开始探索" if _step == STEPS.size() - 1 else "继续"
		return
	if _step >= STEPS.size() - 1:
		_finish()
		return
	_set_step(_step + 1)


func _finish() -> void:
	if _done:
		return
	_done = true
	TutorialTour.active = false
	PlayerData.tutorial_guide_seen = true
	PlayerData.save_data()
	finished.emit()
	queue_free()


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = border
	return sb


func _label(text: String, fs: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	return l
