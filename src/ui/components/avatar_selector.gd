## Avatar secim paneli — 10 karakter portresi, rank badge, equipment overlay.
## Home ekranindan popup olarak acilir.
extends PanelContainer

signal avatar_selected(avatar_id: int)

var _avatar_buttons: Array[Button] = []

const AVATAR_COUNT: int = 10
const AVATAR_NAMES: PackedStringArray = [
	"Sokak Cocugu", "Gangster", "Hustler", "Dealer",
	"Enforcer", "Shadow", "Boss Lady", "OG",
	"Hitman", "Kingpin"
]

# Renk paleti — her avatar icin benzersiz tema rengi (placeholder olarak)
const AVATAR_COLORS: Array[Color] = [
	Color("4A90D9"), Color("D94A4A"), Color("4AD97B"), Color("D9B44A"),
	Color("9B4AD9"), Color("D94A9B"), Color("4AD9D9"), Color("D9824A"),
	Color("7BD94A"), Color("D9D94A"),
]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(ThemeConstants.SURFACE_COLOR, 0.98)
	stylebox.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	stylebox.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	stylebox.content_margin_left = ThemeConstants.CARD_PADDING
	stylebox.content_margin_right = ThemeConstants.CARD_PADDING
	stylebox.content_margin_top = ThemeConstants.CARD_PADDING
	stylebox.content_margin_bottom = ThemeConstants.CARD_PADDING
	add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Baslik
	var title := Label.new()
	title.text = "Karakter Sec"
	title.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Grid container — 2 sutun, 5 satir
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	for i in AVATAR_COUNT:
		var btn := _create_avatar_button(i)
		grid.add_child(btn)
		_avatar_buttons.append(btn)

	_highlight_current()


func _create_avatar_button(avatar_id: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 70)

	# Avatar ikon — renkli daire + harf (placeholder, gercek art gelene kadar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)

	var icon_bg := ColorRect.new()
	icon_bg.color = AVATAR_COLORS[avatar_id]
	icon_bg.custom_minimum_size = Vector2(48, 48)
	hbox.add_child(icon_bg)

	var initial := Label.new()
	initial.text = AVATAR_NAMES[avatar_id].left(1)
	initial.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	initial.add_theme_font_size_override("font_size", 24)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.size = Vector2(48, 48)
	initial.position = Vector2.ZERO
	icon_bg.add_child(initial)

	var name_label := Label.new()
	name_label.text = AVATAR_NAMES[avatar_id]
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	hbox.add_child(name_label)

	btn.pressed.connect(_on_avatar_pressed.bind(avatar_id))
	return btn


func _on_avatar_pressed(avatar_id: int) -> void:
	GameData.avatar_id = avatar_id
	avatar_selected.emit(avatar_id)
	_highlight_current()


func _highlight_current() -> void:
	for i in _avatar_buttons.size():
		var btn := _avatar_buttons[i]
		if i == GameData.avatar_id:
			btn.modulate = ThemeConstants.PRIMARY_COLOR
		else:
			btn.modulate = Color.WHITE


## Secili avatar'in rengini dondur (dis sistemler icin)
static func get_avatar_color(avatar_id: int) -> Color:
	if avatar_id >= 0 and avatar_id < AVATAR_COLORS.size():
		return AVATAR_COLORS[avatar_id]
	return AVATAR_COLORS[0]


## Secili avatar'in adini dondur
static func get_avatar_name(avatar_id: int) -> String:
	if avatar_id >= 0 and avatar_id < AVATAR_NAMES.size():
		return AVATAR_NAMES[avatar_id]
	return AVATAR_NAMES[0]
