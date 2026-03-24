## Bina sistemi — insa, yukseltme, yikma, gelir, savunma.
extends Node

signal building_placed(territory_id: String, building: Dictionary)
signal building_upgraded(territory_id: String, building: Dictionary)
signal building_destroyed(territory_id: String, building_id: String)
signal build_started(territory_id: String, building: Dictionary, finish_time: float)

var active_builds: Array[Dictionary] = []  # {territory_id, building, finish_time}

const INTELLIGENCE_BUILD_BONUS: float = 0.02
const MIN_BUILD_TIME_RATIO: float = 0.2

const BUILDING_DEFS: Dictionary = {
	"stash_house": {
		"name": "Stash House", "category": "INCOME", "required_rank": 0, "required_gang_level": 0, "max_level": 5,
		"build_cost": [500, 1500, 4000, 10000, 25000],
		"build_time": [60, 300, 900, 2700, 7200],
		"income_per_hour": [20, 50, 120, 250, 500],
		"defense_bonus": [0, 0, 0, 0, 0],
	},
	"crack_house": {
		"name": "Crack House", "category": "INCOME", "required_rank": 3, "required_gang_level": 0, "max_level": 5,
		"build_cost": [1000, 3000, 8000, 20000, 50000],
		"build_time": [120, 600, 1800, 5400, 14400],
		"income_per_hour": [40, 100, 240, 500, 1000],
		"defense_bonus": [0, 0, 0, 0, 0],
	},
	"gun_store": {
		"name": "Silah Dukkani", "category": "DEFENSE", "required_rank": 5, "required_gang_level": 0, "max_level": 5,
		"build_cost": [2000, 5000, 12000, 30000, 75000],
		"build_time": [300, 900, 2700, 7200, 18000],
		"income_per_hour": [0, 0, 0, 0, 0],
		"defense_bonus": [100, 250, 500, 1000, 2000],
	},
	"safe_house": {
		"name": "Siginak", "category": "DEFENSE", "required_rank": 7, "required_gang_level": 0, "max_level": 5,
		"build_cost": [3000, 8000, 20000, 50000, 120000],
		"build_time": [600, 1800, 5400, 14400, 36000],
		"income_per_hour": [10, 20, 40, 80, 160],
		"defense_bonus": [200, 500, 1000, 2000, 4000],
	},
	"lookout": {
		"name": "Gozetleme Kulesi", "category": "UTILITY", "required_rank": 4, "required_gang_level": 0, "max_level": 5,
		"build_cost": [1500, 4000, 10000, 25000, 60000],
		"build_time": [180, 600, 1800, 5400, 14400],
		"income_per_hour": [0, 0, 0, 0, 0],
		"defense_bonus": [50, 100, 200, 400, 800],
	},
}


func _process(delta: float) -> void:
	_check_active_builds()


## Bina insa et
func build(territory_id: String, building_type: String) -> Dictionary:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr == null:
		return {"success": false, "reason": "System not ready"}

	var territory: Dictionary = territory_mgr.get_territory(territory_id)
	if territory.is_empty():
		return {"success": false, "reason": "Bolge bulunamadi"}

	# Cete kontrolu
	if territory.get("controlling_gang_id", "") != GameData.gang_id or GameData.gang_id.is_empty():
		return {"success": false, "reason": "Bu bolge sana ait degil"}

	# Bina tanimini bul
	if not BUILDING_DEFS.has(building_type):
		return {"success": false, "reason": "Bina tipi bulunamadi"}

	var bdef: Dictionary = BUILDING_DEFS[building_type]

	# Rank kontrolu
	if bdef["required_rank"] > GameData.rank:
		return {"success": false, "reason": "Rank yetersiz"}

	# Slot kontrolu
	var buildings: Array = territory.get("buildings", [])
	if buildings.size() >= territory.get("building_slots", 2):
		return {"success": false, "reason": "Bina slotu dolu"}

	# Ayni tipten var mi kontrolu
	for b in buildings:
		if b["type"] == building_type:
			return {"success": false, "reason": "Bu tipten zaten var"}

	# Maliyet
	var cost: int = bdef["build_cost"][0]
	if not EconomyManager.spend_cash(cost, "build_%s" % building_type):
		return {"success": false, "reason": "Yetersiz cash"}

	# Insa suresi (intelligence bonusu)
	var base_time: float = bdef["build_time"][0]
	var int_bonus: float = 1.0 - (GameData.intelligence * INTELLIGENCE_BUILD_BONUS)
	int_bonus = maxf(int_bonus, MIN_BUILD_TIME_RATIO)
	var actual_time: float = base_time * int_bonus
	var finish_time: float = Time.get_unix_time_from_system() + actual_time

	var building := {
		"building_id": "bld_%d" % randi(),
		"type": building_type,
		"level": 1,
		"placed_at": Time.get_unix_time_from_system(),
	}

	active_builds.append({
		"territory_id": territory_id,
		"building": building,
		"finish_time": finish_time,
	})

	build_started.emit(territory_id, building, finish_time)
	return {"success": true, "building": building, "finish_time": finish_time}


