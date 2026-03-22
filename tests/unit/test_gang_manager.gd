## GangManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("gang_test", "GangTester")
	GameData.cash = 50000
	GangManager.current_gang = {}
	GangManager.is_in_gang = false
	EconomyManager.transaction_log.clear()


# === CREATE ===

func test_create_gang_success() -> void:
	var result := GangManager.create_gang("TestGang", "TG")
	assert_true(result, "yeterli cash ile cete olusturulabilmeli")
	assert_true(GangManager.is_in_gang, "is_in_gang true olmali")
	assert_eq(GameData.gang_role, "LEADER", "kurucu LEADER olmali")
	assert_eq(GangManager.current_gang["name"], "TestGang")


func test_create_gang_insufficient_cash_fails() -> void:
	GameData.cash = 100
	var result := GangManager.create_gang("PoorGang", "PG")
	assert_false(result, "yetersiz cash ile olusturulamaz")
	assert_false(GangManager.is_in_gang)


func test_create_gang_deducts_cash() -> void:
	var before := GameData.cash
	GangManager.create_gang("CashGang", "CG")
	assert_eq(GameData.cash, before - GangManager.GANG_CREATION_COST)


func test_create_gang_has_one_member() -> void:
	GangManager.create_gang("OneGang", "OG")
	assert_eq(GangManager.get_member_count(), 1, "kurucu tek uye olmali")


# === JOIN ===

func test_join_gang() -> void:
	var gang_data := _make_gang()
	GangManager.join_gang(gang_data)
	assert_true(GangManager.is_in_gang)
	assert_eq(GameData.gang_role, "MEMBER")


# === LEAVE ===

func test_leave_gang() -> void:
	GangManager.create_gang("LeaveGang", "LG")
	GangManager.leave_gang()
	assert_false(GangManager.is_in_gang, "is_in_gang false olmali")
	assert_eq(GameData.gang_id, "", "gang_id temizlenmeli")
	assert_eq(GameData.gang_role, "", "gang_role temizlenmeli")


func test_leave_not_in_gang_noop() -> void:
	GangManager.leave_gang()
	assert_false(GangManager.is_in_gang, "zaten cetede degilken degismemeli")


# === KICK ===

func test_kick_member_as_leader() -> void:
	GangManager.create_gang("KickGang", "KG")
	# Sahte uye ekle
	GangManager.current_gang["members"].append({
		"player_id": "victim_01", "role": "MEMBER",
		"joined_at": 0, "contribution": 0,
	})
	var result := GangManager.kick_member("victim_01")
	assert_true(result, "leader uyeyi atabilmeli")
	assert_eq(GangManager.get_member_count(), 1, "1 uye kalmali")


func test_kick_self_fails() -> void:
	GangManager.create_gang("SelfKick", "SK")
	var result := GangManager.kick_member(GameData.player_id)
	assert_false(result, "kendini atamaz")


# === PROMOTE ===

func test_promote_to_officer() -> void:
	GangManager.create_gang("PromoGang", "PG")
	GangManager.current_gang["members"].append({
		"player_id": "promo_01", "role": "MEMBER",
		"joined_at": 0, "contribution": 0,
	})
	var result := GangManager.promote_to_officer("promo_01")
	assert_true(result, "leader officer atayabilmeli")
	var member := GangManager.current_gang["members"][1]
	assert_eq(member["role"], "OFFICER")


func test_promote_as_member_fails() -> void:
	var gang_data := _make_gang()
	GangManager.join_gang(gang_data)
	var result := GangManager.promote_to_officer("someone")
	assert_false(result, "member officer atayamaz")


# === TREASURY ===

func test_contribute_to_treasury() -> void:
	GangManager.create_gang("Treasury", "TR")
	var result := GangManager.contribute_to_treasury(1000)
	assert_true(result)
	assert_eq(GangManager.current_gang["treasury"], 1000)


func test_contribute_not_in_gang_fails() -> void:
	var result := GangManager.contribute_to_treasury(1000)
	assert_false(result, "cetede degilken katki yapilamaz")


func test_withdraw_from_treasury() -> void:
	GangManager.create_gang("Withdraw", "WD")
	GangManager.current_gang["treasury"] = 10000
	var before := GameData.cash
	var result := GangManager.withdraw_from_treasury(1000)
	assert_true(result, "leader cekim yapabilmeli")
	assert_gt(GameData.cash, before)


func test_withdraw_daily_limit() -> void:
	GangManager.create_gang("Limit", "LM")
	GangManager.current_gang["treasury"] = 1000
	# %20 limit = 200
	GangManager.withdraw_from_treasury(500)
	# En fazla 200 cekilebilmeli
	assert_gte(GangManager.current_gang["treasury"], 800, "gunluk limit asildmamali")


# === MAX MEMBERS ===

func test_max_members_base() -> void:
	GangManager.current_gang = {"gang_level": 1}
	var max_m := GangManager.get_max_members()
	assert_eq(max_m, GangManager.GANG_BASE_MEMBERS + GangManager.MEMBERS_PER_LEVEL)


func test_max_members_capped() -> void:
	GangManager.current_gang = {"gang_level": 100}
	var max_m := GangManager.get_max_members()
	assert_lte(max_m, GangManager.GANG_MAX_MEMBERS, "max member cap asalmaz")


# === XP & LEVEL ===

func test_xp_for_level_increases() -> void:
	var l1 := GangManager.get_xp_for_level(1)
	var l2 := GangManager.get_xp_for_level(2)
	var l3 := GangManager.get_xp_for_level(3)
	assert_gt(l2, l1)
	assert_gt(l3, l2)


func test_add_gang_xp() -> void:
	GangManager.create_gang("XPGang", "XP")
	GangManager.add_gang_xp(100)
	assert_eq(GangManager.current_gang["gang_xp"], 100)


func test_gang_level_up() -> void:
	GangManager.create_gang("LevelGang", "LV")
	var needed := GangManager.get_xp_for_level(2) + 1
	GangManager.add_gang_xp(needed)
	assert_gte(GangManager.current_gang["gang_level"], 2, "yeterli XP ile level artmali")


# === SERIALIZE ===

func test_serialize_roundtrip() -> void:
	GangManager.create_gang("SerGang", "SG")
	GangManager.current_gang["treasury"] = 5000

	var data := GangManager.serialize()
	GangManager.current_gang = {}
	GangManager.is_in_gang = false

	GangManager.deserialize(data)
	assert_true(GangManager.is_in_gang)
	assert_eq(GangManager.current_gang["name"], "SerGang")
	assert_eq(GangManager.current_gang["treasury"], 5000)


# === HELPER ===

func _make_gang() -> Dictionary:
	return {
		"gang_id": "test_gang_01",
		"name": "TestGang",
		"tag": "TG",
		"gang_level": 1,
		"gang_xp": 0,
		"treasury": 0,
		"members": [
			{"player_id": "leader_01", "role": "LEADER", "joined_at": 0, "contribution": 0}
		],
		"controlled_territories": [],
	}
