# scripts/net/NetworkMessage.gd
class_name NetworkMessage
extends RefCounted

var type: int
var data: Dictionary
var sender_id: String = ""
var timestamp: int = 0

func to_json() -> String:
	return JSON.stringify({
		"type": type,
		"data": data,
		"sender_id": sender_id,
		"timestamp": timestamp
	})

static func from_json(json_str: String) -> NetworkMessage:
	var dict = JSON.parse_string(json_str)
	if dict == null: return null
	var msg = NetworkMessage.new()
	msg.type = dict.get("type", 0)
	msg.data = dict.get("data", {})
	msg.sender_id = dict.get("sender_id", "")
	msg.timestamp = dict.get("timestamp", 0)
	return msg
