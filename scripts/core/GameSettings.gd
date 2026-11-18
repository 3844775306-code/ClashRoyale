# scripts/core/GameSettings.gd
extends Node

var music_volume: float = 0.8
var sfx_volume: float = 0.7
var difficulty: int = AISystem.Difficulty.NORMAL   # 引用 AI 枚举

func _ready():
	# 加载设置（可选，此处用默认值）
	pass

func apply_volumes():
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(music_volume))
	bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(sfx_volume))
