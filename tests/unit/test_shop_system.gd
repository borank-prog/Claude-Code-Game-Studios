## ShopSystem unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("shop_test", "ShopTester")
	InventoryManager.items.clear()
	InventoryManager.temp_stash.clear()
	InventoryManager.equipped = {
		"weapon": "", "armor": "", "clothing": "",
		"accessory_1": "", "accessory_2": "",
	}
	EconomyManager.transaction_log.clear()
	UnitManager.hired_units.clear()


# === BUY ===

func test_buy_item_success() -> void:
	GameData.cash = 10000
	var result := ShopSystem.buy_item("wpn_knife")  # 200 cash
	assert_true(result, "yeterli cash ile satin alinabilmeli")
	assert_true(InventoryManager.has_item("wpn_knife"), "envantere eklenmeli")


func test_buy_deducts_cash() -> void:
	GameData.cash = 10000
	var before := GameData.cash
	ShopSystem.buy_item("wpn_knife")
	assert_lt(GameData.cash, before, "cash azalmali")


func test_buy_uses_effective_price_with_tax() -> void:
	GameData.cash = 10000
	var item_def: Dictionary = ItemDB.get_item("wpn_knife")
	var expected_price := ShopSystem.get_effective_buy_price(item_def)
	assert_eq(expected_price, 216, "varsayilan %8 vergi uygulanmali")
	var before := GameData.cash
	ShopSystem.buy_item("wpn_knife")
	assert_eq(GameData.cash, before - expected_price, "shop harcamasi efektif fiyat kadar olmali")


func test_buy_with_crypto_and_customs_applies_discount_and_zero_tax() -> void:
	GameData.cash = 10000
	GameData.rank = 20
	UnitManager.hired_units = {
		"crypto_launderer": 1,
		"corrupt_customs": 1,
	}
	var item_def: Dictionary = ItemDB.get_item("wpn_knife")
	var effective := ShopSystem.get_effective_buy_price(item_def)
	assert_eq(effective, 160, "black market indirimi + sifir vergi beklenir")


func test_buy_insufficient_cash_fails() -> void:
	GameData.cash = 10
	var result := ShopSystem.buy_item("wpn_knife")  # 200 cash
	assert_false(result, "yetersiz cash ile satilamaz")


func test_buy_insufficient_rank_fails() -> void:
	GameData.cash = 100000
	GameData.rank = 0
	var result := ShopSystem.buy_item("wpn_shotgun")  # required_rank: 5
	assert_false(result, "yetersiz rank ile satin alinamaz")


func test_buy_unknown_item_fails() -> void:
	GameData.cash = 100000
	var result := ShopSystem.buy_item("nonexistent_item")
	assert_false(result, "bilinmeyen esya satin alinamaz")


func test_buy_inventory_full_refunds() -> void:
	GameData.cash = 10000
	for i in InventoryManager.MAX_INVENTORY_SLOTS:
		InventoryManager.items.append({"item_id": "filler_%d" % i, "quantity": 1})

	var before := GameData.cash
	var result := ShopSystem.buy_item("wpn_knife")
	assert_false(result, "envanter dolu ise false donmeli")
	assert_eq(GameData.cash, before, "para iade edilmeli")


func test_buy_unit_success() -> void:
	GameData.cash = 100000
	GameData.rank = 20
	var result := ShopSystem.buy_item("drone_operator")
	assert_true(result, "unit satin alimi basarili olmali")
	assert_true(UnitManager.has_unit("drone_operator"), "unit envanteri yerine UnitManager'a eklenmeli")


func test_buy_unit_twice_fails() -> void:
	GameData.cash = 100000
	GameData.rank = 20
	assert_true(ShopSystem.buy_item("chemist"))
	assert_false(ShopSystem.buy_item("chemist"), "tekil unit ikinci kez alinmamali")


# === SELL ===

func test_sell_item_success() -> void:
	InventoryManager.add_item("wpn_knife")
	var before := GameData.cash
	var result := ShopSystem.sell_item("wpn_knife")
	assert_true(result, "envanterdeki esya satilabilmeli")
	assert_gt(GameData.cash, before, "satis cash vermeli")


func test_sell_nonexistent_fails() -> void:
	var result := ShopSystem.sell_item("wpn_knife")
	assert_false(result, "olmayan esya satilamaz")


# === CAN BUY ===

func test_can_buy_true() -> void:
	GameData.cash = 100000
	GameData.rank = 20
	var status := ShopSystem.can_buy("wpn_knife")
	assert_true(status["can_buy"], "yeterli cash ve rank ile can_buy true")


func test_can_buy_unit_rank_fail() -> void:
	GameData.cash = 100000
	GameData.rank = 0
	var status := ShopSystem.can_buy("drone_operator")
	assert_false(status["can_buy"])
	assert_eq(status["reason"], "rank")


func test_can_buy_rank_fail() -> void:
	GameData.cash = 100000
	GameData.rank = 0
	var status := ShopSystem.can_buy("wpn_shotgun")
	assert_false(status["can_buy"])
	assert_eq(status["reason"], "rank")


func test_can_buy_cash_fail() -> void:
	GameData.cash = 0
	GameData.rank = 20
	var status := ShopSystem.can_buy("wpn_knife")
	assert_false(status["can_buy"])
	assert_eq(status["reason"], "cash")


func test_can_buy_inventory_full() -> void:
	GameData.cash = 100000
	GameData.rank = 20
	for i in InventoryManager.MAX_INVENTORY_SLOTS:
		InventoryManager.items.append({"item_id": "filler_%d" % i, "quantity": 1})
	var status := ShopSystem.can_buy("wpn_knife")
	assert_false(status["can_buy"])
	assert_eq(status["reason"], "inventory_full")


# === SHOP ITEMS ===

func test_get_shop_items_filters_by_rank() -> void:
	GameData.rank = 0
	var items := ShopSystem.get_shop_items()
	for item in items:
		assert_lte(item.get("required_rank", 0), 0, "rank 0 ustundeki esyalar gelmemeli")


func test_get_shop_items_by_category() -> void:
	GameData.rank = 20
	var weapons := ShopSystem.get_shop_items("WEAPON")
	for item in weapons:
		assert_eq(item.get("category", ""), "WEAPON", "sadece silahlar gelmeli")
