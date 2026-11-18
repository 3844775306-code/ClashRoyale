# scripts/entities/Tower.gd
class_name Tower
extends Unit

func _ready():
	super._ready()
	# 塔的额外视觉
	var base = MeshInstance3D.new()
	base.mesh = BoxMesh.new()
	base.mesh.size = Vector3(0.5, 0.1, 0.5)
	base.position = Vector3(0, -0.05, 0)
	base.material_override = StandardMaterial3D.new()
	base.material_override.albedo_color = Color.DARK_GRAY
	base.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(base)

# 塔不能移动，覆盖移动函数
func _move_towards(pos: Vector3, delta):
	pass

func _move_forward(delta):
	pass

# 塔的攻击需要寻找范围内敌人，已在 find_target 中完成，但触发攻击需要重写 _physics_process 或直接调用
# 简单起见，保持 Unit 的 _physics_process，但塔的移动为 no-op，所以会停在原地攻击
