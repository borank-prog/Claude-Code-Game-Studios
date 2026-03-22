## HUD ust bar — rank, stamina, cash, respect gosterimi.
extends PanelContainer

@onready var rank_label: Label = %RankLabel
@onready var power_label: Label = %PowerLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_text: Label = %StaminaText
@onready var regen_text: Label = %RegenText
@onready var cash_label: Label = %CashLabel
@onready var premium_label: Label = %PremiumLabel
@onready var respect_bar: ProgressBar = %RespectBar
@onready var respect_text: Label = %RespectText


func _ready() -> void:
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.cash_changed.connect(_on_cash_changed)
	EventBus.premium_changed.connect(_on_premium_changed)
	EventBus.respect_gained.connect(_on_respect_gained)
	EventBus.rank_up.connect(_on_rank_up)
	EventBus.stat_changed.connect(_on_stat_changed)
	_apply_hud_styling()
	call_deferred("_refresh_all")


func _process(_delta: float) -> void:
	# Regen timer guncelle
	var remaining := StaminaManager.get_regen_remaining()
	if remaining > 0:
		var mins := int(remaining) / 60
		var secs := int(remaining) % 60
		regen_text.text = "+1 in %d:%02d" % [mins, secs]
		regen_text.visible = true
	else:
		regen_text.visible = false


func _refresh_all() -> void:
	_update_rank()
	_update_power()
	_update_stamina()
	_update_cash()
	_update_respect()


func _apply_hud_styling() -> void:
	# Rank label — altin neon
	rank_label.add_theme_color_override("font_color", NeonTheme.PRIMARY)
	rank_label.add_theme_font_size_override("font_size", 16)

	# Power label
	power_label.add_theme_color_override("font_color", NeonTheme.NEON_ORANGE)
	power_label.add_theme_font_size_override("font_size", 13)

	# Stamina bar — yesil fill
	var stam_bg := StyleBoxFlat.new()
	stam_bg.bg_color = Color(0.08, 0.15, 0.08)
	stam_bg.corner_radius_top_left = 4
	stam_bg.corner_radius_top_right = 4
	stam_bg.corner_radius_bottom_left = 4
	stam_bg.corner_radius_bottom_right = 4
	stamina_bar.add_theme_stylebox_override("background", stam_bg)

	var stam_fill := StyleBoxFlat.new()
	stam_fill.bg_color = NeonTheme.SUCCESS
	stam_fill.corner_radius_top_left = 4
	stam_fill.corner_radius_top_right = 4
	stam_fill.corner_radius_bottom_left = 4
	stam_fill.corner_radius_bottom_right = 4
	stamina_bar.add_theme_stylebox_override("fill", stam_fill)

	stamina_text.add_theme_color_override("font_color", NeonTheme.SUCCESS)
	stamina_text.add_theme_font_size_override("font_size", 13)
	regen_text.add_theme_color_override("font_color", NeonTheme.TEXT_SECONDARY)
	regen_text.add_theme_font_size_override("font_size", 12)

	# Cash — yesil
	cash_label.add_theme_color_override("font_color", NeonTheme.SUCCESS)
	cash_label.add_theme_font_size_override("font_size", 15)
	# Premium — altin
	premium_label.add_theme_color_override("font_color", NeonTheme.PRIMARY)
	premium_label.add_theme_font_size_override("font_size", 15)

	# Respect bar — mavi neon
	var resp_bg := StyleBoxFlat.new()
	resp_bg.bg_color = Color(0.05, 0.08, 0.15)
	resp_bg.corner_radius_top_left = 3
	resp_bg.corner_radius_top_right = 3
	resp_bg.corner_radius_bottom_left = 3
	resp_bg.corner_radius_bottom_right = 3
	respect_bar.add_theme_stylebox_override("background", resp_bg)

	var resp_fill := StyleBoxFlat.new()
	resp_fill.bg_color = NeonTheme.NEON_BLUE
	resp_fill.corner_radius_top_left = 3
	resp_fill.corner_radius_top_right = 3
	resp_fill.corner_radius_bottom_left = 3
	resp_fill.corner_radius_bottom_right = 3
	respect_bar.add_theme_stylebox_override("fill", resp_fill)

	respect_text.add_theme_color_override("font_color", NeonTheme.NEON_BLUE)
	respect_text.add_theme_font_size_override("font_size", 12)


func _update_rank() -> void:
	rank_label.text = "Rank %d: %s" % [GameData.rank, GameData.get_rank_name()]


func _update_power() -> void:
	power_label.text = "Power: %s" % ThemeConstants.format_number(GameData.get_total_power())


func _update_stamina() -> void:
	stamina_bar.max_value = StaminaManager.max_stamina
	stamina_bar.value = StaminaManager.current
	stamina_text.text = "%d/%d" % [StaminaManager.current, StaminaManager.max_stamina]


func _update_cash() -> void:
	cash_label.text = "$%s" % ThemeConstants.format_number(GameData.cash)
	premium_label.text = "%s" % ThemeConstants.format_number(GameData.premium_currency)


func _update_respect() -> void:
	var current := GameData.respect
	var current_rank_resp := GameData.get_respect_for_rank(GameData.rank)
	var next_rank_resp := GameData.get_next_rank_respect()
	var progress := current - current_rank_resp
	var needed := next_rank_resp - current_rank_resp

	respect_bar.max_value = maxi(needed, 1)
	respect_bar.value = clampi(progress, 0, needed)
	respect_text.text = "%s / %s" % [
		ThemeConstants.format_number(current),
		ThemeConstants.format_number(next_rank_resp)
	]


# === SINYAL YANITLARI ===
func _on_stamina_changed(_current: int, _max: int) -> void:
	_update_stamina()

func _on_cash_changed(_pid: String, _amount: int, _delta: int) -> void:
	_update_cash()

func _on_premium_changed(_pid: String, _amount: int, _delta: int) -> void:
	_update_cash()

func _on_respect_gained(_amount: int, _source: String) -> void:
	_update_respect()

func _on_rank_up(_new_rank: int, _rank_name: String) -> void:
	_refresh_all()

func _on_stat_changed(_stat: String, _val: int, _delta: int) -> void:
	_update_power()
