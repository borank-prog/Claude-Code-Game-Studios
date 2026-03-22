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

const TAB_ICONS: Dictionary = {
	"home": "HOME",
	"missions": "GOREV",
	"map": "HARITA",
	"gang": "CETE",
	"shop": "SHOP",
}


func _ready() -> void:
	# Global neon tema uygula
	theme = NeonTheme.create_theme()

	# Hemen oynanabilir olsun — auth arka planda
	if GameData.player_id.is_empty():
		GameData.initialize_new_player("local_%d" % randi(), "Player")

	# Tab butonlarini bagla + stille
	tab_buttons = {
		"home": tab_home,
		"missions": tab_missions,
		"map": tab_map,
		"gang": tab_gang,
		"shop": tab_shop,
	}

	for tab_name in tab_buttons:
		var btn: Button = tab_buttons[tab_name]
		btn.pressed.connect(_on_tab_pressed.bind(tab_name))
		btn.text = TAB_ICONS.get(tab_name, tab_name)

	# HUD bar stili
	_style_hud_bar()
	# Tab bar stili
	_style_tab_bar()

	# Firebase auth arka planda
	FirebaseAuth.auth_completed.connect(_on_auth_completed)
	FirebaseAuth.auth_failed.connect(_on_auth_failed)
	FirebaseAuth.sign_in_anonymous()

	_switch_tab("home")

	# Tutorial — ilk giris icin
	call_deferred("_start_tutorial")


func _start_tutorial() -> void:
	var TutorialOverlay := preload("res://src/ui/components/tutorial_overlay.gd")
	var tutorial := CanvasLayer.new()
	tutorial.set_script(TutorialOverlay)
	add_child(tutorial)
	tutorial.start_if_needed()


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
			btn.add_theme_color_override("font_color", NeonTheme.PRIMARY)
			# Ust border goster
			var active_sb := StyleBoxFlat.new()
			active_sb.bg_color = Color.TRANSPARENT
			active_sb.border_width_top = 3
			active_sb.border_color = NeonTheme.PRIMARY
			active_sb.content_margin_top = 12
			active_sb.content_margin_bottom = 12
			btn.add_theme_stylebox_override("normal", active_sb)
		else:
			btn.add_theme_color_override("font_color", NeonTheme.TEXT_SECONDARY)
			var inactive_sb := StyleBoxFlat.new()
			inactive_sb.bg_color = Color.TRANSPARENT
			inactive_sb.content_margin_top = 12
			inactive_sb.content_margin_bottom = 12
			btn.add_theme_stylebox_override("normal", inactive_sb)

	# Ekran icerigini guncelle
	for child in content_area.get_children():
		child.visible = false

	if content_area.has_node(tab_name):
		content_area.get_node(tab_name).visible = true


	# Feedback artik FeedbackController (feedback_container script) tarafindan yonetiliyor


func _style_hud_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	style.border_width_bottom = 2
	style.border_color = NeonTheme.PRIMARY.darkened(0.5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud_bar.add_theme_stylebox_override("panel", style)


func _style_tab_bar() -> void:
	var tab_bar: HBoxContainer = tab_home.get_parent()

	# Tab bar arka plan — koyu panel
	var tab_panel := PanelContainer.new()
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = NeonTheme.TAB_BG
	tab_style.border_width_top = 1
	tab_style.border_color = NeonTheme.BORDER
	tab_panel.add_theme_stylebox_override("panel", tab_style)

	# Tab butonlari icin ozel stil
	for tab_name in tab_buttons:
		var btn: Button = tab_buttons[tab_name]
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.TRANSPARENT
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", normal)

		var pressed_sb := StyleBoxFlat.new()
		pressed_sb.bg_color = Color.TRANSPARENT
		pressed_sb.border_width_top = 3
		pressed_sb.border_color = NeonTheme.PRIMARY
		pressed_sb.content_margin_top = 12
		pressed_sb.content_margin_bottom = 12
		btn.add_theme_stylebox_override("pressed", pressed_sb)

		btn.add_theme_font_size_override("font_size", 13)
