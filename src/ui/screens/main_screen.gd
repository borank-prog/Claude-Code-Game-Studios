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


	# Feedback artik FeedbackController (feedback_container script) tarafindan yonetiliyor
