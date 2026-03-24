## BuildingManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("build_test", "BuildTester")
	GameData.cash = 100000
	GameData.rank = 10
	GameData.gang_id = "test_gang"
	GameData.gang_role = "LEADER"
	BuildingManager.active_builds.clear()
	UnitManager.hired_units.clear()

	# Test bolgesi hazirla
	if TerritoryManager.territories.has("suburbs"):
		var t: Dictionary = TerritoryManager.territories["suburbs"]
		t["controlling_gang_id"] = "test_gang"
		t["control_strength"] = 1.0
		t["buildings"] = []


# === BUILD ===

func test_build_success() -> void:
	var result := BuildingManager.build("suburbs", "stash_house")
	assert_true(result["success"], "yeterli sartlarla insa basarili olmali")
	assert_true(result.has("building"))
	assert_true(result.has("finish_time"))


func test_build_deducts_cash() -> void:
	var before := GameData.cash
	BuildingManager.build("suburbs", "stash_house")
	assert_lt(GameData.cash, before, "cash azalmali")


func test_build_not_your_territory_fails() -> void:
	TerritoryManager.territories["suburbs"]["controlling_gang_id"] = "enemy_gang"
	var result := BuildingManager.build("suburbs", "stash_house")
	assert_false(result["success"], "baskasinin bolgesine insa edilemez")


func test_build_insufficient_rank_fails() -> void:
	GameData.rank = 0
	var result := BuildingManager.build("suburbs", "gun_store")  # required_rank: 5
	assert_false(result["success"], "rank yetersiz ise insa edilemez")


func test_build_slot_full_fails() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	var slots: int = t.get("building_slots", 2)
	for i in slots:
		t["buildings"].append({"building_id": "fill_%d" % i, "type": "type_%d" % i, "level": 1})
	var result := BuildingManager.build("suburbs", "stash_house")
	assert_false(result["success"], "slot dolu ise insa edilemez")


func test_build_duplicate_type_fails() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "existing", "type": "stash_house", "level": 1}]
	var result := BuildingManager.build("suburbs", "stash_house")
	assert_false(result["success"], "ayni tipten iki bina olmaz")


func test_build_unknown_type_fails() -> void:
	var result := BuildingManager.build("suburbs", "nonexistent_building")
	assert_false(result["success"])


func test_build_nonexistent_territory_fails() -> void:
	var result := BuildingManager.build("nonexistent", "stash_house")
	assert_false(result["success"])


func test_build_insufficient_cash_fails() -> void:
	GameData.cash = 10
	var result := BuildingManager.build("suburbs", "stash_house")
	assert_false(result["success"], "yetersiz cash ile insa edilemez")


func test_build_intelligence_reduces_time() -> void:
	GameData.intelligence = 20
	var result := BuildingManager.build("suburbs", "lookout")
	assert_true(result["success"])
	var now := Time.get_unix_time_from_system()
	var build_time: float = result["finish_time"] - now
	var base_time: float = BuildingManager.BUILDING_DEFS["lookout"]["build_time"][0]
	assert_lt(build_time, base_time, "intelligence insa suresini azaltmali")


# === UPGRADE ===

func test_upgrade_success() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "bld_1", "type": "stash_house", "level": 1}]
	var result := BuildingManager.upgrade("suburbs", "bld_1")
	assert_true(result["success"], "yukseltme basarili olmali")
	assert_eq(t["buildings"][0]["level"], 2)


func test_upgrade_max_level_fails() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "bld_max", "type": "stash_house", "level": 5}]
	var result := BuildingManager.upgrade("suburbs", "bld_max")
	assert_false(result["success"], "max seviyede yukseltme olmaz")


func test_upgrade_nonexistent_building_fails() -> void:
	var result := BuildingManager.upgrade("suburbs", "nonexistent_bld")
	assert_false(result["success"])


func test_upgrade_not_owned_territory_fails() -> void:
	TerritoryManager.territories["suburbs"]["controlling_gang_id"] = "enemy_gang"
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "bld_enemy", "type": "stash_house", "level": 1}]
	var result := BuildingManager.upgrade("suburbs", "bld_enemy")
	assert_false(result["success"], "sahip olunmayan bolgede yukseltme olmamali")


# === DEMOLISH ===

func test_demolish_success() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "bld_demo", "type": "stash_house", "level": 1}]
	var result := BuildingManager.demolish("suburbs", "bld_demo")
	assert_true(result, "yikma basarili olmali")
	assert_eq(t["buildings"].size(), 0, "bina listesi bos olmali")


func test_demolish_nonexistent_fails() -> void:
	var result := BuildingManager.demolish("suburbs", "nonexistent_bld")
	assert_false(result)


func test_demolish_not_owned_territory_fails() -> void:
	var t: Dictionary = TerritoryManager.territories["suburbs"]
	t["buildings"] = [{"building_id": "bld_enemy", "type": "stash_house", "level": 1}]
	t["controlling_gang_id"] = "enemy_gang"
	var result := BuildingManager.demolish("suburbs", "bld_enemy")
	assert_false(result, "sahip olunmayan bolgede yikim olmamali")


# === INCOME & DEFENSE ===

func test_building_income() -> void:
	var building := {"type": "stash_house", "level": 1}
	var income := BuildingManager.get_building_income(building)
	assert_eq(income, BuildingManager.BUILDING_DEFS["stash_house"]["income_per_hour"][0])


func test_building_income_level_3() -> void:
	var building := {"type": "crack_house", "level": 3}
	var income := BuildingManager.get_building_income(building)
	assert_eq(income, BuildingManager.BUILDING_DEFS["crack_house"]["income_per_hour"][2])


func test_building_income_with_influencer_bonus() -> void:
	UnitManager.hired_units = {"dark_web_influencer": 1}
	var building := {"type": "stash_house", "level": 1}
	var income := BuildingManager.get_building_income(building)
	assert_eq(income, 28, "20 * 1.4 influencer bonusu uygulanmali")


func test_building_defense() -> void:
	var building := {"type": "gun_store", "level": 1}
	var defense := BuildingManager.get_building_defense(building)
	assert_eq(defense, BuildingManager.BUILDING_DEFS["gun_store"]["defense_bonus"][0])


func test_building_defense_level_5() -> void:
	var building := {"type": "safe_house", "level": 5}
	var defense := BuildingManager.get_building_defense(building)
	assert_eq(defense, BuildingManager.BUILDING_DEFS["safe_house"]["defense_bonus"][4])


func test_income_building_has_no_defense() -> void:
	var building := {"type": "stash_house", "level": 1}
	var defense := BuildingManager.get_building_defense(building)
	assert_eq(defense, 0, "gelir binasinin savunmasi olmamali")
