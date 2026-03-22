## Merkezi oyuncu verisi — tum sistemlerin okudugu/yazdigi tek kaynak.
## Deger degisiklikleri SADECE delta fonksiyonlariyla yapilir.
extends Node

# === KIMLIK ===
var player_id: String = ""
var display_name: String = ""
var avatar_id: int = 0
var created_at: int = 0  # Unix timestamp
var last_login: int = 0

# === RANK & SAYGINLIK ===
var rank: int = 0
var respect: int = 0
var season_respect: int = 0

# === STATLAR ===
var strength: int = 0
var endurance: int = 0
var charisma: int = 0
var luck: int = 0
var intelligence: int = 0
var unspent_stat_points: int = 0

# === EKONOMI ===
var cash: int = 0
var premium_currency: int = 0

# === CETE ===
var gang_id: String = ""
var gang_role: String = ""  # "", "LEADER", "OFFICER", "MEMBER"

# === OTURUM ===
var is_online: bool = false
var current_territory: String = ""

# === TUNING KNOBS ===
const INITIAL_STAT_VALUE: int = 5
const STAT_CAP_BASE: int = 10
const STAT_CAP_PER_RANK: int = 5
const STAT_POINTS_PER_RANK: int = 3
const STARTING_CASH: int = 500

const RANK_NAMES: PackedStringArray = [
	"Street Thug", "Petty Criminal", "Pickpocket", "Mugger", "Thief",
	"Hustler", "Enforcer", "Dealer", "Underboss", "Captain",
	"Lieutenant", "Capo", "Consigliere", "Godfather", "Crime Lord",
	"Don", "Boss", "Overlord", "Cartel Lord", "Kingpin"
]

const BASE_RESPECT: float = 100.0
const RESPECT_GROWTH: float = 1.8


func _ready() -> void:
	pass


## Yeni oyuncu verisi olustur
func initialize_new_player(id: String, name: String) -> void:
	player_id = id
	display_name = name
	avatar_id = 0
	created_at = int(Time.get_unix_time_from_system())
	last_login = created_at

	rank = 0
	respect = 0
	season_respect = 0

	strength = INITIAL_STAT_VALUE
	endurance = INITIAL_STAT_VALUE
	charisma = INITIAL_STAT_VALUE
	luck = INITIAL_STAT_VALUE
	intelligence = INITIAL_STAT_VALUE
	unspent_stat_points = 0

	cash = STARTING_CASH
	premium_currency = 0

	gang_id = ""
	gang_role = ""
	is_online = true
	current_territory = ""


# === STAT ISLEMLERI (delta bazli) ===

func get_stat(stat_name: String) -> int:
	match stat_name:
		"strength": return strength
		"endurance": return endurance
		"charisma": return charisma
		"luck": return luck
		"intelligence": return intelligence
		_:
			push_warning("Unknown stat: %s" % stat_name)
			return 0


func apply_stat_delta(stat_name: String, delta: int) -> bool:
	var current := get_stat(stat_name)
	var new_value := clampi(current + delta, 1, get_stat_cap())
	if new_value == current:
		return false

	var actual_delta := new_value - current
	match stat_name:
		"strength": strength = new_value
		"endurance": endurance = new_value
		"charisma": charisma = new_value
		"luck": luck = new_value
		"intelligence": intelligence = new_value
		_: return false

	EventBus.stat_changed.emit(stat_name, new_value, actual_delta)

	if stat_name == "endurance":
		StaminaManager.recalculate_max()

	return true


func spend_stat_point(stat_name: String) -> bool:
	if unspent_stat_points <= 0:
		return false
	if get_stat(stat_name) >= get_stat_cap():
		return false

	unspent_stat_points -= 1
	apply_stat_delta(stat_name, 1)
	return true


func get_stat_cap() -> int:
	return STAT_CAP_BASE + (rank * STAT_CAP_PER_RANK)


# === RANK & RESPECT ===

func get_rank_name() -> String:
	return RANK_NAMES[mini(rank, RANK_NAMES.size() - 1)]


func get_respect_for_rank(target_rank: int) -> int:
	if target_rank <= 0:
		return 0
	return int(floor(BASE_RESPECT * pow(RESPECT_GROWTH, target_rank - 1)))


func get_next_rank_respect() -> int:
	if rank + 1 >= RANK_NAMES.size():
		return get_respect_for_rank(RANK_NAMES.size() - 1)
	return get_respect_for_rank(rank + 1)


func add_respect(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	respect += amount
	season_respect += amount
	EventBus.respect_gained.emit(amount, source)
	_check_rank_up()


func _check_rank_up() -> void:
	while rank + 1 < RANK_NAMES.size() and respect >= get_respect_for_rank(rank + 1):
		rank += 1
		unspent_stat_points += STAT_POINTS_PER_RANK
		StaminaManager.full_refill()
		EventBus.rank_up.emit(rank, get_rank_name())
		EventBus.stat_points_available.emit(unspent_stat_points)


# === POWER SCORE ===

const POWER_WEIGHT_STRENGTH: int = 3
const POWER_WEIGHT_ENDURANCE: int = 2
const POWER_WEIGHT_OTHER: int = 1

func get_power_score() -> int:
	return (strength * POWER_WEIGHT_STRENGTH) \
		+ (endurance * POWER_WEIGHT_ENDURANCE) \
		+ (charisma * POWER_WEIGHT_OTHER) \
		+ (luck * POWER_WEIGHT_OTHER) \
		+ (intelligence * POWER_WEIGHT_OTHER)


func get_total_power() -> int:
	# Power score + equipment power (inventory'den gelecek)
	return get_power_score()


# === CETE ===

func set_gang(id: String, role: String) -> void:
	gang_id = id
	gang_role = role


func leave_gang() -> void:
	gang_id = ""
	gang_role = ""
	EventBus.gang_left.emit()


# === SERIALIZE / DESERIALIZE ===

func serialize() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"avatar_id": avatar_id,
		"created_at": created_at,
		"last_login": last_login,
		"rank": rank,
		"respect": respect,
		"season_respect": season_respect,
		"strength": strength,
		"endurance": endurance,
		"charisma": charisma,
		"luck": luck,
		"intelligence": intelligence,
		"unspent_stat_points": unspent_stat_points,
		"cash": cash,
		"premium_currency": premium_currency,
		"gang_id": gang_id,
		"gang_role": gang_role,
	}


func deserialize(data_dict: Dictionary) -> void:
	player_id = data_dict.get("player_id", "")
	display_name = data_dict.get("display_name", "")
	avatar_id = data_dict.get("avatar_id", 0)
	created_at = data_dict.get("created_at", 0)
	last_login = data_dict.get("last_login", 0)
	rank = data_dict.get("rank", 0)
	respect = data_dict.get("respect", 0)
	season_respect = data_dict.get("season_respect", 0)
	strength = data_dict.get("strength", INITIAL_STAT_VALUE)
	endurance = data_dict.get("endurance", INITIAL_STAT_VALUE)
	charisma = data_dict.get("charisma", INITIAL_STAT_VALUE)
	luck = data_dict.get("luck", INITIAL_STAT_VALUE)
	intelligence = data_dict.get("intelligence", INITIAL_STAT_VALUE)
	unspent_stat_points = data_dict.get("unspent_stat_points", 0)
	cash = data_dict.get("cash", STARTING_CASH)
	premium_currency = data_dict.get("premium_currency", 0)
	gang_id = data_dict.get("gang_id", "")
	gang_role = data_dict.get("gang_role", "")

	StaminaManager.recalculate_max()
