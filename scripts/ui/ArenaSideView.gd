extends Control

# 每个竞技场的侧面战场插画：同一套格/桥/塔基/路径规则，只换主题配色与地标

var arena_idx: int = 1

const THEMES := [
	{"sky": Color(0.35, 0.62, 0.90), "ground": Color(0.22, 0.45, 0.20), "ground2": Color(0.30, 0.55, 0.24), "water": Color(0.22, 0.52, 0.72), "stone": Color(0.62, 0.58, 0.50), "wood": Color(0.60, 0.40, 0.22), "accent": Color(0.90, 0.72, 0.28), "land": "trees"},
	{"sky": Color(0.40, 0.42, 0.48), "ground": Color(0.38, 0.36, 0.34), "ground2": Color(0.47, 0.44, 0.40), "water": Color(0.24, 0.40, 0.48), "stone": Color(0.72, 0.68, 0.60), "wood": Color(0.50, 0.34, 0.20), "accent": Color(0.78, 0.86, 0.70), "land": "bones"},
	{"sky": Color(0.82, 0.58, 0.30), "ground": Color(0.62, 0.46, 0.26), "ground2": Color(0.72, 0.56, 0.32), "water": Color(0.30, 0.58, 0.68), "stone": Color(0.76, 0.66, 0.48), "wood": Color(0.58, 0.38, 0.20), "accent": Color(0.96, 0.76, 0.32), "land": "arena"},
	{"sky": Color(0.40, 0.26, 0.60), "ground": Color(0.28, 0.24, 0.40), "ground2": Color(0.38, 0.30, 0.52), "water": Color(0.30, 0.40, 0.72), "stone": Color(0.62, 0.56, 0.72), "wood": Color(0.46, 0.34, 0.28), "accent": Color(0.78, 0.52, 1.0), "land": "crystals"},
	{"sky": Color(0.46, 0.40, 0.36), "ground": Color(0.40, 0.34, 0.28), "ground2": Color(0.52, 0.44, 0.34), "water": Color(0.35, 0.48, 0.52), "stone": Color(0.70, 0.64, 0.54), "wood": Color(0.65, 0.44, 0.24), "accent": Color(0.92, 0.68, 0.30), "land": "workshop"},
	{"sky": Color(0.32, 0.44, 0.68), "ground": Color(0.24, 0.34, 0.46), "ground2": Color(0.32, 0.44, 0.58), "water": Color(0.20, 0.46, 0.66), "stone": Color(0.58, 0.64, 0.74), "wood": Color(0.44, 0.38, 0.32), "accent": Color(0.38, 0.72, 1.0), "land": "banner"},
	{"sky": Color(0.84, 0.68, 0.34), "ground": Color(0.40, 0.46, 0.26), "ground2": Color(0.50, 0.56, 0.32), "water": Color(0.28, 0.54, 0.62), "stone": Color(0.82, 0.74, 0.52), "wood": Color(0.62, 0.42, 0.22), "accent": Color(1.0, 0.82, 0.30), "land": "royal"},
	{"sky": Color(0.62, 0.82, 0.95), "ground": Color(0.66, 0.78, 0.84), "ground2": Color(0.78, 0.88, 0.94), "water": Color(0.38, 0.66, 0.86), "stone": Color(0.80, 0.88, 0.94), "wood": Color(0.48, 0.42, 0.36), "accent": Color(0.52, 0.86, 1.0), "land": "snow"},
	{"sky": Color(0.30, 0.58, 0.40), "ground": Color(0.16, 0.38, 0.18), "ground2": Color(0.24, 0.50, 0.22), "water": Color(0.18, 0.52, 0.48), "stone": Color(0.54, 0.56, 0.42), "wood": Color(0.50, 0.36, 0.18), "accent": Color(0.96, 0.84, 0.30), "land": "jungle"},
	{"sky": Color(0.70, 0.50, 0.32), "ground": Color(0.44, 0.30, 0.18), "ground2": Color(0.56, 0.40, 0.24), "water": Color(0.26, 0.44, 0.52), "stone": Color(0.64, 0.52, 0.38), "wood": Color(0.58, 0.38, 0.20), "accent": Color(0.96, 0.58, 0.24), "land": "hog"},
	{"sky": Color(0.34, 0.28, 0.56), "ground": Color(0.26, 0.24, 0.36), "ground2": Color(0.36, 0.32, 0.48), "water": Color(0.26, 0.40, 0.66), "stone": Color(0.58, 0.54, 0.68), "wood": Color(0.44, 0.34, 0.30), "accent": Color(0.72, 0.56, 1.0), "land": "electro"},
	{"sky": Color(0.20, 0.18, 0.30), "ground": Color(0.26, 0.22, 0.30), "ground2": Color(0.34, 0.28, 0.38), "water": Color(0.18, 0.34, 0.42), "stone": Color(0.52, 0.50, 0.54), "wood": Color(0.38, 0.26, 0.22), "accent": Color(1.0, 0.48, 0.28), "land": "spooky"},
	{"sky": Color(0.38, 0.56, 0.32), "ground": Color(0.26, 0.42, 0.20), "ground2": Color(0.34, 0.52, 0.26), "water": Color(0.22, 0.46, 0.44), "stone": Color(0.58, 0.60, 0.46), "wood": Color(0.52, 0.38, 0.22), "accent": Color(0.64, 0.94, 0.44), "land": "rascal"},
	{"sky": Color(0.42, 0.70, 0.72), "ground": Color(0.34, 0.52, 0.40), "ground2": Color(0.44, 0.64, 0.50), "water": Color(0.24, 0.60, 0.68), "stone": Color(0.66, 0.70, 0.64), "wood": Color(0.50, 0.38, 0.24), "accent": Color(0.55, 0.95, 0.84), "land": "peak"},
	{"sky": Color(0.52, 0.40, 0.28), "ground": Color(0.38, 0.28, 0.18), "ground2": Color(0.50, 0.38, 0.24), "water": Color(0.24, 0.40, 0.44), "stone": Color(0.58, 0.48, 0.36), "wood": Color(0.50, 0.34, 0.20), "accent": Color(0.92, 0.66, 0.30), "land": "mine"},
	{"sky": Color(0.48, 0.18, 0.18), "ground": Color(0.38, 0.20, 0.18), "ground2": Color(0.52, 0.28, 0.22), "water": Color(0.32, 0.30, 0.34), "stone": Color(0.58, 0.44, 0.40), "wood": Color(0.42, 0.26, 0.18), "accent": Color(1.0, 0.50, 0.24), "land": "butcher"},
	{"sky": Color(0.36, 0.38, 0.44), "ground": Color(0.32, 0.30, 0.30), "ground2": Color(0.42, 0.40, 0.38), "water": Color(0.24, 0.40, 0.46), "stone": Color(0.66, 0.64, 0.58), "wood": Color(0.42, 0.30, 0.22), "accent": Color(0.68, 0.84, 0.80), "land": "tomb"},
	{"sky": Color(0.28, 0.62, 0.70), "ground": Color(0.28, 0.48, 0.38), "ground2": Color(0.38, 0.60, 0.48), "water": Color(0.22, 0.60, 0.72), "stone": Color(0.62, 0.72, 0.68), "wood": Color(0.46, 0.36, 0.24), "accent": Color(0.60, 0.96, 0.92), "land": "sanctuary"},
	{"sky": Color(0.70, 0.30, 0.18), "ground": Color(0.40, 0.22, 0.16), "ground2": Color(0.56, 0.30, 0.18), "water": Color(0.72, 0.26, 0.12), "stone": Color(0.56, 0.38, 0.28), "wood": Color(0.40, 0.24, 0.16), "accent": Color(1.0, 0.58, 0.22), "land": "lava"},
	{"sky": Color(0.58, 0.54, 0.36), "ground": Color(0.40, 0.38, 0.24), "ground2": Color(0.52, 0.50, 0.32), "water": Color(0.26, 0.46, 0.44), "stone": Color(0.62, 0.56, 0.42), "wood": Color(0.50, 0.38, 0.22), "accent": Color(0.94, 0.82, 0.42), "land": "camp"},
	{"sky": Color(0.76, 0.36, 0.58), "ground": Color(0.36, 0.28, 0.38), "ground2": Color(0.50, 0.38, 0.48), "water": Color(0.36, 0.42, 0.64), "stone": Color(0.64, 0.56, 0.62), "wood": Color(0.48, 0.32, 0.28), "accent": Color(1.0, 0.62, 0.82), "land": "festival"},
	{"sky": Color(0.94, 0.72, 0.32), "ground": Color(0.46, 0.36, 0.22), "ground2": Color(0.62, 0.48, 0.28), "water": Color(0.32, 0.56, 0.62), "stone": Color(0.76, 0.62, 0.40), "wood": Color(0.58, 0.38, 0.20), "accent": Color(1.0, 0.86, 0.36), "land": "pancake"},
	{"sky": Color(0.28, 0.38, 0.62), "ground": Color(0.26, 0.34, 0.32), "ground2": Color(0.36, 0.46, 0.40), "water": Color(0.20, 0.38, 0.58), "stone": Color(0.60, 0.66, 0.70), "wood": Color(0.42, 0.32, 0.24), "accent": Color(0.72, 0.86, 1.0), "land": "valhalla"},
	{"sky": Color(0.68, 0.52, 0.24), "ground": Color(0.42, 0.34, 0.20), "ground2": Color(0.56, 0.46, 0.26), "water": Color(0.28, 0.50, 0.54), "stone": Color(0.82, 0.70, 0.42), "wood": Color(0.62, 0.42, 0.22), "accent": Color(1.0, 0.84, 0.34), "land": "legend"},
	{"sky": Color(0.30, 0.46, 0.30), "ground": Color(0.20, 0.36, 0.18), "ground2": Color(0.28, 0.46, 0.24), "water": Color(0.22, 0.46, 0.44), "stone": Color(0.54, 0.54, 0.42), "wood": Color(0.56, 0.38, 0.20), "accent": Color(0.86, 0.66, 0.30), "land": "lumber"},
	{"sky": Color(0.76, 0.70, 0.54), "ground": Color(0.44, 0.42, 0.30), "ground2": Color(0.58, 0.54, 0.38), "water": Color(0.30, 0.54, 0.58), "stone": Color(0.80, 0.74, 0.58), "wood": Color(0.60, 0.42, 0.24), "accent": Color(1.0, 0.82, 0.44), "land": "road"},
	{"sky": Color(0.54, 0.40, 0.26), "ground": Color(0.36, 0.28, 0.18), "ground2": Color(0.48, 0.38, 0.24), "water": Color(0.26, 0.44, 0.48), "stone": Color(0.66, 0.58, 0.44), "wood": Color(0.52, 0.34, 0.20), "accent": Color(0.96, 0.72, 0.32), "land": "street"},
	{"sky": Color(0.78, 0.42, 0.28), "ground": Color(0.34, 0.28, 0.24), "ground2": Color(0.48, 0.38, 0.30), "water": Color(0.32, 0.44, 0.56), "stone": Color(0.70, 0.62, 0.54), "wood": Color(0.50, 0.32, 0.22), "accent": Color(1.0, 0.70, 0.30), "land": "hero"},
	{"sky": Color(0.34, 0.24, 0.52), "ground": Color(0.28, 0.22, 0.38), "ground2": Color(0.38, 0.30, 0.50), "water": Color(0.28, 0.38, 0.62), "stone": Color(0.60, 0.52, 0.68), "wood": Color(0.46, 0.34, 0.28), "accent": Color(0.82, 0.56, 1.0), "land": "academy"},
	{"sky": Color(0.28, 0.20, 0.22), "ground": Color(0.30, 0.22, 0.20), "ground2": Color(0.42, 0.30, 0.24), "water": Color(0.36, 0.24, 0.22), "stone": Color(0.62, 0.46, 0.38), "wood": Color(0.42, 0.26, 0.18), "accent": Color(1.0, 0.44, 0.28), "land": "clash"},
	{"sky": Color(0.34, 0.26, 0.22), "ground": Color(0.30, 0.24, 0.18), "ground2": Color(0.44, 0.34, 0.24), "water": Color(0.28, 0.42, 0.42), "stone": Color(0.66, 0.54, 0.40), "wood": Color(0.56, 0.38, 0.22), "accent": Color(1.0, 0.78, 0.36), "land": "tavern"},
	{"sky": Color(0.24, 0.54, 0.62), "ground": Color(0.22, 0.40, 0.36), "ground2": Color(0.30, 0.52, 0.44), "water": Color(0.20, 0.58, 0.66), "stone": Color(0.58, 0.70, 0.68), "wood": Color(0.46, 0.34, 0.24), "accent": Color(0.58, 0.96, 0.90), "land": "spirit"},
]

