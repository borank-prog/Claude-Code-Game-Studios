## PlayerData (GameData) unit testleri.
extends GutTest

var gd: Node  # GameData referansi


func before_each() -> void:
	gd = GameData
	gd.initialize_new_player("test_player_01", "TestPlayer")


# === INITIALIZE ===

func test_initialize_sets_identity() -> void:
	assert_eq(gd.player_id, "test_player_01", "player_id dogru set edilmeli")
	assert_eq(gd.display_name, "TestPlayer", "display_name dogru set edilmeli")
	assert_eq(gd.avatar_id, 0, "avatar_id 0 olmali")
	assert_gt(gd.created_at, 0, "created_at timestamp olmali")


func test_initialize_sets_default_stats() -> void:
	assert_eq(gd.strength, GameData.INITIAL_STAT_VALUE, "strength baslangiC degeri")
	assert_eq(gd.endurance, GameData.INITIAL_STAT_VALUE, "endurance baslangic degeri")
	assert_eq(gd.charisma, GameData.INITIAL_STAT_VALUE, "charisma baslangic degeri")
	assert_eq(gd.luck, GameData.INITIAL_STAT_VALUE, "luck baslangic degeri")
	assert_eq(gd.intelligence, GameData.INITIAL_STAT_VALUE, "intelligence baslangic degeri")


func test_initialize_sets_economy_defaults() -> void:
	assert_eq(gd.cash, GameData.STARTING_CASH, "baslangic cash %d olmali" % GameData.STARTING_CASH)
	assert_eq(gd.premium_currency, 0, "baslangic premium 0 olmali")


func test_initialize_rank_zero() -> void:
	assert_eq(gd.rank, 0, "baslangic rank 0 olmali")
	assert_eq(gd.respect, 0, "baslangic respect 0 olmali")
	assert_eq(gd.unspent_stat_points, 0, "baslangic stat points 0 olmali")


func test_initialize_no_gang() -> void:
	assert_eq(gd.gang_id, "", "baslangicta gang_id bos olmali")
	assert_eq(gd.gang_role, "", "baslangicta gang_role bos olmali")


# === STAT ISLEMLERI ===

func test_get_stat_returns_correct_values() -> void:
	assert_eq(gd.get_stat("strength"), gd.strength)
	assert_eq(gd.get_stat("endurance"), gd.endurance)
	assert_eq(gd.get_stat("charisma"), gd.charisma)
	assert_eq(gd.get_stat("luck"), gd.luck)
	assert_eq(gd.get_stat("intelligence"), gd.intelligence)


func test_get_stat_unknown_returns_zero() -> void:
	assert_eq(gd.get_stat("nonexistent"), 0, "bilinmeyen stat 0 donmeli")


func test_apply_stat_delta_increases() -> void:
	var old := gd.strength
	var result := gd.apply_stat_delta("strength", 2)
	assert_true(result, "delta uygulanmali")
	assert_eq(gd.strength, old + 2, "strength 2 artmali")


func test_apply_stat_delta_clamped_to_cap() -> void:
	var cap := gd.get_stat_cap()
	gd.apply_stat_delta("strength", cap + 100)
	assert_eq(gd.strength, cap, "stat cap'i gecmemeli")


func test_apply_stat_delta_minimum_one() -> void:
	gd.apply_stat_delta("strength", -1000)
	assert_eq(gd.strength, 1, "stat 1'in altina dusmemeli")


func test_apply_stat_delta_no_change_returns_false() -> void:
	gd.strength = gd.get_stat_cap()
	var result := gd.apply_stat_delta("strength", 1)
	assert_false(result, "zaten cap'te ise false donmeli")


func test_spend_stat_point_success() -> void:
	gd.unspent_stat_points = 3
	var old_str := gd.strength
	var result := gd.spend_stat_point("strength")
	assert_true(result, "stat point harcanmali")
	assert_eq(gd.unspent_stat_points, 2, "1 point harcanmali")
	assert_eq(gd.strength, old_str + 1, "strength 1 artmali")


func test_spend_stat_point_no_points_fails() -> void:
	gd.unspent_stat_points = 0
	var result := gd.spend_stat_point("strength")
	assert_false(result, "point yoksa false donmeli")


func test_spend_stat_point_at_cap_fails() -> void:
	gd.unspent_stat_points = 5
	gd.strength = gd.get_stat_cap()
	var result := gd.spend_stat_point("strength")
	assert_false(result, "cap'te ise false donmeli")
	assert_eq(gd.unspent_stat_points, 5, "point harcanmamali")


func test_stat_cap_increases_with_rank() -> void:
	gd.rank = 0
	var cap0 := gd.get_stat_cap()
	gd.rank = 3
	var cap3 := gd.get_stat_cap()
	assert_gt(cap3, cap0, "rank artinca cap artmali")
	assert_eq(cap3, GameData.STAT_CAP_BASE + 3 * GameData.STAT_CAP_PER_RANK)


# === RANK & RESPECT ===

