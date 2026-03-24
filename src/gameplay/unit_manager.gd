## Operatif birim kiralama ve bonus hesaplama.
extends Node

signal unit_hired(unit_id: String)
signal unit_hire_failed(unit_id: String, reason: String)

var hired_units: Dictionary = {}  # unit_id -> count


func has_unit(unit_id: String) -> bool:
	return get_unit_count(unit_id) > 0


func get_unit_count(unit_id: String) -> int:
	return int(hired_units.get(unit_id, 0))


func get_units_for_rank(target_rank: int) -> Array:
	var result: Array = []
	for unit_id in UnitDB.get_all_units():
		var unit_def: Dictionary = UnitDB.get_unit_data(unit_id)
		if unit_def.get("required_rank", 0) > target_rank:
			continue

		var card := unit_def.duplicate(true)
		var full_desc: String = unit_def.get("description", "")
		var short_desc: String = full_desc.split(".")[0]
		if not short_desc.is_empty():
			short_desc += "."
		card["item_id"] = unit_id
		card["category"] = "OPERATIVE"
		card["buy_price"] = unit_def.get("hire_cost", 0)
		card["power_bonus"] = 0
		card["stat_bonuses"] = {}
		card["is_unit"] = true
		card["shop_line"] = short_desc
		card["owned_count"] = get_unit_count(unit_id)
		result.append(card)
	return result


func can_hire(unit_id: String) -> Dictionary:
	var unit_def: Dictionary = UnitDB.get_unit_data(unit_id)
	if unit_def.is_empty():
		return {"can_hire": false, "reason": "not_found"}

	if GameData.rank < unit_def.get("required_rank", 0):
		return {"can_hire": false, "reason": "rank", "required": unit_def.get("required_rank", 0)}

	var owned: int = get_unit_count(unit_id)
	var max_count: int = unit_def.get("max_count", 1)
	if owned >= max_count:
		return {"can_hire": false, "reason": "already_owned"}

	var hire_cost: int = unit_def.get("hire_cost", 0)
	if not EconomyManager.can_afford(hire_cost):
		return {"can_hire": false, "reason": "cash", "required": hire_cost}

	return {"can_hire": true, "reason": ""}


func hire_unit(unit_id: String) -> Dictionary:
	var status := can_hire(unit_id)
	if not status.get("can_hire", false):
		var fail_reason: String = _reason_to_text(status.get("reason", "failed"))
		unit_hire_failed.emit(unit_id, fail_reason)
		return {"success": false, "reason": fail_reason}

	var unit_def: Dictionary = UnitDB.get_unit_data(unit_id)
	var hire_cost: int = unit_def.get("hire_cost", 0)
	if not EconomyManager.spend_cash(hire_cost, "hire_unit_%s" % unit_id):
		unit_hire_failed.emit(unit_id, "Yetersiz bakiye")
		return {"success": false, "reason": "Yetersiz bakiye"}

	hired_units[unit_id] = get_unit_count(unit_id) + 1
	unit_hired.emit(unit_id)
	return {"success": true}


func get_effect_multiplier(bonus_type: String, default_value: float = 1.0) -> float:
	var result := default_value
	for unit_id in hired_units:
		var count := int(hired_units[unit_id])
		if count <= 0:
			continue

		var unit_def: Dictionary = UnitDB.get_unit_data(unit_id)
		for bonus in unit_def.get("bonuses", []):
			if bonus.get("bonus_type", "") != bonus_type:
				continue
			if bonus.get("bonus_mode", "multiplier") != "multiplier":
				continue

			var bonus_value: float = bonus.get("bonus_value", 1.0)
			result *= pow(bonus_value, count)
	return result


func get_effect_additive(bonus_type: String, default_value: float = 0.0) -> float:
	var result := default_value
	for unit_id in hired_units:
		var count := int(hired_units[unit_id])
		if count <= 0:
			continue

		var unit_def: Dictionary = UnitDB.get_unit_data(unit_id)
		for bonus in unit_def.get("bonuses", []):
			if bonus.get("bonus_type", "") != bonus_type:
				continue
			if bonus.get("bonus_mode", "") != "additive":
				continue

			var bonus_value: float = bonus.get("bonus_value", 0.0)
			result += bonus_value * count
	return result


func serialize() -> Dictionary:
	return {"hired_units": hired_units.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	hired_units.clear()
	var loaded: Dictionary = data.get("hired_units", {})
	for unit_id in loaded:
		if UnitDB.has_unit(unit_id):
			hired_units[unit_id] = maxi(0, int(loaded[unit_id]))


func _reason_to_text(reason: String) -> String:
	match reason:
		"not_found": return "Birim bulunamadi"
		"rank": return "Rank yetersiz"
		"already_owned": return "Bu birim zaten sende"
		"cash": return "Yetersiz bakiye"
		_: return "Kiralama basarisiz"
