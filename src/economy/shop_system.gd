## Magaza sistemi — rank bazli esya satin alma ve satma.
extends Node

signal purchase_completed(item_id: String)
signal purchase_failed(reason: String)
signal sale_completed(item_id: String, cash_gained: int)

const SHOP_TAX_RATE: float = 0.08
const MAX_MARKET_DISCOUNT: float = 0.90
const BLACK_MARKET_CATEGORIES: PackedStringArray = ["WEAPON", "ARMOR", "CONSUMABLE"]
const OPERATIVE_CATEGORY: String = "OPERATIVE"


## Satin al
func buy_item(item_id: String) -> bool:
	if _is_unit_offer(item_id):
		var hire_result: Dictionary = UnitManager.hire_unit(item_id)
		if not hire_result.get("success", false):
			purchase_failed.emit(hire_result.get("reason", "Kiralama basarisiz"))
			return false
		purchase_completed.emit(item_id)
		return true

	var item_def: Dictionary = ItemDB.get_item(item_id)
	if item_def.is_empty():
		purchase_failed.emit("Esya bulunamadi")
		return false

	# Rank kontrolu
	if item_def.get("required_rank", 0) > GameData.rank:
		purchase_failed.emit("Rank yetersiz")
		return false

	# Cash kontrolu
	var price: int = get_effective_buy_price(item_def)
	if not EconomyManager.spend_cash(price, "shop_buy_%s" % item_id):
		purchase_failed.emit("Yetersiz bakiye")
		return false

	# Envantere ekle
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and not inv.add_item(item_id):
		# Envanter dolu — parayi iade et
		EconomyManager.add_cash(price, "shop_refund_%s" % item_id)
		purchase_failed.emit("Envanter dolu")
		return false

	purchase_completed.emit(item_id)
	return true


## Sat
func sell_item(item_id: String, quantity: int = 1) -> bool:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv == null:
		return false

	var item_def: Dictionary = ItemDB.get_item(item_id)
	var sell_price: int = item_def.get("sell_price", 0)

	if inv.sell_item(item_id, quantity):
		sale_completed.emit(item_id, sell_price * quantity)
		return true
	return false


## Rank'a uygun satilik esyalari getir
func get_shop_items(category: String = "") -> Array:
	if category == OPERATIVE_CATEGORY:
		return UnitManager.get_units_for_rank(GameData.rank)

	var result: Array = []
	for item in ItemDB.get_items_for_rank(GameData.rank, category):
		var card: Dictionary = item.duplicate(true)
		card["buy_price_base"] = item.get("buy_price", 0)
		card["buy_price"] = get_effective_buy_price(item)
		result.append(card)
	return result


## Esya satin alinabilir mi (UI icin)
func can_buy(item_id: String) -> Dictionary:
	if _is_unit_offer(item_id):
		var can_hire: Dictionary = UnitManager.can_hire(item_id)
		return {"can_buy": can_hire.get("can_hire", false), "reason": can_hire.get("reason", ""), "required": can_hire.get("required", 0)}

	var item_def: Dictionary = ItemDB.get_item(item_id)
	if item_def.is_empty():
		return {"can_buy": false, "reason": "not_found"}

	if item_def.get("required_rank", 0) > GameData.rank:
		return {"can_buy": false, "reason": "rank", "required": item_def["required_rank"]}

	var effective_price := get_effective_buy_price(item_def)
	if not EconomyManager.can_afford(effective_price):
		return {"can_buy": false, "reason": "cash", "required": effective_price}

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and inv.get_used_slots() >= inv.MAX_INVENTORY_SLOTS:
		return {"can_buy": false, "reason": "inventory_full"}

	return {"can_buy": true, "reason": ""}


func get_effective_buy_price(item_def: Dictionary) -> int:
	var base_price: int = item_def.get("buy_price", 0)
	if base_price <= 0:
		return 0

	var discount_rate := 0.0
	if _is_black_market_item(item_def):
		discount_rate = UnitManager.get_effect_additive("black_market_discount_rate")
	discount_rate = clampf(discount_rate, 0.0, MAX_MARKET_DISCOUNT)

	var discounted_price := int(ceil(base_price * (1.0 - discount_rate)))
	var tax_multiplier: float = maxf(0.0, UnitManager.get_effect_multiplier("shop_tax_multiplier"))
	var tax_rate: float = SHOP_TAX_RATE * tax_multiplier
	return int(ceil(discounted_price * (1.0 + tax_rate)))


func is_owned(item_id: String) -> bool:
	if _is_unit_offer(item_id):
		return UnitManager.has_unit(item_id)
	return InventoryManager.has_item(item_id)


func _is_black_market_item(item_def: Dictionary) -> bool:
	var category: String = item_def.get("category", "")
	return category in BLACK_MARKET_CATEGORIES


func _is_unit_offer(item_id: String) -> bool:
	return UnitDB.has_unit(item_id)
