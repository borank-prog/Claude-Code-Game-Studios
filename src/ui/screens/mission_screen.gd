## Gorev ekrani — gorev listesi, calistirma, sonuc gosterimi.
extends Control

@onready var mission_list: VBoxContainer = %MissionList
@onready var progress_bar: ProgressBar = %MissionProgress
@onready var progress_label: Label = %ProgressLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_text: RichTextLabel = %ResultText

var _result_timer: float = 0.0
var _showing_result: bool = false


func _ready() -> void:
	MissionSystem.mission_list_updated.connect(_on_missions_updated)
	MissionSystem.mission_started.connect(_on_mission_started)
	MissionSystem.mission_resolved.connect(_on_mission_resolved)
	EventBus.stamina_changed.connect(func(_c, _m): _refresh_list())
	EventBus.rank_up.connect(func(_r, _n): MissionSystem._refresh_mission_list())

	result_panel.visible = false
	progress_bar.visible = false
	_refresh_list()


func _process(delta: float) -> void:
	if MissionSystem.is_running():
		progress_bar.value = MissionSystem.get_progress() * 100.0

	if _showing_result:
		_result_timer -= delta
		if _result_timer <= 0:
			result_panel.visible = false
			_showing_result = false


func _refresh_list() -> void:
	_build_mission_buttons(MissionSystem.available_missions)


func _on_missions_updated(missions: Array) -> void:
	_build_mission_buttons(missions)


func _build_mission_buttons(missions: Array) -> void:
	for child in mission_list.get_children():
		child.queue_free()

	for mission in missions:
		var card := _create_mission_card(mission)
		mission_list.add_child(card)


func _create_mission_card(mission: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var style := StyleBoxFlat.new()
	style.bg_color = ThemeConstants.SURFACE_COLOR
	style.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	style.content_margin_left = ThemeConstants.CARD_PADDING
	style.content_margin_right = ThemeConstants.CARD_PADDING
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# Baslik satiri
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_label := Label.new()
	name_label.text = mission.get("name", "Gorev")
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var diff_label := Label.new()
	var difficulty: String = mission.get("difficulty", "EASY")
	diff_label.text = difficulty
	diff_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	diff_label.add_theme_color_override("font_color", _get_difficulty_color(difficulty))
	header.add_child(diff_label)

	# Detay satiri
	var detail := Label.new()
	var success_rate := MissionSystem.calculate_success_rate(mission)
	var cooldown := MissionSystem.get_cooldown_remaining(mission.get("mission_id", ""))
	detail.text = "Stamina: %d | $%d-%d | +%d Resp | %%%d" % [
		mission.get("stamina_cost", 5),
		mission.get("cash_reward_min", 0),
		mission.get("cash_reward_max", 0),
		mission.get("respect_reward", 0),
		int(success_rate * 100),
	]
	detail.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	detail.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	vbox.add_child(detail)

	# Dokunma
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(_on_mission_tapped.bind(mission))
	card.add_child(btn)

	# Durum renklendirmesi
	var can_play := StaminaManager.current >= mission.get("stamina_cost", 5) \
		and GameData.rank >= mission.get("required_rank", 0) \
		and cooldown <= 0 \
		and not MissionSystem.is_running()

	if not can_play:
		card.modulate = Color(0.5, 0.4, 0.4, 0.7)

		if cooldown > 0:
			detail.text += " | CD: %ds" % int(cooldown)

	return card


func _on_mission_tapped(mission: Dictionary) -> void:
	MissionSystem.start_mission(mission.get("mission_id", ""))


func _on_mission_started(_mission: Dictionary) -> void:
	progress_bar.visible = true
	progress_bar.value = 0
	progress_label.text = _mission.get("name", "")
	progress_label.visible = true
	_refresh_list()


func _on_mission_resolved(mission: Dictionary, success: bool, rewards: Dictionary) -> void:
	progress_bar.visible = false
	progress_label.visible = false
	_refresh_list()

	# Sonuc paneli
	var text := ""
	if success:
		text = "[color=#33FF57]BASARILI![/color]\n\n"
		text += "[color=#E2B714]+$%s cash[/color]\n" % ThemeConstants.format_number(rewards.get("cash", 0))
		text += "[color=#00D4FF]+%d respect[/color]\n" % rewards.get("respect", 0)
		if rewards.get("loot") != null:
			var loot: Dictionary = rewards["loot"]
			var rarity_color := ThemeConstants.get_rarity_color(loot.get("rarity", "COMMON")).to_html(false)
			text += "\n[color=#%s]LOOT: %s[/color]" % [rarity_color, loot.get("name", "???")]
	else:
		text = "[color=#FF3333]BASARISIZ![/color]\n\n"
		text += "Stamina kaybedildi.\n"
		text += "[color=#888888]+%d respect (deneme)[/color]" % rewards.get("respect", 0)

	result_text.text = text
	result_panel.visible = true
	_showing_result = true
	_result_timer = 3.0


func _get_difficulty_color(difficulty: String) -> Color:
	match difficulty:
		"EASY": return ThemeConstants.SUCCESS_COLOR
		"MEDIUM": return ThemeConstants.PRIMARY_COLOR
		"HARD": return ThemeConstants.NEON_ACCENT
		"EXTREME": return ThemeConstants.DANGER_COLOR
		_: return ThemeConstants.TEXT_SECONDARY
