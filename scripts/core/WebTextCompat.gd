extends Node
# Web 端没有系统 emoji 字体：把 UI 文本里的 emoji 替换为中文词，
# 避免出现方框/乱码；原生桌面端不处理，保留原 emoji 视觉。

const EMOTES := preload("res://scripts/data/EmoteCatalog.gd")
const TOKENS := {
	"👑": "王冠", "🌐": "联机", "🏆": "奖杯", "💎": "宝石", "🪙": "金币",
	"💧": "圣水", "😀": "表情", "🎵": "音乐", "🔊": "音效", "🎮": "难度",
	"🎞": "回放", "🏰": "塔", "✅": "完成", "❌": "失败", "⚠": "警告",
	"★": "星", "⭐": "星", "▶": "播放", "⏸": "暂停", "🔒": "锁",
	"🆕": "新", "🔍": "搜索", "🛒": "商店", "📦": "宝箱", "🏅": "奖牌",
	"🥇": "第一", "🥈": "第二", "🥉": "第三", "🎭": "面具", "🕊": "和平",
	"⚔": "战斗", "❤": "生命", "✨": "特效", "🏷": "标签", "🎯": "目标",
	"👥": "数量", "📈": "DPS", "📏": "距离", "💥": "溅射", "🏃": "速度",
	"🚶": "方式", "👁": "视野", "⭕": "半径", "🛡": "护盾", "🏟": "竞技场",
	"🃏": "卡牌", "⚙": "机制", "💡": "提示", "🎴": "卡组", "🛡️": "护盾",
}
var _map: Dictionary = {}
var _scan_acc: float = 0.0

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	for item in EMOTES.ITEMS:
		_map[String(item.glyph)] = String(item.name)
	for k in TOKENS.keys():
		_map[String(k)] = String(TOKENS[k])
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_tree")

func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_scan_acc += delta
	if _scan_acc < 0.25:
		return
	_scan_acc = 0.0
	_scan_tree()

func _scan_tree() -> void:
	_walk(get_tree().root)

func _walk(n: Node) -> void:
	_fix(n)
	for c in n.get_children():
		_walk(c)

func _on_node_added(n: Node) -> void:
	if n is Label or n is Button or n is RichTextLabel:
		call_deferred("_fix", n)

func _fix(n: Node) -> void:
	if not (n is Label or n is Button or n is RichTextLabel):
		return
	var src: String = String(n.get("text"))
	if src == "":
		return
	var out := _replace_emoji(src)
	if out != src:
		n.set("text", out)

func _replace_emoji(s: String) -> String:
	var clean := ""
	var first_emoji := ""
	for i in s.length():
		var cp := s.unicode_at(i)
		var ch := s[i]
		if _is_emoji(cp):
			if first_emoji == "":
				first_emoji = ch
			continue
		clean += ch
	clean = clean.strip_edges()
	if clean == "" and first_emoji != "":
		return String(_map.get(first_emoji, "图标"))
	return clean

func _is_emoji(cp: int) -> bool:
	if cp == 0xFE0F or cp == 0x200D or cp == 0x20E3:
		return true
	if cp >= 0x1F000 and cp <= 0x1FAFF:
		return true
	if cp >= 0x2600 and cp <= 0x27BF:
		return true
	if cp >= 0x2B00 and cp <= 0x2BFF:
		return true
	if cp >= 0x1F1E6 and cp <= 0x1F1FF:
		return true
	return false