func _ready():
	set_process(false)
	queue_redraw()

func set_arena(idx: int):
	arena_idx = clampi(idx, 1, THEMES.size())
	queue_redraw()

func _draw():
	var w: float = size.x
	var h: float = size.y
	if w <= 2 or h <= 2:
		return
	var th: Dictionary = THEMES[arena_idx - 1]
	var sky: Color = th.sky
	for i in range(8):
		var t := float(i) / 7.0
		var band := Color(sky.lightened(0.18 * (1.0 - t)).r, sky.lightened(0.18 * (1.0 - t)).g, sky.lightened(0.18 * (1.0 - t)).b)
		draw_rect(Rect2(0, h * t * 0.72, w, h * 0.72 / 8.0 + 1), band)
	draw_circle(Vector2(w * 0.82, h * 0.20), h * 0.10, th.accent.lightened(0.20))
	# 远景山
	for i in range(5):
		var cx := w * (0.12 + i * 0.20)
		var mh := h * (0.20 + 0.04 * (i % 3))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - w * 0.12, h * 0.60),
			Vector2(cx, h * 0.60 - mh),
			Vector2(cx + w * 0.13, h * 0.60),
		]), th.ground.darkened(0.20 + i * 0.02))
	# 草地/战场
	draw_rect(Rect2(0, h * 0.60, w, h * 0.40), th.ground)
	draw_rect(Rect2(0, h * 0.60, w, 3), th.ground2.lightened(0.20))
	# 路径块（规则与战场一致：中线两侧、桥、塔基）
	var line_col: Color = th.ground2.lightened(0.12)
	for i in range(13):
		var x := w * (0.06 + i * 0.075)
		draw_line(Vector2(x, h * 0.62), Vector2(x, h), Color(line_col.r, line_col.g, line_col.b, 0.35), 1.0)
	# 河流横带
	var river_y := h * 0.76
	draw_rect(Rect2(0, river_y, w, h * 0.12), th.water)
	draw_rect(Rect2(0, river_y, w, 2), th.water.lightened(0.35))
	draw_rect(Rect2(0, river_y + h * 0.12 - 2, w, 2), th.water.darkened(0.25))
	# 两座木桥
	for bx in [w * 0.30, w * 0.70]:
		draw_rect(Rect2(bx - w * 0.055, river_y - 2, w * 0.11, h * 0.12 + 4), th.wood)
		for j in range(4):
			draw_line(Vector2(bx - w * 0.055 + j * w * 0.036, river_y), Vector2(bx - w * 0.055 + j * w * 0.036, river_y + h * 0.12), th.wood.darkened(0.30), 1.0)
	# 塔基：左右公主塔 + 中央国王塔（同一规则）
	_draw_tower(Vector2(w * 0.18, h * 0.66), w * 0.070, th, false)
	_draw_tower(Vector2(w * 0.82, h * 0.66), w * 0.070, th, false)
	_draw_tower(Vector2(w * 0.50, h * 0.58), w * 0.090, th, true)
	# 地标装饰
	_draw_land(th.land, w, h, th)
	# 边角暗化
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.06, 0.20))

