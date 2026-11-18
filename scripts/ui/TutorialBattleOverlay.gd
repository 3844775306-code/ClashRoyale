extends Control
# 实战训练：在真实战场里提示部署，不启用敌方 AI。

var battle
var _step := 0
var _t := 0.0
var _panel: Panel
var _title: Label
var _body: Label
var _btn: Button
var _skip: Button
var _done := false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	_panel = Panel.new()
	_panel.position = Vector2(40, 188)
	_panel.size = Vector2(720, 176)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.055, 0.11, 0.96)
	sb.border_color = Color(0.96, 0.77, 0.36, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_title = _label("", 21, Color(1.0, 0.86, 0.45))
	_title.position = Vector2(20, 14)
	_title.size = Vector2(680, 30)
	_panel.add_child(_title)
	_body = _label("", 16, Color(0.87, 0.92, 1.0))
	_body.position = Vector2(20, 48)
	_body.size = Vector2(680, 62)
	_panel.add_child(_body)
	_btn = UiComponents.make_primary_button("下一步", _next_step, Vector2(210, 48))
	_btn.position = Vector2(478, 116)
	_panel.add_child(_btn)
	_skip = UiComponents.make_secondary_button("跳过训练", _finish, Vector2(150, 44))
	_skip.position = Vector2(20, 116)
	_panel.add_child(_skip)
	_refresh()
	set_process(true)

func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _refresh():
	if _step == 0:
		_title.text = "实战训练 1/2 · 部署第一张卡"
		_body.text = "点击底部卡牌，再点击己方战场；也可以直接把卡牌拖到战场。绿色范围表示可放置。"
		_btn.visible = false
	elif _step == 1:
		_title.text = "实战训练 2/2 · 观察圣水"
		_body.text = "部署成功！卡牌费用已扣除，圣水会随时间恢复。继续部署第二张卡，熟悉费用节奏。"
		_btn.visible = true
		_btn.text = "完成训练"
	else:
		_title.text = "实战训练完成"
		_body.text = "你已经学会在真实战场中部署卡牌。去主菜单开始真正的对局吧！"
		_btn.visible = true
		_btn.text = "返回主菜单"

func _process(_delta):
	if _step != 0 or battle == null:
		return
	if battle.stats_elixir_spent[0] > 0 or battle.player_elixir < 4.99:
		_step = 1
		_refresh()

func _next_step():
	if _step == 1:
		_step = 2
		_refresh()
		_btn.pressed.disconnect(_next_step)
		_btn.pressed.connect(_finish)
	else:
		_finish()

func _finish():
	if _done:
		return
	_done = true
	PlayerData.tutorial_done = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
