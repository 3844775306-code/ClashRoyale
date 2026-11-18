extends Control
class_name CardLoadOverlay
# 卡牌加载：深色遮罩 + 顺时针扇形进度（按圣水比例）

var progress: float = 0.0

func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if progress > 0.001:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 * 0.95
		var start: float = -PI * 0.5
		var end: float = start + TAU * progress
		var pts := PackedVector2Array()
		pts.append(c)
		var steps: int = maxi(8, int(64.0 * progress))
		for i in range(steps + 1):
			var a: float = start + (end - start) * float(i) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(1.0, 0.78, 0.25, 0.55))
		draw_arc(c, r, start, end, 64, Color(1.0, 0.88, 0.45, 0.9), 2.0)
		draw_circle(c, r * 0.30, Color(0, 0, 0, 0.25))
