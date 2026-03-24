## Merkezi sinyal yonetici — sistemler arasi iletisim.
## Dogrudan bagimliligi onler: A sistemi sinyal yayar, B sistemi dinler.
extends Node

# === ECONOMY ===
signal cash_changed(player_id: String, new_amount: int, delta: int)
signal premium_changed(player_id: String, new_amount: int, delta: int)
signal transaction_logged(transaction: Dictionary)

# === STAMINA ===
signal stamina_changed(current: int, max_stamina: int)
signal stamina_depleted()
signal stamina_full()

# === PROGRESSION ===
signal respect_gained(amount: int, source: String)
signal rank_up(new_rank: int, rank_name: String)
signal stat_changed(stat_name: String, new_value: int, delta: int)
signal stat_points_available(points: int)

# === MISSION ===
signal mission_started(mission_id: String)
signal mission_completed(mission_id: String, success: bool, rewards: Dictionary)
signal mission_list_refreshed()

# === INVENTORY ===
signal item_acquired(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal equipment_changed(slot: String, item_id: String)
signal inventory_full()
signal unit_hired(unit_id: String, amount: int)
signal unit_hire_failed(unit_id: String, reason: String)

# === GANG ===
signal gang_created(gang_id: String)
signal gang_joined(gang_id: String)
signal gang_left()
signal gang_member_joined(player_id: String)
signal gang_member_left(player_id: String)

# === TERRITORY ===
signal territory_captured(territory_id: String, gang_id: String)
signal territory_lost(territory_id: String)

# === GANG WAR ===
signal raid_declared(raid_id: String, target_territory: String)
signal raid_resolved(raid_id: String, result: String)
signal raid_joined(raid_id: String, player_id: String)

# === UI ===
signal screen_changed(screen_name: String)
signal popup_requested(popup_data: Dictionary)
signal notification_queued(text: String, type: String)

# === FEEDBACK ===
signal show_floating_text(text: String, color: Color, position: Vector2)
signal play_feedback(feedback_type: String)
