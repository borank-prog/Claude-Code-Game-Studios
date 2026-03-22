## Harita ekrani — gorsel bolge haritasi, detay popup, bina yonetimi.
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

var _map_view: Control = null
var _building_panel: PanelContainer = null


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
	close_detail.pressed.connect(_close_panels)

	_setup_map_view()
	_refresh_list()


## Gorsel harita view'i olustur ve territory_list'in ustune yerlestir
func _setup_map_view() -> void:
	var MapViewScript := preload("res://src/ui/components/territory_map_view.gd")
	_map_view = Control.new()
	_map_view.set_script(MapViewScript)
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.territory_tapped.connect(_on_territory_tapped_visual)

	# Eski listeyi gizle, haritayi goster
	territory_list.visible = false
	territory_list.get_parent().add_child(_map_view)
	# Haritayi listenin yerine koy
	territory_list.get_parent().move_child(_map_view, territory_list.get_index())


func _on_territory_tapped_visual(territory_id: String) -> void:
	if territory_mgr == null:
		return
	var territory: Dictionary = territory_mgr.get_territory(territory_id)
	if not territory.is_empty():
		selected_territory = territory
		_show_detail(territory)


func _refresh_list() -> void:
	# Gorsel harita varsa sadece renkleri guncelle
	if _map_view and _map_view.has_method("_update_colors"):
		_map_view._update_colors()


func _show_detail(territory: Dictionary) -> void:
	detail_panel.visible = true
	_close_building_panel()
	detail_name.text = territory.get("name", "???")

	var controlling: String = territory.get("controlling_gang_id", "")
	var control_str: float = territory.get("control_strength", 0.0)
	var income: int = territory.get("base_income", 0)
	var buildings: Array = territory.get("buildings", [])

	var info_text: String = "Tier: %d | Gelir: $%d/sa\n" % [territory.get("tier", 1), income]

	if controlling.is_empty():
		info_text += "Kontrol: Tarafsiz\n"
	elif controlling == GameData.gang_id:
		info_text += "Kontrol: Senin ceten (%%%d)\n" % int(control_str * 100)
	else:
		info_text += "Kontrol: Dusman cete (%%%d)\n" % int(control_str * 100)

	info_text += "Savunma: %d\n" % (territory_mgr.get_defense_power(territory["territory_id"]) if territory_mgr else 0)

	# Komsular
	var adjacent: Array = territory.get("adjacent", [])
	var adj_names: PackedStringArray = []
	for adj_id in adjacent:
		var adj_t: Dictionary = territory_mgr.get_territory(adj_id)
		adj_names.append(adj_t.get("name", adj_id))
	info_text += "Komsular: %s" % ", ".join(adj_names)

	detail_info.text = info_text

	# Binalar
	if buildings.is_empty():
		detail_buildings.text = "Bina yok"
	else:
		var bld_texts: PackedStringArray = []
		for b in buildings:
			var bdef: Dictionary = BuildingManager.BUILDING_DEFS.get(b.get("type", ""), {})
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
	if selected_territory.is_empty():
		return

	var tid: String = selected_territory["territory_id"]
	var controlling: String = selected_territory.get("controlling_gang_id", "")

	if controlling.is_empty():
		# Tarafsiz bolge — dogrudan ele gecir
		if territory_mgr:
			territory_mgr.capture_territory(tid, GameData.gang_id)
			ScreenManager.queue_notification("Bolge ele gecirildi!", "success")
			detail_panel.visible = false
			_refresh_list()
	elif gang_war_mgr:
		# Dusman bolgesi — baskin
		var result: Dictionary = gang_war_mgr.declare_raid(tid)
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
	_show_building_panel()


# === BUILDING PLACEMENT UI ===

