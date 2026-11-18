extends RefCounted
# ============================================================
# 单位程序化动画（替代旧骨骼 .anim）
# 由 Unit.gd 每帧调用：UnitVisualAnim.apply(root, state, t, phase, speed, building)
# root 结构：Body( MeshInstance3D )，其子节点：LegL / LegR / Weapon
# ============================================================

enum State { IDLE, WALK, ATTACK, HIT, DIE }

static func apply(root: Node3D, state: int, t: float, phase: float = 0.0, speed: float = 1.0, building: bool = false, style: String = "") -> void:
	if root == null:
		return
	var body := root.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var weapon := body.get_node_or_null("Weapon") as Node3D
	var leg_l := body.get_node_or_null("LegL") as Node3D
	var leg_r := body.get_node_or_null("LegR") as Node3D

	# 建筑：完全静止（攻击只由炮台/光束表现，不抖）
	if building:
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		body.scale = Vector3.ONE
		if weapon:
			weapon.rotation = Vector3.ZERO
		return

	var bob := 0.0
	var lean := Vector3.ZERO
	var sx := 1.0
	var sy := 1.0
	var wrot := Vector3.ZERO
	var sink := 0.0
	var lrot_l := 0.0
	var lrot_r := 0.0

	match state:
		State.IDLE:
			var b: float = sin(t * 2.1)
			bob = 0.012 * b
			sy = 1.0 + 0.014 * b
			sx = 1.0 - 0.009 * b
			lean = Vector3(0.010 * sin(t * 1.3), 0.03 * sin(t * 0.6), 0.012 * sin(t * 0.9))
			wrot = Vector3(0.04 * sin(t * 1.7), 0, 0.03 * sin(t * 1.1))
		State.WALK:
			var w: float = t * 5.5 * speed
			if style == "boulder_throw":
				w *= 0.85
			var step: float = sin(w)
			# 双频：抬脚 + 落地沉降，比单纯正弦更像走路
			bob = absf(step) * 0.030 + 0.010 * sin(w * 2.0)
			sy = 1.0 + 0.020 * absf(step)
			sx = 1.0 - 0.012 * absf(step)
			lean = Vector3(0.090, 0.045 * sin(w * 0.5), 0.045 * sin(w * 0.5))
			wrot = Vector3(0.22 * sin(w + 0.9), 0, 0.10 * step)
			lrot_l = 0.55 * step
			lrot_r = -0.55 * step
		State.ATTACK:
			var p: float = clampf(phase, 0.0, 1.0)
			if style == "boulder_throw":
				# 巨石投手：后仰-前抛-收势
				var throw_p: float = sin(p * PI)
				lean = Vector3(-0.35 * throw_p + 0.15 * p, 0, 0)
				sink = 0.10 * throw_p
				sx = 1.0 + 0.12 * throw_p
				sy = 1.0 - 0.10 * throw_p
			var l: float
			if p < 0.34:
				l = lerpf(0.0, -0.18, p / 0.34)          # 蓄力后仰
			elif p < 0.62:
				l = lerpf(-0.18, 0.46, (p - 0.34) / 0.28)  # 挥击
			else:
				l = lerpf(0.46, 0.0, (p - 0.62) / 0.38)   # 收招
			lean = Vector3(l, -0.10 * l, 0.05 * l)
			bob = -0.03 * sin(p * PI)
			wrot = Vector3(-l * 2.0, 0, 0)
			# 跨步站位，避免双脚黏一起
			lrot_l = 0.20 + 0.10 * sin(p * PI)
			lrot_r = -0.20 - 0.10 * sin(p * PI)
		State.HIT:
			# 受击不再抖动，仅由受击闪白表现
			bob = 0.0
			lean = Vector3.ZERO
			wrot = Vector3.ZERO
		State.DIE:
			var p2: float = clampf(phase, 0.0, 1.0)
			lean = Vector3(-1.45 * p2, 0, 0.20 * sin(p2 * 6.0) * (1.0 - p2))
			sink = -0.30 * p2
			sy = 1.0 - 0.45 * p2
			sx = 1.0 + 0.10 * p2

	body.position.y = bob + sink
	body.rotation = lean
	body.scale = Vector3(sx, sy, sx)
	if leg_l:
		leg_l.rotation.x = lrot_l
	if leg_r:
		leg_r.rotation.x = lrot_r
	if weapon:
		weapon.rotation = wrot

static func reset(root: Node3D) -> void:
	var body := root.get_node_or_null("Body") as Node3D
	if body == null:
		return
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	for n in ["LegL", "LegR", "Weapon"]:
		var c := body.get_node_or_null(n) as Node3D
		if c:
			c.rotation = Vector3.ZERO
