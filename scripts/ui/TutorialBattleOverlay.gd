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
		_title.text = "实战训练 1/4 · 肉盾先上"
		_body.text = "先部署骑士或巨人，让它们走在前面吸收火力。点击底部卡牌再点己方战场，或直接拖拽。"
		_btn.visible = false
	elif _step == 1:
		_title.text = "实战训练 2/4 · 亡灵空中反击"
		_body.text = "敌方骑士正在推进！骑士是地面近战，打不到空中。部署亡灵，用空中单位无损围杀骑士。"
		_btn.visible = false
	elif _step == 2:
		_title.text = "实战训练 3/4 · 法术清场"
		_body.text = "敌方弓箭手正在输出。用火球或万箭齐发清掉它们；点击法术牌后选择敌方单位所在位置。"
		_btn.visible = false
	elif _step == 3:
		_title.text = "实战训练 4/4 · 巨人拆公主塔"
		_body.text = "用巨人攻击敌方公主塔：巨人只锁定建筑，会无视防守部队直接拆塔；让巨人顶塔，弓箭手/亡灵在后排输出。摧毁一座公主塔即完成训练。"
		_btn.visible = false
	else:
		_title.text = "实战训练完成"
		_body.text = "你已经学会肉盾 + 远程搭配、法术清场，并摧毁了公主塔。去主菜单开始真正的对局吧！"
		_btn.visible = true
		_btn.text = "完成训练"

func _process(_delta):
	if battle == null or battle.tutorial_played == null:
		return
	var played: Array = battle.tutorial_played
	if _step == 0 and (played.has(4) or played.has(9)):
		_step = 1
		_refresh()
	elif _step == 1 and played.has(8):
		_step = 2
		_refresh()
	elif _step == 2 and (played.has(11) or played.has(10)):
		_step = 3
		_refresh()
	elif _step == 3:
		if battle.healths.size() >= 5 and (float(battle.healths[3]) <= 0.0 or float(battle.healths[4]) <= 0.0):
			_step = 4
			_refresh()
			_show_result_sequence()

func _award_tutorial_reward() -> void:
	PlayerData.tutorial_done = true
	if not PlayerData.tutorial_chest_claimed:
		PlayerData.tutorial_chest_claimed = true
		PlayerData.chest_reveal_pending = true
		PlayerData.add_chest("silver")
	PlayerData.save_data()

func _show_result_sequence() -> void:
	if _done:
		return
	_award_tutorial_reward()
	_panel.visible = false
	_btn.visible = false
	_skip.visible = false
	if battle:
		battle.set_process(false)
		battle.set_process_input(false)
		if battle.hud:
			battle.hud.hide_card_tray()
	await get_tree().create_timer(0.9).timeout
	var screen = preload("res://scripts/ui/GameOverScreen.gd").new()
	var hud = battle.hud if battle else null
	if hud == null:
		_finish()
		return
	hud.add_child(screen)
	if ThemeHelper.ui_theme:
		screen.theme = ThemeHelper.ui_theme
	var data := {
		"win": true, "custom_title": "训 练 完 成", "custom_sub": "T R A I N I N G   C O M P L E T E",
		"crowns_my": 1, "crowns_en": 0, "duration": "0:00", "trophy": 0,
		"my_spent": 0, "enemy_spent": 0, "my_over": 0.0, "enemy_over": 0.0,
		"my_top": [], "enemy_top": [],
		"reward_text": "训练奖励：1 个宝箱（返回主菜单查看）",
		"chest_rarity": "silver",
	}
	screen._btn_menu.text = "返 回 主 菜 单"
	screen.populate(data)
	screen._btn_restart.visible = false
	screen.modulate.a = 0.0
	screen.pivot_offset = Vector2(400, 800)
	screen.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(screen, "modulate:a", 1.0, 0.35)
	tw.tween_property(screen, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	screen.menu_pressed.connect(_finish)

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
	_award_tutorial_reward()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
