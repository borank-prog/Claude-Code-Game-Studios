## MissionSystem unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("mission_test", "MissionTester")
	StaminaManager.recalculate_max()
	StaminaManager.current = StaminaManager.max_stamina
	MissionSystem.cooldowns.clear()
	MissionSystem._is_running = false
	MissionSystem._current_mission = {}


# === BASARI ORANI ===

func test_success_rate_clamped_min() -> void:
	var mission := {"base_success_rate": 0.0, "stat_influence": {}}
	var rate := MissionSystem.calculate_success_rate(mission)
	assert_gte(rate, MissionSystem.MIN_SUCCESS_RATE, "rate %f'den dusuk olmamali" % MissionSystem.MIN_SUCCESS_RATE)


func test_success_rate_clamped_max() -> void:
	var mission := {"base_success_rate": 5.0, "stat_influence": {}}
	var rate := MissionSystem.calculate_success_rate(mission)
	assert_lte(rate, MissionSystem.MAX_SUCCESS_RATE, "rate %f'den yuksek olmamali" % MissionSystem.MAX_SUCCESS_RATE)


func test_success_rate_base_only() -> void:
	var mission := {"base_success_rate": 0.5, "stat_influence": {}}
	var rate := MissionSystem.calculate_success_rate(mission)
	assert_almost_eq(rate, 0.5, 0.01, "stat yok ise base rate donmeli")


func test_success_rate_with_stat_influence() -> void:
	GameData.strength = 20
	var mission := {"base_success_rate": 0.3, "stat_influence": {"strength": 0.02}}
	var rate := MissionSystem.calculate_success_rate(mission)
	var expected := clampf(0.3 + 20 * 0.02, 0.05, 0.95)
	assert_almost_eq(rate, expected, 0.01, "stat influence rate'i artirmali")


# === GOREV BASLAMA ===

func test_start_mission_spends_stamina() -> void:
	# Manuel gorev ekle
	var mission := _test_mission()
	MissionSystem.all_missions = [mission]

	var before := StaminaManager.current
	MissionSystem.start_mission("test_m")
	assert_eq(StaminaManager.current, before - mission["stamina_cost"], "stamina harcanmali")


func test_start_mission_fails_insufficient_stamina() -> void:
	StaminaManager.current = 1
	var mission := _test_mission({"stamina_cost": 10})
	MissionSystem.all_missions = [mission]
	var result := MissionSystem.start_mission("test_m")
	assert_false(result, "yetersiz stamina ile false donmeli")


func test_start_mission_fails_insufficient_rank() -> void:
	GameData.rank = 0
	var mission := _test_mission({"required_rank": 5})
	MissionSystem.all_missions = [mission]
	var result := MissionSystem.start_mission("test_m")
	assert_false(result, "yetersiz rank ile false donmeli")


func test_start_mission_fails_on_cooldown() -> void:
	var mission := _test_mission()
	MissionSystem.all_missions = [mission]
	MissionSystem.cooldowns["test_m"] = Time.get_unix_time_from_system() + 999.0
	var result := MissionSystem.start_mission("test_m")
	assert_false(result, "cooldown'da iken false donmeli")


func test_start_mission_fails_when_already_running() -> void:
	var mission := _test_mission()
	MissionSystem.all_missions = [mission]
	MissionSystem._is_running = true
	var result := MissionSystem.start_mission("test_m")
	assert_false(result, "zaten calisiyorken false donmeli")


func test_start_mission_sets_running() -> void:
	var mission := _test_mission()
	MissionSystem.all_missions = [mission]
	MissionSystem.start_mission("test_m")
	assert_true(MissionSystem.is_running(), "is_running true olmali")


func test_start_mission_fails_stat_requirement() -> void:
	GameData.strength = 3
	var mission := _test_mission({"required_stats": {"strength": 10}})
	MissionSystem.all_missions = [mission]
	var result := MissionSystem.start_mission("test_m")
	assert_false(result, "stat yetersiz ise false donmeli")


# === COOLDOWN ===

func test_cooldown_expired() -> void:
	MissionSystem.cooldowns["test_m"] = Time.get_unix_time_from_system() - 10.0
	var remaining := MissionSystem.get_cooldown_remaining("test_m")
	assert_eq(remaining, 0.0, "suresi dolmus cooldown 0 donmeli")


func test_cooldown_active() -> void:
	MissionSystem.cooldowns["test_m"] = Time.get_unix_time_from_system() + 300.0
	var remaining := MissionSystem.get_cooldown_remaining("test_m")
	assert_gt(remaining, 0.0, "aktif cooldown > 0 olmali")


func test_no_cooldown() -> void:
	assert_eq(MissionSystem.get_cooldown_remaining("nonexistent"), 0.0)


# === PROGRESS ===

func test_progress_not_running() -> void:
	MissionSystem._is_running = false
	assert_eq(MissionSystem.get_progress(), 0.0)


func test_progress_midway() -> void:
	MissionSystem._is_running = true
	MissionSystem._current_mission = {"duration_seconds": 10.0}
	MissionSystem._mission_timer = 5.0
	assert_almost_eq(MissionSystem.get_progress(), 0.5, 0.01)


# === ZORLUK CARPANI ===

func test_difficulty_multiplier_easy() -> void:
	assert_eq(MissionSystem._get_difficulty_multiplier("EASY"), 1.0)


func test_difficulty_multiplier_extreme() -> void:
	assert_eq(MissionSystem._get_difficulty_multiplier("EXTREME"), 4.0)


func test_difficulty_multiplier_unknown() -> void:
	assert_eq(MissionSystem._get_difficulty_multiplier("INVALID"), 1.0)


# === HELPER ===

func _test_mission(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"mission_id": "test_m",
		"name": "Test Mission",
		"category": "ROBBERY",
		"difficulty": "EASY",
		"required_rank": 0,
		"required_stats": {},
		"stamina_cost": 5,
		"duration_seconds": 5.0,
		"base_success_rate": 0.5,
		"stat_influence": {},
		"cash_reward_min": 50,
		"cash_reward_max": 150,
		"respect_reward": 10,
		"cooldown_seconds": 0,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base
