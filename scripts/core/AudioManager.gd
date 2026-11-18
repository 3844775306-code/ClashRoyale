# scripts/core/AudioManager.gd
# 音频管理：BGM 常驻播放器 + 按“音效流”复用的 SFX 播放器（不在战斗中创建/销毁节点）
#
# 设计原因：之前在每次攻击/命中时 new AudioStreamPlayer(3D) 并在 finished 后 queue_free，
# 战斗激烈时每秒几十次创建/释放播放器与 playback，Android 上容易触发音频线程竞态崩溃
# （Godot 音频混音线程的 use-after-free 类问题）。改为：
#   1. 每个音效流只创建一个常驻播放器（最多 MAX_VOICES 个），重复播放用 play() 重触发；
#   2. 不连接 finished、不 queue_free，播放器生命周期与 AudioManager 一致；
#   3. 同一音效最小间隔 + 总声部上限，避免手机端声源爆炸。
extends Node

const MAX_VOICES := 32
const DEFAULT_MIN_INTERVAL_MS := 35

var bgm_player: AudioStreamPlayer
var _players3d: Dictionary = {}   # stream_instance_id -> AudioStreamPlayer3D
var _players2d: Dictionary = {}   # stream_instance_id -> AudioStreamPlayer
var _order: Array = []            # 创建顺序，用于超出上限时淘汰最旧
var _last_play_ms: Dictionary = {}  # stream_instance_id -> 上次播放时间

func _ready():
	_ensure_bus_exists("Music")
	_ensure_bus_exists("SFX")

	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	bgm_player.bus = "Music"

	_set_bus_volume("Music", 0.4)   # 初始音乐音量
	_set_bus_volume("SFX", 1.0)     # 初始音效音量

func _ensure_bus_exists(bus_name: String):
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)

func _set_bus_volume(bus_name: String, linear_volume: float):
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_volume))

func play_bgm(stream: AudioStream):
	if stream == null or not Config.SFX_ENABLED:
		return
	if bgm_player.playing:
		bgm_player.stop()
	bgm_player.stream = stream
	bgm_player.play()
	# 循环：播放结束后重新播放（避免重复 connect 报错）
	if not bgm_player.finished.is_connected(_on_bgm_finished):
		bgm_player.finished.connect(_on_bgm_finished)

func _on_bgm_finished():
	bgm_player.play()

func stop_bgm():
	bgm_player.stop()

# 播放音效；global_pos 为 ZERO 时用 2D（全局）播放器，否则用 3D 定位播放器
func play_sfx(stream: AudioStream, global_pos: Vector3 = Vector3.ZERO) -> void:
	if stream == null or not Config.SFX_ENABLED:
		return
	var sid: int = stream.get_instance_id()
	var now: int = Time.get_ticks_msec()
	var min_gap: int = int(Config.SFX_MIN_INTERVAL_MS)
	if min_gap <= 0:
		min_gap = DEFAULT_MIN_INTERVAL_MS
	if now - int(_last_play_ms.get(sid, -100000)) < min_gap:
		return
	_last_play_ms[sid] = now
	if global_pos == Vector3.ZERO:
		var p2: AudioStreamPlayer = _get_player_2d(stream, sid)
		if p2 == null:
			return
		# 复用 playback：stop 后 play 不会重新创建 AudioStreamPlayback
		if p2.playing:
			p2.stop()
		p2.play()
	else:
		var p3: AudioStreamPlayer3D = _get_player_3d(stream, sid)
		if p3 == null:
			return
		p3.global_position = global_pos
		if p3.playing:
			p3.stop()
		p3.play()

func _get_player_3d(stream: AudioStream, sid: int) -> AudioStreamPlayer3D:
	var key: int = sid * 2 + 1
	if _players3d.has(key):
		return _players3d[key]
	if _order.size() >= MAX_VOICES:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = stream
	add_child(p)
	_players3d[key] = p
	_order.append(key)
	return p

func _get_player_2d(stream: AudioStream, sid: int) -> AudioStreamPlayer:
	var key: int = sid * 2
	if _players2d.has(key):
		return _players2d[key]
	if _order.size() >= MAX_VOICES:
		return null
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	add_child(p)
	_players2d[key] = p
	_order.append(key)
	return p

func _evict_oldest() -> void:
	if _order.is_empty():
		return
	var old_key: int = int(_order.pop_front())
	if _players3d.has(old_key):
		var p: AudioStreamPlayer3D = _players3d[old_key]
		p.stop()
		p.queue_free()
		_players3d.erase(old_key)
	elif _players2d.has(old_key):
		var p2: AudioStreamPlayer = _players2d[old_key]
		p2.stop()
		p2.queue_free()
		_players2d.erase(old_key)
