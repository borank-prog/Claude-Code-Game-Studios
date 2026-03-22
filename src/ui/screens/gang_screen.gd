## Cete ekrani — olusturma, bilgi, uye listesi, kasa.
extends Control

@onready var no_gang_panel: VBoxContainer = %NoGangPanel
@onready var gang_info_panel: VBoxContainer = %GangInfoPanel
@onready var create_name_input: LineEdit = %CreateNameInput
@onready var create_tag_input: LineEdit = %CreateTagInput
@onready var create_button: Button = %CreateButton
@onready var create_cost_label: Label = %CreateCostLabel
@onready var gang_name_label: Label = %GangNameLabel
@onready var gang_level_label: Label = %GangLevelLabel
@onready var gang_power_label: Label = %GangPowerLabel
@onready var gang_treasury_label: Label = %GangTreasuryLabel
@onready var gang_territories_label: Label = %GangTerritoriesLabel
@onready var member_list: VBoxContainer = %MemberList
@onready var contribute_button: Button = %ContributeButton
@onready var leave_button: Button = %LeaveButton

var gang_mgr: Node
var territory_mgr: Node


func _ready() -> void:
	gang_mgr = get_node_or_null("/root/GangManager")
	territory_mgr = get_node_or_null("/root/TerritoryManager")

	create_button.pressed.connect(_on_create_pressed)
	contribute_button.pressed.connect(_on_contribute_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	if gang_mgr:
		gang_mgr.gang_created.connect(func(_d): _refresh())
		gang_mgr.gang_joined.connect(func(_d): _refresh())
		gang_mgr.gang_left.connect(func(): _refresh())
		gang_mgr.gang_updated.connect(func(): _refresh())

	create_cost_label.text = "Maliyet: $%s" % ThemeConstants.format_number(GangManager.GANG_CREATION_COST)
	_refresh()


func _refresh() -> void:
	if gang_mgr == null:
		return

	if gang_mgr.is_in_gang:
		no_gang_panel.visible = false
		gang_info_panel.visible = true
		_show_gang_info()
	else:
		no_gang_panel.visible = true
		gang_info_panel.visible = false


func _show_gang_info() -> void:
	var gang: Dictionary = gang_mgr.current_gang
	gang_name_label.text = "[%s] %s" % [gang.get("tag", "??"), gang.get("name", "???")]
	gang_level_label.text = "Level: %d | XP: %s / %s" % [
		gang.get("gang_level", 1),
		ThemeConstants.format_number(gang.get("gang_xp", 0)),
		ThemeConstants.format_number(gang_mgr.get_xp_for_level(gang.get("gang_level", 1) + 1)),
	]
	gang_power_label.text = "Toplam Guc: %s" % ThemeConstants.format_number(gang_mgr.get_total_power())
	gang_treasury_label.text = "Kasa: $%s" % ThemeConstants.format_number(gang.get("treasury", 0))

	# Bolgeler
	var territory_count := 0
	if territory_mgr:
		territory_count = territory_mgr.get_territories_by_gang(GameData.gang_id).size()
	gang_territories_label.text = "Bolgeler: %d" % territory_count

	# Uye listesi
	_build_member_list(gang.get("members", []))


func _build_member_list(members: Array) -> void:
	for child in member_list.get_children():
		child.queue_free()

	for m in members:
		var row := HBoxContainer.new()
		member_list.add_child(row)

		var role_label := Label.new()
		var role: String = m.get("role", "MEMBER")
		role_label.text = role
		role_label.custom_minimum_size = Vector2(80, 0)
		role_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)

		match role:
			"LEADER": role_label.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
			"OFFICER": role_label.add_theme_color_override("font_color", ThemeConstants.NEON_ACCENT)
			_: role_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		row.add_child(role_label)

		var name_label := Label.new()
		var pid: String = m.get("player_id", "???")
		name_label.text = pid.left(12)
		if pid == GameData.player_id:
			name_label.text += " (Sen)"
		name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
		name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var contrib_label := Label.new()
		contrib_label.text = "$%s" % ThemeConstants.format_number(m.get("contribution", 0))
		contrib_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
		contrib_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		row.add_child(contrib_label)


func _on_create_pressed() -> void:
	if gang_mgr == null:
		return

	var gang_name := create_name_input.text.strip_edges()
	var gang_tag := create_tag_input.text.strip_edges().to_upper()

	if gang_name.length() < 3 or gang_name.length() > 20:
		ScreenManager.queue_notification("Isim 3-20 karakter olmali", "error")
		return
	if gang_tag.length() < 2 or gang_tag.length() > 4:
		ScreenManager.queue_notification("Tag 2-4 karakter olmali", "error")
		return

	if gang_mgr.create_gang(gang_name, gang_tag):
		ScreenManager.queue_notification("Cete kuruldu!", "success")
	else:
		ScreenManager.queue_notification("Yetersiz cash ($%s gerekli)" % ThemeConstants.format_number(GangManager.GANG_CREATION_COST), "error")


func _on_contribute_pressed() -> void:
	if gang_mgr == null:
		return

	# Cash'in %10'unu katki yap
	var amount := maxi(100, GameData.cash / 10)
	if gang_mgr.contribute_to_treasury(amount):
		ScreenManager.queue_notification("$%s kasaya eklendi!" % ThemeConstants.format_number(amount), "success")
	else:
		ScreenManager.queue_notification("Yetersiz cash", "error")


func _on_leave_pressed() -> void:
	if gang_mgr == null:
		return
	gang_mgr.leave_gang()
	ScreenManager.queue_notification("Ceteden ayrildin", "info")
