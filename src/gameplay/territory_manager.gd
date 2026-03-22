## Bolge haritasi yonetimi — mahalleler, kontrol, gelir, komsuluk.
extends Node

signal territory_updated(territory_id: String)
signal territory_captured(territory_id: String, gang_id: String)
signal territory_lost(territory_id: String)

var territories: Dictionary = {}  # territory_id -> Territory data
var _income_timer: float = 0.0

const TERRITORIES_PATH: String = "res://assets/data/territories.json"
const INCOME_TICK_INTERVAL: float = 60.0  # Her dakika gelir hesapla
const CONTROL_GROWTH_PER_DAY: float = 0.07
const INITIAL_CONTROL_STRENGTH: float = 0.5
const ENTRENCHMENT_BONUS: int = 500


func _ready() -> void:
	_load_territories()


func _process(delta: float) -> void:
	_income_timer += delta
	if _income_timer >= INCOME_TICK_INTERVAL:
		_income_timer = 0.0
		_process_income_tick()
		_process_control_growth()


func _load_territories() -> void:
	var file := FileAccess.open(TERRITORIES_PATH, FileAccess.READ)
	if file == null:
		push_warning("Territory file not found — loading defaults")
		_load_default_territories()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_load_default_territories()
		return

	var data: Array = json.data if json.data is Array else []
	for t in data:
		territories[t["territory_id"]] = t

	print("TerritoryManager: %d territories loaded" % territories.size())


func _load_default_territories() -> void:
	var defaults := [
		{"territory_id": "suburbs", "name": "Varoslar", "tier": 1, "base_income": 50, "building_slots": 2, "mission_bonus": 1.1, "adjacent": ["slums", "industrial"]},
		{"territory_id": "slums", "name": "Gecekondular", "tier": 1, "base_income": 50, "building_slots": 2, "mission_bonus": 1.1, "adjacent": ["suburbs", "docks", "market"]},
		{"territory_id": "industrial", "name": "Sanayi Bolgesi", "tier": 1, "base_income": 60, "building_slots": 2, "mission_bonus": 1.1, "adjacent": ["suburbs", "docks"]},
		{"territory_id": "docks", "name": "Liman", "tier": 2, "base_income": 150, "building_slots": 3, "mission_bonus": 1.2, "adjacent": ["industrial", "slums", "nightlife", "downtown"]},
		{"territory_id": "market", "name": "Pazar Yeri", "tier": 2, "base_income": 140, "building_slots": 3, "mission_bonus": 1.2, "adjacent": ["slums", "nightlife", "finance"]},
		{"territory_id": "nightlife", "name": "Gece Hayati", "tier": 2, "base_income": 160, "building_slots": 3, "mission_bonus": 1.2, "adjacent": ["docks", "market", "downtown"]},
		{"territory_id": "finance", "name": "Finans Merkezi", "tier": 2, "base_income": 180, "building_slots": 3, "mission_bonus": 1.2, "adjacent": ["market", "marina", "mansion"]},
		{"territory_id": "downtown", "name": "Sehir Merkezi", "tier": 3, "base_income": 400, "building_slots": 4, "mission_bonus": 1.3, "adjacent": ["docks", "nightlife", "marina"]},
		{"territory_id": "marina", "name": "Marina", "tier": 3, "base_income": 350, "building_slots": 4, "mission_bonus": 1.3, "adjacent": ["downtown", "finance", "mansion"]},
		{"territory_id": "mansion", "name": "Saray", "tier": 3, "base_income": 500, "building_slots": 4, "mission_bonus": 1.3, "adjacent": ["finance", "marina"]},
	]

	for t in defaults:
		t["controlling_gang_id"] = ""
		t["control_strength"] = 0.0
		t["contested"] = false
		t["buildings"] = []
		t["last_capture_time"] = 0.0
		territories[t["territory_id"]] = t


## Bolge bilgisi getir
func get_territory(territory_id: String) -> Dictionary:
	return territories.get(territory_id, {})


