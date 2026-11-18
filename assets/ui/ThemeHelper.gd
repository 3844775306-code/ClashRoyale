# assets/ui/ThemeHelper.gd
# 全局 UI 主题系统
#
# 职责：
#   1. 启动时构建一个共享的 Theme 并赋给 root.theme，让所有 Control 自动继承统一风格
#   2. 缓存所有 StyleBox，避免运行时反复创建对象（旧实现每次调用都 new 3 个）
#   3. 提供 make_label / make_button 等工厂函数，消除散落各处的重复样式代码
#
# 所有界面颜色、字号应从下面的调色板与字号常量取用，不要散落魔法数字。
extends Node

# ==================== 颜色调色板 ====================
const COLORS := {
	"primary": Color(0.15, 0.35, 0.7),          # 按钮主色（深蓝）
	"primary_hover": Color(0.25, 0.45, 0.8),    # 按钮悬停
	"primary_pressed": Color(0.1, 0.2, 0.5),    # 按钮按下
	"primary_disabled": Color(0.28, 0.31, 0.38),# 按钮禁用
	"panel_bg": Color(0.05, 0.05, 0.1, 0.88),   # 面板背景
	"row_bg": Color(0.1, 0.1, 0.2, 0.6),        # 列表行背景
	"card_bg": Color(0.15, 0.15, 0.3, 0.85),    # 卡牌背景
	"border": Color(1, 1, 1, 0.3),              # 面板边框
	"border_bright": Color(1, 1, 1, 0.6),       # 强调边框
	"text": Color.WHITE,
	"text_muted": Color(0.75, 0.78, 0.85),
	"text_gray": Color(0.6, 0.6, 0.6),
	"gold": Color.GOLD,
	"shadow": Color(0, 0, 0, 0.5),
	"focus_border": Color(1, 0.85, 0.3),
	"elixir_full_top": Color(0.6, 0.4, 0.8),
	"elixir_full_bottom": Color(0.4, 0.2, 0.6),
	# ---- 重设计补充 ----
	"bg_deep": Color(0.05, 0.09, 0.18),             # 界面深色背景
	"header_bg": Color(0.08, 0.12, 0.24, 0.96),     # 顶部横幅背景
	"gold_bright": Color(1.0, 0.85, 0.35),          # 金色高亮
	"gold_dim": Color(0.85, 0.68, 0.22),            # 金色按下/描边
	"gold_text": Color(0.36, 0.25, 0.06),           # 金色按钮上的深色文字
	"success": Color(0.2, 0.8, 0.45),               # 成功/可开启
	"danger": Color(0.75, 0.22, 0.17),              # 危险按钮
	"danger_hover": Color(0.88, 0.32, 0.25),
	"danger_pressed": Color(0.58, 0.15, 0.12),
	"rarity_common": Color(0.56, 0.64, 0.72),       # 普通稀有度
	"rarity_rare": Color(0.3, 0.56, 0.85),          # 稀有
	"rarity_epic": Color(0.66, 0.34, 0.96),         # 史诗
	"rarity_legendary": Color(0.95, 0.76, 0.3),     # 传奇
	"chip_gold_bg": Color(0.45, 0.34, 0.1, 0.9),    # 金币筹码
	"chip_gem_bg": Color(0.16, 0.36, 0.62, 0.9),    # 宝石筹码
}

# ==================== 基础字号 ====================
const FONT_SIZE_SMALL := 12
const FONT_SIZE_BODY := 16
const FONT_SIZE_MEDIUM := 18
const FONT_SIZE_TITLE := 24
const FONT_SIZE_HERO := 36
const FONT_SIZE_LARGE := 30   # 头部标题

const DEFAULT_FONT_PATH := "res://assets/fonts/STZHONGS.TTF"

# ==================== 共享样式（_ready 中初始化） ====================
var _button_normal: StyleBoxFlat
var _button_hover: StyleBoxFlat
var _button_pressed: StyleBoxFlat
var _button_disabled: StyleBoxFlat
var _button_focus: StyleBoxFlat
var _panel: StyleBoxFlat
var _card: StyleBoxFlat
var _row: StyleBoxFlat
var _font: Font

