# assets/ui/SettingMenu.gd
# 设置弹窗（模态）：深色遮罩 + 居中面板，音量滑块 + 难度选项 + 关闭
extends Control

var music_pct: Label
var sfx_pct: Label


func _ready():
	add_to_group("settings_menu")
	z_index = 200
	_build_ui()
	_load_current_settings()
	UiComponents.fade_in(self)


func _build_ui():
	# 全屏遮罩（拦截点击）
	UiComponents.make_overlay(self)

	# 居中面板
	var panel := UiComponents.make_card(ThemeHelper.COLORS.gold)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28
	vbox.offset_top = 22
	vbox.offset_right = -28
	vbox.offset_bottom = -22
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := UiComponents.make_section_title("设置")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer())

	# ---- 音乐音量（标签 + 滑块 + 数值同排）----
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value_changed.connect(_on_music_volume_changed)
	music_pct = Label.new()
	vbox.add_child(_volume_row("🎵 音乐音量", music_slider, music_pct))

	# ---- 音效音量 ----
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_pct = Label.new()
	vbox.add_child(_volume_row("🔊 音效音量", sfx_slider, sfx_pct))

	# ---- 难度 ----
	vbox.add_child(_row_label("🎮 难度"))
	var difficulty := OptionButton.new()
	difficulty.add_item("简单")
	difficulty.add_item("普通")
	difficulty.add_item("困难")
	difficulty.custom_minimum_size = Vector2(0, 48)
	difficulty.item_selected.connect(_on_difficulty_changed)
	vbox.add_child(difficulty)

	# ---- 对局录像（用于 AI 训练）----
	var rec_check := CheckBox.new()
	rec_check.text = "🎞 本地录制对局（AI 训练与回放）"
	rec_check.custom_minimum_size = Vector2(0, 44)
	rec_check.toggled.connect(_on_record_toggled)
	vbox.add_child(rec_check)

	vbox.add_child(_spacer())

	var close_btn := UiComponents.make_primary_button("关闭", _on_close_pressed, Vector2(0, 60))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(close_btn)

	# 保存引用供 _load_current_settings 使用
	set_meta("music_slider", music_slider)
	set_meta("sfx_slider", sfx_slider)
	set_meta("difficulty", difficulty)
	set_meta("record_check", rec_check)


func _row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", ThemeHelper.COLORS.text_muted)
	return lbl


## 「标签 + 滑块 + 数值」同排的音量行
func _volume_row(label_text: String, slider: HSlider, pct: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	pct.custom_minimum_size = Vector2(52, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 14)
	row.add_child(pct)
	return row


func _spacer() -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	return sp


func _load_current_settings():
	var music_slider: HSlider = get_meta("music_slider")
	var sfx_slider: HSlider = get_meta("sfx_slider")
	var difficulty: OptionButton = get_meta("difficulty")
	music_slider.value = GameSettings.music_volume
	sfx_slider.value = GameSettings.sfx_volume
	_update_pct_labels()
	match GameSettings.difficulty:
		AISystem.Difficulty.EASY: difficulty.selected = 0
		AISystem.Difficulty.NORMAL: difficulty.selected = 1
		AISystem.Difficulty.HARD: difficulty.selected = 2
	var rec_check: CheckBox = get_meta("record_check")
	rec_check.button_pressed = PlayerData.record_replays


func _update_pct_labels():
	music_pct.text = "%d%%" % int(GameSettings.music_volume * 100.0)
	sfx_pct.text = "%d%%" % int(GameSettings.sfx_volume * 100.0)


func _on_music_volume_changed(value: float):
	GameSettings.music_volume = value
	GameSettings.apply_volumes()
	_update_pct_labels()


func _on_sfx_volume_changed(value: float):
	GameSettings.sfx_volume = value
	GameSettings.apply_volumes()
	_update_pct_labels()


func _on_difficulty_changed(index: int):
	GameSettings.difficulty = [AISystem.Difficulty.EASY, AISystem.Difficulty.NORMAL, AISystem.Difficulty.HARD][index]


func _on_record_toggled(on: bool):
	PlayerData.record_replays = on
	PlayerData.save_data()

func _on_close_pressed():
	queue_free()
