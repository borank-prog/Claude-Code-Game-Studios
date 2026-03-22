## Firebase Firestore — REST API ile veri okuma/yazma.
## Oyuncu verisi kaydetme ve yukleme.
extends Node

var _auth: Node  # FirebaseAuth referansi

signal save_completed(success: bool)
signal load_completed(success: bool, data: Dictionary)
signal operation_failed(error: String)


func _ready() -> void:
	# Auth node'unu bul (ayni seviyede veya autoload)
	_auth = get_node_or_null("/root/FirebaseAuth")


## Oyuncu verisini kaydet
func save_player_data(player_id: String, data: Dictionary) -> void:
	if not _auth or not _auth.is_authenticated:
		operation_failed.emit("Not authenticated")
		return

	var url := "%s/players/%s" % [FirebaseConfig.FIRESTORE_BASE_URL, player_id]
	var firestore_data := _dict_to_firestore(data)
	var body := JSON.stringify({"fields": firestore_data})

	var http := HTTPRequest.new()
	http.request_completed.connect(_on_save_completed.bind(http))
	add_child(http)
	http.request(url, _auth.get_auth_header(), HTTPClient.METHOD_PATCH, body)


## Oyuncu verisini yukle
func load_player_data(player_id: String) -> void:
	if not _auth or not _auth.is_authenticated:
		operation_failed.emit("Not authenticated")
		return

	var url := "%s/players/%s" % [FirebaseConfig.FIRESTORE_BASE_URL, player_id]

	var http := HTTPRequest.new()
	http.request_completed.connect(_on_load_completed.bind(http))
	add_child(http)
	http.request(url, _auth.get_auth_header(), HTTPClient.METHOD_GET)


## Kayit yaniti
func _on_save_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		var error_msg := "Save failed: HTTP %d" % response_code
		if body.size() > 0:
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
				if json.data.has("error"):
					error_msg = json.data["error"].get("message", error_msg)
		operation_failed.emit(error_msg)
		save_completed.emit(false)
		return

	print("Firestore: Player data saved")
	save_completed.emit(true)


## Yukleme yaniti
func _on_load_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		operation_failed.emit("Load failed: connection error")
		load_completed.emit(false, {})
		return

	if response_code == 404:
		# Yeni oyuncu — veri yok, bos dondur
		print("Firestore: No player data found (new player)")
		load_completed.emit(true, {})
		return

	if response_code >= 400:
		operation_failed.emit("Load failed: HTTP %d" % response_code)
		load_completed.emit(false, {})
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		operation_failed.emit("JSON parse error")
		load_completed.emit(false, {})
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var fields: Dictionary = data.get("fields", {})
	var result_data := _firestore_to_dict(fields)

	print("Firestore: Player data loaded")
	load_completed.emit(true, result_data)


# === FIRESTORE FORMAT DONUSUMU ===
# Firestore REST API ozel format kullanir:
# {"fieldName": {"stringValue": "hello"}} gibi

func _dict_to_firestore(data: Dictionary) -> Dictionary:
	var result := {}
	for key in data:
		result[key] = _value_to_firestore(data[key])
	return result


func _value_to_firestore(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_STRING:
			return {"stringValue": value}
		TYPE_INT:
			return {"integerValue": str(value)}
		TYPE_FLOAT:
			return {"doubleValue": value}
		TYPE_BOOL:
			return {"booleanValue": value}
		TYPE_DICTIONARY:
			return {"mapValue": {"fields": _dict_to_firestore(value)}}
		TYPE_ARRAY:
			var values := []
			for item in value:
				values.append(_value_to_firestore(item))
			return {"arrayValue": {"values": values}}
		TYPE_NIL:
			return {"nullValue": null}
		_:
			return {"stringValue": str(value)}


func _firestore_to_dict(fields: Dictionary) -> Dictionary:
	var result := {}
	for key in fields:
		result[key] = _firestore_to_value(fields[key])
	return result


func _firestore_to_value(field: Dictionary) -> Variant:
	if field.has("stringValue"):
		return field["stringValue"]
	elif field.has("integerValue"):
		return int(field["integerValue"])
	elif field.has("doubleValue"):
		return field["doubleValue"]
	elif field.has("booleanValue"):
		return field["booleanValue"]
	elif field.has("mapValue"):
		return _firestore_to_dict(field["mapValue"].get("fields", {}))
	elif field.has("arrayValue"):
		var values := []
		for item in field["arrayValue"].get("values", []):
			values.append(_firestore_to_value(item))
		return values
	elif field.has("nullValue"):
		return null
	return null
