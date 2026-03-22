## Cete sistemi — olusturma, davet, uye yonetimi, kasa, level.
extends Node

signal gang_created(gang_data: Dictionary)
signal gang_joined(gang_data: Dictionary)
signal gang_left()
signal gang_updated()
signal member_joined(player_id: String)
signal member_left(player_id: String)

var current_gang: Dictionary = {}
var is_in_gang: bool = false

const GANG_CREATION_COST: int = 5000
const GANG_BASE_MEMBERS: int = 10
const MEMBERS_PER_LEVEL: int = 2
const GANG_MAX_MEMBERS: int = 50
const GANG_BASE_XP: float = 500.0
const GANG_XP_GROWTH: float = 1.6
const GANG_TREASURY_DAILY_WITHDRAW_PERCENT: float = 20.0
const LEADER_INACTIVITY_DAYS: int = 7


func _ready() -> void:
	pass


## Cete olustur
func create_gang(name: String, tag: String) -> bool:
	# Maliyet kontrolu
	if not EconomyManager.spend_cash(GANG_CREATION_COST, "gang_creation"):
		return false

	current_gang = {
		"gang_id": _generate_id(),
		"name": name,
		"tag": tag,
		"emblem_id": 0,
		"created_at": Time.get_unix_time_from_system(),
		"gang_level": 1,
		"gang_xp": 0,
		"treasury": 0,
		"join_policy": "INVITE_ONLY",
		"min_rank_to_join": 0,
		"members": [
			{
				"player_id": GameData.player_id,
				"role": "LEADER",
				"joined_at": Time.get_unix_time_from_system(),
				"contribution": 0,
			}
		],
		"controlled_territories": [],
	}

	GameData.set_gang(current_gang["gang_id"], "LEADER")
	is_in_gang = true

	gang_created.emit(current_gang)
	EventBus.gang_created.emit(current_gang["gang_id"])
	return true


## Ceteye katil (basitlesti — multiplayer'da server-side olacak)
func join_gang(gang_data: Dictionary) -> bool:
	current_gang = gang_data
	current_gang["members"].append({
		"player_id": GameData.player_id,
		"role": "MEMBER",
		"joined_at": Time.get_unix_time_from_system(),
		"contribution": 0,
	})

	GameData.set_gang(gang_data["gang_id"], "MEMBER")
	is_in_gang = true

	gang_joined.emit(current_gang)
	EventBus.gang_joined.emit(current_gang["gang_id"])
	return true


## Ceteden ayril
func leave_gang() -> void:
	if not is_in_gang:
		return

	var was_leader := GameData.gang_role == "LEADER"

	# Uyeyi cikar
	current_gang["members"] = current_gang["members"].filter(
		func(m): return m["player_id"] != GameData.player_id
	)

	# Lider ayrildi — devret
	if was_leader and current_gang["members"].size() > 0:
		_auto_promote_leader()

	# Son uye ayrildi — cete dagil
	if current_gang["members"].size() == 0:
		_disband()
	else:
		gang_updated.emit()

	GameData.leave_gang()
	is_in_gang = false
	current_gang = {}
	gang_left.emit()
	EventBus.gang_left.emit()


## Uye at (leader/officer yetkisi)
func kick_member(player_id: String) -> bool:
	if not _has_permission("kick"):
		return false
	if player_id == GameData.player_id:
		return false

	current_gang["members"] = current_gang["members"].filter(
		func(m): return m["player_id"] != player_id
	)
	member_left.emit(player_id)
	EventBus.gang_member_left.emit(player_id)
	gang_updated.emit()
	return true


## Officer ata (sadece leader)
func promote_to_officer(player_id: String) -> bool:
	if GameData.gang_role != "LEADER":
		return false

	for m in current_gang["members"]:
		if m["player_id"] == player_id:
			m["role"] = "OFFICER"
			gang_updated.emit()
			return true
	return false


