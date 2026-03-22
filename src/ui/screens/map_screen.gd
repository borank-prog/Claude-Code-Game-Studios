## Harita ekrani — bolge listesi, kontrol durumu, baskin baslatma.
extends Control

@onready var territory_list: VBoxContainer = %TerritoryList
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_name: Label = %DetailName
@onready var detail_info: Label = %DetailInfo
@onready var detail_buildings: Label = %DetailBuildings
@onready var action_button: Button = %ActionButton
@onready var build_button: Button = %BuildButton
@onready var close_detail: Button = %CloseDetail

var selected_territory: Dictionary = {}
var territory_mgr: Node
var gang_war_mgr: Node
var building_mgr: Node


func _ready() -> void:
	territory_mgr = get_node_or_null("/root/TerritoryManager")
	gang_war_mgr = get_node_or_null("/root/GangWarManager")
	building_mgr = get_node_or_null("/root/BuildingManager")

	if territory_mgr:
		territory_mgr.territory_updated.connect(func(_t): _refresh_list())
		territory_mgr.territory_captured.connect(func(_t, _g): _refresh_list())

	detail_panel.visible = false
	action_button.pressed.connect(_on_action_pressed)
	build_button.pressed.connect(_on_build_pressed)
	close_detail.pressed.connect(func(): detail_panel.visible = false)

	_refresh_list()


func _refresh_list() -> void:
	for child in territory_list.get_children():
		child.queue_free()

	if territory_mgr == null:
		return

	var territories := territory_mgr.get_all_territories()

	# Tier'a gore sirala
	territories.sort_custom(func(a, b): return a.get("tier", 1) < b.get("tier", 1))

	var current_tier := 0
	for t in territories:
		var tier: int = t.get("tier", 1)
		if tier != current_tier:
			current_tier = tier
			var header := Label.new()
			header.text = "— Tier %d —" % tier
			header.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
			header.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			territory_list.add_child(header)

		territory_list.add_child(_create_territory_card(t))


func _create_territory_card(territory: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)

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

	# Sol: kontrol gostergesi
	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(8, 0)
	indicator.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var controlling := territory.get("controlling_gang_id", "")
	if controlling.is_empty():
		indicator.color = Color(0.5, 0.5, 0.5)  # Tarafsiz
	elif controlling == GameData.gang_id and not GameData.gang_id.is_empty():
		indicator.color = ThemeConstants.PRIMARY_COLOR  # Bizim
	else:
		indicator.color = ThemeConstants.DANGER_COLOR  # Dusmanlar
	hbox.add_child(indicator)

	# Orta: bilgi
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var margin := Control.new()
	margin.custom_minimum_size = Vector2(8, 0)
	hbox.move_child(margin, 1)
	info.get_parent().move_child(info, 2)

	var name_label := Label.new()
	name_label.text = territory.get("name", "???")
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	info.add_child(name_label)

	var detail := Label.new()
	var income := territory_mgr.get_territory_income(territory["territory_id"]) if territory_mgr else 0
	detail.text = "$%d/sa | %d bina slotu" % [territory.get("base_income", 0), territory.get("building_slots", 2)]
	detail.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	detail.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	info.add_child(detail)

	# Dokunma
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(_on_territory_tapped.bind(territory))
	card.add_child(btn)

	return card


func _on_territory_tapped(territory: Dictionary) -> void:
	selected_territory = territory
	_show_detail(territory)


func _show_detail(territory: Dictionary) -> void:
	detail_panel.visible = true
	detail_name.text = territory.get("name", "???")

	var controlling := territory.get("controlling_gang_id", "")
	var control_str := territory.get("control_strength", 0.0)
	var income := territory.get("base_income", 0)
	var buildings: Array = territory.get("buildings", [])

	var info_text := "Tier: %d | Gelir: $%d/sa\n" % [territory.get("tier", 1), income]

	if controlling.is_empty():
		info_text += "Kontrol: Tarafsiz\n"
	elif controlling == GameData.gang_id:
		info_text += "Kontrol: Senin ceten (%%%d)\n" % int(control_str * 100)
	else:
		info_text += "Kontrol: Dusman cete (%%%d)\n" % int(control_str * 100)

	info_text += "Savunma: %d" % (territory_mgr.get_defense_power(territory["territory_id"]) if territory_mgr else 0)
	detail_info.text = info_text

	# Binalar
	if buildings.is_empty():
		detail_buildings.text = "Bina yok"
	else:
		var bld_texts: PackedStringArray = []
		for b in buildings:
			var bdef: Dictionary = BuildingManager.BUILDING_DEFS.get(b.get("type", ""), {}) if building_mgr else {}
			bld_texts.append("%s (Lv.%d)" % [bdef.get("name", b.get("type", "?")), b.get("level", 1)])
		detail_buildings.text = ", ".join(bld_texts)

	# Aksiyon butonu
	if controlling.is_empty():
		action_button.text = "ELE GECIR"
		action_button.visible = not GameData.gang_id.is_empty()
	elif controlling == GameData.gang_id:
		action_button.text = "SENIN BOLGEN"
		action_button.visible = false
	else:
		action_button.text = "BASKIN YAP"
		action_button.visible = not GameData.gang_id.is_empty()

	# Bina butonu
	build_button.visible = (controlling == GameData.gang_id and not GameData.gang_id.is_empty())


func _on_action_pressed() -> void:
	if selected_territory.is_empty() or gang_war_mgr == null:
		return

	var result := gang_war_mgr.declare_raid(selected_territory["territory_id"])
	if result["success"]:
		if result.get("instant", false):
			ScreenManager.queue_notification("Bolge ele gecirildi!", "success")
		else:
			ScreenManager.queue_notification("Baskin ilan edildi!", "info")
		detail_panel.visible = false
		_refresh_list()
	else:
		ScreenManager.queue_notification(result.get("reason", "Basarisiz"), "error")


func _on_build_pressed() -> void:
	if selected_territory.is_empty() or building_mgr == null:
		return
	# Basit bina secimi — ilk uygun bina tipini sec
	for btype in BuildingManager.BUILDING_DEFS:
		var bdef: Dictionary = BuildingManager.BUILDING_DEFS[btype]
		if bdef["required_rank"] <= GameData.rank:
			var result := building_mgr.build(selected_territory["territory_id"], btype)
			if result["success"]:
				ScreenManager.queue_notification("%s insa basladi!" % bdef["name"], "success")
				_show_detail(selected_territory)
				return
			# Zaten var veya slot dolu — sonrakini dene
	ScreenManager.queue_notification("Insa edilecek uygun bina yok", "error")