## Bina yukselt
func upgrade(territory_id: String, building_id: String) -> Dictionary:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr == null:
		return {"success": false, "reason": "System not ready"}

	var territory: Dictionary = territory_mgr.get_territory(territory_id)
	if territory.is_empty():
		return {"success": false, "reason": "Bolge bulunamadi"}
	if territory.get("controlling_gang_id", "") != GameData.gang_id or GameData.gang_id.is_empty():
		return {"success": false, "reason": "Bu bolge sana ait degil"}
	var buildings: Array = territory.get("buildings", [])

	for b in buildings:
		if b["building_id"] == building_id:
			var bdef: Dictionary = BUILDING_DEFS.get(b["type"], {})
			var level: int = b["level"]

			if level >= bdef.get("max_level", 5):
				return {"success": false, "reason": "Max seviye"}

			var cost: int = bdef["build_cost"][level]  # level is 0-indexed for next
			if not EconomyManager.spend_cash(cost, "upgrade_%s" % b["type"]):
				return {"success": false, "reason": "Yetersiz cash"}

			b["level"] = level + 1
			building_upgraded.emit(territory_id, b)
			return {"success": true, "building": b}

	return {"success": false, "reason": "Bina bulunamadi"}


## Bina yik
func demolish(territory_id: String, building_id: String) -> bool:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr == null:
		return false

	var territory: Dictionary = territory_mgr.get_territory(territory_id)
	if territory.is_empty():
		return false
	if territory.get("controlling_gang_id", "") != GameData.gang_id or GameData.gang_id.is_empty():
		return false
	var buildings: Array = territory.get("buildings", [])

	for i in buildings.size():
		if buildings[i]["building_id"] == building_id:
			var removed: Dictionary = buildings[i]
			buildings.remove_at(i)
			building_destroyed.emit(territory_id, building_id)
			return true

	return false


## Bina geliri (saat basina)
func get_building_income(building: Dictionary, apply_unit_bonus: bool = true) -> int:
	var bdef: Dictionary = BUILDING_DEFS.get(building.get("type", ""), {})
	var level: int = building.get("level", 1) - 1  # 0-indexed
	var incomes: Array = bdef.get("income_per_hour", [0])
	var income := 0
	if level < incomes.size():
		income = incomes[level]

	if apply_unit_bonus and income > 0:
		income = int(income * _get_building_income_multiplier())
	return income


## Bina savunma bonusu
func get_building_defense(building: Dictionary) -> int:
	var bdef: Dictionary = BUILDING_DEFS.get(building.get("type", ""), {})
	var level: int = building.get("level", 1) - 1
	var defenses: Array = bdef.get("defense_bonus", [0])
	if level < defenses.size():
		return defenses[level]
	return 0


func _get_building_income_multiplier() -> float:
	var unit_mgr: Node = get_node_or_null("/root/UnitManager")
	if unit_mgr and unit_mgr.has_method("get_effect_multiplier"):
		return unit_mgr.get_effect_multiplier("building_income_multiplier")
	return 1.0


## Aktif insalari kontrol et
func _check_active_builds() -> void:
	var now := Time.get_unix_time_from_system()
	var completed: Array = []

	for build_info in active_builds:
		if now >= build_info["finish_time"]:
			completed.append(build_info)

	for build_info in completed:
		active_builds.erase(build_info)
		_complete_build(build_info)


func _complete_build(build_info: Dictionary) -> void:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr == null:
		return

	var territory: Dictionary = territory_mgr.get_territory(build_info["territory_id"])
	if territory.is_empty():
		return

	if not territory.has("buildings"):
		territory["buildings"] = []
	territory["buildings"].append(build_info["building"])

	building_placed.emit(build_info["territory_id"], build_info["building"])
