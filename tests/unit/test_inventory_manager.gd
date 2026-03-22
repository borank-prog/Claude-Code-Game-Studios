## InventoryManager unit testleri.
extends GutTest


func before_each() -> void:
	GameData.initialize_new_player("inv_test", "InvTester")
	InventoryManager.items.clear()
	InventoryManager.temp_stash.clear()
	InventoryManager.equipped = {
		"weapon": "", "armor": "", "clothing": "",
		"accessory_1": "", "accessory_2": "",
	}
	InventoryManager.equipment_power = 0
	InventoryManager.equipment_stat_bonuses.clear()


# === ADD ITEM ===

func test_add_item_success() -> void:
	var result := InventoryManager.add_item("wpn_knife")
	assert_true(result, "bilinen esya eklenebilmeli")
	assert_eq(InventoryManager.get_item_count("wpn_knife"), 1)


func test_add_unknown_item_fails() -> void:
	var result := InventoryManager.add_item("nonexistent_xyz")
	assert_false(result, "bilinmeyen esya eklenemez")


func test_add_item_slot_limit() -> void:
	# 50 slot doldur
	for i in InventoryManager.MAX_INVENTORY_SLOTS:
		InventoryManager.items.append({"item_id": "filler_%d" % i, "quantity": 1})

	var result := InventoryManager.add_item("wpn_knife")
	assert_false(result, "envanter dolu ise false donmeli")
	assert_gt(InventoryManager.temp_stash.size(), 0, "temp stash'e eklenmeli")


func test_add_stackable_item() -> void:
	# Enerji icecegi stackable
	InventoryManager.add_item("con_energy")
	InventoryManager.add_item("con_energy")
	assert_eq(InventoryManager.get_item_count("con_energy"), 2, "stackable item biriktirilmeli")
	assert_eq(InventoryManager.get_used_slots(), 1, "tek slot kullanilmali")


# === REMOVE ITEM ===

func test_remove_item_success() -> void:
	InventoryManager.add_item("wpn_knife")
	var result := InventoryManager.remove_item("wpn_knife")
	assert_true(result, "mevcut esya cikarilabilmeli")
	assert_eq(InventoryManager.get_item_count("wpn_knife"), 0)


func test_remove_item_not_found() -> void:
	var result := InventoryManager.remove_item("wpn_knife")
	assert_false(result, "olmayan esya cikarilamamali")


func test_remove_partial_stack() -> void:
	InventoryManager.add_item("con_energy")
	InventoryManager.add_item("con_energy")
	InventoryManager.add_item("con_energy")
	InventoryManager.remove_item("con_energy", 1)
	assert_eq(InventoryManager.get_item_count("con_energy"), 2, "1 tane azalmali")


# === HAS ITEM ===

func test_has_item_true() -> void:
	InventoryManager.add_item("wpn_knife")
	assert_true(InventoryManager.has_item("wpn_knife"))


func test_has_item_false() -> void:
	assert_false(InventoryManager.has_item("wpn_knife"))


# === EQUIP ===

func test_equip_weapon() -> void:
	InventoryManager.add_item("wpn_knife")
	var result := InventoryManager.equip_item("wpn_knife")
	assert_true(result, "envanterdeki esya kusalabilmeli")
	assert_eq(InventoryManager.equipped["weapon"], "wpn_knife")


func test_equip_not_in_inventory_fails() -> void:
	var result := InventoryManager.equip_item("wpn_knife")
	assert_false(result, "envanterde olmayan esya kusalamaz")


func test_equip_insufficient_rank_fails() -> void:
	GameData.rank = 0
	InventoryManager.add_item("wpn_shotgun")  # required_rank: 5
	var result := InventoryManager.equip_item("wpn_shotgun")
	assert_false(result, "rank yetersiz ise kusalamaz")


func test_equip_replaces_current() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.add_item("wpn_pistol")
	GameData.rank = 2  # pistol rank 2 gerektirir
	InventoryManager.equip_item("wpn_knife")
	InventoryManager.equip_item("wpn_pistol")
	assert_eq(InventoryManager.equipped["weapon"], "wpn_pistol", "yeni silah eskisini degistirmeli")


func test_equip_updates_power() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")
	assert_gt(InventoryManager.equipment_power, 0, "kusanma power artirmali")


func test_equip_updates_stat_bonuses() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")
	assert_gt(InventoryManager.get_equipment_stat_bonus("strength"), 0, "stat bonus uygulanmali")


# === UNEQUIP ===

func test_unequip_clears_slot() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")
	InventoryManager.unequip_slot("weapon")
	assert_eq(InventoryManager.equipped["weapon"], "", "slot temizlenmeli")


func test_unequip_resets_power() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")
	InventoryManager.unequip_slot("weapon")
	assert_eq(InventoryManager.equipment_power, 0, "power sifirlanmali")


# === SELL ===

func test_sell_item_gives_cash() -> void:
	InventoryManager.add_item("wpn_knife")
	var before := GameData.cash
	InventoryManager.sell_item("wpn_knife")
	assert_gt(GameData.cash, before, "satis cash vermeli")


func test_sell_equipped_unequips_first() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")
	InventoryManager.sell_item("wpn_knife")
	assert_eq(InventoryManager.equipped["weapon"], "", "satilan esya kusanilan yerden cikmali")


func test_sell_nonexistent_fails() -> void:
	var result := InventoryManager.sell_item("wpn_knife")
	assert_false(result, "olmayan esya satilamaz")


# === SLOT MAPPING ===

func test_weapon_maps_to_weapon_slot() -> void:
	assert_eq(InventoryManager._get_slot_for_category("WEAPON"), "weapon")


func test_armor_maps_to_armor_slot() -> void:
	assert_eq(InventoryManager._get_slot_for_category("ARMOR"), "armor")


func test_clothing_maps_to_clothing_slot() -> void:
	assert_eq(InventoryManager._get_slot_for_category("CLOTHING"), "clothing")


func test_unknown_maps_to_empty() -> void:
	assert_eq(InventoryManager._get_slot_for_category("VEHICLE"), "", "bilinmeyen kategori bos donmeli")


# === SERIALIZE ===

func test_serialize_roundtrip() -> void:
	InventoryManager.add_item("wpn_knife")
	InventoryManager.equip_item("wpn_knife")

	var data := InventoryManager.serialize()
	InventoryManager.items.clear()
	InventoryManager.equipped["weapon"] = ""

	InventoryManager.deserialize(data)
	assert_true(InventoryManager.has_item("wpn_knife"))
	assert_eq(InventoryManager.equipped["weapon"], "wpn_knife")


# === TEMP STASH ===

func test_temp_stash_cleanup() -> void:
	InventoryManager.temp_stash = [
		{"item_id": "old", "quantity": 1, "expires": 0.0},
		{"item_id": "new", "quantity": 1, "expires": Time.get_unix_time_from_system() + 9999},
	]
	InventoryManager.clean_temp_stash()
	assert_eq(InventoryManager.temp_stash.size(), 1, "suresi dolan stash temizlenmeli")
	assert_eq(InventoryManager.temp_stash[0]["item_id"], "new")
