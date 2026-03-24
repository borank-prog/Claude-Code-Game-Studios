## TerritoryManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("terr_test", "TerrTester")
	UnitManager.hired_units.clear()
	# Tum bolgeleri tarafsiza don
	for tid in TerritoryManager.territories:
		var t: Dictionary = TerritoryManager.territories[tid]
		t["controlling_gang_id"] = ""
		t["control_strength"] = 0.0
		t["contested"] = false
		t["buildings"] = []


# === TERRITORY DATA ===

func test_territories_loaded() -> void:
	assert_gt(TerritoryManager.territories.size(), 0, "bolgeler yuklu olmali")


func test_get_territory_valid() -> void:
	var t := TerritoryManager.get_territory("suburbs")
	assert_false(t.is_empty(), "suburbs mevcut olmali")
	assert_eq(t["territory_id"], "suburbs")


func test_get_territory_invalid() -> void:
	var t := TerritoryManager.get_territory("nonexistent")
	assert_true(t.is_empty(), "olmayan bolge bos dondur")


func test_get_all_territories() -> void:
	var all := TerritoryManager.get_all_territories()
	assert_gt(all.size(), 0)


# === ADJACENCY ===

func test_adjacent_territories() -> void:
	assert_true(TerritoryManager.are_adjacent("suburbs", "slums"), "suburbs-slums komsu olmali")
	assert_true(TerritoryManager.are_adjacent("suburbs", "industrial"), "suburbs-industrial komsu olmali")


func test_non_adjacent_territories() -> void:
	assert_false(TerritoryManager.are_adjacent("suburbs", "mansion"), "suburbs-mansion komsu olmamali")


func test_adjacency_unknown_territory() -> void:
	assert_false(TerritoryManager.are_adjacent("nonexistent", "suburbs"))


# === CAPTURE ===

func test_capture_neutral_territory() -> void:
	var result := TerritoryManager.capture_territory("suburbs", "gang_01")
	assert_true(result, "tarafsiz bolge ele gecirilmeli")
	var t := TerritoryManager.get_territory("suburbs")
	assert_eq(t["controlling_gang_id"], "gang_01")
	assert_almost_eq(t["control_strength"], TerritoryManager.INITIAL_CONTROL_STRENGTH, 0.01)


func test_capture_already_owned_fails() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var result := TerritoryManager.capture_territory("suburbs", "gang_01")
	assert_false(result, "zaten sahip olunan bolge tekrar ele gecirilememeli")


func test_capture_from_enemy() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var result := TerritoryManager.capture_territory("suburbs", "gang_02")
	assert_true(result, "dusman bolgesi ele gecirilmeli")
	assert_eq(TerritoryManager.get_territory("suburbs")["controlling_gang_id"], "gang_02")


func test_capture_clears_buildings() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	TerritoryManager.territories["suburbs"]["buildings"] = [{"type": "stash_house"}]
	TerritoryManager.capture_territory("suburbs", "gang_02")
	assert_eq(TerritoryManager.get_territory("suburbs")["buildings"].size(), 0, "ele gecirilince binalar yok olur")


func test_capture_nonexistent_fails() -> void:
	var result := TerritoryManager.capture_territory("nonexistent", "gang_01")
	assert_false(result)


# === NEUTRALIZE ===

func test_neutralize_territory() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	TerritoryManager.neutralize_territory("suburbs")
	var t := TerritoryManager.get_territory("suburbs")
	assert_eq(t["controlling_gang_id"], "", "tarafsiz olmali")
	assert_eq(t["control_strength"], 0.0)


# === TERRITORIES BY GANG ===

func test_get_territories_by_gang() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	TerritoryManager.capture_territory("slums", "gang_01")
	TerritoryManager.capture_territory("docks", "gang_02")
	var gang1 := TerritoryManager.get_territories_by_gang("gang_01")
	assert_eq(gang1.size(), 2, "gang_01'in 2 bolgesi olmali")


func test_get_territories_by_gang_empty() -> void:
	var result := TerritoryManager.get_territories_by_gang("nonexistent")
	assert_eq(result.size(), 0)


# === INCOME ===

func test_territory_income_with_control() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["control_strength"] = 1.0
	var income := TerritoryManager.get_territory_income("suburbs")
	assert_eq(income, t["base_income"], "full control'de base income donmeli")


func test_territory_income_partial_control() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["control_strength"] = 0.5
	var income := TerritoryManager.get_territory_income("suburbs")
	assert_eq(income, int(t["base_income"] * 0.5), "yarim kontrol = yarim gelir")


func test_territory_income_no_control() -> void:
	var income := TerritoryManager.get_territory_income("suburbs")
	assert_eq(income, 0, "kontrol yok = gelir yok")


func test_territory_income_includes_buildings() -> void:
	GameData.gang_id = "gang_01"
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["control_strength"] = 1.0
	t["buildings"] = [{"type": "stash_house", "level": 1}]
	var income := TerritoryManager.get_territory_income("suburbs")
	assert_eq(income, t["base_income"] + 20, "base income + bina geliri hesaplanmali")


func test_territory_income_buildings_scaled_by_influencer() -> void:
	GameData.gang_id = "gang_01"
	UnitManager.hired_units = {"dark_web_influencer": 1}
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["control_strength"] = 1.0
	t["buildings"] = [{"type": "stash_house", "level": 1}]
	var income := TerritoryManager.get_territory_income("suburbs")
	assert_eq(income, t["base_income"] + 28, "influencer ile bina geliri carpilmali")


# === DEFENSE ===

func test_defense_power_with_entrenchment() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["control_strength"] = 1.0
	var defense := TerritoryManager.get_defense_power("suburbs")
	assert_eq(defense, TerritoryManager.ENTRENCHMENT_BONUS, "full control = max entrenchment")


func test_defense_power_with_buildings() -> void:
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var t := TerritoryManager.get_territory("suburbs")
	t["buildings"] = [{"type": "gun_store", "defense_bonus": 200}]
	t["control_strength"] = 0.0
	var defense := TerritoryManager.get_defense_power("suburbs")
	assert_eq(defense, 200, "bina savunmasi eklenmeli")


# === MISSION BONUS ===

func test_mission_bonus_own_territory() -> void:
	GameData.gang_id = "gang_01"
	TerritoryManager.capture_territory("suburbs", "gang_01")
	var bonus := TerritoryManager.get_mission_bonus("suburbs")
	assert_gt(bonus, 1.0, "kendi bolgesinde bonus olmali")


func test_mission_bonus_enemy_territory() -> void:
	GameData.gang_id = "gang_01"
	TerritoryManager.capture_territory("suburbs", "gang_02")
	var bonus := TerritoryManager.get_mission_bonus("suburbs")
	assert_eq(bonus, 1.0, "dusman bolgesinde bonus olmamali")


func test_mission_bonus_neutral() -> void:
	var bonus := TerritoryManager.get_mission_bonus("suburbs")
	assert_eq(bonus, 1.0, "tarafsiz bolgede bonus olmamali")


# === TIERS ===

func test_tier_1_income_lower_than_tier_3() -> void:
	var t1 := TerritoryManager.get_territory("suburbs")
	var t3 := TerritoryManager.get_territory("downtown")
	assert_gt(t3["base_income"], t1["base_income"], "tier 3 geliri tier 1'den yuksek olmali")
