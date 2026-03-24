## GangWarManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("war_test", "WarTester")
	GameData.cash = 100000
	GameData.rank = 10
	GameData.gang_id = "attacker_gang"
	GameData.gang_role = "LEADER"
	StaminaManager.recalculate_max()
	StaminaManager.current = StaminaManager.max_stamina
	GangWarManager.active_raids.clear()
	GangWarManager.raid_history.clear()
	UnitManager.hired_units.clear()
	GangManager.is_in_gang = true
	GangManager.current_gang = {
		"gang_id": "attacker_gang", "name": "Attackers",
		"members": [{"player_id": "war_test", "role": "LEADER", "joined_at": 0, "contribution": 0}],
		"controlled_territories": [],
	}

	# Bolgeleri hazirla
	for tid in TerritoryManager.territories:
		var t: Dictionary = TerritoryManager.territories[tid]
		t["controlling_gang_id"] = ""
		t["control_strength"] = 0.0
		t["buildings"] = []


# === DECLARE RAID ===

func test_declare_raid_neutral_instant() -> void:
	var result := GangWarManager.declare_raid("suburbs")
	assert_true(result["success"], "tarafsiz bolgeye baskin basarili olmali")
	assert_true(result.get("instant", false), "tarafsiz bolge aninda cozulmeli")


func test_declare_raid_captures_neutral() -> void:
	GangWarManager.declare_raid("suburbs")
	var t := TerritoryManager.get_territory("suburbs")
	assert_eq(t["controlling_gang_id"], "attacker_gang", "bolge ele gecirilmeli")


func test_declare_raid_enemy_not_instant() -> void:
	TerritoryManager.capture_territory("suburbs", "defender_gang")
	# Komsuluk icin bir bolge al
	TerritoryManager.capture_territory("slums", "attacker_gang")
	var result := GangWarManager.declare_raid("suburbs")
	assert_true(result["success"])
	assert_false(result.get("instant", false), "dusman bolge aninda cozulmemeli")


func test_declare_raid_spends_stamina() -> void:
	var before := StaminaManager.current
	GangWarManager.declare_raid("suburbs")
	assert_lt(StaminaManager.current, before, "stamina harcanmali")


func test_declare_raid_not_in_gang_fails() -> void:
	GangManager.is_in_gang = false
	var result := GangWarManager.declare_raid("suburbs")
	assert_false(result["success"])


func test_declare_raid_own_territory_fails() -> void:
	TerritoryManager.capture_territory("suburbs", "attacker_gang")
	var result := GangWarManager.declare_raid("suburbs")
	assert_false(result["success"], "kendi bolgesine saldiramaz")


func test_declare_raid_no_adjacent_fails() -> void:
	TerritoryManager.capture_territory("mansion", "defender_gang")
	# attacker_gang'in bolge yok, mansion komsusu yok
	var result := GangWarManager.declare_raid("mansion")
	# mansion dusman bolgesi ama komsuluk yok
	assert_false(result["success"], "komsu bolge olmadan saldiramaz")


func test_declare_raid_insufficient_stamina_fails() -> void:
	StaminaManager.current = 1
	var result := GangWarManager.declare_raid("suburbs")
	assert_false(result["success"])


func test_declare_raid_insufficient_permission_fails() -> void:
	GameData.gang_role = "MEMBER"
	var result := GangWarManager.declare_raid("suburbs")
	assert_false(result["success"], "member baskin ilan edemez")


# === JOIN RAID ===

func test_join_raid_success() -> void:
	TerritoryManager.capture_territory("suburbs", "defender_gang")
	TerritoryManager.capture_territory("slums", "attacker_gang")
	var result := GangWarManager.declare_raid("suburbs")
	var raid_id: String = result["raid"]["raid_id"]
	var joined := GangWarManager.join_raid(raid_id)
	assert_true(joined, "baskina katilinabilmeli")


func test_join_raid_twice_fails() -> void:
	TerritoryManager.capture_territory("suburbs", "defender_gang")
	TerritoryManager.capture_territory("slums", "attacker_gang")
	var result := GangWarManager.declare_raid("suburbs")
	var raid_id: String = result["raid"]["raid_id"]
	assert_false(GangWarManager.join_raid(raid_id), "ayni oyuncu ikinci kez katilamamali")


func test_join_nonexistent_raid_fails() -> void:
	var result := GangWarManager.join_raid("nonexistent_raid")
	assert_false(result)


func test_raid_enemy_defense_multiplier_default() -> void:
	assert_eq(GangWarManager._get_raid_enemy_defense_multiplier(), 1.0)


func test_raid_enemy_defense_multiplier_with_drone_operator() -> void:
	UnitManager.hired_units = {"drone_operator": 1}
	assert_eq(GangWarManager._get_raid_enemy_defense_multiplier(), 0.9)


# === COOLDOWN ===

func test_territory_cooldown_after_raid() -> void:
	GangWarManager.declare_raid("suburbs")  # Tarafsiz, aninda cozulur
	# Simdi suburbs icin cooldown olmali
	var on_cd := GangWarManager._is_territory_on_cooldown("suburbs")
	assert_true(on_cd, "baskin sonrasi cooldown olmali")


func test_no_cooldown_fresh_territory() -> void:
	var on_cd := GangWarManager._is_territory_on_cooldown("suburbs")
	assert_false(on_cd, "baskin yapilmamis bolge cooldown'da olmamali")


# === ACTIVE RAIDS ===

func test_get_active_raid_exists() -> void:
	TerritoryManager.capture_territory("suburbs", "defender_gang")
	TerritoryManager.capture_territory("slums", "attacker_gang")
	GangWarManager.declare_raid("suburbs")
	var raid := GangWarManager.get_active_raid_for_territory("suburbs")
	assert_false(raid.is_empty(), "aktif baskin olmali")


func test_get_active_raid_empty() -> void:
	var raid := GangWarManager.get_active_raid_for_territory("suburbs")
	assert_true(raid.is_empty(), "aktif baskin olmamali")


# === SERIALIZE ===

func test_serialize_roundtrip() -> void:
	GangWarManager.declare_raid("suburbs")
	var data := GangWarManager.serialize()
	GangWarManager.active_raids.clear()
	GangWarManager.raid_history.clear()
	GangWarManager.deserialize(data)
	assert_gt(GangWarManager.raid_history.size(), 0, "history korunmali")
