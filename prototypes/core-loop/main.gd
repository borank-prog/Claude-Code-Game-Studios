# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the core mission loop satisfying on mobile?
# Date: 2026-03-22
extends Control

# UI References
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel
@onready var cash_label: Label = %CashLabel
@onready var respect_label: Label = %RespectLabel
@onready var rank_label: Label = %RankLabel
@onready var power_label: Label = %PowerLabel
@onready var mission_container: VBoxContainer = %MissionContainer
@onready var shop_container: VBoxContainer = %ShopContainer
@onready var result_panel: Panel = %ResultPanel
@onready var result_label: RichTextLabel = %ResultLabel
@onready var tab_missions: Button = %TabMissions
@onready var tab_shop: Button = %TabShop
@onready var tab_stats: Button = %TabStats
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var mission_progress: ProgressBar = %MissionProgress
@onready var feedback_label: Label = %FeedbackLabel

var data: Node  # GameData autoload
var current_tab: String = "missions"
var is_mission_running: bool = false
var mission_timer: float = 0.0
var mission_duration: float = 0.0
var current_mission: Dictionary = {}

func _ready() -> void:
	data = get_node("/root/GameData")
	data.last_regen_time = Time.get_ticks_msec() / 1000.0

	tab_missions.pressed.connect(_on_tab_missions)
	tab_shop.pressed.connect(_on_tab_shop)
	tab_stats.pressed.connect(_on_tab_stats)

	_build_mission_list()
	_build_shop_list()
	_build_stats_list()
	_update_hud()
	_show_tab("missions")
	result_panel.visible = false
	mission_progress.visible = false
	feedback_label.text = ""

func _process(delta: float) -> void:
	data.update_stamina()
	_update_hud()

	if is_mission_running:
		mission_timer += delta
		mission_progress.value = (mission_timer / mission_duration) * 100.0
		if mission_timer >= mission_duration:
			_resolve_mission()

func _update_hud() -> void:
	stamina_bar.max_value = data.max_stamina
	stamina_bar.value = data.stamina
	stamina_label.text = "Stamina: %d/%d" % [data.stamina, data.max_stamina]
	cash_label.text = "Cash: $%s" % _format_number(data.cash)
	respect_label.text = "Respect: %s / %s" % [_format_number(data.respect), _format_number(data.get_next_rank_respect())]
	rank_label.text = "Rank %d: %s" % [data.rank, data.get_rank_name()]
	power_label.text = "Power: %d" % data.calculate_power_score()

func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)

# === TABS ===
func _show_tab(tab: String) -> void:
	current_tab = tab
	mission_container.visible = tab == "missions"
	shop_container.visible = tab == "shop"
	stats_container.visible = tab == "stats"
	tab_missions.modulate = Color.WHITE if tab == "missions" else Color(0.5, 0.5, 0.5)
	tab_shop.modulate = Color.WHITE if tab == "shop" else Color(0.5, 0.5, 0.5)
	tab_stats.modulate = Color.WHITE if tab == "stats" else Color(0.5, 0.5, 0.5)

func _on_tab_missions() -> void:
	_show_tab("missions")
func _on_tab_shop() -> void:
	_show_tab("shop")
func _on_tab_stats() -> void:
	_build_stats_list()
	_show_tab("stats")

# === MISSIONS ===
func _build_mission_list() -> void:
	for child in mission_container.get_children():
		child.queue_free()

	for mission in data.MISSIONS:
		var btn := Button.new()
		var success_rate := _calc_success_rate(mission)
		btn.text = "%s [%s]\nStamina: %d | Cash: $%d-%d | Resp: +%d | Basari: %%%d" % [
			mission["name"], mission["difficulty"],
			mission["stamina_cost"], mission["cash_min"], mission["cash_max"],
			mission["respect"], int(success_rate * 100)
		]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.pressed.connect(_on_mission_pressed.bind(mission))

		if data.stamina < mission["stamina_cost"]:
			btn.modulate = Color(0.5, 0.3, 0.3)
		mission_container.add_child(btn)

func _calc_success_rate(mission: Dictionary) -> float:
	var rate: float = mission["base_success"]
	rate += data.get_stat(mission["stat"]) * mission["stat_influence"]
	return clampf(rate, 0.05, 0.95)

func _on_mission_pressed(mission: Dictionary) -> void:
	if is_mission_running:
		return
	if data.stamina < mission["stamina_cost"]:
		_show_feedback("Yetersiz stamina!", Color.RED)
		return

	data.stamina -= mission["stamina_cost"]
	current_mission = mission
	is_mission_running = true
	mission_timer = 0.0
	mission_duration = mission["duration"]
	mission_progress.visible = true
	mission_progress.value = 0
	_show_feedback("%s baslatildi..." % mission["name"], Color.YELLOW)