## Tum bolgeleri getir
func get_all_territories() -> Array:
	return territories.values()


## Cete tarafindan kontrol edilen bolgeler
func get_territories_by_gang(gang_id: String) -> Array:
	var result: Array = []
	for t in territories.values():
		if t.get("controlling_gang_id", "") == gang_id:
			result.append(t)
	return result


## Bolge ele gecir
func capture_territory(territory_id: String, gang_id: String) -> bool:
	if not territories.has(territory_id):
		return false

	var t: Dictionary = territories[territory_id]

	# Zaten bu cetenin mi
	if t["controlling_gang_id"] == gang_id:
		return false

	# Onceki ceteyi bilgilendir
	var old_gang: String = t["controlling_gang_id"]
	if not old_gang.is_empty():
		EventBus.territory_lost.emit(territory_id)

	t["controlling_gang_id"] = gang_id
	t["control_strength"] = INITIAL_CONTROL_STRENGTH
	t["contested"] = false
	t["last_capture_time"] = Time.get_unix_time_from_system()
	t["buildings"] = []  # Binalar yok edilir

	territory_captured.emit(territory_id, gang_id)
	EventBus.territory_captured.emit(territory_id, gang_id)
	territory_updated.emit(territory_id)
	return true


## Bolgeyi tarafsiza don
func neutralize_territory(territory_id: String) -> void:
	if not territories.has(territory_id):
		return
	var t: Dictionary = territories[territory_id]
	t["controlling_gang_id"] = ""
	t["control_strength"] = 0.0
	t["contested"] = false
	t["buildings"] = []
	territory_updated.emit(territory_id)


## Komsuluk kontrolu
func are_adjacent(territory_a: String, territory_b: String) -> bool:
	var t := get_territory(territory_a)
	return territory_b in t.get("adjacent", [])


## Bolge savunma gucu
func get_defense_power(territory_id: String) -> int:
	var t := get_territory(territory_id)
	var building_defense := 0
	for b in t.get("buildings", []):
		building_defense += b.get("defense_bonus", 0)
	var entrenchment := int(t.get("control_strength", 0.0) * ENTRENCHMENT_BONUS)
	return building_defense + entrenchment


## Bolge geliri (saat basina)
func get_territory_income(territory_id: String) -> int:
	var t := get_territory(territory_id)
	var base: int = t.get("base_income", 0)
	var control: float = t.get("control_strength", 0.0)
	return int(base * control)


## Gorev bonusu
func get_mission_bonus(territory_id: String) -> float:
	var t := get_territory(territory_id)
	if t.get("controlling_gang_id", "") == GameData.gang_id and not GameData.gang_id.is_empty():
		return t.get("mission_bonus", 1.0)
	return 1.0


## Periyodik gelir isleme
func _process_income_tick() -> void:
	if GameData.gang_id.is_empty():
		return

	var total_income := 0
	for t in territories.values():
		if t.get("controlling_gang_id", "") == GameData.gang_id:
			total_income += get_territory_income(t["territory_id"])

	# Saat basina gelir / 60 = dakika basina gelir
	var minute_income := total_income / 60
	if minute_income > 0:
		EconomyManager.add_cash(minute_income, "territory_income")


## Kontrol gucu artisi (zamana bagli)
func _process_control_growth() -> void:
	var growth_per_minute := CONTROL_GROWTH_PER_DAY / 1440.0
	for territory_id in territories:
		var t: Dictionary = territories[territory_id]
		if not t.get("controlling_gang_id", "").is_empty():
			t["control_strength"] = minf(t["control_strength"] + growth_per_minute, 1.0)


## Serialize
func serialize() -> Dictionary:
	return {"territories": territories.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	if data.has("territories"):
		for tid in data["territories"]:
			if territories.has(tid):
				var saved: Dictionary = data["territories"][tid]
				for key in saved:
					territories[tid][key] = saved[key]
