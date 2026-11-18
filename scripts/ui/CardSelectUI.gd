# scripts/ui/CardSelectUI.gd
# 选卡弹窗（模态）：从拥有的卡牌中选择并指定数量，用于部落请求卡牌。
# 通过外部设置的 callback(card_id, amount) 返回结果；点击遮罩或取消关闭。
extends Control

# 回调函数 (card_id, amount)
var callback: Callable = Callable()

var max_request := 4

# 数据
var card_configs: Array = []
var owned_cards: Dictionary = {}          # { card_id: quantity }
var row_buttons: Dictionary = {}          # { card_id: Button }
var selected_card_id: int = -1
var request_amount: int = 0

# 节点
var list_box: VBoxContainer
var quantity_label: Label
var increase_btn: Button
var decrease_btn: Button
var confirm_btn: Button


func _ready():
	_load_cards()
	_build_ui()
	_update_quantity_display()
	_update_buttons_state()
	UiComponents.fade_in(self)


func _load_cards():
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not bm:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	card_configs = bm.configs
	owned_cards.clear()
	for cid in PlayerData.card_quantities.keys():
		if PlayerData.get_card_quantity(cid) > 0:
			owned_cards[cid] = PlayerData.get_card_quantity(cid)


# ==================== 界面构建 ====================

func _build_ui():
	# 遮罩：点击关闭
	var overlay := UiComponents.make_overlay(self)
	overlay.gui_input.connect(_on_overlay_gui_input)

	# 居中面板
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -430
	panel.offset_bottom = 430
	add_child(panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 18
	root.offset_right = -24
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := UiComponents.make_section_title("请求卡牌")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# 卡牌列表
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	# 数量行
	var qty_row := HBoxContainer.new()
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.add_theme_constant_override("separation", 16)
	root.add_child(qty_row)
	decrease_btn = UiComponents.make_secondary_button("−", _on_decrease, Vector2(64, 48))
	qty_row.add_child(decrease_btn)
	quantity_label = Label.new()
	quantity_label.text = "请求 0 张"
	quantity_label.custom_minimum_size = Vector2(180, 0)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_size_override("font_size", 22)
	qty_row.add_child(quantity_label)
	increase_btn = UiComponents.make_primary_button("＋", _on_increase, Vector2(64, 48))
	qty_row.add_child(increase_btn)

	# 底部按钮
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	var cancel_btn := UiComponents.make_secondary_button("取消", _on_cancel, Vector2(180, 56))
	bottom.add_child(cancel_btn)
	confirm_btn = UiComponents.make_primary_button("确认请求", _on_confirm, Vector2(180, 56))
	bottom.add_child(confirm_btn)

	_build_card_rows()


func _build_card_rows():
	for child in list_box.get_children():
		child.queue_free()
	row_buttons.clear()
	for cfg in card_configs:
		if cfg.card_id <= 3:
			continue
		var own_count = owned_cards.get(cfg.card_id, 0)
		if own_count <= 0:
			continue
		var btn := Button.new()
		btn.text = "%s  x%d" % [cfg.card_name, own_count]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(_on_card_row_pressed.bind(cfg.card_id))
		ThemeHelper.apply_muted_button(btn)
		list_box.add_child(btn)
		row_buttons[cfg.card_id] = btn

	# 空状态：没有可请求的卡牌
	if row_buttons.is_empty():
		var empty := Label.new()
		empty.text = "暂无可请求的卡牌\n先到卡牌升级或宝箱里攒点卡吧"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 120)
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		list_box.add_child(empty)
		if confirm_btn:
			confirm_btn.disabled = true


# ==================== 交互 ====================

func _on_card_row_pressed(card_id: int):
	selected_card_id = card_id
	request_amount = min(1, owned_cards.get(card_id, 1))
	_highlight_selected()
	_update_quantity_display()
	_update_buttons_state()


func _highlight_selected():
	for cid in row_buttons.keys():
		var btn: Button = row_buttons[cid]
		if cid == selected_card_id:
			ThemeHelper.apply_tab_active(btn)
		else:
			ThemeHelper.apply_muted_button(btn)


func _on_increase():
	if selected_card_id == -1:
		return
	var own_count = owned_cards.get(selected_card_id, 0)
	var max_allow = min(max_request, own_count)
	request_amount = clampi(request_amount + 1, 1, max_allow)
	_update_quantity_display()
	_update_buttons_state()


func _on_decrease():
	if selected_card_id == -1:
		return
	request_amount = maxi(request_amount - 1, 1)
	_update_quantity_display()
	_update_buttons_state()


func _update_quantity_display():
	quantity_label.text = "请求 %d 张" % request_amount


func _update_buttons_state():
	var has_selection := selected_card_id != -1
	decrease_btn.disabled = not has_selection or request_amount <= 1
	if has_selection:
		var max_allow = min(max_request, owned_cards.get(selected_card_id, 0))
		increase_btn.disabled = request_amount >= max_allow
	else:
		increase_btn.disabled = true
	confirm_btn.disabled = not has_selection or request_amount == 0


func _on_confirm():
	if selected_card_id != -1 and request_amount > 0 and callback.is_valid():
		callback.call(selected_card_id, request_amount)
	queue_free()


func _on_cancel():
	queue_free()


func _on_overlay_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		queue_free()
