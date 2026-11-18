extends RefCounted

# 表情收藏目录：官方 emote_id 映射到本作设计的表情
const ITEMS := [
	{"id": "15_2", "name": "国王点赞", "glyph": "👍", "color": "#FFD24A", "desc": "干得漂亮！"},
	{"id": "18_3", "name": "公主飞吻", "glyph": "😘", "color": "#FF7FB0", "desc": "送你一个飞吻"},
	{"id": "110_0", "name": "皮卡怒吼", "glyph": "😡", "color": "#8E6BFF", "desc": "P.E.K.K.A 生气了"},
	{"id": "goblin_laugh", "name": "哥布林大笑", "glyph": "😂", "color": "#6FD65A", "desc": "嘿嘿嘿嘿"},
	{"id": "skeleton_taunt", "name": "骷髅嘲讽", "glyph": "💀", "color": "#D8D8D8", "desc": "骨头都笑散了"},
	{"id": "hog_charge", "name": "野猪冲锋", "glyph": "🐗", "color": "#C98B4A", "desc": "冲啊！"},
	{"id": "wizard_fire", "name": "法师火球", "glyph": "🔥", "color": "#FF8A3A", "desc": "燃烧吧！"},
	{"id": "baby_dragon", "name": "飞龙宝宝", "glyph": "🐲", "color": "#5AD6C8", "desc": "嗷呜～"},
	{"id": "royal_ghost", "name": "皇家幽灵", "glyph": "👻", "color": "#9ADFFF", "desc": "你看不见我"},
	{"id": "elixir_hype", "name": "圣水狂热", "glyph": "🧪", "color": "#C45AFF", "desc": "圣水满上！"},
	{"id": "good_game", "name": "GG", "glyph": "🤝", "color": "#FFD24A", "desc": "打得好"},
	{"id": "cry_face", "name": "哭哭", "glyph": "😭", "color": "#6FA8FF", "desc": "这也太惨了"},
]

static func all() -> Array:
	return ITEMS

static func find(id: String) -> Dictionary:
	for item in ITEMS:
		if String(item.id) == id:
			return item
	return {}

static func display(id: String) -> Dictionary:
	var item: Dictionary = find(id)
	if item.is_empty():
		return {"id": id, "name": "神秘表情", "glyph": "🎭", "color": "#B8C6D8", "desc": "未收录的表情"}
	return item

static func glyph(id: String) -> String:
	return String(display(id).glyph)

static func name_of(id: String) -> String:
	return String(display(id).name)

static func color_of(id: String) -> Color:
	return Color(String(display(id).color))