func _draw_tower(pos: Vector2, tw: float, th: Dictionary, king: bool):
	var body_h := tw * (1.8 if king else 1.4)
	var base := Rect2(pos.x - tw * 0.5, pos.y - body_h, tw, body_h)
	draw_rect(base, th.stone)
	draw_rect(Rect2(base.position.x - 4, base.position.y - 6, base.size.x + 8, 8), th.stone.darkened(0.25))
	# 城垛
	var n := 3 if not king else 4
	for i in range(n):
		var cw := (tw + 8) / n
		draw_rect(Rect2(base.position.x - 4 + i * cw, base.position.y - 16, cw * 0.65, 12), th.stone.lightened(0.10))
	# 队伍色旗/宝石
	var team_col := Color(0.20, 0.48, 0.95) if pos.x < size.x * 0.5 else Color(0.92, 0.24, 0.24)
	draw_rect(Rect2(pos.x - tw * 0.18, pos.y - body_h * 0.62, tw * 0.36, body_h * 0.24), team_col.darkened(0.15))
	draw_circle(Vector2(pos.x, pos.y - body_h * 0.50), tw * 0.10, team_col.lightened(0.25))
	if king:
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x - tw * 0.32, base.position.y - 16),
			Vector2(pos.x, base.position.y - 34),
			Vector2(pos.x + tw * 0.32, base.position.y - 16),
		]), th.accent)

