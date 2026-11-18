extends Control
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")
const CARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
# 结算画面：紫金王座（对齐 tools/gameover_design_a.png 设计）
signal restart_pressed
signal menu_pressed

var _data: Dictionary = {}
var _title: Label
var _sub: Label
var _score: Label
var _vs: Label
var _stat_labels: Array = []
var _reward: Label
var _top_my: Array = []
var _top_en: Array = []
var _btn_restart: Button
var _btn_menu: Button
var _chest_preview
var _top_icons: Array = []

const PANEL := Rect2(112, 320, 576, 960)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _mk_label(66, Color(1.0, 0.91, 0.63), HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _mk_label(22, Color(0.80, 0.68, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_score = _mk_label(52, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_vs = _mk_label(20, Color(0.80, 0.72, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_reward = _mk_label(20, Color(1.0, 0.93, 0.68), HORIZONTAL_ALIGNMENT_LEFT)
	for i in 16:
		_stat_labels.append(_mk_label(19, Color(0.86, 0.78, 0.98), HORIZONTAL_ALIGNMENT_LEFT))
	_btn_restart = UiComponents.make_primary_button("再 来 一 局", func(): restart_pressed.emit(), Vector2(440, 72))
	_btn_restart.position = Vector2(PANEL.position.x + 56, PANEL.position.y + 800)
	_btn_restart.size = Vector2(464, 72)
	add_child(_btn_restart)
	_btn_menu = UiComponents.make_secondary_button("返 回 菜 单", func(): menu_pressed.emit(), Vector2(440, 60))
	_btn_menu.position = Vector2(PANEL.position.x + 56, PANEL.position.y + 886)
	_btn_menu.size = Vector2(464, 60)
	add_child(_btn_menu)
	_chest_preview = CHEST3D.new()
	_chest_preview.position = Vector2(PANEL.position.x + 44, PANEL.position.y + 500)
	_chest_preview.size = Vector2(80, 80)
	_chest_preview.custom_minimum_size = Vector2(80, 80)
	_chest_preview.visible = false
	add_child(_chest_preview)

func _mk_label(fs: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.10))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.02, 0.07, 0.62))
	# 面板阴影
	for i in range(14):
		var a: float = 0.05 * (1.0 - float(i) / 14.0)
		draw_rect(PANEL.grow(float(i) * 2.0), Color(0, 0, 0, a))
	# 紫色渐变面板
	var bands: int = 30
	for i in range(bands):
		var t: float = float(i) / float(bands)
		var c: Color = Color(0.16, 0.08, 0.29).lerp(Color(0.09, 0.05, 0.18), t)
		draw_rect(Rect2(PANEL.position.x, PANEL.position.y + PANEL.size.y * t, PANEL.size.x, PANEL.size.y / float(bands) + 1.0), c)
	# 双层金边
	draw_rect(PANEL, Color(0.94, 0.77, 0.36), false, 4.0)
	draw_rect(PANEL.grow(-10.0), Color(0.55, 0.42, 0.20, 0.85), false, 2.0)
	# 四角饰线
	var gold := Color(0.95, 0.80, 0.42)
	for c in [PANEL.position, Vector2(PANEL.end.x, PANEL.position.y), Vector2(PANEL.position.x, PANEL.end.y), PANEL.end]:
		var sx: float = 1.0 if c.x < PANEL.get_center().x else -1.0
		var sy: float = 1.0 if c.y < PANEL.get_center().y else -1.0
		draw_line(c, c + Vector2(sx * 42.0, 0), gold, 4.0)
		draw_line(c, c + Vector2(0, sy * 42.0), gold, 4.0)
	# 三冠
	var cx: float = PANEL.position.x + PANEL.size.x * 0.5
	_crown(Vector2(cx, PANEL.position.y + 62.0), 26.0)
	_crown(Vector2(cx - 52.0, PANEL.position.y + 70.0), 20.0)
	_crown(Vector2(cx + 52.0, PANEL.position.y + 70.0), 20.0)
	# 分隔线
	draw_line(Vector2(PANEL.position.x + 88, PANEL.position.y + 208), Vector2(PANEL.end.x - 88, PANEL.position.y + 208), Color(0.94, 0.77, 0.36, 0.6), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, PANEL.position.y + 201), Vector2(cx + 9, PANEL.position.y + 208), Vector2(cx, PANEL.position.y + 215), Vector2(cx - 9, PANEL.position.y + 208)]), Color(0.98, 0.86, 0.52))
	# 四块统计卡
	for i in range(4):
		var col: int = i % 2
		var row: int = i / 2
		var r := Rect2(PANEL.position.x + 38 + col * 262, PANEL.position.y + 348 + row * 76, 248, 62)
		draw_rect(r, Color(0.22, 0.13, 0.37, 0.9))
		draw_rect(r, Color(0.47, 0.35, 0.67, 0.7), false, 1.0)
	# 统计条（数据可视化）
	var spent_my: float = maxf(1.0, float(_data.get("my_spent", 1)))
	var spent_en: float = maxf(1.0, float(_data.get("enemy_spent", 1)))
	var spent_total: float = maxf(1.0, spent_my + spent_en)
	var over_my: float = maxf(0.0, float(_data.get("my_over", 0.0)))
	var over_en: float = maxf(0.0, float(_data.get("enemy_over", 0.0)))
	var over_total: float = maxf(1.0, over_my + over_en)
	for i in range(4):
		var col: int = i % 2
		var row: int = i / 2
		var bx: float = PANEL.position.x + 54 + col * 262
		var by: float = PANEL.position.y + 400 + row * 76
		draw_rect(Rect2(bx, by, 190, 7), Color(0.10, 0.06, 0.16, 0.9))
		var ratio: float = 0.5
		if i == 2:
			ratio = spent_my / spent_total
			draw_rect(Rect2(bx, by, 190.0 * ratio, 7), Color(0.24, 0.56, 1.0, 0.95))
			draw_rect(Rect2(bx + 190.0 * ratio, by, 190.0 * (1.0 - ratio), 7), Color(1.0, 0.34, 0.32, 0.95))
		elif i == 3:
			ratio = over_my / over_total if over_total > 0.0 else 0.5
			draw_rect(Rect2(bx, by, 190.0 * ratio, 7), Color(0.72, 0.48, 1.0, 0.95))
			draw_rect(Rect2(bx + 190.0 * ratio, by, 190.0 * (1.0 - ratio), 7), Color(0.55, 0.36, 0.80, 0.95))
	# 奖励条
	var rr := Rect2(PANEL.position.x + 38, PANEL.position.y + 500, PANEL.size.x - 76, 84)
	draw_rect(rr, Color(0.27, 0.17, 0.43, 0.95))
	draw_rect(rr, Color(0.94, 0.77, 0.36, 0.8), false, 2.0)
