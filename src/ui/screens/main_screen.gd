## Ana ekran — tab navigasyonu, HUD, ekran yonetimi.
## Tum alt ekranlari icerir ve tab bar ile gecis saglar.
extends Control

@onready var hud_bar: PanelContainer = %HudBar
@onready var content_area: Control = %ContentArea
@onready var tab_home: Button = %TabHome
@onready var tab_missions: Button = %TabMissions
@onready var tab_map: Button = %TabMap
@onready var tab_gang: Button = %TabGang
@onready var tab_shop: Button = %TabShop
@onready var feedback_container: Control = %FeedbackContainer

var current_tab: String = "home"
var tab_buttons: Dictionary = {}


func _ready() -> void:
	# Hemen oynanabilir olsun — auth arka planda
	if GameData.player_id.is_empty():
		GameData.initialize_new_player("local_%d" % randi(), "Player")

	# Tab butonlarini bagla
	tab_buttons = {
		"home": tab_home,
		"missions": tab_missions,
		"map": tab_map,
		"gang": tab_gang,
		"shop": tab_shop,
	}

	for tab_name in tab_buttons:
		tab_buttons[tab_name].pressed.connect(_on_tab_pressed.bind(tab_name))

	# Firebase auth arka planda
	FirebaseAuth.auth_completed.connect(_on_auth_completed)
	FirebaseAuth.auth_failed.connect(_on_auth_failed)
	FirebaseAuth.sign_in_anonymous()

	# Feedback sinyalleri
	EventBus.cash_changed.connect(_on_cash_changed)
	EventBus.respect_gained.connect(_on_respect_gained)
	EventBus.rank_up.connect(_on_rank_up)

	_switch_tab("home")


func _on_auth_completed(success: bool, user_id: String) -> void:
	if success:
		GameData.player_id = user_id
		CloudSave.start_after_auth()


func _on_auth_failed(error: String) -> void:
	push_warning("Auth failed (offline mode): %s" % error)


func _on_tab_pressed(tab_name: String) -> void:
	_switch_tab(tab_name)


func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	ScreenManager.switch_screen(tab_name)

	# Tab renklerini guncelle
	for tn in tab_buttons:
		var btn: Button = tab_buttons[tn]
		if tn == tab_name:
			btn.modulate = ThemeConstants.PRIMARY_COLOR
		else:
			btn.modulate = ThemeConstants.TEXT_SECONDARY

	# Ekran icerigini guncelle
	for child in content_area.get_children():
		child.visible = false

	if content_area.has_node(tab_name):
		content_area.get_node(tab_name).visible = true


# === FEEDBACK ===
func _on_cash_changed(_pid: String, _amount: int, delta: int) -> void:
	if delta > 0:
		_show_floating_text("+$%s" % ThemeConstants.format_number(delta), ThemeConstants.SUCCESS_COLOR)
	elif delta < 0:
		_show_floating_text("-$%s" % ThemeConstants.format_number(absi(delta)), ThemeConstants.DANGER_COLOR)


func _on_respect_gained(amount: int, _source: String) -> void:
	_show_floating_text("+%d Respect" % amount, ThemeConstants.NEON_BLUE)


func _on_rank_up(_new_rank: int, rank_name: String) -> void:
	_show_floating_text("RANK UP! %s" % rank_name, ThemeConstants.PRIMARY_COLOR)


func _show_floating_text(text: String, color: Color) -> void:
	if feedback_container == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SUBHEADING)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, feedback_container.size.y / 2.0)
	label.size = Vector2(feedback_container.size.x, 40)
	feedback_container.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, ThemeConstants.FEEDBACK_FLOAT_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, ThemeConstants.FEEDBACK_FLOAT_DURATION).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
