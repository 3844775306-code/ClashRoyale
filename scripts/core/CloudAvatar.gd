extends Node
# 云端头像：avatar:<scoped_player_id> = {data: base64(png), updated}
# 本地自定义头像上传后，好友/排行榜/部落等界面按 player_id 拉取。

const PREFIX := "avatar:"
const MAX_BYTES := 512 * 1024

var _cache: Dictionary = {}
var _fetching: Dictionary = {}


func _ready() -> void:
	if AccountManager and not AccountManager.session_changed.is_connected(_on_session):
		AccountManager.session_changed.connect(_on_session)
	call_deferred("_on_session")


func _on_session() -> void:
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return
	_sync_self()


func upload_self() -> void:
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return
	var img := _local_image()
	if img == null:
		return
	img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var bytes := img.save_png_to_buffer()
	if bytes.size() > MAX_BYTES:
		return
	var pid := str(ClanManager.get_player_id())
	var b64 := Marshalls.raw_to_base64(bytes)
	_cache[pid] = ImageTexture.create_from_image(img)
	await SupabaseAPI.upsert(PREFIX + pid, {
		"data": b64, "updated_at": int(Time.get_unix_time_from_system()),
	})


func remove_self() -> void:
	var pid := str(ClanManager.get_player_id())
	_cache.erase(pid)
	if pid != "" and AccountManager and AccountManager.is_supabase_authenticated():
		SupabaseAPI.delete_key(PREFIX + pid)


func _sync_self() -> void:
	var pid := str(ClanManager.get_player_id())
	if pid == "" or pid == "0":
		return
	var local := _local_image()
	if local != null:
		await upload_self()
		return
	var img: Image = await fetch_image(pid)
	if img != null:
		PlayerData.set_custom_avatar_image(img)


func apply(icon, pid: String, name: String, avatar_seed: int, avatar_index: int, is_self: bool = false) -> void:
	if icon == null:
		return
	if is_self:
		icon.setup(name, avatar_seed, avatar_index, PlayerData.get_avatar_texture())
		return
	icon.setup(name, avatar_seed, avatar_index)
	if pid == "":
		return
	if _cache.has(pid):
		icon.custom_texture = _cache[pid]
		icon.queue_redraw()
		return
	if _fetching.has(pid):
		return
	_fetching[pid] = true
	var img: Image = await fetch_image(pid)
	_fetching.erase(pid)
	if img != null and is_instance_valid(icon):
		var tex := ImageTexture.create_from_image(img)
		_cache[pid] = tex
		icon.custom_texture = tex
		icon.queue_redraw()


func fetch_image(pid: String) -> Image:
	if _cache.has(pid):
		return _cache[pid].get_image()
	if not AccountManager or not AccountManager.is_supabase_authenticated():
		return null
	var v: Dictionary = await SupabaseAPI.get_value(PREFIX + pid)
	if v.is_empty():
		return null
	var b64 := String(v.get("data", ""))
	if b64 == "":
		return null
	var raw := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	if img.load_png_from_buffer(raw) != OK:
		return null
	_cache[pid] = ImageTexture.create_from_image(img)
	return img


func _local_image() -> Image:
	var path := PlayerData.avatar_custom_path
	if path == "":
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	return Image.load_from_file(abs_path)