func _crown(center: Vector2, s: float) -> void:
	var gold := Color(0.98, 0.80, 0.35)
	var edge := Color(0.45, 0.28, 0.05)
	# 底座
	draw_rect(Rect2(center.x - s * 0.95, center.y + s * 0.10, s * 1.9, s * 0.42), gold)
	# 三个尖峰
	var peaks := [-0.75, 0.0, 0.75]
	var tips := [-0.62, -0.80, -0.62]
	for i in range(3):
		var px: float = center.x + peaks[i] * s
		var tri := PackedVector2Array([
			Vector2(px - s * 0.26, center.y + s * 0.14),
			Vector2(px, center.y + tips[i] * s),
			Vector2(px + s * 0.26, center.y + s * 0.14)])
		draw_colored_polygon(tri, gold)
		draw_circle(Vector2(px, center.y + tips[i] * s), s * 0.07, Color(1.0, 0.92, 0.60))
	# 底边
	draw_line(Vector2(center.x - s * 0.95, center.y + s * 0.53), Vector2(center.x + s * 0.95, center.y + s * 0.53), edge, 2.5)
func populate(data: Dictionary) -> void:
	_data = data
	visible = true
	var win: bool = data.get("win", false)
	_title.visible = true
	_sub.visible = true
	_score.visible = true
	_vs.visible = true
	_title.text = String(data.get("custom_title", "胜  利" if win else "失  败"))
	_title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.63) if win else Color(0.95, 0.55, 0.55))
	_sub.text = String(data.get("custom_sub", "V I C T O R Y" if win else "D E F E A T"))
	_sub.add_theme_color_override("font_color", Color(0.80, 0.68, 1.0) if win else Color(0.9, 0.6, 0.6))
	_score.text = "%d : %d" % [data.get("crowns_my", 0), data.get("crowns_en", 0)]
	_vs.text = "你  VS  对手"
	_title.position = Vector2(PANEL.position.x, PANEL.position.y + 88)
	_title.size = Vector2(PANEL.size.x, 80)
	_sub.position = Vector2(PANEL.position.x, PANEL.position.y + 176)
	_sub.size = Vector2(PANEL.size.x, 34)
	_score.position = Vector2(PANEL.position.x, PANEL.position.y + 226)
	_score.size = Vector2(PANEL.size.x, 64)
	_vs.position = Vector2(PANEL.position.x, PANEL.position.y + 288)
	_vs.size = Vector2(PANEL.size.x, 30)
	# 统计卡文字
	var stat_keys := ["摧毁防御塔", "战斗用时", "圣水花费 我/敌", "圣水溢出 我/敌"]
	var stat_vals: Array = [
		"%d / 3" % data.get("crowns_my", 0),
		String(data.get("duration", "0:00")),
		"%d / %d" % [int(data.get("my_spent", 0)), int(data.get("enemy_spent", 0))],
		"%.1f / %.1f" % [float(data.get("my_over", 0.0)), float(data.get("enemy_over", 0.0))],
	]
	for i in range(4):
		var idx: int = i * 2
		var lbl: Label = _stat_labels[idx]
		var val: Label = _stat_labels[idx + 1]
		lbl.text = stat_keys[i]
		lbl.add_theme_color_override("font_color", Color(0.72, 0.64, 0.86))
		lbl.add_theme_font_size_override("font_size", 16)
		val.text = String(stat_vals[i])
		val.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70))
		var col: int = i % 2
		var row: int = i / 2
		var x: float = PANEL.position.x + 54 + col * 262
		var y: float = PANEL.position.y + 356 + row * 76
		lbl.position = Vector2(x, y)
		lbl.size = Vector2(200, 24)
		val.position = Vector2(x, y + 26)
		val.size = Vector2(200, 28)
		lbl.visible = true
		val.visible = true
	# 奖励
	_reward.text = String(data.get("reward_text", "+%d 奖杯     +500 金币    黄金宝箱" % int(data.get("trophy", 0))))
	_reward.position = Vector2(PANEL.position.x + 132, PANEL.position.y + 532)
	_reward.size = Vector2(PANEL.size.x - 170, 40)
	_reward.visible = true
	for ci in _top_icons:
		if is_instance_valid(ci): ci.queue_free()
	_top_icons.clear()
	if _chest_preview:
		_chest_preview.visible = win
		_chest_preview.rarity = String(data.get("chest_rarity", "gold"))
		_chest_preview.queue_redraw()
	# TOP3 双方
	_top_my = data.get("my_top", [])
	_top_en = data.get("enemy_top", [])
	_draw_top3()
	_btn_restart.visible = true
	_btn_menu.visible = true
	# 结算面板入场动画
	pivot_offset = PANEL.get_center()
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.30)
	tw.tween_property(self, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _draw_top3() -> void:
	for ci in _top_icons:
		if is_instance_valid(ci): ci.queue_free()
	_top_icons.clear()
	var sides := [[_top_my, 0], [_top_en, 1]]
	for side in sides:
		var arr: Array = side[0]
		var side_i: int = int(side[1])
		var base_x: float = PANEL.position.x + 42 + side_i * 288
		var title_idx: int = 8 + side_i * 4
		var title: Label = _stat_labels[title_idx]
		title.text = "我方伤害 TOP3" if side_i == 0 else "敌方伤害 TOP3"
		title.position = Vector2(base_x, PANEL.position.y + 606)
		title.size = Vector2(238, 22)
		title.add_theme_color_override("font_color", Color(0.86, 0.76, 1.0) if side_i == 0 else Color(1.0, 0.76, 0.70))
		title.add_theme_font_size_override("font_size", 15)
		title.visible = true
		for j in range(3):
			var li: int = title_idx + 1 + j
			if li >= _stat_labels.size():
				continue
			var lbl: Label = _stat_labels[li]
			var row_y: float = PANEL.position.y + 628 + j * 40
			if j < arr.size():
				var ent: Array = arr[j]
				var cid: int = int(ent[2]) if ent.size() > 2 else 0
				var cname: String = String(ent[0])
				var dmg: int = int(ent[1])
				var card = CARD_ICON.new()
				card.custom_minimum_size = Vector2(28, 36)
				card.size = Vector2(28, 36)
				card.position = Vector2(base_x, row_y)
				card.setup("card", 1, cname, cid)
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(card)
				_top_icons.append(card)
				lbl.text = "%d. %s  %d" % [j + 1, cname, dmg]
				lbl.position = Vector2(base_x + 36, row_y + 7)
				lbl.size = Vector2(198, 24)
			else:
				lbl.text = ""
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.visible = true

