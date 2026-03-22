## Gorsel geri bildirim yoneticisi — floating text, rank-up efekti,
## loot drop animasyonu, mission sonuc animasyonu.
## EventBus sinyallerini dinler, animasyonlari feedback_container'a ekler.
extends Control

var _notification_queue: Array[Dictionary] = []
var _is_showing_notification: bool = false
var _notification_timer: Timer

const FLOAT_DURATION: float = 1.0
const FLOAT_DISTANCE: float = 80.0
const RANK_UP_DURATION: float = 1.5
const LOOT_DROP_DURATION: float = 0.8
const MISSION_RESULT_DURATION: float = 1.2
const NOTIFICATION_DISPLAY_TIME: float = 2.0
const NOTIFICATION_MAX_QUEUE: int = 5


func _ready() -> void:
	# Bildirim timer'i
	_notification_timer = Timer.new()
	_notification_timer.one_shot = true
	_notification_timer.timeout.connect(_on_notification_timeout)
	add_child(_notification_timer)

	# Sinyalleri dinle
	EventBus.cash_changed.connect(_on_cash_changed)
	EventBus.premium_changed.connect(_on_premium_changed)
	EventBus.respect_gained.connect(_on_respect_gained)
	EventBus.rank_up.connect(_on_rank_up)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.notification_queued.connect(_on_notification_queued)
	EventBus.show_floating_text.connect(_on_show_floating_text)
	EventBus.raid_resolved.connect(_on_raid_resolved)


# === FLOATING TEXT ===

func show_floating_text(text: String, color: Color, start_pos: Vector2 = Vector2.ZERO) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SUBHEADING)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if start_pos == Vector2.ZERO:
		start_pos = Vector2(0, size.y * 0.4)

	label.position = start_pos
	label.size = Vector2(size.x, 40)
	label.modulate.a = 1.0
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_pos.y - FLOAT_DISTANCE, FLOAT_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION * 0.4)\
		.set_delay(FLOAT_DURATION * 0.6)
	# scale punch — buyuyup kuculme
	label.pivot_offset = label.size / 2.0
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)\
		.set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.chain().tween_callback(label.queue_free)


# === RANK UP EFEKTI ===