# 重设计补充的共享样式
var _btn_primary_normal: StyleBoxFlat
var _btn_primary_hover: StyleBoxFlat
var _btn_primary_pressed: StyleBoxFlat
var _btn_primary_disabled: StyleBoxFlat
var _btn_danger_normal: StyleBoxFlat
var _btn_danger_hover: StyleBoxFlat
var _btn_danger_pressed: StyleBoxFlat
var _btn_danger_disabled: StyleBoxFlat
var _btn_card_normal: StyleBoxFlat
var _btn_card_hover: StyleBoxFlat
var _btn_card_pressed: StyleBoxFlat
var _btn_card_disabled: StyleBoxFlat
var _btn_muted_normal: StyleBoxFlat
var _btn_muted_hover: StyleBoxFlat
var _btn_muted_pressed: StyleBoxFlat
var _header: StyleBoxFlat
var _tab_active: StyleBoxFlat
var _tab_idle: StyleBoxFlat
var _progress_gold: StyleBoxFlat
var _icon_badge: StyleBoxFlat


func _ready():
	_load_font()
	_build_shared_styles()
	_apply_global_theme()


func _load_font():
	if ResourceLoader.exists(DEFAULT_FONT_PATH):
		_font = load(DEFAULT_FONT_PATH)
func apply_emoji_fallback(f: Font) -> Font:
	return f


# ==================== 样式构建 ====================

