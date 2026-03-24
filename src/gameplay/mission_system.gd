## Gorev sistemi — cekirdek 30-saniyelik dongu.
## Data-driven: JSON'dan gorev yukler, basari hesaplar, odul dagitir.
extends Node

signal mission_started(mission: Dictionary)
signal mission_resolved(mission: Dictionary, success: bool, rewards: Dictionary)
signal mission_list_updated(missions: Array)

var all_missions: Array = []
var available_missions: Array = []
var cooldowns: Dictionary = {}  # mission_id -> cooldown_end_timestamp

var _is_running: bool = false
var _current_mission: Dictionary = {}
var _mission_timer: float = 0.0

const MISSIONS_PATH: String = "res://assets/data/missions.json"
const MISSIONS_PER_REFRESH: int = 8
const MISSION_REFRESH_INTERVAL: float = 3600.0  # 1 saat
const MIN_SUCCESS_RATE: float = 0.05
const MAX_SUCCESS_RATE: float = 0.95
const TERRITORY_BONUS: float = 1.20
const FAILURE_RESPECT_RATIO: float = 0.2  # Basarisizlikta %20 respect


func _ready() -> void:
	_load_missions()
	_refresh_mission_list()


func _process(delta: float) -> void:
	if _is_running:
		_mission_timer += delta
		if _mission_timer >= _current_mission.get("duration_seconds", 5.0):
			_resolve()


