extends Node

var current_state: int = Config.GameStatus.MENU

func _ready():
	# 调试：CR_DEV_SCENE=res://scenes/battle.tscn 可直接进战斗场景
	var dev_scene := OS.get_environment("CR_DEV_SCENE")
	if dev_scene != "":
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().change_scene_to_file(dev_scene)
		if OS.get_environment("CR_DEV_SHOT") != "":
			_dev_capture(OS.get_environment("CR_DEV_SHOT"))
		return
	# 初始进入菜单
	change_state(Config.GameStatus.MENU)

func _dev_capture(path: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path.get_basename() + "_a.png")
	print("DEV_SHOT a")
	# 第二个镜头拉近，看单位/子弹细节
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.size = 24.0
	await get_tree().create_timer(3.5).timeout
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png(path.get_basename() + "_b.png")
	print("DEV_SHOT b")
	get_tree().quit()

func change_state(new_state: int):
	current_state = new_state
	match new_state:
		Config.GameStatus.MENU:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		Config.GameStatus.PLAYING:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		Config.GameStatus.GAME_OVER:
			# 游戏结束面板将在battle场景内处理
			pass