func _make_stylebox(bg: Color, radius: int = 0, border_width: int = 0,
		border_color: Color = Color.TRANSPARENT, with_shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border_color
	if radius > 0:
		sb.set_corner_radius_all(radius)
	if with_shadow:
		sb.shadow_size = 4
		sb.shadow_color = COLORS.shadow
		sb.shadow_offset = Vector2(2, 2)
	return sb


func _build_shared_styles():
	_button_normal = _make_stylebox(COLORS.primary, 12, 2, COLORS.border, true)
	_button_hover = _make_stylebox(COLORS.primary_hover, 12, 2, Color.WHITE, true)
	_button_pressed = _make_stylebox(COLORS.primary_pressed, 12, 2, Color(0.8, 0.8, 0.8), false)
	_button_disabled = _make_stylebox(COLORS.primary_disabled, 12, 2, Color(1, 1, 1, 0.15), false)
	# 移动端无键盘焦点，焦点框做成透明，避免点击后出现多余描边
	_button_focus = _make_stylebox(Color(0, 0, 0, 0), 12, 0, Color.TRANSPARENT, false)
	_panel = _make_stylebox(COLORS.panel_bg, 16, 1, COLORS.border, false)
	_card = _make_stylebox(COLORS.card_bg, 8, 2, COLORS.border_bright, false)
	_row = _make_stylebox(COLORS.row_bg, 6, 0, Color.TRANSPARENT, false)

	# ---- 重设计补充：主按钮（金）、危险按钮（红）、卡片按钮、次要按钮 ----
	_btn_primary_normal = _make_stylebox(COLORS.gold, 14, 2, COLORS.gold_bright, true)
	_btn_primary_hover = _make_stylebox(COLORS.gold_bright, 14, 2, Color.WHITE, true)
	_btn_primary_pressed = _make_stylebox(COLORS.gold_dim, 14, 2, Color(0.8, 0.65, 0.2), false)
	_btn_primary_disabled = _make_stylebox(Color(0.3, 0.28, 0.2), 14, 2, Color(1, 1, 1, 0.12), false)

	_btn_danger_normal = _make_stylebox(COLORS.danger, 14, 2, Color(1, 0.4, 0.3, 0.5), true)
	_btn_danger_hover = _make_stylebox(COLORS.danger_hover, 14, 2, Color.WHITE, true)
	_btn_danger_pressed = _make_stylebox(COLORS.danger_pressed, 14, 2, Color(0.4, 0.1, 0.1), false)
	_btn_danger_disabled = _make_stylebox(Color(0.3, 0.24, 0.22), 14, 2, Color(1, 1, 1, 0.1), false)

	_btn_card_normal = _make_stylebox(COLORS.card_bg, 14, 1, Color(1, 1, 1, 0.12), true)
	_btn_card_hover = _make_stylebox(Color(0.2, 0.2, 0.38, 0.95), 14, 2, COLORS.gold, true)
	_btn_card_pressed = _make_stylebox(Color(0.12, 0.12, 0.26), 14, 1, Color(1, 1, 1, 0.2), false)
	_btn_card_disabled = _make_stylebox(Color(0.15, 0.16, 0.24), 14, 1, Color(1, 1, 1, 0.08), false)

	_btn_muted_normal = _make_stylebox(Color(0.14, 0.17, 0.3), 14, 1, Color(1, 1, 1, 0.15), false)
	_btn_muted_hover = _make_stylebox(Color(0.2, 0.24, 0.4), 14, 1, Color(1, 1, 1, 0.35), false)
	_btn_muted_pressed = _make_stylebox(Color(0.1, 0.12, 0.22), 14, 1, Color(1, 1, 1, 0.2), false)

	# ---- 顶部横幅（仅底部圆角 + 底部金边）----
	_header = _make_stylebox(COLORS.header_bg, 0, 0, Color.TRANSPARENT, false)
	_header.corner_radius_bottom_left = 20
	_header.corner_radius_bottom_right = 20
	_header.border_width_bottom = 2
	_header.border_color = COLORS.gold_dim

	_tab_active = _make_stylebox(COLORS.primary, 12, 2, COLORS.gold, false)
	_tab_idle = _make_stylebox(Color(0.12, 0.15, 0.28, 0.9), 12, 1, Color(1, 1, 1, 0.15), false)
	_progress_gold = _make_stylebox(COLORS.gold, 4, 0, Color.TRANSPARENT, false)
	_icon_badge = _make_stylebox(Color(0.12, 0.2, 0.4, 0.95), 10, 1, Color(1, 1, 1, 0.35), false)


## 构建全局 Theme 并设置到根节点，之后所有 Control 自动继承
func _apply_global_theme():
	var theme := Theme.new()
	if _font:
		theme.default_font = _font
	theme.default_font_size = FONT_SIZE_BODY

	# ---- Button ----
	theme.set_stylebox("normal", "Button", _button_normal)
	theme.set_stylebox("hover", "Button", _button_hover)
	theme.set_stylebox("pressed", "Button", _button_pressed)
	theme.set_stylebox("disabled", "Button", _button_disabled)
	theme.set_stylebox("focus", "Button", _button_focus)
	theme.set_font_size("font_size", "Button", FONT_SIZE_MEDIUM)
	theme.set_color("font_color", "Button", COLORS.text)
	theme.set_color("font_hover_color", "Button", COLORS.text)
	theme.set_color("font_pressed_color", "Button", Color(0.9, 0.9, 0.9))
	theme.set_color("font_disabled_color", "Button", Color(0.75, 0.75, 0.75))
	theme.set_constant("outline_size", "Button", 0)

	# ---- Panel / PanelContainer ----
	theme.set_stylebox("panel", "Panel", _panel)
	theme.set_stylebox("panel", "PanelContainer", _panel)

	# ---- Label ----
	theme.set_color("font_color", "Label", COLORS.text)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	# ---- LineEdit / TextEdit ----
	var input_bg := _make_stylebox(Color(0, 0, 0, 0.35), 8, 1, Color(1, 1, 1, 0.25), false)
	var input_focus := _make_stylebox(Color(0.1, 0.2, 0.4, 0.5), 8, 2, COLORS.focus_border, false)
	theme.set_stylebox("normal", "LineEdit", input_bg)
	theme.set_stylebox("focus", "LineEdit", input_focus)
	theme.set_stylebox("normal", "TextEdit", input_bg)
	theme.set_stylebox("focus", "TextEdit", input_focus)
	theme.set_color("font_color", "LineEdit", COLORS.text)
	theme.set_color("font_color", "TextEdit", COLORS.text)
	theme.set_font_size("font_size", "LineEdit", FONT_SIZE_BODY)
	theme.set_font_size("font_size", "TextEdit", FONT_SIZE_BODY)

	# ---- OptionButton ----
	theme.set_stylebox("normal", "OptionButton", input_bg)
	theme.set_stylebox("hover", "OptionButton", input_bg)
	theme.set_stylebox("pressed", "OptionButton", input_bg)
	theme.set_stylebox("focus", "OptionButton", input_focus)
	theme.set_color("font_color", "OptionButton", COLORS.text)

	# ---- HSlider ----
	theme.set_stylebox("slider", "HSlider", _make_stylebox(Color(0, 0, 0, 0.4), 3, 0, Color.TRANSPARENT, false))
	theme.set_stylebox("grabber_area", "HSlider", _make_stylebox(COLORS.primary, 3, 0, Color.TRANSPARENT, false))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _make_stylebox(COLORS.primary_hover, 3, 0, Color.TRANSPARENT, false))
	theme.set_stylebox("grabber", "HSlider", _make_stylebox(Color.WHITE, 8, 0, Color.TRANSPARENT, false))
	theme.set_stylebox("grabber_highlight", "HSlider", _make_stylebox(Color.WHITE, 8, 0, Color.TRANSPARENT, false))

	# ---- CheckBox / SpinBox ----
	theme.set_color("font_color", "CheckBox", COLORS.text)
	theme.set_color("font_color", "SpinBox", COLORS.text)

	# ---- ProgressBar ----
	theme.set_stylebox("background", "ProgressBar", _make_stylebox(Color(0, 0, 0, 0.45), 4, 1, Color(1, 1, 1, 0.2), false))
	theme.set_stylebox("fill", "ProgressBar", _make_stylebox(COLORS.primary, 4, 0, Color.TRANSPARENT, false))

	# ---- TabContainer ----
	theme.set_stylebox("panel", "TabContainer", _make_stylebox(Color(0.08, 0.1, 0.2, 0.9), 12, 1, COLORS.border, false))
	theme.set_stylebox("tab_unselected", "TabContainer", _make_stylebox(Color(0.12, 0.15, 0.28), 6, 1, Color(1, 1, 1, 0.15), false))
	theme.set_stylebox("tab_selected", "TabContainer", _make_stylebox(COLORS.primary, 6, 1, COLORS.border_bright, false))
	theme.set_stylebox("tab_hovered", "TabContainer", _make_stylebox(COLORS.primary_hover, 6, 1, Color(1, 1, 1, 0.3), false))
	theme.set_color("font_unselected_color", "TabContainer", COLORS.text_muted)
	theme.set_color("font_selected_color", "TabContainer", COLORS.text)
	theme.set_color("font_hovered_color", "TabContainer", COLORS.text)
	theme.set_font_size("font_size", "TabContainer", FONT_SIZE_MEDIUM)

	# ---- ScrollContainer（透明面板，避免挡住内容）----
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	get_tree().root.theme = theme


