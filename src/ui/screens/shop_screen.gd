## Magaza ekrani — kategori sekmeli, satin alma/satma.
extends Control

const NeonThemeClass := preload("res://src/ui/neon_theme.gd")

@onready var category_bar: HBoxContainer = %CategoryBar
@onready var item_list: VBoxContainer = %ItemList
@onready var buy_panel: PanelContainer = %BuyPanel
@onready var buy_item_name: Label = %BuyItemName
@onready var buy_item_stats: Label = %BuyItemStats
@onready var buy_price: Label = %BuyPrice
@onready var buy_button: Button = %BuyButton
@onready var buy_close: Button = %BuyClose

var current_category: String = "WEAPON"
var selected_item: Dictionary = {}
var category_buttons: Dictionary = {}

const CATEGORIES: PackedStringArray = ["WEAPON", "ARMOR", "CLOTHING", "CONSUMABLE", "OPERATIVE"]
const CATEGORY_NAMES: Dictionary = {
	"WEAPON": "Silahlar",
	"ARMOR": "Zirh",
	"CLOTHING": "Kiyafet",
	"CONSUMABLE": "Sarf",
	"OPERATIVE": "Operatif",
}


func _ready() -> void:
	_build_category_bar()

	# Buy panel stili
	var bp_style := StyleBoxFlat.new()
	bp_style.bg_color = Color(NeonThemeClass.SURFACE, 0.98)
	bp_style.corner_radius_top_left = 12
	bp_style.corner_radius_top_right = 12
	bp_style.corner_radius_bottom_left = 12
	bp_style.corner_radius_bottom_right = 12
	bp_style.border_width_left = 2
	bp_style.border_width_right = 2
	bp_style.border_width_top = 2
	bp_style.border_width_bottom = 2
	bp_style.border_color = NeonThemeClass.PRIMARY.darkened(0.3)
	bp_style.content_margin_left = 20
	bp_style.content_margin_right = 20
	bp_style.content_margin_top = 16
	bp_style.content_margin_bottom = 16
	buy_panel.add_theme_stylebox_override("panel", bp_style)
	buy_panel.visible = false

	buy_item_name.add_theme_font_size_override("font_size", 20)
	buy_item_stats.add_theme_color_override("font_color", NeonThemeClass.TEXT_SECONDARY)
	buy_price.add_theme_color_override("font_color", NeonThemeClass.SUCCESS)
	buy_price.add_theme_font_size_override("font_size", 20)

	buy_button.pressed.connect(_on_buy_pressed)
	buy_close.pressed.connect(func(): buy_panel.visible = false)
	ShopSystem.purchase_completed.connect(_on_purchase_completed)
	ShopSystem.purchase_failed.connect(_on_purchase_failed)
	_refresh_items()


func _build_category_bar() -> void:
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = CATEGORY_NAMES.get(cat, cat)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, ThemeConstants.MIN_TOUCH_TARGET)
		btn.pressed.connect(_on_category_pressed.bind(cat))
		category_bar.add_child(btn)
		category_buttons[cat] = btn
	_update_category_highlight()


func _on_category_pressed(cat: String) -> void:
	current_category = cat
	_update_category_highlight()
	_refresh_items()


func _update_category_highlight() -> void:
	for cat in category_buttons:
		var btn: Button = category_buttons[cat]
		btn.modulate = ThemeConstants.PRIMARY_COLOR if cat == current_category else Color.WHITE


func _refresh_items() -> void:
	for child in item_list.get_children():
		child.queue_free()

	var items := ShopSystem.get_shop_items(current_category)
	# Fiyata gore sirala
	items.sort_custom(func(a, b): return a.get("buy_price", 0) < b.get("buy_price", 0))

	for item in items:
		var card := _create_item_card(item)
		item_list.add_child(card)


func _create_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 75)
	var is_unit: bool = item.get("is_unit", false)

	var rarity: String = item.get("rarity", "COMMON" if not is_unit else "RARE")
	var rarity_color := ThemeConstants.get_rarity_color(rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = NeonThemeClass.CARD_BG
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_color = rarity_color
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	# Sol: isim ve stat
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.add_theme_color_override("font_color", ThemeConstants.get_rarity_color(rarity))
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	info.add_child(name_label)

	var stat_text: String
	if is_unit:
		stat_text = item.get("shop_line", item.get("description", ""))
	else:
		stat_text = "Power +%d" % item.get("power_bonus", 0)
		var bonuses: Dictionary = item.get("stat_bonuses", {})
		for stat in bonuses:
			stat_text += " | %s +%d" % [stat.capitalize(), bonuses[stat]]
	var stat_label := Label.new()
	stat_label.text = stat_text
	if is_unit:
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	stat_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	info.add_child(stat_label)

	# Sag: fiyat
	var price_label := Label.new()
	price_label.text = "$%s" % ThemeConstants.format_number(item.get("buy_price", 0))
	price_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)

	var can_info: Dictionary = ShopSystem.can_buy(item.get("item_id", ""))
	if can_info["can_buy"]:
		price_label.add_theme_color_override("font_color", ThemeConstants.SUCCESS_COLOR)
	else:
		price_label.add_theme_color_override("font_color", ThemeConstants.DANGER_COLOR)
	hbox.add_child(price_label)

	# Rank kontrolu
	if item.get("required_rank", 0) > GameData.rank:
		card.modulate = Color(0.4, 0.4, 0.4, 0.6)
		stat_label.text += " | Rank %d gerekli" % item["required_rank"]

	# Sahiplik kontrolu
	if ShopSystem.is_owned(item.get("item_id", "")):
		name_label.text += " [SAHIP]"

	# Dokunma
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(_on_item_tapped.bind(item))
	card.add_child(btn)

	return card


func _on_item_tapped(item: Dictionary) -> void:
	selected_item = item
	var is_unit: bool = item.get("is_unit", false)
	buy_item_name.text = item.get("name", "???")
	buy_item_name.add_theme_color_override("font_color", ThemeConstants.get_rarity_color(item.get("rarity", "COMMON")))

	var stat_text: String
	if is_unit:
		stat_text = item.get("description", "")
	else:
		stat_text = "Power +%d" % item.get("power_bonus", 0)
		var bonuses: Dictionary = item.get("stat_bonuses", {})
		for stat in bonuses:
			stat_text += "\n%s +%d" % [stat.capitalize(), bonuses[stat]]
	buy_item_stats.text = stat_text
	buy_price.text = "$%s" % ThemeConstants.format_number(item.get("buy_price", 0))

	var can_info: Dictionary = ShopSystem.can_buy(item.get("item_id", ""))
	buy_button.disabled = not can_info["can_buy"]
	if can_info["can_buy"]:
		buy_button.text = "KIRALA" if is_unit else "SATIN AL"
	else:
		buy_button.text = _format_buy_fail_reason(can_info.get("reason", ""))

	buy_panel.visible = true


func _on_buy_pressed() -> void:
	if selected_item.is_empty():
		return
	ShopSystem.buy_item(selected_item.get("item_id", ""))


func _on_purchase_completed(_item_id: String) -> void:
	buy_panel.visible = false
	_refresh_items()


func _on_purchase_failed(reason: String) -> void:
	buy_button.text = reason


func _format_buy_fail_reason(reason: String) -> String:
	match reason:
		"rank":
			return "RANK YETERSIZ"
		"cash":
			return "BAKIYE YETERSIZ"
		"inventory_full":
			return "ENVANTER DOLU"
		"already_owned":
			return "ZATEN SENDE"
		"not_found":
			return "KAYIT YOK"
		_:
			return reason.to_upper()
