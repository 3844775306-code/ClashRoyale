extends Control
# 新手训练营：奖杯为0的新玩家自动进入；老玩家可从主菜单手动进入。

const INK := Color(0.02, 0.03, 0.06)
const NAVY := Color(0.045, 0.065, 0.13)
const GOLD := Color(0.96, 0.77, 0.36)
const PARCHMENT := Color(0.94, 0.91, 0.82)
const MUTED := Color(0.66, 0.73, 0.84)
const BLUE := Color(0.32, 0.62, 1.0)
const RED := Color(1.0, 0.42, 0.36)
const PAGE_COUNT := 6

var _page := 0
var _panel: Panel
var _body: VBoxContainer
var _step_lbl: Label
var _next_btn: Button
var _back_btn: Button
var _skip_btn: Button

func _ready():
	UiComponents.add_background(self)
	_build_header()
	_panel = Panel.new()
	_panel.position = Vector2(40, 162)
	_panel.size = Vector2(720, 1190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.052, 0.105, 0.96)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.72)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_body = VBoxContainer.new()
	_body.position = Vector2(44, 40)
	_body.size = Vector2(632, 1000)
	_body.add_theme_constant_override("separation", 18)
	_panel.add_child(_body)
	_build_footer()
	_render()

func _build_header():
	var back := UiComponents.make_secondary_button("‹ 返回", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"), Vector2(130, 48))
	back.position = Vector2(34, 46)
	add_child(back)
	var title := _label("新 手 训 练 营", 30, GOLD)
	title.position = Vector2(180, 42)
	title.size = Vector2(440, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := _label("TOY DIORAMA · ROOKIE CAMP", 12, Color(MUTED.r, MUTED.g, MUTED.b, 0.75))
	sub.position = Vector2(180, 88)
	sub.size = Vector2(440, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	_skip_btn = UiComponents.make_secondary_button("跳过", _skip, Vector2(110, 48))
	_skip_btn.position = Vector2(656, 46)
	add_child(_skip_btn)

func _build_footer():
	_step_lbl = _label("", 14, MUTED)
	_step_lbl.position = Vector2(62, 1378)
	_step_lbl.size = Vector2(280, 30)
	add_child(_step_lbl)
	_back_btn = UiComponents.make_secondary_button("上一步", _prev, Vector2(160, 54))
	_back_btn.position = Vector2(300, 1368)
	add_child(_back_btn)
	_next_btn = UiComponents.make_primary_button("下一步", _next, Vector2(250, 58))
	_next_btn.position = Vector2(476, 1366)
	add_child(_next_btn)

func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _render():
	for ch in _body.get_children():
		ch.queue_free()
	_step_lbl.text = "第 %d / %d 步" % [_page + 1, PAGE_COUNT]
	_back_btn.visible = _page > 0
	_next_btn.text = "开始第一场" if _page == PAGE_COUNT - 1 else "下一步"
	_skip_btn.visible = _page < PAGE_COUNT - 1
	match _page:
		0: _page_welcome()
		1: _page_starter_cards()
		2: _page_elixir()
		3: _page_deploy()
		4: _page_towers()
		5: _page_finish()
	call_deferred("_fit_panel")

func _fit_panel():
	await get_tree().process_frame
	var need: float = _body.get_combined_minimum_size().y + 84.0
	_panel.size.y = clampf(need, 520.0, 1190.0)
	_body.size.y = _panel.size.y - 80.0

func _heading(title: String, sub: String):
	var t := _label(title, 34, PARCHMENT)
	_body.add_child(t)
	var s := _label(sub, 16, MUTED)
	_body.add_child(s)
	_body.add_child(_line())

func _line() -> Control:
	var l := ColorRect.new()
	l.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30)
	l.custom_minimum_size = Vector2(0, 2)
	return l

func _tip(number: String, title: String, body_text: String, accent: Color = GOLD):
	var p := Panel.new()
	p.custom_minimum_size = Vector2(632, 132)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.18, 0.86)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", sb)
	_body.add_child(p)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18; h.offset_right = -18; h.offset_top = 14; h.offset_bottom = -14
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var badge := Label.new()
	badge.text = number
	badge.custom_minimum_size = Vector2(62, 62)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 28)
	badge.add_theme_color_override("font_color", accent)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	bsb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(31)
	badge.add_theme_stylebox_override("normal", bsb)
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var t := _label(title, 21, PARCHMENT)
	v.add_child(t)
	var b := _label(body_text, 15, MUTED)
	v.add_child(b)

