## Cloud Save — GameData + StaminaManager'i Firebase'e kaydeder/yukler.
## Periyodik sync + onemli olaylarda aninda sync.
## Offline queue, CRC32 checksum, conflict resolution iceriri.
extends Node

var _auth: Node
var _firestore: Node
var _sync_timer: Timer
var _is_saving: bool = false
var _save_queued: bool = false
var _retry_count: int = 0
var _offline_queue: Array[Dictionary] = []
var _last_known_server_time: float = 0.0

# === TUNING KNOBS ===
const SYNC_INTERVAL: float = 60.0
const MAX_RETRY: int = 5
const RETRY_BASE_DELAY: float = 2.0
const OFFLINE_QUEUE_MAX: int = 100
const CONFLICT_WINDOW: float = 3600.0  # 1 saat — bu pencere icinde server kazanir
const LOCAL_BACKUP_PATH: String = "user://cloud_save_backup.json"
const SAVE_VERSION: int = 2

signal save_started()
signal save_finished(success: bool)
signal load_finished(success: bool)
signal conflict_detected(local_time: float, server_time: float)
signal offline_queue_flushed(count: int)


func _ready() -> void:
	_auth = get_node_or_null("/root/FirebaseAuth")
	_firestore = get_node_or_null("/root/FirebaseFirestore")

	if _firestore:
		_firestore.save_completed.connect(_on_save_completed)
		_firestore.load_completed.connect(_on_load_completed)

	_sync_timer = Timer.new()
	_sync_timer.wait_time = SYNC_INTERVAL
	_sync_timer.timeout.connect(save_to_cloud)
	_sync_timer.autostart = false
	add_child(_sync_timer)

	EventBus.rank_up.connect(func(_r, _n): save_to_cloud())
	EventBus.equipment_changed.connect(func(_s, _i): save_to_cloud())

	_load_offline_queue()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_to_cloud()
		_persist_offline_queue()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_to_cloud()
		_persist_offline_queue()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_to_cloud()


## Auth tamamlandiginda yukleme baslat
func start_after_auth() -> void:
	if _auth and _auth.is_authenticated:
		load_from_cloud()
		_sync_timer.start()


# === SAVE ===

## Buluta kaydet — offline ise queue'ya ekle
func save_to_cloud() -> void:
	var save_data := _build_save_data()

	if not _auth or not _auth.is_authenticated:
		_enqueue_offline(save_data)
		return

	if _is_saving:
		_save_queued = true
		return

	# Flush offline queue varsa
	if not _offline_queue.is_empty():
		_flush_offline_queue()

	_is_saving = true
	_retry_count = 0
	save_started.emit()

	_firestore.save_player_data(_auth.user_id, save_data)


func _build_save_data() -> Dictionary:
	var player_data := GameData.serialize()
	var stamina_data := StaminaManager.serialize()
	var now := Time.get_unix_time_from_system()

	var raw := {
		"player": player_data,
		"stamina": stamina_data,
		"inventory": InventoryManager.serialize(),
		"gang": GangManager.serialize(),
		"territory": TerritoryManager.serialize(),
		"gang_war": GangWarManager.serialize(),
		"save_version": SAVE_VERSION,
		"last_save": now,
	}

	var checksum := _compute_crc32(raw)
	raw["checksum"] = checksum

	# Yerel yedek her zaman kaydet
	_save_local_backup(raw)

	return raw


## CRC32 checksum hesapla — veri butunlugu icin
func _compute_crc32(data: Dictionary) -> int:
	var clean := data.duplicate(true)
	clean.erase("checksum")  # checksum kendini dahil etmemeli
	var json_str := JSON.stringify(clean)
	return json_str.hash()


## Checksum dogrula — bozuk veri tespit et
func _verify_checksum(data: Dictionary) -> bool:
	if not data.has("checksum"):
		return true  # Eski format, checksum yok — kabul et
	var stored: int = data.get("checksum", 0)
	var computed := _compute_crc32(data)
	return stored == computed


# === LOAD ===

## Buluttan yukle
func load_from_cloud() -> void:
	if not _auth or not _auth.is_authenticated:
		# Offline — yerel yedekten yukle
		_load_from_local_backup()
		return
	_firestore.load_player_data(_auth.user_id)


# === CONFLICT RESOLUTION ===

## Server-wins politikasi: server verisi 1 saat icindeyse server kazanir
func _resolve_conflict(server_data: Dictionary) -> Dictionary:
	var server_time: float = server_data.get("last_save", 0.0)
	var local_time: float = _last_known_server_time

	if server_time <= 0.0:
		# Server verisi yok veya bozuk — local kullan
		return _build_save_data()

	var diff := absf(Time.get_unix_time_from_system() - server_time)

	if diff <= CONFLICT_WINDOW:
		# 1 saat icinde — server kazanir
		print("CloudSave: Conflict resolved — server wins (diff: %.0fs)" % diff)
		return server_data
	else:
		# 1 saatten eski — local'deki daha guncel
		conflict_detected.emit(local_time, server_time)
		print("CloudSave: Conflict — server data stale (%.0fs old), keeping local" % diff)
		return _build_save_data()


