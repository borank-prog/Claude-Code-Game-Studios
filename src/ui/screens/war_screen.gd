## Gang War ekrani — aktif baskinlar, hazirlik, katilim, sonuc.
## Map ekranindan popup olarak acilir veya tab iceriginden erisilebilir.
extends Control

signal war_closed()

var _war_mgr: Node
var _territory_mgr: Node
var _gang_mgr: Node

@onready var active_raids_list: VBoxContainer = %ActiveRaidsList
@onready var raid_history_list: VBoxContainer = %RaidHistoryList
@onready var no_raids_label: Label = %NoRaidsLabel

var _update_timer: float = 0.0


func _ready() -> void:
	_war_mgr = get_node_or_null("/root/GangWarManager")
	_territory_mgr = get_node_or_null("/root/TerritoryManager")
	_gang_mgr = get_node_or_null("/root/GangManager")

	if _war_mgr:
		_war_mgr.raid_declared.connect(func(_r): _refresh())
		_war_mgr.raid_resolved.connect(func(_r): _refresh())

	visibility_changed.connect(func(): if visible: _refresh())
	call_deferred("_refresh")


func _process(delta: float) -> void:
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_update_timers()


func _refresh() -> void:
	_build_active_raids()
	_build_history()


# === AKTIF BASKINLAR ===

func _build_active_raids() -> void:
	for child in active_raids_list.get_children():
		child.queue_free()

	if _war_mgr == null:
		return

	var raids: Array = _war_mgr.active_raids
	no_raids_label.visible = raids.is_empty()

	for raid in raids:
		if raid.get("resolved", false):
			continue
		active_raids_list.add_child(_create_raid_card(raid))


