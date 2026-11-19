# scripts/ui/CardSelectUI.gd
# 选卡弹窗（模态）：从拥有的卡牌中选择并指定数量，用于部落请求卡牌。
# 通过外部设置的 callback(card_id, amount) 返回结果；点击遮罩或取消关闭。
extends Control
const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")

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
		if CARD_RARITY.rarity_of_id(cfg.card_id) == "legendary":
			continue
		var own_count = owned_cards.get(cfg.card_id, 0)
		if own_count <= 0:
			continue
		var btn := Button.new()
		btn.text = ""
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 88)
		btn.add_theme_stylebox_override("normal", _card_row_style(false))
		btn.add_theme_stylebox_override("hover", _card_row_style(false, true))
		btn.add_theme_stylebox_override("pressed", _card_row_style(true))
		btn.add_theme_stylebox_override("focus", _card_row_style(false))
		btn.pressed.connect(_on_card_row_pressed.bind(cfg.card_id))
		list_box.add_child(btn)
		row_buttons[cfg.card_id] = btn

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 10
		hbox.offset_right = -12
		hbox.add_theme_constant_override("separation", 12)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)

		var art_path := _official_art(cfg.card_id)
		if art_path == "":
			art_path = "res://assets/cards_web/%s.png" % String(cfg.card_name)
		if not ResourceLoader.exists(art_path):
			art_path = "res://assets/cards_rendered/%s.png" % String(cfg.card_name)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(68, 68)
		tex.size = Vector2(68, 68)
		if ResourceLoader.exists(art_path):
			tex.texture = load(art_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 2)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(info)
		var nm := Label.new()
		nm.text = String(cfg.card_name)
		nm.add_theme_font_size_override("font_size", 17)
		nm.add_theme_color_override("font_color", ThemeHelper.COLORS.text)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(nm)
		var sub := Label.new()
		sub.text = "Lv.%d · 拥有 %d 张" % [PlayerData.get_card_level(cfg.card_id), own_count]
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(sub)

		var marker := Label.new()
		marker.text = "✓"
		marker.visible = false
		marker.custom_minimum_size = Vector2(30, 0)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 24)
		marker.add_theme_color_override("font_color", ThemeHelper.COLORS.gold)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(marker)
		btn.set_meta("marker", marker)

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
	var rar: String = CARD_RARITY.rarity_of_id(card_id)
	request_amount = 40 if rar == "common" else 4
	_highlight_selected()
	_update_quantity_display()
	_update_buttons_state()


func _highlight_selected():
	for cid in row_buttons.keys():
		var btn: Button = row_buttons[cid]
		var marker = btn.get_meta("marker", null)
		if marker != null:
			marker.visible = int(cid) == selected_card_id
		btn.add_theme_stylebox_override("normal", _card_row_style(int(cid) == selected_card_id))


func _on_increase():
	pass


func _on_decrease():
	pass


func _update_quantity_display():
	if selected_card_id == -1:
		quantity_label.text = "请选择卡牌"
	else:
		quantity_label.text = "请求 %d 张（固定）" % request_amount


func _update_buttons_state():
	var has_selection := selected_card_id != -1
	decrease_btn.disabled = true
	increase_btn.disabled = true
	confirm_btn.disabled = not has_selection or request_amount <= 0


func _on_confirm():
	if selected_card_id != -1 and request_amount > 0 and callback.is_valid():
		callback.call(selected_card_id, request_amount)
	queue_free()


func _on_cancel():
	queue_free()


func _official_art(cid: int) -> String:
	var f := FileAccess.open("res://data/official_card_art.json", FileAccess.READ)
	if f == null:
		return ""
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return ""
	return String(parsed.get(str(cid), ""))

func _card_row_style(selected: bool, hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.075, 0.035, 0.96) if selected else (Color(0.07, 0.10, 0.18, 0.94) if not hover else Color(0.10, 0.14, 0.24, 0.96))
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2 if selected else 1)
	sb.border_color = ThemeHelper.COLORS.gold if selected else Color(1, 1, 1, 0.12)
	return sb


func _on_overlay_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		queue_free()