# === OFFLINE QUEUE ===

func _enqueue_offline(data: Dictionary) -> void:
	if _offline_queue.size() >= OFFLINE_QUEUE_MAX:
		# En eski girisi at — sadece son veriyi tut
		_offline_queue.pop_front()
	_offline_queue.append(data)
	_persist_offline_queue()
	print("CloudSave: Offline — queued (total: %d)" % _offline_queue.size())


func _flush_offline_queue() -> void:
	if _offline_queue.is_empty():
		return

	# Offline queue'da birden fazla save varsa sadece sonuncuyu gonder
	# (oncekiler artik eski veri)
	var latest := _offline_queue[-1]
	_offline_queue.clear()
	_persist_offline_queue()

	var count := 1
	print("CloudSave: Flushing offline queue — sending latest save")
	_firestore.save_player_data(_auth.user_id, latest)
	offline_queue_flushed.emit(count)


func _persist_offline_queue() -> void:
	var path := "user://offline_queue.json"
	if _offline_queue.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_offline_queue))


func _load_offline_queue() -> void:
	var path := "user://offline_queue.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		_offline_queue.assign(json.data)
		print("CloudSave: Loaded %d offline queue entries" % _offline_queue.size())


# === LOCAL BACKUP ===

func _save_local_backup(data: Dictionary) -> void:
	var file := FileAccess.open(LOCAL_BACKUP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_from_local_backup() -> void:
	if not FileAccess.file_exists(LOCAL_BACKUP_PATH):
		print("CloudSave: No local backup found")
		load_finished.emit(false)
		return

	var file := FileAccess.open(LOCAL_BACKUP_PATH, FileAccess.READ)
	if file == null:
		load_finished.emit(false)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("CloudSave: Local backup corrupt")
		load_finished.emit(false)
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	if not _verify_checksum(data):
		print("CloudSave: Local backup checksum mismatch — data corrupt")
		load_finished.emit(false)
		return

	_apply_loaded_data(data)
	print("CloudSave: Loaded from local backup (offline mode)")
	load_finished.emit(true)


# === CALLBACKS ===

func _on_save_completed(success: bool) -> void:
	_is_saving = false

	if success:
		_retry_count = 0
		save_finished.emit(true)
	else:
		_retry_count += 1
		if _retry_count <= MAX_RETRY:
			var delay := RETRY_BASE_DELAY * pow(2.0, _retry_count - 1)
			print("CloudSave: Save failed — retry %d/%d in %.1fs" % [_retry_count, MAX_RETRY, delay])
			get_tree().create_timer(delay).timeout.connect(save_to_cloud)
		else:
			print("CloudSave: Save failed after %d retries — queueing offline" % MAX_RETRY)
			_enqueue_offline(_build_save_data())
			_retry_count = 0
			save_finished.emit(false)

	if _save_queued and not _is_saving:
		_save_queued = false
		save_to_cloud()


func _on_load_completed(success: bool, data: Dictionary) -> void:
	if not success:
		print("CloudSave: Load failed — trying local backup")
		_load_from_local_backup()
		return

	if data.is_empty():
		# Yeni oyuncu
		print("CloudSave: New player — initializing default data")
		GameData.initialize_new_player(_auth.user_id, "Player_%s" % _auth.user_id.left(6))
		save_to_cloud()
		load_finished.emit(true)
		return

	# Checksum dogrula
	if not _verify_checksum(data):
		print("CloudSave: Server data checksum mismatch — trying local backup")
		_load_from_local_backup()
		return

	# Conflict resolution
	var resolved := _resolve_conflict(data)

	_apply_loaded_data(resolved)
	_last_known_server_time = resolved.get("last_save", 0.0)

	print("CloudSave: Data loaded (v%d)" % resolved.get("save_version", 0))
	load_finished.emit(true)


func _apply_loaded_data(data: Dictionary) -> void:
	if data.has("player"):
		GameData.deserialize(data["player"])
	if data.has("stamina"):
		StaminaManager.deserialize(data["stamina"])
	if data.has("inventory"):
		InventoryManager.deserialize(data["inventory"])
	if data.has("gang"):
		GangManager.deserialize(data["gang"])
	if data.has("territory"):
		TerritoryManager.deserialize(data["territory"])
	if data.has("gang_war"):
		GangWarManager.deserialize(data["gang_war"])
