## Cloud Save — GameData + StaminaManager'i Firebase'e kaydeder/yukler.
## Periyodik sync + onemli olaylarda aninda sync.
extends Node

var _auth: Node
var _firestore: Node
var _sync_timer: Timer
var _is_saving: bool = false
var _save_queued: bool = false

const SYNC_INTERVAL: float = 60.0  # Her 60 saniyede otomatik sync

signal save_started()
signal save_finished(success: bool)
signal load_finished(success: bool)


func _ready() -> void:
	_auth = get_node_or_null("/root/FirebaseAuth")
	_firestore = get_node_or_null("/root/FirebaseFirestore")

	if _firestore:
		_firestore.save_completed.connect(_on_save_completed)
		_firestore.load_completed.connect(_on_load_completed)

	# Periyodik sync timer
	_sync_timer = Timer.new()
	_sync_timer.wait_time = SYNC_INTERVAL
	_sync_timer.timeout.connect(save_to_cloud)
	_sync_timer.autostart = false
	add_child(_sync_timer)

	# Onemli olaylarda aninda kaydet
	EventBus.rank_up.connect(func(_r, _n): save_to_cloud())
	EventBus.equipment_changed.connect(func(_s, _i): save_to_cloud())

	# Uygulama arka plana gittiginde kaydet


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		save_to_cloud()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_to_cloud()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_to_cloud()


## Auth tamamlandiginda yukleme baslat
func start_after_auth() -> void:
	if _auth and _auth.is_authenticated:
		load_from_cloud()
		_sync_timer.start()


## Buluta kaydet
func save_to_cloud() -> void:
	if not _auth or not _auth.is_authenticated:
		return

	if _is_saving:
		_save_queued = true
		return

	_is_saving = true
	save_started.emit()

	var save_data := {
		"player": GameData.serialize(),
		"stamina": StaminaManager.serialize(),
		"save_version": 1,
		"last_save": Time.get_unix_time_from_system(),
	}

	_firestore.save_player_data(_auth.user_id, save_data)


## Buluttan yukle
func load_from_cloud() -> void:
	if not _auth or not _auth.is_authenticated:
		return
	_firestore.load_player_data(_auth.user_id)


## Kayit yaniti
func _on_save_completed(success: bool) -> void:
	_is_saving = false
	save_finished.emit(success)

	if not success:
		print("CloudSave: Save failed — will retry next interval")

	if _save_queued:
		_save_queued = false
		save_to_cloud()


## Yukleme yaniti
func _on_load_completed(success: bool, data: Dictionary) -> void:
	if not success:
		print("CloudSave: Load failed — using local/default data")
		load_finished.emit(false)
		return

	if data.is_empty():
		# Yeni oyuncu — varsayilan veri ile baslat
		print("CloudSave: New player — initializing default data")
		GameData.initialize_new_player(_auth.user_id, "Player_%s" % _auth.user_id.left(6))
		save_to_cloud()  # Ilk kayit
	else:
		# Mevcut veriyi yukle
		if data.has("player"):
			GameData.deserialize(data["player"])
		if data.has("stamina"):
			StaminaManager.deserialize(data["stamina"])
		print("CloudSave: Data loaded (v%d)" % data.get("save_version", 0))

	load_finished.emit(true)
