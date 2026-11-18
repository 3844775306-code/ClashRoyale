# scripts/ui/ReplayArena.gd
# 2D 战术回放画布：绘制竞技场、塔和单位快照。
extends Control

const ARENA_X := -9.0
const ARENA_Z := -15.5
const ARENA_W := 18.0
const ARENA_H := 31.0

var meta: Dictionary = {}
var frame: Dictionary = {}
var _tex_cache: Dictionary = {}

func set_data(m: Dictionary, f: Dictionary) -> void:
	meta = m
	frame = f
	queue_redraw()

func _world_to_px(x: float, z: float) -> Vector2:
	var r := Rect2(22, 22, size.x - 44, size.y - 44)
	return Vector2(
		r.position.x + (x - ARENA_X) / ARENA_W * r.size.x,
		r.position.y + (z - ARENA_Z) / ARENA_H * r.size.y
	)

func _arena_rect() -> Rect2:
	return Rect2(22, 22, size.x - 44, size.y - 44)

func _draw():
	var r := _arena_rect()
	# 草地/地面
	draw_rect(r, Color(0.18, 0.46, 0.31))
	for i in range(8):
		var band := Rect2(r.position.x, r.position.y + r.size.y * i / 8.0, r.size.x, r.size.y / 8.0)
		draw_rect(band, Color(0.18, 0.46, 0.31).lightened(0.04 * float(i % 2)))
	# 河流
	var river_y: float = r.position.y + r.size.y * 0.5
	var river_h: float = r.size.y / ARENA_H * 2.8
	draw_rect(Rect2(r.position.x, river_y - river_h * 0.5, r.size.x, river_h), Color(0.16, 0.44, 0.63))
	# 桥
	for frac in [0.2, 0.8]:
		var bx: float = r.position.x + r.size.x * frac
		var bw: float = r.size.x / ARENA_W * 1.4
		draw_rect(Rect2(bx - bw * 0.5, river_y - river_h * 0.65, bw, river_h * 1.3), Color(0.58, 0.45, 0.26))
	# 战线
	for frac in [0.2, 0.8]:
		var lx: float = r.position.x + r.size.x * frac
		draw_line(Vector2(lx, r.position.y), Vector2(lx, r.position.y + r.size.y), Color(1, 1, 1, 0.08), 1.0)
	draw_rect(r, Color(0.92, 0.82, 0.52, 0.85), false, 2.0)

	# 塔
	var towers: Array = meta.get("towers", [])
	var hp_arr: Array = frame.get("towers", [])
	var idx := 0
	for tower in towers:
		var pos: Vector2 = _world_to_px(float(tower.get("x", 0)), float(tower.get("z", 0)))
		var team: int = int(tower.get("team", 0))
		var card_id: int = int(tower.get("card_id", 1))
		var idx_hp: int = (team * 3) + [0, 1, 2][clampi(card_id - 1, 0, 2)]
		var hp_ratio: float = 1.0
		var max_hp: float = maxf(1.0, float(tower.get("max_health", 7000.0)))
		if idx_hp < hp_arr.size():
			hp_ratio = clampf(float(hp_arr[idx_hp]) / max_hp, 0.0, 1.0)
		var col: Color = Color(0.35, 0.66, 1.0) if team == 0 else Color(1.0, 0.38, 0.36)
		if hp_ratio <= 0.0:
			col = Color(0.35, 0.35, 0.38)
		var tower_size := 38.0 if card_id >= 3 else 30.0
		draw_rect(Rect2(pos - Vector2(tower_size, tower_size) * 0.5, Vector2(tower_size, tower_size)), col)
		draw_rect(Rect2(pos - Vector2(tower_size, tower_size) * 0.5, Vector2(tower_size, tower_size)), Color(1, 1, 1, 0.7), false, 2.0)
		if hp_ratio < 0.999:
			draw_rect(Rect2(pos + Vector2(-tower_size * 0.6, tower_size * 0.7), Vector2(tower_size * 1.2, 5)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(pos + Vector2(-tower_size * 0.6, tower_size * 0.7), Vector2(tower_size * 1.2 * hp_ratio, 5)), Color(0.45, 1.0, 0.5))
		idx += 1

	# 单位
	var units: Array = frame.get("units", [])
	for u in units:
		var team: int = int(u[0])
		var cid: int = int(u[1])
		var cname: String = String(u[2])
		if cid <= 3:
			continue
		var pos: Vector2 = _world_to_px(float(u[3]), float(u[4]))
		var ratio: float = clampf(float(u[5]), 0.0, 1.0)
		var col: Color = Color(0.40, 0.72, 1.0) if team == 0 else Color(1.0, 0.46, 0.40)
		draw_circle(pos, 13.0, Color(0, 0, 0, 0.55))
		draw_circle(pos, 11.0, col)
		var tex := _portrait(cname)
		if tex:
			draw_texture_rect(tex, Rect2(pos - Vector2(9, 9), Vector2(18, 18)), false)
		draw_arc(pos, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
		if ratio < 0.98:
			draw_rect(Rect2(pos + Vector2(-13, 14), Vector2(26, 4)), Color(0, 0, 0, 0.65))
			draw_rect(Rect2(pos + Vector2(-13, 14), Vector2(26 * ratio, 4)), Color(0.45, 1.0, 0.5))
	# 我方/敌方标签
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(r.position.x + 10, r.position.y + r.size.y - 14), "我方", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 0.85, 1.0))
	draw_string(f, Vector2(r.position.x + 10, r.position.y + 28), "敌方", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.6, 0.55))

func _portrait(card_name: String) -> Texture2D:
	if card_name == "":
		return null
	if _tex_cache.has(card_name):
		return _tex_cache[card_name]
	var safe: String = card_name
	var path: String = "res://assets/cards_web/%s.png" % safe
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % safe
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[card_name] = tex
	return tex
