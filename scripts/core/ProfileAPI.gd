extends Node
# 公开玩家资料同步：profile:<scoped_id>
# 只同步公开字段，不上传金币/钻石/邮箱/回放等私人数据。

const PREFIX := "profile:"
const PUBLISH_SEC := 60.0

var _cache: Dictionary = {}
var _cache_at: Dictionary = {}
var _acc := 0.0
var _publishing := false


func _ready() -> void:
	set_process(true)
	_acc = PUBLISH_SEC


func _process(delta: float) -> void:
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return
	_acc += delta
	if _acc >= PUBLISH_SEC:
		_acc = 0.0
		publish_self()


func publish_self() -> void:
	if _publishing or not AccountManager or not AccountManager.is_supabase_authenticated():
		return
	var pid := str(ClanManager.get_player_id())
	if pid == "" or pid == "0":
		return
	_publishing = true
	await SupabaseAPI.upsert(PREFIX + pid, public_payload())
	_publishing = false


func public_payload() -> Dictionary:
	var deck: Array = []
	for cid in PlayerData.get_active_deck():
		deck.append({"id": int(cid), "level": PlayerData.get_card_level(int(cid))})
	return {
		"player_id": str(ClanManager.get_player_id()),
		"name": PlayerData.player_name,
		"avatar_seed": PlayerData.avatar_seed,
		"avatar_index": PlayerData.avatar_index,
		"trophies": PlayerData.trophies,
		"highest_trophies": PlayerData.highest_trophies,
		"arena": PlayerData.get_arena(),
		"clan": ClanManager.get_my_clan_name() if ClanManager.has_method("get_my_clan_name") else "",
		"battle_wins": PlayerData.battle_wins,
		"battle_losses": PlayerData.battle_losses,
		"battle_draws": PlayerData.battle_draws,
		"three_crowns": PlayerData.three_crown_wins,
		"current_streak": PlayerData.current_streak,
		"best_streak": PlayerData.best_streak,
		"season_crowns": PlayerData.season_crowns,
		"honor_title": PlayerData.honor_title,
		"tower_choice": PlayerData.tower_choice,
		"tower_used": PlayerData.get_most_used_tower(),
		"bio": PlayerData.bio,
		"role": PlayerData.clan_role,
		"donations": PlayerData.total_donations,
		"collection_level": PlayerData.get_collection_level(),
		"current_deck": deck,
		"top_cards": PlayerData.get_most_used_cards(3),
		"recent_battles": PlayerData.recent_battles.slice(0, 5).duplicate(true),
		"trophy_badges": PlayerData.claimed_achievements.size(),
		"mastery_badges": PlayerData.get_mastery_card_count(),
		"season_badges": PlayerData.season_claimed.size(),
		"updated_at": int(Time.get_unix_time_from_system()),
	}


func fetch(pid: String, force: bool = false) -> Dictionary:
	if pid == "":
		return {}
	if not force and _cache.has(pid):
		return Dictionary(_cache[pid]).duplicate(true)
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return {}
	var v: Dictionary = await SupabaseAPI.get_value(PREFIX + pid)
	if v is Dictionary and not v.is_empty():
		_cache[pid] = v.duplicate(true)
		_cache_at[pid] = int(Time.get_unix_time_from_system())
		return v.duplicate(true)
	return {}