## Kasaya katki
func contribute_to_treasury(amount: int) -> bool:
	if not is_in_gang:
		return false
	if not EconomyManager.spend_cash(amount, "gang_treasury_contribute"):
		return false

	current_gang["treasury"] = current_gang.get("treasury", 0) + amount
	_add_member_contribution(GameData.player_id, amount)
	gang_updated.emit()
	return true


## Kasadan cekim (leader/officer, gunluk limitli)
func withdraw_from_treasury(amount: int) -> bool:
	if not _has_permission("withdraw"):
		return false

	var treasury: int = current_gang.get("treasury", 0)
	var daily_limit := int(treasury * GANG_TREASURY_DAILY_WITHDRAW_PERCENT / 100.0)
	var actual := mini(amount, mini(daily_limit, treasury))

	if actual <= 0:
		return false

	current_gang["treasury"] -= actual
	EconomyManager.add_cash(actual, "gang_treasury_withdraw")
	gang_updated.emit()
	return true


## Cete XP ekle (gorev, savas, bolge)
func add_gang_xp(amount: int) -> void:
	if not is_in_gang:
		return

	current_gang["gang_xp"] = current_gang.get("gang_xp", 0) + amount
	_check_level_up()
	gang_updated.emit()


## Max uye sayisi
func get_max_members() -> int:
	var level: int = current_gang.get("gang_level", 1)
	return mini(GANG_BASE_MEMBERS + (level * MEMBERS_PER_LEVEL), GANG_MAX_MEMBERS)


## Uye sayisi
func get_member_count() -> int:
	return current_gang.get("members", []).size()


## Cete toplam gucu
func get_total_power() -> int:
	# Solo dev'de sadece mevcut oyuncunun gucu — multiplayer'da tum uyeler
	return InventoryManager.get_total_power()


## Level icin gereken XP
func get_xp_for_level(level: int) -> int:
	return int(floor(GANG_BASE_XP * pow(GANG_XP_GROWTH, level - 1)))


## Level up kontrolu
func _check_level_up() -> void:
	var level: int = current_gang.get("gang_level", 1)
	var xp: int = current_gang.get("gang_xp", 0)
	var required := get_xp_for_level(level + 1)

	while xp >= required and level < 20:
		level += 1
		required = get_xp_for_level(level + 1)

	if level != current_gang.get("gang_level", 1):
		current_gang["gang_level"] = level


## Yetki kontrolu
func _has_permission(action: String) -> bool:
	match action:
		"kick", "invite", "war_declare":
			return GameData.gang_role in ["LEADER", "OFFICER"]
		"withdraw":
			return GameData.gang_role in ["LEADER", "OFFICER"]
		"settings", "promote", "disband":
			return GameData.gang_role == "LEADER"
		_:
			return true


## Otomatik lider atama
func _auto_promote_leader() -> void:
	# En yuksek katkili officer'i sec, yoksa en yuksek katkili member'i
	var best: Dictionary = {}
	var best_contribution := -1

	for m in current_gang["members"]:
		if m.get("contribution", 0) > best_contribution:
			best = m
			best_contribution = m.get("contribution", 0)

	if not best.is_empty():
		best["role"] = "LEADER"


## Ceteyi dagit
func _disband() -> void:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	if territory_mgr:
		for tid in current_gang.get("controlled_territories", []):
			territory_mgr.neutralize_territory(tid)
	current_gang = {}


## Uye katkisini artir
func _add_member_contribution(player_id: String, amount: int) -> void:
	for m in current_gang["members"]:
		if m["player_id"] == player_id:
			m["contribution"] = m.get("contribution", 0) + amount
			return


## Benzersiz ID olustur
func _generate_id() -> String:
	return "gang_%d_%d" % [Time.get_unix_time_from_system(), randi()]


## Serialize
func serialize() -> Dictionary:
	return {
		"current_gang": current_gang.duplicate(true),
		"is_in_gang": is_in_gang,
	}


func deserialize(data: Dictionary) -> void:
	current_gang = data.get("current_gang", {})
	is_in_gang = data.get("is_in_gang", false)