func show_rank_up(rank_name: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(ThemeConstants.PRIMARY_COLOR, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title := Label.new()
	title.text = "RANK UP!"
	title.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position.y = -60
	title.size = Vector2(size.x, 60)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ZERO
	overlay.add_child(title)

	var name_label := Label.new()
	name_label.text = rank_name
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.position.y = 20
	name_label.size = Vector2(size.x, 40)
	name_label.modulate.a = 0.0
	overlay.add_child(name_label)

	var tween := create_tween()

	# Flash overlay
	tween.tween_property(overlay, "color:a", 0.3, 0.15)
	tween.tween_property(overlay, "color:a", 0.1, 0.2)

	# Title scale in
	tween.parallel().tween_property(title, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.15)

	# Name fade in
	tween.parallel().tween_property(name_label, "modulate:a", 1.0, 0.3).set_delay(0.2)

	# Hold
	tween.tween_interval(0.6)

	# Fade out
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)


# === LOOT DROP ANIMASYONU ===

func show_loot_drop(item_name: String, rarity: String) -> void:
	var color := ThemeConstants.get_rarity_color(rarity)

	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size = Vector2(200, 80)
	container.position = Vector2((size.x - 200) / 2.0, size.y * 0.3)
	container.modulate.a = 0.0
	container.scale = Vector2(0.5, 0.5)
	container.pivot_offset = container.size / 2.0
	add_child(container)

	var rarity_label := Label.new()
	rarity_label.text = rarity
	rarity_label.add_theme_color_override("font_color", color)
	rarity_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)

	var tween := create_tween()
	tween.set_parallel(true)
	# Drop in (yukaridan dusturme)
	tween.tween_property(container, "position:y", size.y * 0.35, LOOT_DROP_DURATION * 0.4)\
		.from(size.y * 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(container, "modulate:a", 1.0, 0.15)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hold + fade out
	tween.chain().tween_interval(0.5)
	tween.chain().tween_property(container, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(container.queue_free)


# === MISSION SONUC ANIMASYONU ===

func show_mission_result(success: bool, cash: int, respect: int) -> void:
	var result_text := "MISSION COMPLETE!" if success else "MISSION FAILED"
	var result_color := ThemeConstants.SUCCESS_COLOR if success else ThemeConstants.DANGER_COLOR

	var label := Label.new()
	label.text = result_text
	label.add_theme_color_override("font_color", result_color)
	label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = size.y * 0.25
	label.size = Vector2(size.x, 50)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ZERO
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if success and cash > 0:
		tween.tween_callback(show_floating_text.bind(
			"+$%s" % ThemeConstants.format_number(cash),
			ThemeConstants.SUCCESS_COLOR,
			Vector2(0, size.y * 0.35)
		)).set_delay(0.2)

	if success and respect > 0:
		tween.tween_callback(show_floating_text.bind(
			"+%d Respect" % respect,
			ThemeConstants.NEON_BLUE,
			Vector2(0, size.y * 0.42)
		)).set_delay(0.15)

	tween.tween_interval(0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


# === BASKIN SONUC ANIMASYONU ===

func show_raid_result(result: String, territory_name: String, loot: int) -> void:
	var text: String
	var color: Color
	match result:
		"ATTACKER_WIN":
			text = "ZAFER!"
			color = ThemeConstants.SUCCESS_COLOR
		"DEFENDER_WIN":
			text = "YENILGI"
			color = ThemeConstants.DANGER_COLOR
		"DRAW":
			text = "BERABERE"
			color = ThemeConstants.PRIMARY_COLOR
		_:
			text = "SONUC"
			color = ThemeConstants.TEXT_PRIMARY

	# Ust baslik
	var title := Label.new()
	title.text = text
	title.add_theme_color_override("font_color", color)
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position.y = -80
	title.size = Vector2(size.x, 60)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ZERO
	add_child(title)

	# Bolge adi
	var sub := Label.new()
	sub.text = territory_name
	sub.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	sub.add_theme_font_size_override("font_size", ThemeConstants.FONT_SUBHEADING)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.position.y = -20
	sub.size = Vector2(size.x, 30)
	sub.modulate.a = 0.0
	add_child(sub)

	var tween := create_tween()
	# Title zoom in
	tween.tween_property(title, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.15)
	# Sub fade in
	tween.parallel().tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.15)

	# Loot floating text
	if result == "ATTACKER_WIN" and loot > 0:
		tween.tween_callback(show_floating_text.bind(
			"+$%s YAGMA" % ThemeConstants.format_number(loot),
			ThemeConstants.SUCCESS_COLOR,
			Vector2(0, size.y * 0.55)
		)).set_delay(0.3)

	# Hold + fade out
	tween.tween_interval(1.0)
	tween.tween_property(title, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(sub, "modulate:a", 0.0, 0.3)
	tween.tween_callback(title.queue_free)
	tween.tween_callback(sub.queue_free)


# === BILDIRIM SISTEMI ===

func _on_notification_queued(text: String, type: String) -> void:
	if _notification_queue.size() >= NOTIFICATION_MAX_QUEUE:
		return

	_notification_queue.append({"text": text, "type": type})
	if not _is_showing_notification:
		_show_next_notification()


func _show_next_notification() -> void:
	if _notification_queue.is_empty():
		_is_showing_notification = false
		return

	_is_showing_notification = true
	var data: Dictionary = _notification_queue.pop_front()

	var color: Color
	match data.get("type", "info"):
		"success": color = ThemeConstants.SUCCESS_COLOR
		"warning": color = ThemeConstants.PRIMARY_COLOR
		"error": color = ThemeConstants.DANGER_COLOR
		_: color = ThemeConstants.TEXT_PRIMARY

	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(ThemeConstants.SURFACE_COLOR, 0.95)
	stylebox.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	stylebox.content_margin_left = ThemeConstants.CARD_PADDING
	stylebox.content_margin_right = ThemeConstants.CARD_PADDING
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	stylebox.border_width_left = 3
	stylebox.border_color = color
	panel.add_theme_stylebox_override("panel", stylebox)

	panel.position = Vector2(ThemeConstants.SCREEN_MARGIN, -60)
	panel.size = Vector2(size.x - ThemeConstants.SCREEN_MARGIN * 2, 50)
	add_child(panel)

	var label := Label.new()
	label.text = data["text"]
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(label)

	# Slide in
	var tween := create_tween()
	tween.tween_property(panel, "position:y", ThemeConstants.SCREEN_MARGIN, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _notification_timer.start(NOTIFICATION_DISPLAY_TIME))

	# Timeout'ta slide out
	_notification_timer.timeout.connect(func():
		var out_tween := create_tween()
		out_tween.tween_property(panel, "position:y", -60.0, 0.15)
		out_tween.tween_callback(panel.queue_free)
		out_tween.tween_callback(_show_next_notification)
	, CONNECT_ONE_SHOT)


# === SINYAL YANITLARI ===

func _on_cash_changed(_pid: String, _amount: int, delta: int) -> void:
	if delta > 0:
		show_floating_text("+$%s" % ThemeConstants.format_number(delta), ThemeConstants.SUCCESS_COLOR)
	elif delta < 0:
		show_floating_text("-$%s" % ThemeConstants.format_number(absi(delta)), ThemeConstants.DANGER_COLOR)


func _on_premium_changed(_pid: String, _amount: int, delta: int) -> void:
	if delta > 0:
		show_floating_text("+%d Premium" % delta, ThemeConstants.RARITY_LEGENDARY)


func _on_respect_gained(amount: int, _source: String) -> void:
	show_floating_text("+%d Respect" % amount, ThemeConstants.NEON_BLUE)


func _on_rank_up(new_rank: int, rank_name: String) -> void:
	show_rank_up(rank_name)


func _on_item_acquired(item_id: String, _quantity: int) -> void:
	var item: Dictionary = ItemDB.get_item(item_id) if ItemDB.has_method("get_item") else {}
	var item_name: String = item.get("name", item_id)
	var rarity: String = item.get("rarity", "COMMON")
	show_loot_drop(item_name, rarity)


func _on_mission_completed(mission_id: String, success: bool, rewards: Dictionary) -> void:
	var cash: int = rewards.get("cash", 0)
	var respect: int = rewards.get("respect", 0)
	show_mission_result(success, cash, respect)


func _on_show_floating_text(text: String, color: Color, pos: Vector2) -> void:
	show_floating_text(text, color, pos)


func _on_raid_resolved(raid_id: String, result: String) -> void:
	var territory_mgr: Node = get_node_or_null("/root/TerritoryManager")
	var war_mgr: Node = get_node_or_null("/root/GangWarManager")
	var territory_name := "Bolge"
	var loot := 0

	if war_mgr:
		for raid in war_mgr.raid_history:
			if raid.get("raid_id", "") == raid_id:
				loot = raid.get("loot_stolen", 0)
				if territory_mgr:
					var t: Dictionary = territory_mgr.get_territory(raid.get("target_territory_id", ""))
					territory_name = t.get("name", "Bolge")
				break

	show_raid_result(result, territory_name, loot)