func _draw_land(kind: String, w: float, h: float, th: Dictionary):
	match kind:
		"trees", "jungle", "lumber":
			for i in range(7):
				var x := w * (0.04 + i * 0.13)
				var sz := h * (0.08 + 0.02 * (i % 3))
				draw_rect(Rect2(x - 2, h * 0.62 - sz * 0.3, 4, sz * 0.5), th.wood.darkened(0.2))
				draw_circle(Vector2(x, h * 0.62 - sz * 0.6), sz * 0.55, th.ground2.lightened(0.20))
		"bones", "tomb":
			for i in range(5):
				var x := w * (0.05 + i * 0.20)
				draw_rect(Rect2(x, h * 0.60, 5, h * 0.12), th.stone.lightened(0.15))
				draw_rect(Rect2(x - 7, h * 0.60 + 3, 19, 4), th.stone.lightened(0.10))
		"crystals", "academy", "electro", "spirit":
			for i in range(6):
				var x := w * (0.06 + i * 0.16)
				var cy := h * (0.62 - 0.05 * (i % 3))
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, cy - h * 0.12), Vector2(x + 7, cy), Vector2(x, cy + 5), Vector2(x - 7, cy)
				]), th.accent.lightened(0.15))
		"snow", "valhalla", "peak":
			for i in range(9):
				var x := w * (0.04 + i * 0.11)
				draw_circle(Vector2(x, h * (0.61 - 0.02 * (i % 2))), 2, Color(1, 1, 1, 0.8))
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, h * 0.61 - h * 0.11), Vector2(x + 8, h * 0.61), Vector2(x - 8, h * 0.61)
				]), Color(0.92, 0.97, 1.0, 0.85))
		"lava", "butcher", "clash":
			for i in range(12):
				var x := w * (0.03 + i * 0.085)
				draw_circle(Vector2(x, h * (0.94 - 0.02 * (i % 3))), 3, Color(1.0, 0.42, 0.12, 0.85))
		"workshop", "mine", "camp", "royal", "legend", "road", "street", "tavern":
			for i in range(5):
				var x := w * (0.05 + i * 0.20)
				draw_rect(Rect2(x, h * 0.565, 24, 16), th.wood.darkened(0.15))
				draw_rect(Rect2(x - 4, h * 0.545, 32, 7), th.accent.darkened(0.25))
		"arena", "festival", "pancake", "rascal", "hero", "sanctuary", "spooky", "hog", "banner":
			for i in range(8):
				var x := w * (0.04 + i * 0.135)
				draw_line(Vector2(x, h * 0.60), Vector2(x, h * 0.52), th.accent, 2.0)
				draw_circle(Vector2(x, h * 0.515), 3, th.accent.lightened(0.25))