# ==================== 样式应用（缓存复用，不再每次新建对象） ====================

## 按钮样式：使用全局缓存的 StyleBox，所有按钮共享同一批资源
func apply_button_style(btn: Button):
	btn.add_theme_stylebox_override("normal", _button_normal)
	btn.add_theme_stylebox_override("hover", _button_hover)
	btn.add_theme_stylebox_override("pressed", _button_pressed)
	btn.add_theme_stylebox_override("disabled", _button_disabled)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MEDIUM)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.75))


## 面板背景样式
func apply_panel_style(panel: Panel):
	panel.add_theme_stylebox_override("panel", _panel)


## 列表行背景样式
func apply_row_style(row: Panel):
	row.add_theme_stylebox_override("panel", _row)


## 卡牌面板样式（战斗中频繁创建，复用共享资源避免分配）
func apply_card_style(card: Panel):
	card.add_theme_stylebox_override("panel", _card)


## 对战手牌卡面：稀有度描边（顶边加粗高亮）+ 深色底 + 圆角
func make_card_face(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.16)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


## 标签通用设置：仅覆盖与主题默认不同的值，避免冗余
func apply_label_style(label: Label, font_size: int = FONT_SIZE_BODY, color: Color = COLORS.text):
	if font_size != FONT_SIZE_BODY:
		label.add_theme_font_size_override("font_size", font_size)
	if color != COLORS.text:
		label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


# ==================== 工厂函数 ====================

