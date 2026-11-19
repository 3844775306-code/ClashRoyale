extends Control
# 通用头像：自定义图片或根据 seed 生成的 Q 版小国王。

var player_name: String = ""
var avatar_seed: int = 0
var avatar_index: int = 0
var custom_texture: Texture2D = null
var team_color: Color = Color(0.95, 0.76, 0.32)
var profile: Dictionary = {}

signal clicked

func setup(name: String, seed_value: int, index: int, texture: Texture2D = null) -> void:
	player_name = name
	avatar_seed = seed_value
	avatar_index = absi(index) % 12
	custom_texture = texture
	queue_redraw()

func setup_local() -> void:
	setup(PlayerData.player_name, PlayerData.avatar_seed, PlayerData.avatar_index, PlayerData.get_avatar_texture())

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size = Vector2(44, 44)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func _draw():
	var s: float = minf(size.x, size.y)
	if s <= 2.0:
		return
	var c: Vector2 = size * 0.5
	var r: float = s * 0.5
	var h: int = absi(avatar_seed)
	# 背景圆
	var bg := Color(0.06, 0.10, 0.18, 1.0)
	draw_circle(c, r, Color(0.02, 0.03, 0.06, 0.95))
	draw_circle(c, r - 2.0, bg)
	if custom_texture:
		var inner := Rect2(c - Vector2(r * 0.78, r * 0.78), Vector2(r * 1.56, r * 1.56))
		draw_texture_rect(custom_texture, inner, false)
	else:
		var skin: Color = Color(0.92, 0.75, 0.55) if h % 2 == 0 else Color(0.78, 0.58, 0.40)
		var hair: Color = [Color(0.22, 0.15, 0.10), Color(0.48, 0.28, 0.14), Color(0.80, 0.66, 0.38), Color(0.15, 0.15, 0.20)][h % 4]
		var cloth: Color = [Color(0.24, 0.44, 0.86), Color(0.72, 0.25, 0.30), Color(0.26, 0.56, 0.36), Color(0.52, 0.30, 0.72)][(h / 4) % 4]
		# 身体
		draw_circle(c + Vector2(0, r * 0.48), r * 0.55, cloth)
		# 头
		draw_circle(c + Vector2(0, -r * 0.04), r * 0.46, skin)
		# 头发/帽子
		draw_arc(c + Vector2(0, -r * 0.06), r * 0.45, PI, TAU, 16, hair, r * 0.24)
		if avatar_index % 4 == 0:
			# 小皇冠
			var cy: float = c.y - r * 0.48
			draw_colored_polygon(PackedVector2Array([Vector2(c.x-r*0.26,cy+r*0.14),Vector2(c.x-r*0.18,cy-r*0.12),Vector2(c.x-r*0.04,cy+r*0.04),Vector2(c.x,cy-r*0.18),Vector2(c.x+r*0.04,cy+r*0.04),Vector2(c.x+r*0.18,cy-r*0.12),Vector2(c.x+r*0.26,cy+r*0.14)]), Color(1.0,0.78,0.25))
		elif avatar_index % 4 == 1:
			draw_circle(c + Vector2(-r*0.45, -r*0.12), r*0.15, hair)
			draw_circle(c + Vector2(r*0.45, -r*0.12), r*0.15, hair)
		elif avatar_index % 4 == 2:
			draw_rect(Rect2(c.x-r*0.36,c.y-r*0.30,r*0.72,r*0.10), Color(0.18,0.18,0.22))
		# 眼睛
		draw_circle(c + Vector2(-r*0.16, -r*0.02), maxf(1.5, r*0.055), Color(0.10, 0.08, 0.08))
		draw_circle(c + Vector2(r*0.16, -r*0.02), maxf(1.5, r*0.055), Color(0.10, 0.08, 0.08))
		draw_arc(c + Vector2(0, r*0.12), r*0.14, 0.2, PI-0.2, 12, Color(0.45,0.18,0.14), maxf(1.2,r*0.035))
	# 外圈
	draw_arc(c, r - 1.5, 0.0, TAU, 32, team_color, maxf(2.0, s*0.045), true)