func _resolve_mission() -> void:
	is_mission_running = false
	mission_progress.visible = false

	var success_rate := _calc_success_rate(current_mission)
	var roll := randf()
	var success := roll <= success_rate

	if success:
		var cash_earned: int = randi_range(current_mission["cash_min"], current_mission["cash_max"])
		var charisma_bonus: float = 1.0 + data.charisma * 0.02
		cash_earned = int(cash_earned * charisma_bonus)
		var respect_earned: int = current_mission["respect"]

		data.cash += cash_earned
		data.respect += respect_earned

		var result_text := "[color=green]BASARILI![/color]\n\n"
		result_text += "[color=yellow]+$%s cash[/color]\n" % _format_number(cash_earned)
		result_text += "[color=cyan]+%d respect[/color]\n" % respect_earned

		# Loot chance (prototype: random stat boost)
		if randf() < 0.15:  # %15 loot sansi
			var bonus_stat: String = ["strength", "endurance", "charisma", "luck"].pick_random()
			match bonus_stat:
				"strength": data.strength += 1
				"endurance":
					data.endurance += 1
					data.recalculate_max_stamina()
				"charisma": data.charisma += 1
				"luck": data.luck += 1
			result_text += "\n[color=magenta]BONUS: +1 %s![/color]" % bonus_stat

		# Rank up check
		if data.check_rank_up():
			result_text += "\n\n[color=gold]*** RANK UP! ***[/color]\n"
			result_text += "[color=gold]%s[/color]" % data.get_rank_name()

		_show_result(result_text)
	else:
		data.respect += max(1, current_mission["respect"] / 5)
		var result_text := "[color=red]BASARISIZ![/color]\n\n"
		result_text += "Stamina kaybedildi.\n"
		result_text += "[color=gray]+%d respect (deneme icin)[/color]" % max(1, current_mission["respect"] / 5)
		_show_result(result_text)

	_build_mission_list()
	_build_stats_list()

# === SHOP ===
func _build_shop_list() -> void:
	for child in shop_container.get_children():
		child.queue_free()

	for item in data.SHOP_ITEMS:
		var btn := Button.new()
		var owned := data.equipped_weapon_id == item["id"]
		btn.text = "%s%s\nFiyat: $%s | Guc: +%d | %s: +%d" % [
			item["name"],
			" [KUSANIL]" if owned else "",
			_format_number(item["price"]), item["power"],
			item["stat"], item["stat_bonus"]
		]
		btn.custom_minimum_size = Vector2(0, 70)

		if owned:
			btn.modulate = Color(0.3, 0.8, 0.3)
		elif data.cash < item["price"]:
			btn.modulate = Color(0.5, 0.3, 0.3)

		btn.pressed.connect(_on_shop_pressed.bind(item))
		shop_container.add_child(btn)

func _on_shop_pressed(item: Dictionary) -> void:
	if data.equipped_weapon_id == item["id"]:
		_show_feedback("Zaten kusanili!", Color.YELLOW)
		return
	if data.cash < item["price"]:
		_show_feedback("Yetersiz cash!", Color.RED)
		return

	data.cash -= item["price"]
	data.equipped_weapon_id = item["id"]
	data.equipment_power = item["power"]

	# Apply stat bonus
	match item["stat"]:
		"strength": data.strength += item["stat_bonus"]
		"endurance":
			data.endurance += item["stat_bonus"]
			data.recalculate_max_stamina()
		"charisma": data.charisma += item["stat_bonus"]
		"luck": data.luck += item["stat_bonus"]

	_show_feedback("%s satin alindi! Power: %d" % [item["name"], data.calculate_power_score()], Color.GREEN)
	_build_shop_list()
	_build_mission_list()
	_build_stats_list()

# === STATS ===
func _build_stats_list() -> void:
	for child in stats_container.get_children():
		child.queue_free()

	var stats_text := [
		"Strength: %d" % data.strength,
		"Endurance: %d" % data.endurance,
		"Charisma: %d" % data.charisma,
		"Luck: %d" % data.luck,
		"",
		"Power Score: %d" % data.calculate_power_score(),
		"Equipment Power: %d" % data.equipment_power,
		"Max Stamina: %d" % data.max_stamina,
		"",
		"Toplam Gorev Basari Oranlari:",
	]

	for mission in data.MISSIONS:
		var rate := _calc_success_rate(mission)
		stats_text.append("  %s: %%%d" % [mission["name"], int(rate * 100)])

	for line in stats_text:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 16)
		stats_container.add_child(lbl)

# === FEEDBACK ===
func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	var tween := create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0.0, 2.0).from(1.0)

func _show_result(text: String) -> void:
	result_label.text = text
	result_panel.visible = true
	# Auto-hide after 3 seconds
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): result_panel.visible = false)

func _on_result_close() -> void:
	result_panel.visible = false