func _page_welcome():
	_heading("欢迎，未来的国王", "只需几步，就能学会如何部署你的第一张卡牌。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	for item in [["01", "圣水", "卡牌的费用与恢复"], ["02", "部署", "点击或拖拽到战场"], ["03", "皇冠", "摧毁塔来赢得对局"]]:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(196, 190)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.10, 0.19, 0.9)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(16)
		p.add_theme_stylebox_override("panel", sb)
		row.add_child(p)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14; v.offset_right = -14; v.offset_top = 14; v.offset_bottom = -14
		v.add_theme_constant_override("separation", 8)
		p.add_child(v)
		v.add_child(_label(item[0], 30, GOLD))
		v.add_child(_label(item[1], 22, PARCHMENT))
		v.add_child(_label(item[2], 13, MUTED))
	_body.add_child(_label("完成训练营后，你会获得第一套基础卡组。", 15, Color(0.72, 0.84, 0.98)))

func _page_starter_cards():
	_heading("你的六张起始卡牌", "默认出战卡组就是这六张；先认识它们，再进战场练习。")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	var cards := [
		["骑士", "3 圣水", "地面近战坦克；不能攻击空军。"],
		["弓箭手", "3 圣水", "远程输出，可以攻击空中单位。"],
		["亡灵", "3 圣水", "空中群体；地面近战打不到它，可无伤围杀骑士。"],
		["巨人", "5 圣水", "只攻击建筑，用来吸引防御塔火力。"],
		["火球", "4 圣水", "范围法术，清理成群的中低血量单位。"],
		["万箭齐发", "3 圣水", "大范围低伤害法术，克制骷髅/哥布林人海。"],
	]
	for c in cards:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(300, 116)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.10, 0.19, 0.92)
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.32)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(14)
		p.add_theme_stylebox_override("panel", sb)
		grid.add_child(p)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -10
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var head := HBoxContainer.new()
		v.add_child(head)
		head.add_child(_label(c[0], 20, PARCHMENT))
		var cost := _label(c[1], 14, Color(0.80, 0.66, 1.0))
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(cost)
		v.add_child(_label(c[2], 13, MUTED))
	_body.add_child(_label("目标类型：巨人只攻击建筑；骑士等地面近战不能攻击空军；亡灵是空中单位，可以无损瓦解敌方骑士。", 14, Color(0.72, 0.84, 0.98)))

func _page_elixir():
	_heading("圣水是战斗的燃料", "卡牌左下角的数字就是费用；圣水会随时间恢复。")
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(632, 52)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.18, 0.08, 0.30, 0.95)
	bsb.border_color = Color(0.72, 0.52, 1.0, 0.8)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(26)
	bar.add_theme_stylebox_override("panel", bsb)
	_body.add_child(bar)
	var fill := Panel.new()
	fill.position = Vector2(4, 4)
	fill.size = Vector2(560, 44)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.55, 0.32, 0.90, 0.92)
	fsb.set_corner_radius_all(22)
	fill.add_theme_stylebox_override("panel", fsb)
	bar.add_child(fill)
	var num := _label("5.0", 20, Color(0.95, 0.90, 1.0))
	num.position = Vector2(570, 8)
	bar.add_child(num)
	_tip("1", "看费用", "高费卡更强，但需要更久攒圣水；低费卡更适合快速反应。")
	_tip("2", "不要溢出", "圣水满时继续恢复会浪费；保持出牌，别让圣水条一直停满。")
	_tip("3", "1V2 规则", "1V2 中单人一方圣水恢复和上限翻倍；联机模式可在席位界面查看。", BLUE)

func _page_deploy():
	_heading("把卡牌放到己方半场", "点击卡牌后再点战场，或直接拖拽卡牌松手。")
	_tip("A", "点击部署", "先点底部卡牌，再点战场上的目标位置。绿色区域表示可以放置。")
	_tip("B", "拖拽部署", "按住卡牌拖到战场；拖动时会显示范围和费用。")
	_tip("C", "注意位置", "部队会从放置位置出发；法术可以投到更远的位置。", RED)

func _page_towers():
	_heading("公主塔、国王塔与皇冠", "摧毁公主塔得 1 冠，摧毁国王塔直接获胜。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_body.add_child(row)
	for item in [["公主塔", "两侧防御塔
摧毁获得 1 冠", BLUE], ["国王塔", "中央核心
被摧毁直接结束对局", GOLD]]:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(300, 220)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.09, 0.17, 0.9)
		sb.border_color = Color(item[2].r, item[2].g, item[2].b, 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		p.add_theme_stylebox_override("panel", sb)
		row.add_child(p)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 18; v.offset_right = -18; v.offset_top = 18; v.offset_bottom = -18
		v.add_child(_label(item[0], 25, item[2]))
		v.add_child(_label(item[1], 15, MUTED))
		p.add_child(v)
	_body.add_child(_label("对局结束时皇冠多的一方获胜；三冠是完胜。", 16, PARCHMENT))

func _page_finish():
	_heading("训练完成", "你已经了解了圣水、部署与皇冠。准备好开始第一场对局了吗？")
	var p := Panel.new()
	p.custom_minimum_size = Vector2(632, 260)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.18, 0.9)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	p.add_theme_stylebox_override("panel", sb)
	_body.add_child(p)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26; v.offset_right = -26; v.offset_top = 26; v.offset_bottom = -26
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_label("你现在可以：", 22, GOLD))
	v.add_child(_label("· 在主菜单点击「开始对战」
· 在「卡组配置」更换出战卡
· 在「联机」创建房间与朋友对战", 16, PARCHMENT))
	_body.add_child(UiComponents.make_secondary_button("返回主菜单", _finish_menu, Vector2(632, 56)))

func _next():
	if _page >= PAGE_COUNT - 1:
		_finish_battle()
		return
	_page += 1
	_render()

func _prev():
	_page = maxi(0, _page - 1)
	_render()

func _finish_battle():
	PlayerData.tutorial_practice = true
	LoadingScreen.change_scene("res://scenes/battle.tscn", "正在进入实战训练…")

func _finish_menu():
	PlayerData.tutorial_done = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _skip():
	PlayerData.tutorial_done = true
	PlayerData.save_data()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
