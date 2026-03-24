## StaminaManager unit testleri.
extends GutTest

var sm: Node  # StaminaManager referansi


func before_each() -> void:
	sm = StaminaManager
	GameData.initialize_new_player("stam_test", "StamTester")
	UnitManager.hired_units.clear()
	sm.recalculate_max()
	sm.current = sm.max_stamina
	sm.last_regen_time = Time.get_unix_time_from_system()


# === MAX STAMINA ===

func test_max_stamina_base() -> void:
	GameData.endurance = 0
	sm.recalculate_max()
	assert_eq(sm.max_stamina, StaminaManager.BASE_STAMINA, "endurance 0 iken base stamina")


func test_max_stamina_with_endurance() -> void:
	GameData.endurance = 10
	sm.recalculate_max()
	var expected := StaminaManager.BASE_STAMINA + (10 * StaminaManager.STAMINA_PER_ENDURANCE)
	assert_eq(sm.max_stamina, expected, "endurance max stamina'yi artirmali")


func test_max_stamina_default_endurance() -> void:
	# initialize_new_player endurance = 5 yapar
	var expected := StaminaManager.BASE_STAMINA + (GameData.INITIAL_STAT_VALUE * StaminaManager.STAMINA_PER_ENDURANCE)
	assert_eq(sm.max_stamina, expected)


# === SPEND ===

func test_spend_success() -> void:
	sm.current = 50
	var result := sm.spend(10)
	assert_true(result, "yeterli stamina ile true donmeli")
	assert_eq(sm.current, 40, "10 harcanmali")


func test_spend_insufficient_fails() -> void:
	sm.current = 5
	var result := sm.spend(10)
	assert_false(result, "yetersiz stamina ile false donmeli")
	assert_eq(sm.current, 5, "stamina degismemeli")


func test_spend_exact_amount() -> void:
	sm.current = 15
	var result := sm.spend(15)
	assert_true(result)
	assert_eq(sm.current, 0, "tam tutar harcanabilmeli")


func test_spend_zero_fails() -> void:
	sm.current = 50
	var result := sm.spend(0)
	assert_false(result, "0 harcama false donmeli")


func test_spend_negative_fails() -> void:
	sm.current = 50
	var result := sm.spend(-5)
	assert_false(result, "negatif harcama false donmeli")


# === FULL REFILL ===

func test_full_refill_restores_max() -> void:
	sm.current = 10
	sm.full_refill()
	assert_eq(sm.current, sm.max_stamina, "full refill max'a getirmeli")


func test_full_refill_resets_regen_time() -> void:
	sm.last_regen_time = 0.0
	sm.full_refill()
	var now := Time.get_unix_time_from_system()
	assert_almost_eq(sm.last_regen_time, now, 2.0, "regen time sifirlanmali")


# === LAZY REGEN ===

func test_regen_when_below_max() -> void:
	sm.current = sm.max_stamina - 5
	# Regen zamanini 3 interval oncesine ayarla
	sm.last_regen_time = Time.get_unix_time_from_system() - (StaminaManager.REGEN_INTERVAL * 3)
	sm._update_regen()
	assert_eq(sm.current, sm.max_stamina - 2, "3 regen puani gelmeli (5-3=2 eksik)")


func test_regen_capped_at_max() -> void:
	sm.current = sm.max_stamina - 1
	sm.last_regen_time = Time.get_unix_time_from_system() - (StaminaManager.REGEN_INTERVAL * 10)
	sm._update_regen()
	assert_eq(sm.current, sm.max_stamina, "max'i gecmemeli")


func test_no_regen_when_full() -> void:
	sm.current = sm.max_stamina
	var old_time := sm.last_regen_time
	sm._update_regen()
	assert_eq(sm.current, sm.max_stamina, "zaten max ise degismemeli")


func test_regen_partial_interval_no_gain() -> void:
	sm.current = sm.max_stamina - 5
	sm.last_regen_time = Time.get_unix_time_from_system() - (StaminaManager.REGEN_INTERVAL * 0.5)
	sm._update_regen()
	assert_eq(sm.current, sm.max_stamina - 5, "yarim interval'de regen olmamali")


func test_regen_interval_reduced_by_chemist() -> void:
	UnitManager.hired_units = {"chemist": 1}
	assert_eq(sm._get_regen_interval(), StaminaManager.REGEN_INTERVAL * 0.6)


# === REGEN TIMER ===

func test_get_regen_remaining_when_full() -> void:
	sm.current = sm.max_stamina
	assert_eq(sm.get_regen_remaining(), 0.0, "max iken 0 donmeli")


func test_get_regen_remaining_when_below() -> void:
	sm.current = sm.max_stamina - 1
	sm.last_regen_time = Time.get_unix_time_from_system() - 30.0
	var remaining := sm.get_regen_remaining()
	assert_almost_eq(remaining, StaminaManager.REGEN_INTERVAL - 30.0, 2.0, "kalan sure dogru olmali")


func test_get_full_regen_remaining_when_full() -> void:
	sm.current = sm.max_stamina
	assert_eq(sm.get_full_regen_remaining(), 0.0)


func test_get_full_regen_remaining_deficit() -> void:
	sm.current = sm.max_stamina - 3
	sm.last_regen_time = Time.get_unix_time_from_system()
	var expected := StaminaManager.REGEN_INTERVAL + 2 * StaminaManager.REGEN_INTERVAL  # 3 interval
	assert_almost_eq(sm.get_full_regen_remaining(), expected, 2.0, "3 puan icin 3 interval")


# === SERIALIZE / DESERIALIZE ===

func test_serialize_roundtrip() -> void:
	sm.current = 42
	sm.max_stamina = 120
	sm.last_regen_time = 1000000.0

	var data := sm.serialize()
	sm.current = 0
	sm.max_stamina = 0
	sm.last_regen_time = 0.0

	sm.deserialize(data)
	assert_eq(sm.current, 42)
	assert_eq(sm.max_stamina, 120)
	assert_almost_eq(sm.last_regen_time, 1000000.0, 1.0)


func test_deserialize_missing_fields_uses_defaults() -> void:
	var old_max := sm.max_stamina
	sm.deserialize({})
	assert_eq(sm.current, old_max, "eksik current default max olmali")
	assert_eq(sm.max_stamina, StaminaManager.BASE_STAMINA, "eksik max default base olmali")
