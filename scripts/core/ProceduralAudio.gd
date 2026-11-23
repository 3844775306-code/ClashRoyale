# scripts/core/ProceduralAudio.gd
# 程序化合成音效/音乐（完全原创，无版权素材）
# 用法：const PA := preload("res://scripts/core/ProceduralAudio.gd")
#       PA.get_sound("arrow") -> AudioStream
# 首次调用时合成并缓存，后续直接返回。
extends RefCounted

const SR := 22050          # 采样率
const TWO_PI := TAU

static var _cache: Dictionary = {}

# 可用的音效名
# arrow：远程攻击；victory：胜利；defeat：失败；menu_theme：菜单音乐（兜底）
static func get_sound(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStream = null
	match sound_name:
		"arrow":
			stream = _wav(_arrow_samples(), false)
		"coin":
			stream = _wav(_coin_samples(), false)
		"gem":
			stream = _wav(_gem_samples(), false)
		"victory":
			stream = _wav(_victory_samples(), false)
		"defeat":
			stream = _wav(_defeat_samples(), false)
		"menu_theme":
			# 不做引擎级 LOOP：由 AudioManager 在 finished 后重播，避开部分 Android
			# 音频后端在 WAV 循环点上的崩溃（菜单优先使用 assets/audio/bgm/menu_theme.ogg）
			stream = _wav(_menu_theme_samples(), false)
		_:
			push_warning("ProceduralAudio: 未知音效 " + sound_name)
			return null
	_cache[sound_name] = stream
	return stream


# ---------------- 基础合成 ----------------
static func _wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	# 归一化到 0.95，避免削波
	var peak: float = 0.0001
	for v in samples:
		var a: float = absf(v)
		if a > peak:
			peak = a
	var gain: float = 0.95 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i] * gain, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(round(v * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _add_tone(buf: PackedFloat32Array, start: int, freq: float, dur: float,
		amp: float, wave: String = "triangle", decay: float = 5.0) -> void:
	var n: int = int(dur * SR)
	if n <= 0:
		return
	for i in n:
		var idx: int = start + i
		if idx < 0 or idx >= buf.size():
			break
		var t: float = float(i) / SR
		var env: float = minf(1.0, t / 0.006) * exp(-t * decay)
		var ph: float = TWO_PI * freq * t
		var v: float
		if wave == "triangle":
			v = 2.0 / PI * asin(sin(ph))
		elif wave == "square":
			v = 1.0 if sin(ph) >= 0.0 else -1.0
		else:
			v = sin(ph)
		buf[idx] += v * amp * env


# ---------------- 具体音色 ----------------
# 金币：短促双音
static func _coin_samples() -> PackedFloat32Array:
	var dur := 0.22
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	_add_tone(buf, 0, 1350.0, 0.12, 0.42, "triangle", 12.0)
	_add_tone(buf, int(0.055 * SR), 1900.0, 0.16, 0.30, "triangle", 10.0)
	return buf


# 钻石：清爽的高音提示
static func _gem_samples() -> PackedFloat32Array:
	var dur := 0.38
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	_add_tone(buf, 0, 1050.0, 0.22, 0.34, "sine", 8.0)
	_add_tone(buf, int(0.06 * SR), 1580.0, 0.30, 0.28, "sine", 7.0)
	_add_tone(buf, int(0.12 * SR), 2100.0, 0.22, 0.18, "triangle", 9.0)
	return buf


# 远程攻击：短促的“嗖”声（滤波噪声 + 下滑正弦）
static func _arrow_samples() -> PackedFloat32Array:
	var dur := 0.18
	var n: int = int(dur * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / SR
		var env: float = minf(1.0, t / 0.004) * exp(-t * 16.0)
		lp = lp * 0.82 + rng.randf_range(-1.0, 1.0) * 0.18
		var sweep_f: float = 1100.0 - 700.0 * (t / dur)
		var sweep: float = sin(TWO_PI * sweep_f * t)
		buf[i] = (lp * 0.75 + sweep * 0.35) * env
	return buf


# 胜利：上行三音 + 收尾和弦
static func _victory_samples() -> PackedFloat32Array:
	var dur := 1.7
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	var notes := [523.25, 659.25, 783.99, 1046.50]
	var step := 0.20
	for i in notes.size():
		_add_tone(buf, int(i * step * SR), notes[i], 0.55, 0.32, "triangle", 4.5)
	# 收尾和弦
	var start: int = int((notes.size() - 1) * step * SR)
	_add_tone(buf, start, 523.25, 0.9, 0.20, "triangle", 2.6)
	_add_tone(buf, start, 659.25, 0.9, 0.16, "triangle", 2.6)
	_add_tone(buf, start, 783.99, 0.9, 0.16, "triangle", 2.6)
	return buf


# 失败：下行小调音
static func _defeat_samples() -> PackedFloat32Array:
	var dur := 1.9
	var buf := PackedFloat32Array()
	buf.resize(int(dur * SR))
	var notes := [392.00, 349.23, 293.66, 220.00]
	var step := 0.34
	for i in notes.size():
		_add_tone(buf, int(i * step * SR), notes[i], 0.7, 0.30, "sine", 3.0)
		_add_tone(buf, int(i * step * SR), notes[i] * 0.5, 0.7, 0.12, "triangle", 3.0)
	return buf


# 菜单音乐：4 小节循环（C-G-Am-F），钢琴式琶音 + 低音
static func _menu_theme_samples() -> PackedFloat32Array:
	var bpm := 112.0
	var beat: float = 60.0 / bpm
	var eighth: float = beat * 0.5
	var bars := 4
	var total: int = int(round(bars * 4.0 * beat * SR))
	var buf := PackedFloat32Array()
	buf.resize(total)
	var chords := [
		[261.63, 329.63, 392.00],   # C
		[196.00, 246.94, 293.66],   # G
		[220.00, 261.63, 329.63],   # Am
		[174.61, 220.00, 261.63],   # F
	]
	var bass := [130.81, 98.00, 110.00, 87.31]
	var arp := [0, 1, 2, 1, 0, 2, 1, 2]
	for bar in bars:
		var chord: Array = chords[bar]
		var bar_start: float = float(bar) * 4.0 * beat
		# 低音：每小节两拍
		for b in [0, 2]:
			_add_tone(buf, int((bar_start + float(b) * beat) * SR), float(bass[bar]),
				beat * 0.85, 0.16, "sine", 2.2)
		# 琶音：八分音符
		for e in 8:
			var note: float = float(chord[int(arp[e])])
			if e >= 6:
				note *= 2.0   # 后半小节高八度，增加流动感
			_add_tone(buf, int((bar_start + float(e) * eighth) * SR), note,
				eighth * 1.6, 0.15, "triangle", 6.0)
	return buf
