## EconomyManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("eco_test", "EcoTester")
	EconomyManager.transaction_log.clear()


# === CASH ISLEMLERI ===

func test_add_cash_increases_balance() -> void:
	var start := GameData.cash
	EconomyManager.add_cash(100, "test_reward")
	assert_eq(GameData.cash, start + 100, "cash 100 artmali")


func test_add_cash_zero_ignored() -> void:
	var start := GameData.cash
	EconomyManager.add_cash(0, "test")
	assert_eq(GameData.cash, start, "0 ekleme degistirmemeli")


func test_add_cash_negative_ignored() -> void:
	var start := GameData.cash
	EconomyManager.add_cash(-50, "test")
	assert_eq(GameData.cash, start, "negatif ekleme degistirmemeli")


func test_spend_cash_success() -> void:
	GameData.cash = 1000
	var result := EconomyManager.spend_cash(300, "test_purchase")
	assert_true(result, "yeterli bakiye ile true donmeli")
	assert_eq(GameData.cash, 700, "300 harcanmali")


func test_spend_cash_insufficient_fails() -> void:
	GameData.cash = 100
	var result := EconomyManager.spend_cash(500, "test")
	assert_false(result, "yetersiz bakiye ile false donmeli")
	assert_eq(GameData.cash, 100, "bakiye degismemeli")


func test_spend_cash_exact_amount() -> void:
	GameData.cash = 200
	var result := EconomyManager.spend_cash(200, "test")
	assert_true(result, "tam tutar harcanabilmeli")
	assert_eq(GameData.cash, 0, "bakiye 0 olmali")


func test_spend_cash_zero_fails() -> void:
	var result := EconomyManager.spend_cash(0, "test")
	assert_false(result, "0 harcama false donmeli")


func test_spend_cash_negative_fails() -> void:
	var result := EconomyManager.spend_cash(-10, "test")
	assert_false(result, "negatif harcama false donmeli")


func test_cash_never_goes_negative() -> void:
	GameData.cash = 50
	EconomyManager.spend_cash(100, "test")
	assert_gte(GameData.cash, 0, "cash negatif olmamali")


# === PREMIUM CURRENCY ===

func test_add_premium_increases() -> void:
	GameData.premium_currency = 0
	EconomyManager.add_premium(10, "iap")
	assert_eq(GameData.premium_currency, 10)


func test_add_premium_zero_ignored() -> void:
	GameData.premium_currency = 5
	EconomyManager.add_premium(0, "test")
	assert_eq(GameData.premium_currency, 5)


func test_spend_premium_success() -> void:
	GameData.premium_currency = 100
	var result := EconomyManager.spend_premium(30, "test")
	assert_true(result)
	assert_eq(GameData.premium_currency, 70)


func test_spend_premium_insufficient_fails() -> void:
	GameData.premium_currency = 5
	var result := EconomyManager.spend_premium(10, "test")
	assert_false(result)
	assert_eq(GameData.premium_currency, 5, "premium degismemeli")


# === CHARISMA MULTIPLIER ===

func test_charisma_multiplier_base() -> void:
	GameData.charisma = 0
	var mult := EconomyManager.get_charisma_multiplier()
	assert_almost_eq(mult, 1.0, 0.001, "charisma 0 iken carpan 1.0 olmali")


func test_charisma_multiplier_scales() -> void:
	GameData.charisma = 10
	var mult := EconomyManager.get_charisma_multiplier()
	var expected := 1.0 + 10 * EconomyManager.CHARISMA_REWARD_BONUS
	assert_almost_eq(mult, expected, 0.001, "charisma 10 iken carpan %f olmali" % expected)


# === CAN AFFORD ===

func test_can_afford_true() -> void:
	GameData.cash = 500
	assert_true(EconomyManager.can_afford(500), "tam tutari karsilayabilmeli")
	assert_true(EconomyManager.can_afford(100), "dusuk tutari karsilayabilmeli")


func test_can_afford_false() -> void:
	GameData.cash = 50
	assert_false(EconomyManager.can_afford(100), "yetersiz bakiye false donmeli")


# === TRANSACTION LOG ===

func test_transaction_logged_on_add_cash() -> void:
	EconomyManager.add_cash(100, "mission_reward")
	assert_eq(EconomyManager.transaction_log.size(), 1, "1 log girisi olmali")
	var entry: Dictionary = EconomyManager.transaction_log[0]
	assert_eq(entry["currency"], "CASH")
	assert_eq(entry["amount"], 100)
	assert_eq(entry["source"], "mission_reward")


func test_transaction_logged_on_spend() -> void:
	GameData.cash = 1000
	EconomyManager.spend_cash(200, "shop_buy")
	assert_eq(EconomyManager.transaction_log.size(), 1)
	assert_eq(EconomyManager.transaction_log[0]["amount"], -200)


func test_transaction_log_capped() -> void:
	GameData.cash = 999999
	for i in range(EconomyManager.TRANSACTION_LOG_MAX + 50):
		EconomyManager.add_cash(1, "spam")
	assert_lte(
		EconomyManager.transaction_log.size(),
		EconomyManager.TRANSACTION_LOG_MAX,
		"log %d'yi gecmemeli" % EconomyManager.TRANSACTION_LOG_MAX
	)


func test_transaction_balance_field_correct() -> void:
	GameData.cash = 1000
	EconomyManager.add_cash(500, "test")
	var entry: Dictionary = EconomyManager.transaction_log[0]
	assert_eq(entry["balance"], 1500, "balance son bakiyeyi gostermeli")


# === DAILY NET FLOW ===

func test_daily_net_flow_empty() -> void:
	var flow := EconomyManager.get_daily_net_flow()
	assert_eq(flow["income"], 0)
	assert_eq(flow["expense"], 0)
	assert_eq(flow["net"], 0)


func test_daily_net_flow_mixed() -> void:
	GameData.cash = 10000
	EconomyManager.add_cash(500, "mission")
	EconomyManager.spend_cash(200, "shop")
	EconomyManager.add_cash(300, "territory")
	var flow := EconomyManager.get_daily_net_flow()
	assert_eq(flow["income"], 800, "income = 500 + 300")
	assert_eq(flow["expense"], 200, "expense = 200")
	assert_eq(flow["net"], 600, "net = 800 - 200")
