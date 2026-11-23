extends Control
# AI 演示案例检验：对比“记忆命中”和“留出集命中”，判断 AI 是在泛化还是只背案例。

const DATA_PATH := "res://data/ai/card_demo_cases.jsonl"

var _cases: Array = []
var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 240
	_cases = _load_cases()
	_build_ui()
	_run_check()


func _load_cases() -> Array:
	var out: Array = []
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary and int(d.get("successful_team", -1)) >= 0:
			out.append(d)
	return out


func _build_ui() -> void:
	UiComponents.make_overlay(self)
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -640
	panel.offset_bottom = 640
	add_child(panel)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_right = -22
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "AI 案例检验"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
	root.add_child(title)
	var hint := Label.new()
	hint.text = "记忆命中高不代表学会；留出集命中才有泛化意义。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 24
	_scroll.follow_focus = true
	root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	var close := UiComponents.make_primary_button("关闭", queue_free, Vector2(0, 56))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(close)


func _run_check() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(_line("案例总数：%d" % _cases.size(), Color(0.92, 0.95, 1.0), 20, true))
	if _cases.is_empty():
		_list.add_child(_line("未找到 data/ai/card_demo_cases.jsonl\n先运行导入工具。", Color(0.95, 0.55, 0.45), 16))
		return

	var all_stats := _score(_cases, _cases)
	var train: Array = []
	var test: Array = []
	for i in range(_cases.size()):
		if i % 5 == 0:
			test.append(_cases[i])
		else:
			train.append(_cases[i])
	var hold_stats := _score(train, test)

	_list.add_child(_line("记忆命中：卡牌 %d/%d · 分路 %d/%d" % [
		all_stats.card, _cases.size(), all_stats.lane, _cases.size()], Color(0.55, 0.90, 0.62), 17, true))
	_list.add_child(_line("留出集：   卡牌 %d/%d · 分路 %d/%d" % [
		hold_stats.card, test.size(), hold_stats.lane, test.size()], Color(1.0, 0.78, 0.42), 17, true))
	var verdict := "泛化不足：更像记住案例，需要更多真实对局。"
	if test.size() > 0 and hold_stats.card >= int(ceil(test.size() * 0.6)):
		verdict = "留出集表现尚可，但仍需更多对局验证。"
	_list.add_child(_line(verdict, Color(0.82, 0.86, 0.95), 15))

	_list.add_child(_line("---- 留出集明细 ----", ThemeHelper.COLORS.gold, 17, true))
	for r in hold_stats.rows:
		var mark := "✓" if r.get("card_hit", false) else "✗"
		var col := Color(0.55, 0.90, 0.62) if r.get("card_hit", false) else Color(0.95, 0.55, 0.45)
		var lane_mark := "分路✓" if r.get("lane_hit", false) else "分路✗"
		_list.add_child(_line("%s  %s   预测:%s  %s" % [
			mark, String(r.get("target", "")), String(r.get("pred", "无")), lane_mark], col, 14))


func _score(memory: Array, items: Array) -> Dictionary:
	var card_hit := 0
	var lane_hit := 0
	var rows: Array = []
	for c in items:
		var pred := _predict(memory, c)
		if pred.is_empty():
			rows.append({"target": String(c.get("target", "")), "pred": "无覆盖", "card_hit": false, "lane_hit": false})
			continue
		var expected: Array = c.get("friendly_cards", [])
		var predicted: Array = pred.get("friendly_cards", [])
		var card_ok := false
		for cid in predicted:
			if expected.has(cid):
				card_ok = true
				break
		var lane_ok := _case_lane(pred) >= 0 and _case_lane(pred) == _case_lane(c)
		card_hit += int(card_ok)
		lane_hit += int(lane_ok)
		rows.append({"target": String(c.get("target", "")), "pred": String(pred.get("target", "")),
			"card_hit": card_ok, "lane_hit": lane_ok})
	return {"card": card_hit, "lane": lane_hit, "rows": rows}


func _predict(memory: Array, case: Dictionary) -> Dictionary:
	var enemy: Array = case.get("enemy_cards", [])
	if enemy.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score := 0.0
	for m in memory:
		var menemy: Array = m.get("enemy_cards", [])
		var overlap := 0
		for eid in enemy:
			if menemy.has(eid):
				overlap += 1
		if overlap <= 0:
			continue
		var friends: Array = m.get("friendly_cards", [])
		if friends.is_empty():
			continue
		var score := float(overlap) / float(maxi(1, enemy.size())) + float(friends.size()) * 0.03
		if score > best_score:
			best_score = score
			best = m
	return best


func _case_lane(case: Dictionary) -> int:
	var evs: Array = case.get("friendly_events", [])
	if evs.is_empty():
		return -1
	return 0 if float(evs[0].get("x", 0.0)) < 0.0 else 1


func _line(text: String, col: Color, fs: int = 15, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
