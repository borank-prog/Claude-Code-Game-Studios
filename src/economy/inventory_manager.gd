## Envanter ve ekipman yonetimi — esya depolama, kusanma, satis.
extends Node

signal inventory_changed()
signal equipment_changed(slot: String, item_id: String)

# Envanter: [{item_id, quantity}]
var items: Array[Dictionary] = []

# Ekipman slotlari
var equipped: Dictionary = {
	"weapon": "",
	"armor": "",
	"clothing": "",
	"accessory_1": "",
	"accessory_2": "",
}

var equipment_power: int = 0
var equipment_stat_bonuses: Dictionary = {}  # stat_name -> total bonus

const MAX_INVENTORY_SLOTS: int = 50
const TEMP_STASH_DURATION: float = 86400.0  # 24 saat

var temp_stash: Array[Dictionary] = []  # Envanter doluyken dusme


func _ready() -> void:
	pass


## Envantere esya ekle
func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_def := ItemDB.get_item(item_id)
	if item_def.is_empty():
		push_warning("Unknown item: %s" % item_id)
		return false

	# Stackable mi?
	if item_def.get("is_stackable", false):
		for i in items.size():
			if items[i]["item_id"] == item_id:
				var max_stack: int = item_def.get("max_stack", 99)
				items[i]["quantity"] = mini(items[i]["quantity"] + quantity, max_stack)
				inventory_changed.emit()
				EventBus.item_acquired.emit(item_id, quantity)
				return true

	# Slot kontrolu
	if get_used_slots() >= MAX_INVENTORY_SLOTS:
		# Temp stash'e at
		temp_stash.append({"item_id": item_id, "quantity": quantity, "expires": Time.get_unix_time_from_system() + TEMP_STASH_DURATION})
		EventBus.inventory_full.emit()
		return false

	items.append({"item_id": item_id, "quantity": quantity})
	inventory_changed.emit()
	EventBus.item_acquired.emit(item_id, quantity)
	return true


## Envanterden esya cikar
func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in items.size():
		if items[i]["item_id"] == item_id:
			items[i]["quantity"] -= quantity
			if items[i]["quantity"] <= 0:
				items.remove_at(i)
			inventory_changed.emit()
			EventBus.item_removed.emit(item_id, quantity)
			return true
	return false


## Esya miktarini sor
func get_item_count(item_id: String) -> int:
	for entry in items:
		if entry["item_id"] == item_id:
			return entry["quantity"]
	return 0


## Esya var mi
func has_item(item_id: String) -> bool:
	return get_item_count(item_id) > 0


## Kullanilan slot sayisi
func get_used_slots() -> int:
	return items.size()


## Esya kusan
func equip_item(item_id: String) -> bool:
	if not has_item(item_id):
		return false

	var item_def := ItemDB.get_item(item_id)
	if item_def.is_empty():
		return false

	# Rank kontrolu
	if item_def.get("required_rank", 0) > GameData.rank:
		return false

	# Hangi slot?
	var slot := _get_slot_for_category(item_def.get("category", ""))
	if slot.is_empty():
		return false

	# Mevcut ekipmani cikar
	if not equipped[slot].is_empty():
		unequip_slot(slot)

	equipped[slot] = item_id
	_recalculate_equipment_bonuses()
	equipment_changed.emit(slot, item_id)
	EventBus.equipment_changed.emit(slot, item_id)
	return true


## Slottaki ekipmani cikar
func unequip_slot(slot: String) -> void:
	if equipped.has(slot) and not equipped[slot].is_empty():
		equipped[slot] = ""
		_recalculate_equipment_bonuses()
		equipment_changed.emit(slot, "")
		EventBus.equipment_changed.emit(slot, "")


## Esya sat
func sell_item(item_id: String, quantity: int = 1) -> bool:
	if not has_item(item_id):
		return false

	# Kusanili esya satilmaz
	for slot in equipped:
		if equipped[slot] == item_id:
			unequip_slot(slot)

	var item_def := ItemDB.get_item(item_id)
	var sell_price: int = item_def.get("sell_price", 0)

	if remove_item(item_id, quantity):
		EconomyManager.add_cash(sell_price * quantity, "sell_%s" % item_id)
		return true
	return false


## Ekipman bonuslarini yeniden hesapla
func _recalculate_equipment_bonuses() -> void:
	equipment_power = 0
	equipment_stat_bonuses.clear()

	for slot in equipped:
		var item_id: String = equipped[slot]
		if item_id.is_empty():
			continue

		var item_def := ItemDB.get_item(item_id)
		equipment_power += item_def.get("power_bonus", 0)

		var bonuses: Dictionary = item_def.get("stat_bonuses", {})
		for stat_name in bonuses:
			if not equipment_stat_bonuses.has(stat_name):
				equipment_stat_bonuses[stat_name] = 0
			equipment_stat_bonuses[stat_name] += bonuses[stat_name]


## Toplam guc (GameData power + equipment)
func get_total_power() -> int:
	return GameData.get_power_score() + equipment_power


## Belirli bir stat'in ekipman bonusu
func get_equipment_stat_bonus(stat_name: String) -> int:
	return equipment_stat_bonuses.get(stat_name, 0)


## Kategori -> slot eslestirmesi
func _get_slot_for_category(category: String) -> String:
	match category:
		"WEAPON": return "weapon"
		"ARMOR": return "armor"
		"CLOTHING": return "clothing"
		_: return ""


## Envanter listesini kategoriyle dondur (UI icin)
func get_inventory_with_details() -> Array:
	var result: Array = []
	for entry in items:
		var item_def := ItemDB.get_item(entry["item_id"])
		if not item_def.is_empty():
			var detail := item_def.duplicate()
			detail["quantity"] = entry["quantity"]
			detail["is_equipped"] = _is_equipped(entry["item_id"])
			result.append(detail)
	return result


func _is_equipped(item_id: String) -> bool:
	for slot in equipped:
		if equipped[slot] == item_id:
			return true
	return false


## Temp stash'i kontrol et ve suresi dolanlari sil
func clean_temp_stash() -> void:
	var now := Time.get_unix_time_from_system()
	temp_stash = temp_stash.filter(func(s): return s["expires"] > now)


## Serialize
func serialize() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"equipped": equipped.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	items.clear()
	for entry in data.get("items", []):
		items.append(entry)
	for slot in data.get("equipped", {}):
		if equipped.has(slot):
			equipped[slot] = data["equipped"][slot]
	_recalculate_equipment_bonuses()
