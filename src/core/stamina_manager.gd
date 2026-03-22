## Stamina yonetimi — lazy regen, harcama, refill.
## Server zamani kullanir, client saatine guvenmez.
extends Node

var current: int = 0
var max_stamina: int = 100
var last_regen_time: float = 0.0

# === TUNING KNOBS ===
const BASE_STAMINA: int = 100
const STAMINA_PER_ENDURANCE: int = 2
const REGEN_INTERVAL: float = 120.0  # 2 dakikada 1 puan


func _ready() -> void:
	last_regen_time = Time.get_unix_time_from_system()
	recalculate_max()
	current = max_stamina


func _process(_delta: float) -> void:
	_update_regen()


## Lazy regen — her frame'de hesapla ama sadece gerektigi kadar guncelle
func _update_regen() -> void:
	if current >= max_stamina:
		return

	var now := Time.get_unix_time_from_system()
	var elapsed := now - last_regen_time
	var regen_points := int(elapsed / REGEN_INTERVAL)

	if regen_points > 0:
		var old := current
		current = mini(current + regen_points, max_stamina)
		last_regen_time += regen_points * REGEN_INTERVAL
		EventBus.stamina_changed.emit(current, max_stamina)

		if current >= max_stamina:
			EventBus.stamina_full.emit()


## Max stamina'yi endurance'a gore yeniden hesapla
func recalculate_max() -> void:
	max_stamina = BASE_STAMINA + (GameData.endurance * STAMINA_PER_ENDURANCE)
	EventBus.stamina_changed.emit(current, max_stamina)


## Stamina harca — basarili ise true doner
func spend(amount: int) -> bool:
	_update_regen()
	if amount <= 0 or current < amount:
		if current < amount:
			EventBus.stamina_depleted.emit()
		return false

	current -= amount
	EventBus.stamina_changed.emit(current, max_stamina)
	return true


## Full refill (rank up, ozel olay)
func full_refill() -> void:
	current = max_stamina
	last_regen_time = Time.get_unix_time_from_system()
	EventBus.stamina_changed.emit(current, max_stamina)
	EventBus.stamina_full.emit()


## Kalan regen suresi (sonraki 1 puan icin saniye)
func get_regen_remaining() -> float:
	if current >= max_stamina:
		return 0.0
	var now := Time.get_unix_time_from_system()
	var elapsed := now - last_regen_time
	return maxf(0.0, REGEN_INTERVAL - elapsed)


## Full regen suresi (tum stamina icin saniye)
func get_full_regen_remaining() -> float:
	if current >= max_stamina:
		return 0.0
	var deficit := max_stamina - current
	var next_regen := get_regen_remaining()
	return next_regen + (deficit - 1) * REGEN_INTERVAL


## Serialize (Cloud Save icin)
func serialize() -> Dictionary:
	return {
		"current": current,
		"max_stamina": max_stamina,
		"last_regen_time": last_regen_time,
	}


func deserialize(data: Dictionary) -> void:
	current = data.get("current", max_stamina)
	max_stamina = data.get("max_stamina", BASE_STAMINA)
	last_regen_time = data.get("last_regen_time", Time.get_unix_time_from_system())
	_update_regen()