## JSON'dan gorevleri yukle
func _load_missions() -> void:
	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("Mission file not found: %s" % MISSIONS_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Mission JSON parse error: %s" % json.get_error_message())
		return

	all_missions = json.data if json.data is Array else []
	print("MissionSystem: %d missions loaded" % all_missions.size())


## Gorev listesini yenile (rank'a uygun gorevleri sec)
func _refresh_mission_list() -> void:
	var eligible: Array = []
	for mission in all_missions:
		if mission.get("required_rank", 0) <= GameData.rank:
			eligible.append(mission)

	# Zorluk dagilimi ile sec
	eligible.shuffle()
	available_missions = eligible.slice(0, mini(MISSIONS_PER_REFRESH, eligible.size()))
	mission_list_updated.emit(available_missions)
	EventBus.mission_list_refreshed.emit()


## Gorev baslat
func start_mission(mission_id: String) -> bool:
	if _is_running:
		return false

	var mission := _find_mission(mission_id)
	if mission.is_empty():
		return false

	# Gereksinim kontrolu
	if GameData.rank < mission.get("required_rank", 0):
		return false

	# Stat gereksinimi
	var req_stats: Dictionary = mission.get("required_stats", {})
	for stat_name in req_stats:
		if GameData.get_stat(stat_name) < req_stats[stat_name]:
			return false

	# Cooldown kontrolu
	if _is_on_cooldown(mission_id):
		return false

	# Stamina kontrolu + harcama
	var cost: int = mission.get("stamina_cost", 5)
	if not StaminaManager.spend(cost):
		return false

	# Gorevi baslat
	_current_mission = mission
	_is_running = true
	_mission_timer = 0.0

	mission_started.emit(mission)
	EventBus.mission_started.emit(mission_id)
	return true


## Gorev sonucunu hesapla
func _resolve() -> void:
	_is_running = false
	var mission := _current_mission
	var mission_id: String = mission.get("mission_id", "")

	# Basari hesapla
	var success_rate := calculate_success_rate(mission)
	var roll := randf()
	var success := roll <= success_rate

	var rewards := {}

	if success:
		# Cash odulu
		var cash_min: int = mission.get("cash_reward_min", 50)
		var cash_max: int = mission.get("cash_reward_max", 150)
		var cash_earned: int = randi_range(cash_min, cash_max)
		cash_earned = int(cash_earned * EconomyManager.get_charisma_multiplier())
		cash_earned = int(cash_earned * _get_territory_cash_multiplier())

		# Respect odulu
		var respect_earned: int = mission.get("respect_reward", 10)
		var diff_mult := _get_difficulty_multiplier(mission.get("difficulty", "EASY"))
		respect_earned = int(respect_earned * diff_mult)

		# Odul uygula
		EconomyManager.add_cash(cash_earned, "mission_%s" % mission_id)
		GameData.add_respect(respect_earned, "mission_%s" % mission_id)

		rewards = {
			"success": true,
			"cash": cash_earned,
			"respect": respect_earned,
			"loot": null,
		}

		# Loot roll
		var loot: Dictionary = ItemDB.roll_loot(["WEAPON", "ARMOR", "CLOTHING"])
		if not loot.is_empty():
			rewards["loot"] = loot
			var inv: Node = get_node_or_null("/root/InventoryManager")
			if inv:
				inv.add_item(loot["item_id"], 1)
			else:
				EventBus.item_acquired.emit(loot["item_id"], 1)
	else:
		# Basarisizlik — kucuk respect
		var fail_respect: int = maxi(1, int(mission.get("respect_reward", 10) * FAILURE_RESPECT_RATIO))
		GameData.add_respect(fail_respect, "mission_fail_%s" % mission_id)

		rewards = {
			"success": false,
			"cash": 0,
			"respect": fail_respect,
			"loot": null,
		}

	# Cooldown uygula
	var cooldown: int = mission.get("cooldown_seconds", 0)
	if cooldown > 0:
		cooldowns[mission_id] = Time.get_unix_time_from_system() + cooldown

	mission_resolved.emit(mission, success, rewards)
	EventBus.mission_completed.emit(mission_id, success, rewards)
	_current_mission = {}


## Basari orani hesapla
func calculate_success_rate(mission: Dictionary) -> float:
	var rate: float = mission.get("base_success_rate", 0.5)
	var influences: Dictionary = mission.get("stat_influence", {})
	for stat_name in influences:
		rate += GameData.get_stat(stat_name) * influences[stat_name]
	return clampf(rate, MIN_SUCCESS_RATE, MAX_SUCCESS_RATE)


## Kontrol edilen bolgelerden mission cash bonusu
func _get_territory_cash_multiplier() -> float:
	if GameData.gang_id.is_empty():
		return 1.0

	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr == null:
		return 1.0

	# Aktif bolge seciliyse onu kullan
	if not GameData.current_territory.is_empty():
		var current_bonus: float = territory_mgr.get_mission_bonus(GameData.current_territory)
		if current_bonus > 1.0:
			return current_bonus

	# Geriye donuk uyumluluk: secili bolge yoksa kontrol edilen bolgelerden en iyi bonus
	var best_bonus := 1.0
	var controlled: Array = territory_mgr.get_territories_by_gang(GameData.gang_id)
	for territory in controlled:
		best_bonus = maxf(best_bonus, territory.get("mission_bonus", TERRITORY_BONUS))
	return best_bonus


## Cooldown kontrolu
func _is_on_cooldown(mission_id: String) -> bool:
	if not cooldowns.has(mission_id):
		return false
	return Time.get_unix_time_from_system() < cooldowns[mission_id]


## Cooldown kalan sure
func get_cooldown_remaining(mission_id: String) -> float:
	if not cooldowns.has(mission_id):
		return 0.0
	return maxf(0.0, cooldowns[mission_id] - Time.get_unix_time_from_system())


## Zorluk carpani
func _get_difficulty_multiplier(difficulty: String) -> float:
	match difficulty:
		"EASY": return 1.0
		"MEDIUM": return 1.5
		"HARD": return 2.5
		"EXTREME": return 4.0
		_: return 1.0


## Gorev bul (ID ile)
func _find_mission(mission_id: String) -> Dictionary:
	for mission in all_missions:
		if mission.get("mission_id", "") == mission_id:
			return mission
	return {}


## Gorev suresi ilerleme orani (UI icin, 0.0 - 1.0)
func get_progress() -> float:
	if not _is_running:
		return 0.0
	var duration: float = _current_mission.get("duration_seconds", 5.0)
	return clampf(_mission_timer / duration, 0.0, 1.0)


## Su an gorev calisiyor mu
func is_running() -> bool:
	return _is_running
