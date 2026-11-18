extends Control
# 护盾外框：只画边框（内部完全透明），套在等级徽章上不遮挡数字
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var top_y: float = 4.0
	var pts := PackedVector2Array([
		Vector2(cx - w * 0.40, top_y),
		Vector2(cx + w * 0.40, top_y),
		Vector2(cx + w * 0.47, top_y + h * 0.16),
		Vector2(cx + w * 0.34, top_y + h * 0.50),
		Vector2(cx, h - 4.0),
		Vector2(cx - w * 0.34, top_y + h * 0.50),
		Vector2(cx - w * 0.47, top_y + h * 0.16)])
	var border := pts.duplicate()
	border.append(pts[0])
	# 深色底描边 + 金色描边（两次 polyline，不填充）
	draw_polyline(border, Color(0.20, 0.12, 0.03, 0.95), 5.5)
	draw_polyline(border, Color(1.0, 0.84, 0.36, 1.0), 2.8)
	# 顶部高光
	draw_line(Vector2(cx - w * 0.22, top_y + 2.0), Vector2(cx + w * 0.22, top_y + 2.0), Color(1, 0.96, 0.75, 0.95), 1.6)
