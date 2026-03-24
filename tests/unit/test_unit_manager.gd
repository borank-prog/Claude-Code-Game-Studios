## UnitManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("unit_test", "UnitTester")
	GameData.cash = 100000
	GameData.rank = 20
	UnitManager.hired_units.clear()


func test_hire_unit_success() -> void:
	var result := UnitManager.hire_unit("crypto_launderer")
	assert_true(result.get("success", false), "unit kiralanabilmeli")
	assert_true(UnitManager.has_unit("crypto_launderer"))


func test_hire_unit_twice_fails() -> void:
	assert_true(UnitManager.hire_unit("chemist").get("success", false))
	var second := UnitManager.hire_unit("chemist")
	assert_false(second.get("success", false), "tekil unit ikinci kez alinmamali")


func test_effect_multiplier_reads_owned_unit() -> void:
	UnitManager.hired_units = {"drone_operator": 1}
	assert_eq(UnitManager.get_effect_multiplier("raid_enemy_defense_multiplier"), 0.9)


func test_effect_additive_reads_owned_unit() -> void:
	UnitManager.hired_units = {"the_cleaner": 1}
	assert_eq(UnitManager.get_effect_additive("vip_success_add"), 0.12)


func test_serialize_roundtrip() -> void:
	UnitManager.hired_units = {"chemist": 1, "drone_operator": 1}
	var data := UnitManager.serialize()
	UnitManager.hired_units.clear()
	UnitManager.deserialize(data)
	assert_true(UnitManager.has_unit("chemist"))
	assert_true(UnitManager.has_unit("drone_operator"))
