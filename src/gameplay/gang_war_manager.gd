## Gang War — asenkron bolge baskinlari, guc hesaplama, sonuc isleme.
extends Node

signal raid_declared(raid: Dictionary)
signal raid_preparation(raid: Dictionary, time_remaining: float)
signal raid_resolved(raid: Dictionary)

var active_raids: Array[Dictionary] = []
var raid_history: Array[Dictionary] = []

const WAR_PREPARATION_HOURS: float = 4.0
const WAR_LOCKOUT_HOURS: float = 1.0
const WIN_THRESHOLD: float = 1.2
const LOSE_THRESHOLD: float = 0.8
const RNG_VARIANCE: float = 0.1
const MORALE_PER_MEMBER: float = 0.05
const ENTRENCHMENT_MULTIPLIER: float = 0.5
const LOOT_HOURS: int = 6
const BASE_WAR_RESPECT: int = 200
const MIN_ATTACKERS: int = 1  # Solo dev icin 1 (prod'da 3)
const RAID_COOLDOWN_HOURS: float = 24.0
const RAID_DECLARE_COST: int = 15
const RAID_JOIN_COST: int = 10

# NPC savunma gucu — tier bazli, solo oyuncunun ilerleme hizina uygun
# Tier 1: Rank 0-3 oyuncu solo alabilir (power ~40-60)
# Tier 2: Rank 5-7 oyuncu ekipmanla alabilir (power ~100-200)
# Tier 3: Rank 8+ oyuncu veya 2-3 kisilik cete (power ~250-500)
const NPC_DEFENSE_BY_TIER: Dictionary = {
	1: 80,   # Varos — baslangic oyuncusuyla alinabilir
	2: 250,  # Orta — orta seviye oyuncu + ekipman
	3: 600,  # Merkez — deneyimli oyuncu veya kucuk cete
}

var _check_timer: float = 0.0


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= 10.0:  # Her 10 saniyede kontrol
		_check_timer = 0.0
		_process_active_raids()


## Baskin ilan et
func declare_raid(target_territory_id: String) -> Dictionary:
	var gang_mgr: Node = get_node_or_null("/root/GangManager")
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")

	if gang_mgr == null or territory_mgr == null:
		return {"success": false, "reason": "System not ready"}

	if not gang_mgr.is_in_gang:
		return {"success": false, "reason": "Cetede degilsin"}

	if not gang_mgr._has_permission("war_declare"):
		return {"success": false, "reason": "Yetkin yok"}

	var target: Dictionary = territory_mgr.get_territory(target_territory_id)
	if target.is_empty():
		return {"success": false, "reason": "Bolge bulunamadi"}

	# Kendi bolgene saldiramaz
	if target.get("controlling_gang_id", "") == GameData.gang_id:
		return {"success": false, "reason": "Kendi bolgen"}

	# Komsuluk kontrolu — cete en az bir komsfu bolgeyi kontrol etmeli
	var gang_territories: Array = territory_mgr.get_territories_by_gang(GameData.gang_id)
	var has_adjacent := false
	for gt in gang_territories:
		if territory_mgr.are_adjacent(gt["territory_id"], target_territory_id):
			has_adjacent = true
			break

	# Tarafsiz bolge icin komsuluk sartsiz (ilk bolge ele gecirme)
	if target.get("controlling_gang_id", "").is_empty():
		has_adjacent = true

	if not has_adjacent:
		return {"success": false, "reason": "Komsu bolgen yok"}

	# Cooldown kontrolu
	if _is_territory_on_cooldown(target_territory_id):
		return {"success": false, "reason": "Bekleme suresi"}

	# Stamina harca
	if not StaminaManager.spend(RAID_DECLARE_COST):
		return {"success": false, "reason": "Yetersiz stamina"}

	# Baskin olustur
	var raid := {
		"raid_id": "raid_%d_%d" % [Time.get_unix_time_from_system(), randi()],
		"attacker_gang_id": GameData.gang_id,
		"defender_gang_id": target.get("controlling_gang_id", ""),
		"target_territory_id": target_territory_id,
		"declared_at": Time.get_unix_time_from_system(),
		"resolves_at": Time.get_unix_time_from_system() + (WAR_PREPARATION_HOURS * 3600),
		"resolved": false,
		"attackers": [
			{
				"player_id": GameData.player_id,
				"power_contribution": InventoryManager.get_total_power(),
				"stamina_spent": RAID_DECLARE_COST,
			}
		],
		"defenders": [],
		"result": "",
		"territory_changed": false,
		"loot_stolen": 0,
	}

	# Tarafsiz bolge icin aninda coz
	if target.get("controlling_gang_id", "").is_empty():
		raid["resolves_at"] = Time.get_unix_time_from_system()
		_resolve_raid_against_neutral(raid, target_territory_id)
		return {"success": true, "raid": raid, "instant": true}

	active_raids.append(raid)
	raid_declared.emit(raid)
	EventBus.raid_declared.emit(raid["raid_id"], target_territory_id)
	return {"success": true, "raid": raid, "instant": false}


## Baskina katil
func join_raid(raid_id: String) -> bool:
	for raid in active_raids:
		if raid["raid_id"] == raid_id and not raid["resolved"]:
			# Ayni oyuncu ayni baskina iki kez katilamaz
			for attacker in raid.get("attackers", []):
				if attacker.get("player_id", "") == GameData.player_id:
					return false

			# Kilitlenme kontrolu
			var lockout_time: float = raid["resolves_at"] - (WAR_LOCKOUT_HOURS * 3600)
			if Time.get_unix_time_from_system() > lockout_time:
				return false  # Kilitlenme suresi

			if not StaminaManager.spend(RAID_JOIN_COST):
				return false

			raid["attackers"].append({
				"player_id": GameData.player_id,
				"power_contribution": InventoryManager.get_total_power(),
				"stamina_spent": RAID_JOIN_COST,
			})

			EventBus.raid_joined.emit(raid_id, GameData.player_id)
			return true
	return false