## 创建已应用默认样式的 Label
static func make_label(text: String = "", font_size: int = FONT_SIZE_BODY,
		color: Color = COLORS.text, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	if font_size != FONT_SIZE_BODY:
		label.add_theme_font_size_override("font_size", font_size)
	if color != COLORS.text:
		label.add_theme_color_override("font_color", color)
	return label


## 创建已应用默认样式的 Button
static func make_button(text: String = "", min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	return btn


## 创建圆角面板
static func make_panel() -> Panel:
	var panel := Panel.new()
	ThemeHelper.apply_panel_style(panel)
	return panel


# ==================== 重设计补充：按钮/横幅/进度条样式 ====================

## 稀有度 → 颜色映射（宝箱 rarity 字段与通用命名）
static func rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common", "silver":
			return COLORS.rarity_common
		"rare", "gold":
			return COLORS.rarity_rare
		"epic", "magical":
			return COLORS.rarity_epic
		"legendary":
			return COLORS.rarity_legendary
	return COLORS.text_muted


## 圣水费用 → 稀有度色（卡牌通用：≤3 普通 / ≤5 稀有 / ≤7 史诗 / 其余传奇）
static func cost_rarity(cost: int) -> Color:
	if cost <= 3:
		return COLORS.rarity_common
	if cost <= 5:
		return COLORS.rarity_rare
	if cost <= 7:
		return COLORS.rarity_epic
	return COLORS.rarity_legendary


## 卡牌类型 → emoji 图标（战斗手牌 / 详情名片复用）
static func card_emoji(cfg) -> String:
	if cfg.type == Config.UnitType.BUILDING:
		return "🏰"
	if cfg.type == Config.UnitType.AIR:
		return "🕊️"
	if cfg.max_health <= 1 and cfg.damage > 0:
		return "✨"
	return "⚔️"


## 金色主按钮（购买 / 开始对战 / 确认）
func apply_primary_button(btn: Button):
	btn.add_theme_stylebox_override("normal", _btn_primary_normal)
	btn.add_theme_stylebox_override("hover", _btn_primary_hover)
	btn.add_theme_stylebox_override("pressed", _btn_primary_pressed)
	btn.add_theme_stylebox_override("disabled", _btn_primary_disabled)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MEDIUM)
	btn.add_theme_color_override("font_color", COLORS.gold_text)
	btn.add_theme_color_override("font_hover_color", COLORS.gold_text)
	btn.add_theme_color_override("font_pressed_color", COLORS.gold_text)
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.5))


## 红色危险按钮（离开部落 / 删除）
func apply_danger_button(btn: Button):
	btn.add_theme_stylebox_override("normal", _btn_danger_normal)
	btn.add_theme_stylebox_override("hover", _btn_danger_hover)
	btn.add_theme_stylebox_override("pressed", _btn_danger_pressed)
	btn.add_theme_stylebox_override("disabled", _btn_danger_disabled)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MEDIUM)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)


## 菜单卡片按钮（主菜单 / 大按钮）
func apply_card_button_style(btn: Button):
	btn.add_theme_stylebox_override("normal", _btn_card_normal)
	btn.add_theme_stylebox_override("hover", _btn_card_hover)
	btn.add_theme_stylebox_override("pressed", _btn_card_pressed)
	btn.add_theme_stylebox_override("disabled", _btn_card_disabled)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_color_override("font_color", COLORS.text)
	btn.add_theme_color_override("font_hover_color", COLORS.text)


## 次要按钮（设置 / 退出等低调操作）
func apply_muted_button(btn: Button):
	btn.add_theme_stylebox_override("normal", _btn_muted_normal)
	btn.add_theme_stylebox_override("hover", _btn_muted_hover)
	btn.add_theme_stylebox_override("pressed", _btn_muted_pressed)
	btn.add_theme_stylebox_override("disabled", _btn_muted_normal)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	btn.add_theme_color_override("font_color", COLORS.text_muted)
	btn.add_theme_color_override("font_hover_color", COLORS.text)


## 顶部横幅
func apply_header_style(panel: Panel):
	panel.add_theme_stylebox_override("panel", _header)


## 金色进度条（经验条 / 升级进度）
func apply_progress_gold(bar: ProgressBar):
	bar.add_theme_stylebox_override("fill", _progress_gold)


## 分节导航：高亮 / 常规两个状态
func apply_tab_active(btn: Button):
	btn.add_theme_stylebox_override("normal", _tab_active)
	btn.add_theme_stylebox_override("hover", _tab_active)
	btn.add_theme_stylebox_override("pressed", _tab_active)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MEDIUM)
	btn.add_theme_color_override("font_color", COLORS.text)

func apply_tab_idle(btn: Button):
	btn.add_theme_stylebox_override("normal", _tab_idle)
	btn.add_theme_stylebox_override("hover", _tab_idle)
	btn.add_theme_stylebox_override("pressed", _tab_idle)
	btn.add_theme_stylebox_override("focus", _button_focus)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_MEDIUM)
	btn.add_theme_color_override("font_color", COLORS.text_muted)


## 等级徽章小圆角面板
func apply_badge_style(panel: Panel):
	panel.add_theme_stylebox_override("panel", _icon_badge)


## 创建金色主按钮
static func make_primary_button(text: String = "", min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_primary_button(btn)
	return btn


## 创建红色危险按钮
static func make_danger_button(text: String = "", min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_danger_button(btn)
	return btn


## 创建次要按钮
static func make_muted_button(text: String = "", min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size
	ThemeHelper.apply_muted_button(btn)
	return btn
