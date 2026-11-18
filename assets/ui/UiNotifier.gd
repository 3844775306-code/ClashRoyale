# assets/ui/UiNotifier.gd
# 提示条：显示一条短暂的消息后自动淡出。
# ClanManager 等模块通过 get_tree().get_first_node_in_group("ui_notifier").show_message(...) 调用。
extends Label

var _timer: float = 0.0
var _fading: bool = false

func show_message(text: String, duration: float = 3.0):
	self.text = text
	visible = true
	modulate.a = 1.0
	_timer = duration
	_fading = false

func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_fading = true
	if _fading:
		modulate.a -= delta * 1.5
		if modulate.a <= 0.0:
			visible = false
