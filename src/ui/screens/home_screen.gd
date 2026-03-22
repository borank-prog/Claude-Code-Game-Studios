## Ana sayfa — profil ozeti, hizli erisim, stat dagitimi.
extends Control

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var name_label: Label = %NameLabel
@onready var rank_title: Label = %RankTitle
@onready var power_value: Label = %PowerValue
@onready var stat_container: VBoxContainer = %StatContainer
@onready var stat_points_label: Label = %StatPointsLabel
@onready var equip_container: VBoxContainer = %EquipContainer

const STAT_NAMES: Dictionary = {
	"strength": "Guc",
	"endurance": "Dayaniklilik",
	"charisma": "Karizma",
	"luck": "Sans",
	"intelligence": "Zeka",
}


func _ready() -> void:
	EventBus.stat_changed.connect(func(_s, _v, _d): _refresh())
	EventBus.rank_up.connect(func(_r, _n): _refresh())
	EventBus.equipment_changed.connect(func(_s, _i): _refresh())
	EventBus.stat_points_available.connect(func(_p): _refresh())
	visibility_changed.connect(_on_visible)
	# Geciktirilmis ilk refresh — GameData initialize olduktan sonra
	call_deferred("_refresh")


func _on_visible() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	name_label.text = GameData.display_name
	rank_title.text = "Rank %d — %s" % [GameData.rank, GameData.get_rank_name()]
	power_value.text = "Power: %s" % ThemeConstants.format_number(InventoryManager.get_total_power())

	_build_stats()
	_build_equipment()


func _build_stats() -> void:
	for child in stat_container.get_children():
		child.queue_free()

	stat_points_label.text = "Stat Puanlari: %d" % GameData.unspent_stat_points
	stat_points_label.visible = GameData.unspent_stat_points > 0

	for stat_name in STAT_NAMES:
		var row := HBoxContainer.new()
		stat_container.add_child(row)

		var label := Label.new()
		var base_val := GameData.get_stat(stat_name)
		var equip_bonus := InventoryManager.get_equipment_stat_bonus(stat_name)
		label.text = "%s: %d" % [STAT_NAMES[stat_name], base_val]
		if equip_bonus > 0:
			label.text += " (+%d)" % equip_bonus
		label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
		label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		# Stat cap gostergesi
		var cap_label := Label.new()
		cap_label.text = "/ %d" % GameData.get_stat_cap()
		cap_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		cap_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		row.add_child(cap_label)

		# + butonu (stat puani varsa)
		if GameData.unspent_stat_points > 0 and base_val < GameData.get_stat_cap():
			var plus_btn := Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(ThemeConstants.MIN_TOUCH_TARGET, ThemeConstants.MIN_TOUCH_TARGET)
			plus_btn.pressed.connect(_on_stat_plus.bind(stat_name))
			row.add_child(plus_btn)


func _build_equipment() -> void:
	for child in equip_container.get_children():
		child.queue_free()

	var slot_names := {"weapon": "Silah", "armor": "Zirh", "clothing": "Kiyafet"}
	for slot in slot_names:
		var row := HBoxContainer.new()
		equip_container.add_child(row)

		var slot_label := Label.new()
		slot_label.text = "%s: " % slot_names[slot]
		slot_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
		slot_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		row.add_child(slot_label)

		var item_id: String = InventoryManager.equipped.get(slot, "")
		var item_label := Label.new()
		if item_id.is_empty():
			item_label.text = "Bos"
			item_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		else:
			var item_def: Dictionary = ItemDB.get_item(item_id)
			item_label.text = item_def.get("name", "???")
			item_label.add_theme_color_override("font_color",
				ThemeConstants.get_rarity_color(item_def.get("rarity", "COMMON")))
		item_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)


func _on_stat_plus(stat_name: String) -> void:
	GameData.spend_stat_point(stat_name)
	_refresh()
