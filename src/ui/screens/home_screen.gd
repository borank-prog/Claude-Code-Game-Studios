## Ana sayfa — profil ozeti, avatar secimi, rank badge, stat dagitimi.
extends Control

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var name_label: Label = %NameLabel
@onready var rank_title: Label = %RankTitle
@onready var power_value: Label = %PowerValue
@onready var stat_container: VBoxContainer = %StatContainer
@onready var stat_points_label: Label = %StatPointsLabel
@onready var equip_container: VBoxContainer = %EquipContainer

var _avatar_selector: PanelContainer = null
var _avatar_color_rect: ColorRect = null
var _avatar_initial: Label = null
var _rank_badge: Label = null

const STAT_NAMES: Dictionary = {
	"strength": "Guc",
	"endurance": "Dayaniklilik",
	"charisma": "Karizma",
	"luck": "Sans",
	"intelligence": "Zeka",
}

const AvatarSelector := preload("res://src/ui/components/avatar_selector.gd")


func _ready() -> void:
	EventBus.stat_changed.connect(func(_s, _v, _d): _refresh())
	EventBus.rank_up.connect(func(_r, _n): _refresh())
	EventBus.equipment_changed.connect(func(_s, _i): _refresh())
	EventBus.stat_points_available.connect(func(_p): _refresh())
	visibility_changed.connect(_on_visible)
	_setup_avatar_display()
	call_deferred("_refresh")


func _on_visible() -> void:
	if visible:
		_refresh()


## Avatar gorsel alanini ayarla — renkli placeholder + rank badge
func _setup_avatar_display() -> void:
	# Avatar renkli placeholder (TextureRect yerine uzerine ColorRect + Label)
	_avatar_color_rect = ColorRect.new()
	_avatar_color_rect.custom_minimum_size = Vector2(80, 80)
	_avatar_color_rect.size = Vector2(80, 80)
	_avatar_color_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	avatar_rect.add_child(_avatar_color_rect)

	_avatar_initial = Label.new()
	_avatar_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_initial.add_theme_font_size_override("font_size", 36)
	_avatar_initial.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	_avatar_initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_color_rect.add_child(_avatar_initial)

	# Rank badge — sol ust kose
	_rank_badge = Label.new()
	_rank_badge.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	_rank_badge.add_theme_color_override("font_color", ThemeConstants.BG_COLOR)
	_rank_badge.position = Vector2(0, 0)
	_rank_badge.size = Vector2(28, 20)
	_rank_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_rect.add_child(_rank_badge)

	# Avatar'a tikla — secim paneli ac
	var click_btn := Button.new()
	click_btn.flat = true
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	click_btn.pressed.connect(_toggle_avatar_selector)
	avatar_rect.add_child(click_btn)


func _update_avatar_display() -> void:
	var color := AvatarSelector.get_avatar_color(GameData.avatar_id)
	_avatar_color_rect.color = color
	_avatar_initial.text = AvatarSelector.get_avatar_name(GameData.avatar_id).left(1)

	# Rank badge
	_rank_badge.text = str(GameData.rank)
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = ThemeConstants.PRIMARY_COLOR
	badge_bg.corner_radius_bottom_right = 6
	_rank_badge.add_theme_stylebox_override("normal", badge_bg)


func _toggle_avatar_selector() -> void:
	if _avatar_selector != null:
		_avatar_selector.queue_free()
		_avatar_selector = null
		return

	_avatar_selector = AvatarSelector.new()
	_avatar_selector.position = Vector2(0, avatar_rect.size.y + 8)
	_avatar_selector.z_index = 10
	_avatar_selector.avatar_selected.connect(func(_id):
		_update_avatar_display()
		_avatar_selector.queue_free()
		_avatar_selector = null
	)
	add_child(_avatar_selector)


func _refresh() -> void:
	# Profil bilgileri
	name_label.text = GameData.display_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", NeonTheme.TEXT_PRIMARY)

	rank_title.text = "Rank %d — %s" % [GameData.rank, GameData.get_rank_name()]
	rank_title.add_theme_font_size_override("font_size", 16)
	rank_title.add_theme_color_override("font_color", NeonTheme.PRIMARY)

	power_value.text = "Power: %s" % ThemeConstants.format_number(InventoryManager.get_total_power())
	power_value.add_theme_font_size_override("font_size", 14)
	power_value.add_theme_color_override("font_color", NeonTheme.NEON_ORANGE)

	_update_avatar_display()
	_build_stats()
	_build_equipment()


