## Gorsel bolge haritasi — node bazli, baglanti cizgili, renk kodlu.
## Pinch-to-zoom (0.5x-3.0x), drag pan destekli.
extends Control

const NeonThemeClass := preload("res://src/ui/neon_theme.gd")

signal territory_tapped(territory_id: String)

var territory_mgr: Node
var _nodes: Dictionary = {}  # territory_id -> Control (node widget)
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _canvas: Control  # Tum node'larin parent'i — zoom/pan buna uygulanir

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const NODE_SIZE := Vector2(100, 60)
const NODE_SPACING := Vector2(130, 120)

# Bolge konumlari — harita layoutu (normalize edilmis, 0-1 arasi)
# Tier 1 ust kisim, Tier 3 alt kisim (piramit seklinde)
const TERRITORY_POSITIONS: Dictionary = {
	"suburbs":     Vector2(0.15, 0.10),
	"slums":       Vector2(0.50, 0.10),
	"industrial":  Vector2(0.85, 0.10),
	"docks":       Vector2(0.75, 0.35),
	"market":      Vector2(0.30, 0.35),
	"nightlife":   Vector2(0.55, 0.38),
	"finance":     Vector2(0.15, 0.60),
	"downtown":    Vector2(0.65, 0.62),
	"marina":      Vector2(0.40, 0.78),
	"mansion":     Vector2(0.25, 0.92),
}


func _ready() -> void:
	territory_mgr = get_node_or_null("/root/TerritoryManager")
	clip_contents = true

	_canvas = Control.new()
	add_child(_canvas)

	call_deferred("_build_map")

	if territory_mgr:
		territory_mgr.territory_updated.connect(func(_t): _update_colors())
		territory_mgr.territory_captured.connect(func(_t, _g): _update_colors())


func _build_map() -> void:
	if territory_mgr == null:
		return

	# Baglanti cizgileri (node'lardan once ciz, altta kalsin)
	var line_canvas := Control.new()
	line_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(line_canvas)
	line_canvas.draw.connect(func(): _draw_connections(line_canvas))
	# line_canvas'a referans tut
	_canvas.set_meta("line_canvas", line_canvas)

	# Bolge node'lari
	for tid in TERRITORY_POSITIONS:
		var territory: Dictionary = territory_mgr.get_territory(tid)
		if territory.is_empty():
			continue
		var node_widget := _create_territory_node(territory)
		_canvas.add_child(node_widget)
		_nodes[tid] = node_widget

	_apply_layout()
	_update_colors()


func _create_territory_node(territory: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = NODE_SIZE
	panel.size = NODE_SIZE
	panel.pivot_offset = NODE_SIZE / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = NeonThemeClass.CARD_BG
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = NeonThemeClass.BORDER
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = territory.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var info_label := Label.new()
	info_label.text = "T%d | $%d/sa" % [territory.get("tier", 1), territory.get("base_income", 0)]
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Tiklanabilir overlay
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func(): territory_tapped.emit(territory["territory_id"]))
	panel.add_child(btn)

	# Meta bilgi sakla
	panel.set_meta("territory_id", territory["territory_id"])

	return panel


func _apply_layout() -> void:
	var map_size := size * 0.9  # %90 alan kullan, kenarlar bos
	var offset := size * 0.05

	for tid in _nodes:
		if TERRITORY_POSITIONS.has(tid):
			var norm_pos: Vector2 = TERRITORY_POSITIONS[tid]
			var pixel_pos := offset + Vector2(norm_pos.x * map_size.x, norm_pos.y * map_size.y)
			_nodes[tid].position = pixel_pos - NODE_SIZE / 2.0

	# Cizgileri guncelle
	var line_canvas: Control = _canvas.get_meta("line_canvas", null)
	if line_canvas:
		line_canvas.queue_redraw()


func _update_colors() -> void:
	if territory_mgr == null:
		return

	for tid in _nodes:
		var territory: Dictionary = territory_mgr.get_territory(tid)
		var panel: PanelContainer = _nodes[tid]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()

		var controlling: String = territory.get("controlling_gang_id", "")
		if controlling.is_empty():
			style.border_color = Color(0.5, 0.5, 0.5, 0.8)  # Gri — tarafsiz
		elif controlling == GameData.gang_id and not GameData.gang_id.is_empty():
			style.border_color = ThemeConstants.PRIMARY_COLOR  # Altin — bizim
		else:
			style.border_color = ThemeConstants.DANGER_COLOR  # Kirmizi — dusman

		# Contested flash
		if territory.get("contested", false):
			style.border_color = style.border_color.lerp(Color.WHITE, 0.5 * (sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5))

		panel.add_theme_stylebox_override("panel", style)


func _draw_connections(canvas: Control) -> void:
	if territory_mgr == null:
		return

	for tid in _nodes:
		var territory: Dictionary = territory_mgr.get_territory(tid)
		var adjacent: Array = territory.get("adjacent", [])
		var from_pos: Vector2 = _nodes[tid].position + NODE_SIZE / 2.0

		for adj_id in adjacent:
			# Her baglanti sadece bir kez ciz (alfabetik siralama ile)
			if adj_id < tid and _nodes.has(adj_id):
				continue
			if not _nodes.has(adj_id):
				continue
			var to_pos: Vector2 = _nodes[adj_id].position + NODE_SIZE / 2.0
			canvas.draw_line(from_pos, to_pos, Color(0.3, 0.3, 0.4, 0.6), 2.0, true)


# === ZOOM & PAN ===

func _gui_input(event: InputEvent) -> void:
	# Drag pan
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start = event.position
			else:
				_is_dragging = false

		# Scroll zoom (masaustunde)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-0.1, event.position)

	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _drag_start
		_drag_start = event.position
		_pan_offset += delta
		_canvas.position = _pan_offset

	# Pinch-to-zoom (mobil)
	if event is InputEventScreenDrag:
		_pan_offset += event.relative
		_canvas.position = _pan_offset

	if event is InputEventMagnifyGesture:
		_apply_zoom((event.factor - 1.0) * 0.5, event.position)


func _apply_zoom(delta: float, focus: Vector2) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom + delta, MIN_ZOOM, MAX_ZOOM)

	if _zoom != old_zoom:
		# Zoom focus point'e dogru
		var zoom_ratio := _zoom / old_zoom
		_pan_offset = focus + (_pan_offset - focus) * zoom_ratio
		_canvas.scale = Vector2(_zoom, _zoom)
		_canvas.position = _pan_offset


## Haritayi sifirla (ortalanmis, 1x zoom)
func reset_view() -> void:
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	_canvas.scale = Vector2.ONE
	_canvas.position = Vector2.ZERO


## Belirli bir bolgeye zoom yap
func focus_territory(territory_id: String) -> void:
	if not _nodes.has(territory_id):
		return
	var target_pos: Vector2 = _nodes[territory_id].position + NODE_SIZE / 2.0
	_zoom = 2.0
	_canvas.scale = Vector2(_zoom, _zoom)
	_pan_offset = size / 2.0 - target_pos * _zoom
	_canvas.position = _pan_offset