## Tarafsiz bolgeye baskin — aninda coz
func _resolve_raid_against_neutral(raid: Dictionary, territory_id: String) -> void:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr:
		territory_mgr.capture_territory(territory_id, raid["attacker_gang_id"])

	raid["resolved"] = true
	raid["result"] = "ATTACKER_WIN"
	raid["territory_changed"] = true

	# Respect odulu
	GameData.add_respect(50, "capture_neutral_territory")

	# Gang XP
	var gang_mgr: Node = get_node_or_null("/root/GangManager")
	if gang_mgr:
		gang_mgr.add_gang_xp(500)

	raid_resolved.emit(raid)
	EventBus.raid_resolved.emit(raid["raid_id"], "ATTACKER_WIN")
	raid_history.append(raid)


## Aktif baskinlari kontrol et ve cozumle
func _process_active_raids() -> void:
	var now := Time.get_unix_time_from_system()
	var to_resolve: Array = []

	for raid in active_raids:
		if not raid["resolved"] and now >= raid["resolves_at"]:
			to_resolve.append(raid)

	for raid in to_resolve:
		_resolve_raid(raid)
		active_raids.erase(raid)


## Baskin cozumle (PvP)
func _resolve_raid(raid: Dictionary) -> void:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")

	# Saldiri gucu
	var attack_power := 0
	for attacker in raid["attackers"]:
		attack_power += attacker["power_contribution"]

	var attacker_count: int = raid["attackers"].size()
	var morale_bonus: float = 1.0 + (attacker_count * MORALE_PER_MEMBER)
	attack_power = int(attack_power * morale_bonus)

	# Savunma gucu
	var defense_power := 0
	var target_id: String = raid["target_territory_id"]

	if territory_mgr:
		defense_power = territory_mgr.get_defense_power(target_id)

	# Savunan cete uyelerinin gucu (simule — multiplayer'da gercek veri)
	# Solo dev: NPC savunma gucu tier bazli (baslangic oyuncuyla alinabilir)
	var territory: Dictionary = territory_mgr.get_territory(target_id) if territory_mgr else {}
	var tier: int = territory.get("tier", 1)
	var npc_defense: int = NPC_DEFENSE_BY_TIER.get(tier, 150)
	defense_power += npc_defense

	# RNG
	if defense_power <= 0:
		defense_power = 1

	var power_ratio: float = float(attack_power) / float(defense_power)
	var rng_factor: float = randf_range(1.0 - RNG_VARIANCE, 1.0 + RNG_VARIANCE)
	var final_ratio: float = power_ratio * rng_factor

	# Sonuc
	var result: String
	if final_ratio >= WIN_THRESHOLD:
		result = "ATTACKER_WIN"
	elif final_ratio <= LOSE_THRESHOLD:
		result = "DEFENDER_WIN"
	else:
		result = "DRAW"

	raid["resolved"] = true
	raid["result"] = result

	# Sonuclari uygula
	match result:
		"ATTACKER_WIN":
			raid["territory_changed"] = true
			if territory_mgr:
				territory_mgr.capture_territory(target_id, raid["attacker_gang_id"])

			# Loot
			var income: int = territory.get("base_income", 100)
			raid["loot_stolen"] = income * LOOT_HOURS
			EconomyManager.add_cash(raid["loot_stolen"], "raid_loot")

			# Respect
			var war_respect := int(BASE_WAR_RESPECT * maxf(1.0, float(defense_power) / float(attack_power)))
			GameData.add_respect(war_respect, "raid_win")

			# Gang XP
			var gang_mgr: Node = get_node_or_null("/root/GangManager")
			if gang_mgr:
				gang_mgr.add_gang_xp(1000)

		"DEFENDER_WIN":
			raid["territory_changed"] = false
			# Kaybeden icin respect yok — stamina zaten kayip

		"DRAW":
			raid["territory_changed"] = false
			GameData.add_respect(int(BASE_WAR_RESPECT * 0.2), "raid_draw")

	raid_resolved.emit(raid)
	EventBus.raid_resolved.emit(raid["raid_id"], result)
	raid_history.append(raid)


## Cooldown kontrolu
func _is_territory_on_cooldown(territory_id: String) -> bool:
	for raid in raid_history:
		if raid["target_territory_id"] == territory_id:
			var time_since: float = Time.get_unix_time_from_system() - raid.get("resolves_at", 0)
			if time_since < RAID_COOLDOWN_HOURS * 3600:
				return true
	return false


## Aktif baskin var mi (bu bolge icin)
func get_active_raid_for_territory(territory_id: String) -> Dictionary:
	for raid in active_raids:
		if raid["target_territory_id"] == territory_id and not raid["resolved"]:
			return raid
	return {}


## Serialize
func serialize() -> Dictionary:
	return {
		"active_raids": active_raids.duplicate(true),
		"raid_history": raid_history.slice(maxi(0, raid_history.size() - 50)),  # Son 50
	}


func deserialize(data: Dictionary) -> void:
	active_raids.clear()
	for r in data.get("active_raids", []):
		active_raids.append(r)
	raid_history.clear()
	for r in data.get("raid_history", []):
		raid_history.append(r)
