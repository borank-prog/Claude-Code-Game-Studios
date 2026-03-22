## Data-driven esya veritabani — JSON'dan yukler, calisma zamaninda degismez.
extends Node

var items: Dictionary = {}  # item_id -> ItemDefinition dict
var items_by_category: Dictionary = {}  # category -> Array[item_id]
var items_by_rarity: Dictionary = {}  # rarity -> Array[item_id]
var _loaded: bool = false

const ITEMS_DIR: String = "res://assets/data/items/"
const SELL_RATIO: float = 0.3

const RARITY_ORDER: PackedStringArray = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_POWER_MULTIPLIER: Dictionary = {
	"COMMON": 1.0, "UNCOMMON": 1.3, "RARE": 1.7, "EPIC": 2.2, "LEGENDARY": 3.0
}
const DROP_CHANCE: Dictionary = {
	"COMMON": 0.60, "UNCOMMON": 0.25, "RARE": 0.10, "EPIC": 0.04, "LEGENDARY": 0.01
}


func _ready() -> void:
	_load_all_items()


## Tum JSON dosyalarini yukle
func _load_all_items() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("Item directory not found: %s — loading embedded defaults" % ITEMS_DIR)
		_load_default_items()
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_item_file(ITEMS_DIR + file_name)
		file_name = dir.get_next()

	if items.is_empty():
		push_warning("No items loaded from JSON — loading embedded defaults")
		_load_default_items()

	_loaded = true
	print("ItemDB: %d items loaded" % items.size())


func _load_item_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open item file: %s" % path)
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return

	var data = json.data
	if data is Array:
		for item_data in data:
			_register_item(item_data)
	elif data is Dictionary:
		_register_item(data)


func _register_item(data: Dictionary) -> void:
	var item_id: String = data.get("item_id", "")
	if item_id.is_empty():
		push_error("Item missing item_id: %s" % str(data))
		return

	if items.has(item_id):
		push_warning("Duplicate item_id '%s' — skipping" % item_id)
		return

	# Otomatik sell_price hesapla
	if not data.has("sell_price"):
		data["sell_price"] = int(floor(data.get("buy_price", 0) * SELL_RATIO))

	items[item_id] = data

	# Kategori indeksi
	var category: String = data.get("category", "MISC")
	if not items_by_category.has(category):
		items_by_category[category] = []
	items_by_category[category].append(item_id)

	# Rarity indeksi
	var rarity: String = data.get("rarity", "COMMON")
	if not items_by_rarity.has(rarity):
		items_by_rarity[rarity] = []
	items_by_rarity[rarity].append(item_id)


## Esya getir (null degilse Dictionary doner)
func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


## Kategoriye gore listele
func get_items_by_category(category: String) -> Array:
	var ids: Array = items_by_category.get(category, [])
	var result: Array = []
	for id in ids:
		result.append(items[id])
	return result


## Rank'a uygun esyalari filtrele
func get_items_for_rank(target_rank: int, category: String = "") -> Array:
	var result: Array = []
	for item_id in items:
		var item: Dictionary = items[item_id]
		if item.get("required_rank", 0) <= target_rank:
			if category.is_empty() or item.get("category", "") == category:
				result.append(item)
	return result


## Loot roll — rarity bazli rastgele esya sec
func roll_loot(allowed_categories: Array = []) -> Dictionary:
	var roll := randf()
	var cumulative := 0.0
	var target_rarity := "COMMON"

	for rarity in RARITY_ORDER:
		cumulative += DROP_CHANCE.get(rarity, 0.0)
		if roll <= cumulative:
			target_rarity = rarity
			break

	var candidates: Array = items_by_rarity.get(target_rarity, [])
	if not allowed_categories.is_empty():
		candidates = candidates.filter(func(id):
			return items[id].get("category", "") in allowed_categories
		)

	if candidates.is_empty():
		return {}

	var chosen_id: String = candidates[randi() % candidates.size()]
	return items[chosen_id]


## Varsayilan esyalar (JSON yoksa)
func _load_default_items() -> void:
	var defaults := [
		{"item_id": "wpn_knife", "name": "Bicak", "category": "WEAPON", "rarity": "COMMON",
		 "buy_price": 200, "power_bonus": 5, "stat_bonuses": {"strength": 2}, "required_rank": 0},
		{"item_id": "wpn_pistol", "name": "Tabanca", "category": "WEAPON", "rarity": "COMMON",
		 "buy_price": 800, "power_bonus": 15, "stat_bonuses": {"strength": 5}, "required_rank": 2},
		{"item_id": "wpn_shotgun", "name": "Pompali", "category": "WEAPON", "rarity": "UNCOMMON",
		 "buy_price": 2500, "power_bonus": 35, "stat_bonuses": {"strength": 10}, "required_rank": 5},
		{"item_id": "wpn_rifle", "name": "Tufek", "category": "WEAPON", "rarity": "RARE",
		 "buy_price": 6000, "power_bonus": 60, "stat_bonuses": {"strength": 18}, "required_rank": 8},
		{"item_id": "wpn_sniper", "name": "Keskin Nisanci", "category": "WEAPON", "rarity": "EPIC",
		 "buy_price": 15000, "power_bonus": 100, "stat_bonuses": {"strength": 30, "luck": 5}, "required_rank": 12},
		{"item_id": "arm_vest", "name": "Celik Yelek", "category": "ARMOR", "rarity": "COMMON",
		 "buy_price": 1500, "power_bonus": 10, "stat_bonuses": {"endurance": 8}, "required_rank": 1},
		{"item_id": "arm_kevlar", "name": "Kevlar Zirh", "category": "ARMOR", "rarity": "UNCOMMON",
		 "buy_price": 4000, "power_bonus": 25, "stat_bonuses": {"endurance": 15}, "required_rank": 6},
		{"item_id": "arm_heavy", "name": "Agir Zirh", "category": "ARMOR", "rarity": "RARE",
		 "buy_price": 10000, "power_bonus": 50, "stat_bonuses": {"endurance": 25}, "required_rank": 10},
		{"item_id": "clt_hoodie", "name": "Kapusonlu", "category": "CLOTHING", "rarity": "COMMON",
		 "buy_price": 300, "power_bonus": 2, "stat_bonuses": {"charisma": 3}, "required_rank": 0},
		{"item_id": "clt_suit", "name": "Takim Elbise", "category": "CLOTHING", "rarity": "UNCOMMON",
		 "buy_price": 2000, "power_bonus": 8, "stat_bonuses": {"charisma": 10}, "required_rank": 4},
		{"item_id": "clt_designer", "name": "Marka Kiyafet", "category": "CLOTHING", "rarity": "RARE",
		 "buy_price": 8000, "power_bonus": 20, "stat_bonuses": {"charisma": 20}, "required_rank": 9},
		{"item_id": "con_energy", "name": "Enerji Icecegi", "category": "CONSUMABLE", "rarity": "COMMON",
		 "buy_price": 50, "power_bonus": 0, "stat_bonuses": {}, "required_rank": 0,
		 "is_stackable": true, "max_stack": 10, "effect": "stamina_restore", "effect_value": 20},
	]
	for item_data in defaults:
		_register_item(item_data)
