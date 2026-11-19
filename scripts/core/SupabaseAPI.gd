extends Node
# Supabase 共享数据层：clan/leaderboard/inventory 统一存 cr_data(key,value)

const URL := "https://oewvixujojsbqwxfnkfk.supabase.co"
const KEY := "sb_publishable_ppeyEdIwDfUDkcrmTFBVjQ_6P8i64F3"
const TABLE := "cr_data"

func _token() -> String:
	var am = get_node_or_null("/root/AccountManager")
	if am and am.has_method("supabase_token"):
		return String(am.supabase_token())
	return ""

func is_ready() -> bool:
	return _token() != ""

func _headers(extra: Array = []) -> PackedStringArray:
	var h := PackedStringArray([
		"apikey: " + KEY,
		"Authorization: Bearer " + (_token() if _token() != "" else KEY),
		"Content-Type: application/json",
	])
	for e in extra:
		h.append(String(e))
	return h

func _request(method: int, path: String, body: Dictionary = {}, extra: Array = []) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var headers := _headers(extra)
	var err := http.request(URL + path, headers, method, JSON.stringify(body) if not body.is_empty() else "")
	if err != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var res: Array = await http.request_completed
	http.queue_free()
	return res

func _parse(res: Array):
	var text := String(res[3].get_string_from_utf8())
	return JSON.parse_string(text)

func list_prefix(prefix: String, limit: int = 500) -> Array:
	var res: Array = await _request(HTTPClient.METHOD_GET,
		"/rest/v1/%s?key=like.%s*&select=key,value,updated_at&limit=%d" % [TABLE, prefix, limit])
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return []
	var data = _parse(res)
	return data if data is Array else []

func get_value(key: String) -> Dictionary:
	var res: Array = await _request(HTTPClient.METHOD_GET,
		"/rest/v1/%s?key=eq.%s&select=value" % [TABLE, key])
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {}
	var data = _parse(res)
	if data is Array and data.size() > 0 and data[0] is Dictionary:
		var v = data[0].get("value", {})
		return v if v is Dictionary else {}
	return {}

func upsert(key: String, value: Dictionary) -> bool:
	var res: Array = await _request(HTTPClient.METHOD_POST,
		"/rest/v1/%s?on_conflict=key" % TABLE,
		{"key": key, "value": value},
		["Prefer: resolution=merge-duplicates,return=minimal"])
	return int(res[1]) >= 200 and int(res[1]) < 300