func _show_building_panel() -> void:
	_close_building_panel()

	_building_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ThemeConstants.SURFACE_COLOR, 0.98)
	style.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	style.content_margin_left = ThemeConstants.CARD_PADDING
	style.content_margin_right = ThemeConstants.CARD_PADDING
	style.content_margin_top = ThemeConstants.CARD_PADDING
	style.content_margin_bottom = ThemeConstants.CARD_PADDING
	_building_panel.add_theme_stylebox_override("panel", style)
	_building_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_building_panel.position.y = -200
	_building_panel.z_index = 20
	add_child(_building_panel)

	var vbox := VBoxContainer.new()
	_building_panel.add_child(vbox)

	# Baslik
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "Bina Sec"
	title.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SUBHEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(ThemeConstants.MIN_TOUCH_TARGET, ThemeConstants.MIN_TOUCH_TARGET)
	close_btn.pressed.connect(_close_building_panel)
	header_hbox.add_child(close_btn)

	# Slot bilgisi
	var territory: Dictionary = selected_territory
	var buildings: Array = territory.get("buildings", [])
	var max_slots: int = territory.get("building_slots", 2)
	var used_slots: int = buildings.size()

	var slot_label := Label.new()
	slot_label.text = "Slot: %d / %d" % [used_slots, max_slots]
	slot_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	slot_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	vbox.add_child(slot_label)

	# Mevcut binalar
	if not buildings.is_empty():
		var existing_label := Label.new()
		existing_label.text = "— Mevcut Binalar —"
		existing_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		existing_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		existing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(existing_label)

		for b in buildings:
			var bdef: Dictionary = BuildingManager.BUILDING_DEFS.get(b.get("type", ""), {})
			var brow := HBoxContainer.new()
			vbox.add_child(brow)

			var bname := Label.new()
			bname.text = "%s Lv.%d" % [bdef.get("name", "?"), b.get("level", 1)]
			bname.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
			bname.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
			bname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(bname)

			# Yukseltme butonu
			if b.get("level", 1) < bdef.get("max_level", 5):
				var up_cost: int = bdef["build_cost"][b["level"]]  # next level cost
				var up_btn := Button.new()
				up_btn.text = "Yuksel $%s" % ThemeConstants.format_number(up_cost)
				up_btn.custom_minimum_size = Vector2(0, ThemeConstants.MIN_TOUCH_TARGET)
				up_btn.pressed.connect(_on_upgrade_pressed.bind(territory["territory_id"], b["building_id"]))
				brow.add_child(up_btn)

	# Yeni bina butonlari
	if used_slots < max_slots:
		var sep := HSeparator.new()
		vbox.add_child(sep)

		var new_label := Label.new()
		new_label.text = "— Yeni Bina —"
		new_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		new_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_label)

		var existing_types: Array = []
		for b in buildings:
			existing_types.append(b.get("type", ""))

		for btype in BuildingManager.BUILDING_DEFS:
			if btype in existing_types:
				continue  # Ayni tipten zaten var

			var bdef: Dictionary = BuildingManager.BUILDING_DEFS[btype]
			var can_build: bool = bdef["required_rank"] <= GameData.rank

			var row := HBoxContainer.new()
			vbox.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)

			var name_l := Label.new()
			name_l.text = bdef["name"]
			name_l.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
			name_l.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY if can_build else ThemeConstants.TEXT_SECONDARY)
			info.add_child(name_l)

			var detail_l := Label.new()
			var income: int = bdef["income_per_hour"][0]
			var defense: int = bdef["defense_bonus"][0]
			var detail_parts: PackedStringArray = []
			if income > 0:
				detail_parts.append("$%d/sa" % income)
			if defense > 0:
				detail_parts.append("Def: %d" % defense)
			if not can_build:
				detail_parts.append("Rank %d gerekli" % bdef["required_rank"])
			detail_l.text = " | ".join(detail_parts)
			detail_l.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
			detail_l.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
			info.add_child(detail_l)

			var cost: int = bdef["build_cost"][0]
			var btn := Button.new()
			btn.text = "$%s" % ThemeConstants.format_number(cost)
			btn.custom_minimum_size = Vector2(0, ThemeConstants.MIN_TOUCH_TARGET)
			btn.disabled = not can_build or not EconomyManager.can_afford(cost)
			btn.pressed.connect(_on_build_type_pressed.bind(territory["territory_id"], btype))
			row.add_child(btn)


func _on_build_type_pressed(territory_id: String, building_type: String) -> void:
	if building_mgr == null:
		return
	var result: Dictionary = building_mgr.build(territory_id, building_type)
	if result["success"]:
		var bdef: Dictionary = BuildingManager.BUILDING_DEFS.get(building_type, {})
		ScreenManager.queue_notification("%s insa basladi!" % bdef.get("name", "Bina"), "success")
		# Detay panelini guncelle
		if territory_mgr:
			selected_territory = territory_mgr.get_territory(territory_id)
			_show_detail(selected_territory)
		_show_building_panel()  # Listeyi yenile
	else:
		ScreenManager.queue_notification(result.get("reason", "Insa basarisiz"), "error")


func _on_upgrade_pressed(territory_id: String, building_id: String) -> void:
	if building_mgr == null:
		return
	var result: Dictionary = building_mgr.upgrade(territory_id, building_id)
	if result["success"]:
		ScreenManager.queue_notification("Bina yukseltildi!", "success")
		if territory_mgr:
			selected_territory = territory_mgr.get_territory(territory_id)
			_show_detail(selected_territory)
		_show_building_panel()
	else:
		ScreenManager.queue_notification(result.get("reason", "Yukseltme basarisiz"), "error")


func _close_building_panel() -> void:
	if _building_panel:
		_building_panel.queue_free()
		_building_panel = null


func _close_panels() -> void:
	detail_panel.visible = false
	_close_building_panel()
