## Magaza ekrani — kategori sekmeli, satin alma/satma.
extends Control

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

const CATEGORIES: PackedStringArray = ["WEAPON", "ARMOR", "CLOTHING", "CONSUMABLE"]
const CATEGORY_NAMES: Dictionary = {
	"WEAPON": "Silahlar",
	"ARMOR": "Zirh",
	"CLOTHING": "Kiyafet",
	"CONSUMABLE": "Sarf",
}


func _ready() -> void:
	_build_category_bar()
	buy_panel.visible = false
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

	var style := StyleBoxFlat.new()
	style.bg_color = ThemeConstants.SURFACE_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
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
	var rarity: String = item.get("rarity", "COMMON")
	name_label.text = item.get("name", "???")
	name_label.add_theme_color_override("font_color", ThemeConstants.get_rarity_color(rarity))
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	info.add_child(name_label)

	var stat_text := "Power +%d" % item.get("power_bonus", 0)
	var bonuses: Dictionary = item.get("stat_bonuses", {})
	for stat in bonuses:
		stat_text += " | %s +%d" % [stat.capitalize(), bonuses[stat]]
	var stat_label := Label.new()
	stat_label.text = stat_text
	stat_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	stat_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	info.add_child(stat_label)

	# Sag: fiyat
	var price_label := Label.new()
	price_label.text = "$%s" % ThemeConstants.format_number(item.get("buy_price", 0))
	price_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)

	var can_info := ShopSystem.can_buy(item.get("item_id", ""))
	if can_info["can_buy"]:
		price_label.add_theme_color_override("font_color", ThemeConstants.SUCCESS_COLOR)
	else:
		price_label.add_theme_color_override("font_color", ThemeConstants.DANGER_COLOR)
	hbox.add_child(price_label)

	# Rank kontrolu
	if item.get("required_rank", 0) > GameData.rank:
		card.modulate = Color(0.4, 0.4, 0.4, 0.6)
		stat_label.text += " | Rank %d gerekli" % item["required_rank"]

	# Envanterde var mi
	if InventoryManager.has_item(item.get("item_id", "")):
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
	buy_item_name.text = item.get("name", "???")

	var stat_text := "Power +%d" % item.get("power_bonus", 0)
	var bonuses: Dictionary = item.get("stat_bonuses", {})
	for stat in bonuses:
		stat_text += "\n%s +%d" % [stat.capitalize(), bonuses[stat]]
	buy_item_stats.text = stat_text
	buy_price.text = "$%s" % ThemeConstants.format_number(item.get("buy_price", 0))

	var can_info := ShopSystem.can_buy(item.get("item_id", ""))
	buy_button.disabled = not can_info["can_buy"]
	buy_button.text = "SATIN AL" if can_info["can_buy"] else can_info.get("reason", "").to_upper()

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
