## Ekonomi yonetimi — tum para islemleri bu sistemden gecer.
## Transaction log tutar, atomik islemler saglar.
extends Node

var transaction_log: Array[Dictionary] = []

# === TUNING KNOBS ===
const CHARISMA_REWARD_BONUS: float = 0.02
const GANG_TREASURY_DAILY_WITHDRAW_PERCENT: float = 20.0
const TRANSACTION_LOG_MAX: int = 500  # Bellekte tutulan max log


## Cash ekle (gorev odulu, bina geliri, vb.)
func add_cash(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	GameData.cash += amount
	_log_transaction("CASH", amount, source)
	EventBus.cash_changed.emit(GameData.player_id, GameData.cash, amount)


## Cash harca — basarili ise true doner
func spend_cash(amount: int, source: String = "") -> bool:
	if amount <= 0:
		return false
	if GameData.cash < amount:
		return false
	GameData.cash -= amount
	_log_transaction("CASH", -amount, source)
	EventBus.cash_changed.emit(GameData.player_id, GameData.cash, -amount)
	return true


## Premium currency ekle (IAP, odul)
func add_premium(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	GameData.premium_currency += amount
	_log_transaction("PREMIUM", amount, source)
	EventBus.premium_changed.emit(GameData.player_id, GameData.premium_currency, amount)


## Premium harca
func spend_premium(amount: int, source: String = "") -> bool:
	if amount <= 0:
		return false
	if GameData.premium_currency < amount:
		return false
	GameData.premium_currency -= amount
	_log_transaction("PREMIUM", -amount, source)
	EventBus.premium_changed.emit(GameData.player_id, GameData.premium_currency, -amount)
	return true


## Charisma bonus carpani
func get_charisma_multiplier() -> float:
	return 1.0 + GameData.charisma * CHARISMA_REWARD_BONUS


## Cash yeterliligi kontrol (UI icin)
func can_afford(amount: int) -> bool:
	return GameData.cash >= amount


## Transaction log
func _log_transaction(currency: String, amount: int, source: String) -> void:
	var entry := {
		"currency": currency,
		"amount": amount,
		"source": source,
		"timestamp": Time.get_unix_time_from_system(),
		"balance": GameData.cash if currency == "CASH" else GameData.premium_currency,
	}
	transaction_log.append(entry)
	EventBus.transaction_logged.emit(entry)

	# Bellek siniri
	if transaction_log.size() > TRANSACTION_LOG_MAX:
		transaction_log = transaction_log.slice(transaction_log.size() - TRANSACTION_LOG_MAX)


## Gunluk net akis (analytics icin)
func get_daily_net_flow() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var day_ago := now - 86400.0
	var income := 0
	var expense := 0
	for t in transaction_log:
		if t["timestamp"] >= day_ago and t["currency"] == "CASH":
			if t["amount"] > 0:
				income += t["amount"]
			else:
				expense += absi(t["amount"])
	return {"income": income, "expense": expense, "net": income - expense}