func _create_raid_card(raid: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ThemeConstants.SURFACE_COLOR
	style.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	style.border_width_left = 3
	style.border_color = ThemeConstants.DANGER_COLOR
	style.content_margin_left = ThemeConstants.CARD_PADDING
	style.content_margin_right = ThemeConstants.CARD_PADDING
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# Hedef bolge adi
	var target_id: String = raid.get("target_territory_id", "")
	var territory: Dictionary = _territory_mgr.get_territory(target_id) if _territory_mgr else {}
	var target_name := Label.new()
	target_name.text = "Hedef: %s" % territory.get("name", target_id)
	target_name.add_theme_color_override("font_color", ThemeConstants.DANGER_COLOR)
	target_name.add_theme_font_size_override("font_size", ThemeConstants.FONT_SUBHEADING)
	vbox.add_child(target_name)

	# Timer
	var timer_label := Label.new()
	timer_label.name = "Timer_%s" % raid.get("raid_id", "")
	var remaining := maxf(0, raid.get("resolves_at", 0) - Time.get_unix_time_from_system())
	timer_label.text = "Cozum: %s" % _format_time(remaining)
	timer_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	timer_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	timer_label.set_meta("resolves_at", raid.get("resolves_at", 0))
	vbox.add_child(timer_label)

	# Guc gostergesi
	var power_hbox := HBoxContainer.new()
	vbox.add_child(power_hbox)

	var attack_power := 0
	for attacker in raid.get("attackers", []):
		attack_power += attacker.get("power_contribution", 0)
	var morale := 1.0 + raid.get("attackers", []).size() * GangWarManager.MORALE_PER_MEMBER
	attack_power = int(attack_power * morale)

	var defense_power := 0
	if _territory_mgr:
		defense_power = _territory_mgr.get_defense_power(target_id)
	defense_power += territory.get("tier", 1) * 200  # NPC savunma

	var atk_label := Label.new()
	atk_label.text = "Saldiri: %s" % ThemeConstants.format_number(attack_power)
	atk_label.add_theme_color_override("font_color", ThemeConstants.SUCCESS_COLOR)
	atk_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	atk_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_hbox.add_child(atk_label)

	var def_label := Label.new()
	def_label.text = "Savunma: %s" % ThemeConstants.format_number(defense_power)
	def_label.add_theme_color_override("font_color", ThemeConstants.DANGER_COLOR)
	def_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	power_hbox.add_child(def_label)

	# Katilimci sayisi
	var participants := Label.new()
	participants.text = "Katilimci: %d | Moral: +%d%%" % [
		raid.get("attackers", []).size(),
		int((morale - 1.0) * 100)
	]
	participants.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	participants.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	vbox.add_child(participants)

	# Kilitlenme uyarisi
	var lockout_time: float = raid.get("resolves_at", 0) - (GangWarManager.WAR_LOCKOUT_HOURS * 3600)
	if Time.get_unix_time_from_system() > lockout_time:
		var lockout_label := Label.new()
		lockout_label.text = "KILITLENDI — yeni katilim yok"
		lockout_label.add_theme_color_override("font_color", ThemeConstants.NEON_ACCENT)
		lockout_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		vbox.add_child(lockout_label)
	else:
		# Katil butonu
		var join_btn := Button.new()
		join_btn.text = "KATIL (%d Stamina)" % GangWarManager.RAID_JOIN_COST
		join_btn.custom_minimum_size = Vector2(0, ThemeConstants.MIN_TOUCH_TARGET)
		join_btn.pressed.connect(_on_join_raid.bind(raid.get("raid_id", "")))
		vbox.add_child(join_btn)

	return card


func _on_join_raid(raid_id: String) -> void:
	if _war_mgr == null:
		return
	if _war_mgr.join_raid(raid_id):
		ScreenManager.queue_notification("Baskina katildin!", "success")
		_refresh()
	else:
		ScreenManager.queue_notification("Katilim basarisiz (stamina veya kilitlenme)", "error")


# === SONUC GECMISI ===

func _build_history() -> void:
	for child in raid_history_list.get_children():
		child.queue_free()

	if _war_mgr == null:
		return

	# Son 10 baskin
	var history: Array = _war_mgr.raid_history
	var recent := history.slice(maxi(0, history.size() - 10))
	recent.reverse()

	for raid in recent:
		raid_history_list.add_child(_create_history_card(raid))


func _create_history_card(raid: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()

	var target_id: String = raid.get("target_territory_id", "")
	var territory: Dictionary = _territory_mgr.get_territory(target_id) if _territory_mgr else {}

	# Sonuc ikonu
	var result_label := Label.new()
	var result: String = raid.get("result", "")
	match result:
		"ATTACKER_WIN":
			result_label.text = "ZAFER"
			result_label.add_theme_color_override("font_color", ThemeConstants.SUCCESS_COLOR)
		"DEFENDER_WIN":
			result_label.text = "YENILGI"
			result_label.add_theme_color_override("font_color", ThemeConstants.DANGER_COLOR)
		"DRAW":
			result_label.text = "BERABERE"
			result_label.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
		_:
			result_label.text = "???"
			result_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)

	result_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	result_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(result_label)

	var name_label := Label.new()
	name_label.text = territory.get("name", target_id)
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Loot
	var loot: int = raid.get("loot_stolen", 0)
	if loot > 0:
		var loot_label := Label.new()
		loot_label.text = "+$%s" % ThemeConstants.format_number(loot)
		loot_label.add_theme_color_override("font_color", ThemeConstants.SUCCESS_COLOR)
		loot_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		row.add_child(loot_label)

	return row


# === TIMER UPDATE ===

func _update_timers() -> void:
	for child in active_raids_list.get_children():
		if child is PanelContainer:
			_update_card_timer(child)


func _update_card_timer(card: PanelContainer) -> void:
	# Timer label'i bul
	for node in card.get_children():
		if node is VBoxContainer:
			for child in node.get_children():
				if child is Label and child.has_meta("resolves_at"):
					var resolves_at: float = child.get_meta("resolves_at")
					var remaining := maxf(0, resolves_at - Time.get_unix_time_from_system())
					child.text = "Cozum: %s" % _format_time(remaining)
					if remaining <= 0:
						_refresh()  # Cozulmus — listeni yenile
					return


func _format_time(seconds: float) -> String:
	if seconds <= 0:
		return "SIMDI"
	var hours := int(seconds) / 3600
	var mins := (int(seconds) % 3600) / 60
	var secs := int(seconds) % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, mins, secs]
	return "%02d:%02d" % [mins, secs]