func test_rank_name_at_zero() -> void:
	gd.rank = 0
	assert_eq(gd.get_rank_name(), "Street Thug")


func test_rank_name_at_max() -> void:
	gd.rank = 19
	assert_eq(gd.get_rank_name(), "Kingpin")


func test_rank_name_beyond_max_clamps() -> void:
	gd.rank = 100
	assert_eq(gd.get_rank_name(), "Kingpin", "max rank'in ustunde clamp olmali")


func test_respect_for_rank_zero_is_zero() -> void:
	assert_eq(gd.get_respect_for_rank(0), 0)


func test_respect_for_rank_one() -> void:
	var expected := int(floor(GameData.BASE_RESPECT * pow(GameData.RESPECT_GROWTH, 0)))
	assert_eq(gd.get_respect_for_rank(1), expected)


func test_respect_curve_is_exponential() -> void:
	var r1 := gd.get_respect_for_rank(1)
	var r2 := gd.get_respect_for_rank(2)
	var r3 := gd.get_respect_for_rank(3)
	assert_gt(r2, r1, "rank 2 > rank 1 olmali")
	assert_gt(r3, r2, "rank 3 > rank 2 olmali")
	# Buyume orani ~1.8x olmali
	var ratio := float(r2) / float(r1)
	assert_almost_eq(ratio, GameData.RESPECT_GROWTH, 0.1, "buyume orani ~1.8 olmali")


func test_add_respect_increases() -> void:
	gd.respect = 0
	gd.add_respect(50, "test")
	assert_eq(gd.respect, 50)
	assert_eq(gd.season_respect, 50)


func test_add_respect_zero_ignored() -> void:
	gd.respect = 10
	gd.add_respect(0, "test")
	assert_eq(gd.respect, 10, "0 ekleme degistirmemeli")


func test_add_respect_negative_ignored() -> void:
	gd.respect = 10
	gd.add_respect(-5, "test")
	assert_eq(gd.respect, 10, "negatif ekleme degistirmemeli")


func test_rank_up_on_enough_respect() -> void:
	gd.rank = 0
	gd.respect = 0
	gd.unspent_stat_points = 0
	var needed := gd.get_respect_for_rank(1)
	gd.add_respect(needed, "test")
	assert_eq(gd.rank, 1, "yeterli respect ile rank artmali")
	assert_eq(gd.unspent_stat_points, GameData.STAT_POINTS_PER_RANK, "rank up stat point vermeli")


func test_multiple_rank_ups() -> void:
	gd.rank = 0
	gd.respect = 0
	gd.unspent_stat_points = 0
	var needed := gd.get_respect_for_rank(3) + 1
	gd.add_respect(needed, "test")
	assert_gte(gd.rank, 3, "yeterli respect ile 3+ rank atlamali")
	assert_eq(gd.unspent_stat_points, gd.rank * GameData.STAT_POINTS_PER_RANK)


# === POWER SCORE ===

func test_power_score_formula() -> void:
	gd.strength = 10
	gd.endurance = 8
	gd.charisma = 5
	gd.luck = 5
	gd.intelligence = 5
	var expected := (10 * 3) + (8 * 2) + 5 + 5 + 5  # 61
	assert_eq(gd.get_power_score(), expected, "power score formulu dogru olmali")


# === GANG ===

func test_set_gang() -> void:
	gd.set_gang("gang_01", "LEADER")
	assert_eq(gd.gang_id, "gang_01")
	assert_eq(gd.gang_role, "LEADER")


func test_leave_gang() -> void:
	gd.set_gang("gang_01", "MEMBER")
	gd.leave_gang()
	assert_eq(gd.gang_id, "", "gang_id temizlenmeli")
	assert_eq(gd.gang_role, "", "gang_role temizlenmeli")


# === SERIALIZE / DESERIALIZE ===

func test_serialize_roundtrip() -> void:
	gd.initialize_new_player("rt_test", "RoundTrip")
	gd.rank = 5
	gd.respect = 999
	gd.strength = 15
	gd.cash = 9999
	gd.premium_currency = 50
	gd.set_gang("g1", "OFFICER")

	var data := gd.serialize()
	gd.initialize_new_player("reset", "Reset")  # Sifirla

	gd.deserialize(data)

	assert_eq(gd.player_id, "rt_test")
	assert_eq(gd.display_name, "RoundTrip")
	assert_eq(gd.rank, 5)
	assert_eq(gd.respect, 999)
	assert_eq(gd.strength, 15)
	assert_eq(gd.cash, 9999)
	assert_eq(gd.premium_currency, 50)
	assert_eq(gd.gang_id, "g1")
	assert_eq(gd.gang_role, "OFFICER")


func test_deserialize_missing_fields_uses_defaults() -> void:
	gd.deserialize({})
	assert_eq(gd.player_id, "", "eksik alan default olmali")
	assert_eq(gd.strength, GameData.INITIAL_STAT_VALUE, "eksik stat default olmali")
	assert_eq(gd.cash, GameData.STARTING_CASH, "eksik cash default olmali")
