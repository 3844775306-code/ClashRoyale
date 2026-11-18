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
	_skip = UiComponents.make_secondary_button("跳过训练", _skip_training, Vector2(150, 44))
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
		_title.text = "实战训练 1/3 · 肉盾先上"
		_body.text = "先部署骑士或巨人，让它们走在前面吸收火力。点击底部卡牌再点己方战场，或直接拖拽。"
		_btn.visible = false
	elif _step == 1:
		_title.text = "实战训练 2/3 · 远程跟上"
		_body.text = "肉盾已经就位。现在部署弓箭手或亡灵，让远程单位在肉盾后面输出。"
		_btn.visible = false
	elif _step == 2:
		_title.text = "实战训练 3/3 · 法术清场"
		_body.text = "敌方弓箭手正在输出。用火球或万箭齐发清掉它们；点击法术牌后选择敌方单位所在位置。"
		_btn.visible = false
	else:
		_title.text = "实战训练完成"
		_body.text = "你已经学会肉盾 + 远程的搭配，以及用法术清理远程单位。去主菜单开始真正的对局吧！"
		_btn.visible = true
		_btn.text = "完成训练"

func _process(_delta):
	if battle == null or battle.tutorial_played == null:
		return
	var played: Array = battle.tutorial_played
	if _step == 0 and (played.has(4) or played.has(9)):
		_step = 1
		_refresh()
	elif _step == 1 and (played.has(44) or played.has(8)):
		_step = 2
		_refresh()
	elif _step == 2 and (played.has(11) or played.has(10)):
		_step = 3
		_refresh()
		if not _btn.pressed.is_connected(_finish):
			_btn.pressed.connect(_finish)

func _next_step():
	_finish()


func _skip_training():
	if _done:
		return
	_done = true
	PlayerData.tutorial_done = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _finish():
	if _done:
		return
	_done = true
	PlayerData.tutorial_done = true
	if not PlayerData.tutorial_chest_claimed:
		PlayerData.tutorial_chest_claimed = true
		PlayerData.add_chest("silver")
	PlayerData.save_data()
	var notifier := get_tree().get_first_node_in_group("ui_notifier")
	if notifier and "text" in notifier:
		notifier.text = "新手训练完成：获得 1 个宝箱"
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
