# scripts/core/TutorialTour.gd
# 教程后的交互式模块巡览：菜单对话 → 进入模块 → 模块内细节提示 → 返回菜单继续下一站
extends Node

const STEPS := [
	{"scene": "", "title": "训练结束", "detail": ""},
	{"scene": "", "title": "开始对战", "detail": ""},
	{"scene": "res://scenes/deck_builder.tscn", "title": "卡组配置",
		"detail": "这里是卡组配置。上方 1-5 是 5 套卡组；点卡池里的卡牌，再点卡桌上方的空位放入卡组，满 8 张即可。点右上角返回会保存。"},
	{"scene": "res://scenes/chest_ui.tscn", "title": "宝箱",
		"detail": "这里是宝箱界面。当前宝箱可以点击开启，下方队列是其它宝箱。每天前 4 场胜利会获得宝箱，别忘了回来领取。"},
	{"scene": "res://scenes/network_lobby.tscn", "title": "联机",
		"detail": "这里是联机房间。创建房间后把 IP/房间码发给朋友；也可以输入朋友的房间码加入。进入房间后可选规则、添加席位并开始。"},
	{"scene": "res://scenes/clan_ui.tscn", "title": "部落",
		"detail": "这里是部落。下方聊天栏可以和伙伴交流；成员页可以请求/捐赠卡牌，首领可以审批申请和管理成员。"},
	{"scene": "res://scenes/collection.tscn", "title": "收藏",
		"detail": "这里是收藏。可以查看表情、万能卡和收藏等级奖励；卡牌大师与收藏等级奖励都可以一键领取。"},
	{"scene": "", "title": "出发吧", "detail": ""},
]

var active := false
var step := 0
var _tip_shown := false
var _tip_generation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not active or _tip_shown:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if String(scene.scene_file_path) != String(STEPS[step].get("scene", "")):
		return
	_tip_shown = true
	_tip_generation += 1
	_show_tip_later(scene, _tip_generation)


func _show_tip_later(scene: Node, generation: int) -> void:
	await get_tree().create_timer(0.45).timeout
	if not active or generation != _tip_generation:
		return
	if get_tree().current_scene != scene:
		return
	var tip = (load("res://scripts/ui/TourTip.gd") as GDScript).new()
	tip.setup(step, STEPS[step])
	scene.add_child(tip)


func start_step(index: int) -> void:
	if index < 0 or index >= STEPS.size():
		return
	active = true
	step = index
	_tip_shown = false
	_tip_generation += 1
	var scene_path := String(STEPS[index].get("scene", ""))
	if scene_path == "":
		return
	LoadingScreen.change_scene(scene_path, "正在前往%s…" % String(STEPS[index].get("title", "模块")))


func resume_step() -> int:
	return step if active else 0


func finish_tip() -> void:
	if not active:
		return
	step += 1
	_tip_shown = false
	_tip_generation += 1
	if step >= STEPS.size():
		active = false
		PlayerData.tutorial_guide_seen = true
		PlayerData.save_data()
	else:
		active = true
	LoadingScreen.change_scene("res://scenes/menu.tscn", "正在返回主菜单…")


func skip_tour() -> void:
	active = false
	_tip_shown = false
	_tip_generation += 1
	PlayerData.tutorial_guide_seen = true
	PlayerData.save_data()
	if get_tree().current_scene != null and String(get_tree().current_scene.scene_file_path) != "res://scenes/menu.tscn":
		LoadingScreen.change_scene("res://scenes/menu.tscn", "正在返回主菜单…")
