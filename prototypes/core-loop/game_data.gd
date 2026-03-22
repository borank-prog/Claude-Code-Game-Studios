# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the core mission loop satisfying on mobile?
# Date: 2026-03-22
extends Node

# === PLAYER DATA ===
var player_name: String = "Player"
var rank: int = 0
var respect: int = 0
var cash: int = 500
var strength: int = 5
var endurance: int = 5
var charisma: int = 5
var luck: int = 5

# === STAMINA ===
var stamina: int = 100
var max_stamina: int = 110  # 100 + endurance*2
var last_regen_time: float = 0.0
const REGEN_INTERVAL: float = 10.0  # 10s for prototype (120s in prod)

# === EQUIPMENT ===
var equipped_weapon_id: String = ""
var equipment_power: int = 0

# === RANK DATA ===
const RANK_NAMES: Array = [
	"Street Thug", "Petty Criminal", "Pickpocket", "Mugger", "Thief",
	"Hustler", "Enforcer", "Dealer", "Underboss", "Captain",
	"Lieutenant", "Capo", "Consigliere", "Godfather", "Crime Lord",
	"Don", "Boss", "Overlord", "Cartel Lord", "Kingpin"
]

const RANK_RESPECT: Array = [
	0, 100, 180, 324, 583, 1050, 1890, 3402, 6124, 11023,
	19841, 35714, 64286, 115714, 208286, 374914, 674846, 1214723, 2186501, 3935702
]

# === MISSIONS ===
const MISSIONS: Array = [
	{
		"id": "rob_store", "name": "Market Soygunu", "category": "ROBBERY",
		"difficulty": "EASY", "stamina_cost": 5,
		"cash_min": 50, "cash_max": 150, "respect": 10,
		"base_success": 0.7, "stat": "strength", "stat_influence": 0.03,
		"duration": 3.0
	},
	{
		"id": "drug_run", "name": "Uyusturucu Teslimat", "category": "TRAFFICKING",
		"difficulty": "MEDIUM", "stamina_cost": 10,
		"cash_min": 150, "cash_max": 400, "respect": 25,
		"base_success": 0.5, "stat": "endurance", "stat_influence": 0.03,
		"duration": 5.0
	},
	{
		"id": "extortion", "name": "Harac Toplama", "category": "EXTORTION",
		"difficulty": "EASY", "stamina_cost": 5,
		"cash_min": 80, "cash_max": 200, "respect": 15,
		"base_success": 0.65, "stat": "charisma", "stat_influence": 0.04,
		"duration": 4.0
	},
	{
		"id": "bank_heist", "name": "Banka Soygunu", "category": "ROBBERY",
		"difficulty": "HARD", "stamina_cost": 20,
		"cash_min": 500, "cash_max": 2000, "respect": 80,
		"base_success": 0.3, "stat": "strength", "stat_influence": 0.02,
		"duration": 7.0
	},
	{
		"id": "assassination", "name": "Suikast Gorevi", "category": "ASSASSINATION",
		"difficulty": "EXTREME", "stamina_cost": 35,
		"cash_min": 1000, "cash_max": 5000, "respect": 200,
		"base_success": 0.2, "stat": "luck", "stat_influence": 0.02,
		"duration": 8.0
	}
]

# === SHOP ===
const SHOP_ITEMS: Array = [
	{"id": "knife", "name": "Bicak", "price": 200, "power": 5, "stat": "strength", "stat_bonus": 2},
	{"id": "pistol", "name": "Tabanca", "price": 800, "power": 15, "stat": "strength", "stat_bonus": 5},
	{"id": "shotgun", "name": "Pompalı", "price": 2500, "power": 35, "stat": "strength", "stat_bonus": 10},
	{"id": "rifle", "name": "Tufek", "price": 6000, "power": 60, "stat": "strength", "stat_bonus": 18},
	{"id": "vest", "name": "Celik Yelek", "price": 1500, "power": 10, "stat": "endurance", "stat_bonus": 8},
	{"id": "car", "name": "Kacis Araci", "price": 5000, "power": 20, "stat": "luck", "stat_bonus": 10},
]

# === FUNCTIONS ===
func get_rank_name() -> String:
	return RANK_NAMES[mini(rank, RANK_NAMES.size() - 1)]

func get_next_rank_respect() -> int:
	if rank + 1 < RANK_RESPECT.size():
		return RANK_RESPECT[rank + 1]
	return RANK_RESPECT[RANK_RESPECT.size() - 1]

func get_stat(stat_name: String) -> int:
	match stat_name:
		"strength": return strength
		"endurance": return endurance
		"charisma": return charisma
		"luck": return luck
		_: return 5

func update_stamina() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if last_regen_time == 0.0:
		last_regen_time = now
		return
	var elapsed := now - last_regen_time
	var regen_points := int(elapsed / REGEN_INTERVAL)
	if regen_points > 0:
		stamina = mini(stamina + regen_points, max_stamina)
		last_regen_time += regen_points * REGEN_INTERVAL

func recalculate_max_stamina() -> void:
	max_stamina = 100 + endurance * 2

func check_rank_up() -> bool:
	if rank + 1 < RANK_RESPECT.size() and respect >= RANK_RESPECT[rank + 1]:
		rank += 1
		stamina = max_stamina  # Full refill on rank up
		return true
	return false

func calculate_power_score() -> int:
	return (strength * 3) + (endurance * 2) + (charisma) + (luck) + equipment_power