func _build_stats() -> void:
	for child in stat_container.get_children():
		child.queue_free()

	stat_points_label.text = "Stat Puanlari: %d" % GameData.unspent_stat_points
	stat_points_label.visible = GameData.unspent_stat_points > 0
	stat_points_label.add_theme_color_override("font_color", NeonTheme.PRIMARY)
	stat_points_label.add_theme_font_size_override("font_size", 16)

	var stat_colors := {
		"strength": NeonTheme.DANGER,
		"endurance": NeonTheme.SUCCESS,
		"charisma": NeonTheme.PRIMARY,
		"luck": NeonTheme.NEON_ORANGE,
		"intelligence": NeonTheme.NEON_BLUE,
	}

	for stat_name in STAT_NAMES:
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = NeonTheme.CARD_BG
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.border_width_left = 3
		card_style.border_color = stat_colors.get(stat_name, NeonTheme.TEXT_SECONDARY)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 6
		card_style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", card_style)
		stat_container.add_child(card)

		var row := HBoxContainer.new()
		card.add_child(row)

		var base_val := GameData.get_stat(stat_name)
		var equip_bonus := InventoryManager.get_equipment_stat_bonus(stat_name)
		var stat_color: Color = stat_colors.get(stat_name, NeonTheme.TEXT_PRIMARY)

		# Sol: isim + deger
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_hbox := HBoxContainer.new()
		info.add_child(name_hbox)

		var label := Label.new()
		label.text = STAT_NAMES[stat_name]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", stat_color)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_hbox.add_child(label)

		var val_label := Label.new()
		val_label.text = "%d" % base_val
		if equip_bonus > 0:
			val_label.text += " (+%d)" % equip_bonus
		val_label.add_theme_font_size_override("font_size", 16)
		val_label.add_theme_color_override("font_color", NeonTheme.TEXT_PRIMARY)
		name_hbox.add_child(val_label)

		var cap_label := Label.new()
		cap_label.text = "/%d" % GameData.get_stat_cap()
		cap_label.add_theme_font_size_override("font_size", 12)
		cap_label.add_theme_color_override("font_color", NeonTheme.TEXT_DIM)
		name_hbox.add_child(cap_label)

		# Stat bar
		var bar := ProgressBar.new()
		bar.max_value = GameData.get_stat_cap()
		bar.value = base_val
		bar.custom_minimum_size = Vector2(0, 6)
		bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.08, 0.08, 0.12)
		bar_bg.corner_radius_top_left = 3
		bar_bg.corner_radius_top_right = 3
		bar_bg.corner_radius_bottom_left = 3
		bar_bg.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = stat_color.darkened(0.3)
		bar_fill.corner_radius_top_left = 3
		bar_fill.corner_radius_top_right = 3
		bar_fill.corner_radius_bottom_left = 3
		bar_fill.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", bar_fill)
		info.add_child(bar)

		# + butonu (stat puani varsa)
		if GameData.unspent_stat_points > 0 and base_val < GameData.get_stat_cap():
			var plus_btn := Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(ThemeConstants.MIN_TOUCH_TARGET, ThemeConstants.MIN_TOUCH_TARGET)
			plus_btn.pressed.connect(_on_stat_plus.bind(stat_name))
			var plus_style := StyleBoxFlat.new()
			plus_style.bg_color = NeonTheme.PRIMARY.darkened(0.5)
			plus_style.corner_radius_top_left = 6
			plus_style.corner_radius_top_right = 6
			plus_style.corner_radius_bottom_left = 6
			plus_style.corner_radius_bottom_right = 6
			plus_btn.add_theme_stylebox_override("normal", plus_style)
			plus_btn.add_theme_color_override("font_color", NeonTheme.PRIMARY)
			row.add_child(plus_btn)


func _build_equipment() -> void:
	for child in equip_container.get_children():
		child.queue_free()

	var slot_icons := {"weapon": "W", "armor": "A", "clothing": "C"}
	var slot_names := {"weapon": "Silah", "armor": "Zirh", "clothing": "Kiyafet"}

	for slot in slot_names:
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = NeonTheme.CARD_BG
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)
		equip_container.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		# Slot ikon (renkli kare)
		var icon_bg := ColorRect.new()
		icon_bg.custom_minimum_size = Vector2(36, 36)
		icon_bg.color = NeonTheme.SURFACE_LIGHT
		row.add_child(icon_bg)

		var icon_letter := Label.new()
		icon_letter.text = slot_icons.get(slot, "?")
		icon_letter.add_theme_font_size_override("font_size", 18)
		icon_letter.add_theme_color_override("font_color", NeonTheme.TEXT_SECONDARY)
		icon_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_bg.add_child(icon_letter)

		# Slot bilgi
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var slot_label := Label.new()
		slot_label.text = slot_names[slot]
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", NeonTheme.TEXT_SECONDARY)
		info.add_child(slot_label)

		var item_id: String = InventoryManager.equipped.get(slot, "")
		var item_label := Label.new()
		if item_id.is_empty():
			item_label.text = "Bos"
			item_label.add_theme_color_override("font_color", NeonTheme.TEXT_DIM)
			icon_bg.color = NeonTheme.SURFACE_LIGHT
		else:
			var item_def: Dictionary = ItemDB.get_item(item_id)
			var rarity_color := ThemeConstants.get_rarity_color(item_def.get("rarity", "COMMON"))
			item_label.text = item_def.get("name", "???")
			item_label.add_theme_color_override("font_color", rarity_color)
			icon_bg.color = rarity_color.darkened(0.6)
			icon_letter.add_theme_color_override("font_color", rarity_color)
			card_style.border_width_left = 3
			card_style.border_color = rarity_color.darkened(0.3)
			card.add_theme_stylebox_override("panel", card_style)
		item_label.add_theme_font_size_override("font_size", 15)
		info.add_child(item_label)


func _on_stat_plus(stat_name: String) -> void:
	GameData.spend_stat_point(stat_name)
	_refresh()
