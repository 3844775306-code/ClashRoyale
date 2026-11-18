extends Control
class_name HealthBarBar
# 仿 honor-king 项目 HealthBarControl 的绘制方式：
# 深色圆角底 + 上下双色填充（上亮下暗=立体感）+ 队伍色细边框 + 受伤闪橙

var ratio: float = 1.0
var team_color: Color = Color(0.23, 0.55, 0.96)
var _disp: float = 1.0
var _flash: float = 0.0
var _flash_w: float = 0.0
var _highlight: float = 0.0
var show_threshold: bool = false

func set_ratio(r: float) -> void:
	var rv: float = clampf(r, 0.0, 1.0)
	if absf(rv - _disp) > 0.001:
		_highlight = 0.35
	if rv < _disp - 0.001:
		_flash = 0.5
		_flash_w = _disp - rv
	ratio = rv

func set_team(col: Color) -> void:
	team_color = col
	queue_redraw()

func _process(delta: float) -> void:
	if absf(_disp - ratio) > 0.0005:
		_disp = lerpf(_disp, ratio, 0.35)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	if _highlight > 0.0:
		_highlight = maxf(0.0, _highlight - delta * 2.2)
		queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return
	var r: int = int(h * 0.35)
	# 底
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.16, 0.88)
	bg.border_color = Color(0.04, 0.05, 0.08, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(r)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	# 血量：上亮下暗
	var fw: float = maxf(0.0, _disp * w)
	if fw > 0.5:
		var top := StyleBoxFlat.new()
		top.bg_color = team_color.lightened(0.22)
		top.corner_radius_top_left = r
		top.corner_radius_top_right = r
		draw_style_box(top, Rect2(0, 1, fw, (h - 2.0) * 0.52))
		var bot := StyleBoxFlat.new()
		bot.bg_color = team_color.darkened(0.22)
		bot.corner_radius_bottom_left = r
		bot.corner_radius_bottom_right = r
		draw_style_box(bot, Rect2(0, (h - 2.0) * 0.52 + 1.0, fw, (h - 2.0) * 0.48))
	# 受伤闪橙
	if _flash > 0.0 and _flash_w > 0.0:
		var fww: float = clampf(_flash_w, 0.0, 1.0) * w * (_flash / 0.5)
		draw_rect(Rect2(fw - fww, 2.0, fww, h - 4.0), Color(1.0, 0.62, 0.20, 0.85))
	if show_threshold:
		var tx: float = 1.0 + (w - 2.0) * 0.5
		draw_line(Vector2(tx, 1.0), Vector2(tx, h - 1.0), Color(1.0, 0.85, 0.35, 0.9), 1.5)
	# 血量变化高亮
	if _highlight > 0.0 and fw > 0.5:
		draw_rect(Rect2(1.0, 1.0, fw - 2.0, h - 2.0), Color(1.0, 1.0, 1.0, 0.45 * (_highlight / 0.35)))
	# 队伍色细边框
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = Color(team_color.r, team_color.g, team_color.b, 0.55)
	border.set_border_width_all(1)
	border.set_corner_radius_all(r)
	draw_style_box(border, Rect2(Vector2.ZERO, size))
