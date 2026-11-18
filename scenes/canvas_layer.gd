extends CanvasLayer

func _ready():
	var btn = $Button  # 确保按钮路径正确
	btn.pressed.connect(func(): GameManager.change_state(Config.GameStatus.PLAYING))
# 如果不想用 lambda，也可以写：
# btn.pressed.connect(_on_play_pressed)
#
# func _on_play_pressed():
#     GameManager.change_state(Config.GameStatus.PLAYING)
