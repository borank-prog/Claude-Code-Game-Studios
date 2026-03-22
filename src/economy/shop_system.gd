## Magaza sistemi — rank bazli esya satin alma ve satma.
extends Node

signal purchase_completed(item_id: String)
signal purchase_failed(reason: String)
signal sale_completed(item_id: String, cash_gained: int)


## Satin al
func buy_item(item_id: String) -> bool:
	var item_def := ItemDB.get_item(item_id)
	if item_def.is_empty():
		purchase_failed.emit("Esya bulunamadi")
		return false

	# Rank kontrolu
	if item_def.get("required_rank", 0) > GameData.rank:
		purchase_failed.emit("Rank yetersiz")
		return false

	# Cash kontrolu
	var price: int = item_def.get("buy_price", 0)
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

	var item_def := ItemDB.get_item(item_id)
	var sell_price: int = item_def.get("sell_price", 0)

	if inv.sell_item(item_id, quantity):
		sale_completed.emit(item_id, sell_price * quantity)
		return true
	return false


## Rank'a uygun satilik esyalari getir
func get_shop_items(category: String = "") -> Array:
	return ItemDB.get_items_for_rank(GameData.rank, category)


## Esya satin alinabilir mi (UI icin)
func can_buy(item_id: String) -> Dictionary:
	var item_def := ItemDB.get_item(item_id)
	if item_def.is_empty():
		return {"can_buy": false, "reason": "not_found"}

	if item_def.get("required_rank", 0) > GameData.rank:
		return {"can_buy": false, "reason": "rank", "required": item_def["required_rank"]}

	if not EconomyManager.can_afford(item_def.get("buy_price", 0)):
		return {"can_buy": false, "reason": "cash", "required": item_def["buy_price"]}

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and inv.get_used_slots() >= inv.MAX_INVENTORY_SLOTS:
		return {"can_buy": false, "reason": "inventory_full"}

	return {"can_buy": true, "reason": ""}
