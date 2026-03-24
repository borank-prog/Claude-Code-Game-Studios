## Tutorial overlay — ilk 5 adim tooltip, atlanabilir, bir kez gosterilir.
## GameData'da tutorial_completed flag'i kontrol eder.
extends CanvasLayer

signal tutorial_completed()
signal step_shown(step_index: int)

var _current_step: int = 0
var _overlay: ColorRect
var _tooltip: PanelContainer
var _is_active: bool = false

const SAVE_KEY := "tutorial_completed"
const TOOLTIP_MIN_WIDTH := 260.0
const TOOLTIP_MAX_WIDTH := 420.0

const STEPS: Array[Dictionary] = [
	{
		"title": "Gorev Yap",
		"text": "Gorevler sekmesine git ve ilk gorevini tamamla.\nStamina harcar, cash ve respect kazanirsin.",
		"tab": "missions",
	},
	{
		"title": "Esya Al",
		"text": "Magazadan silah veya zirh satin al.\nEkipman gucunu arttirir.",
		"tab": "shop",
	},
	{
		"title": "Stat Dagit",
		"text": "Ana sayfada stat puanlarini dagit.\nRank atladikca yeni puanlar kazanirsin.",
		"tab": "home",
	},
	{
		"title": "Cete Kur",
		"text": "Cete sekmesinden kendi ceteni kur.\nBolge kontrolu icin cete gerekli.",
		"tab": "gang",
	},
	{
		"title": "Bolge Ele Gecir",
		"text": "Haritadan bir bolge sec ve ele gecir.\nBolgeler gelir ve savunma saglar.",
		"tab": "map",
	},
]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


## Tutorial'i baslat (eger daha once tamamlanmadiysa)
func start_if_needed() -> void:
	if _is_tutorial_completed():
		return
	_current_step = 0
	_is_active = true
	_show_step()


## Tutorial'i zorla baslat (test icin)
func force_start() -> void:
	_current_step = 0
	_is_active = true
	_show_step()


func _is_tutorial_completed() -> bool:
	# Kalici flag — CloudSave/GameData serialize ile saklanir
	return GameData.tutorial_completed or GameData.get_meta(SAVE_KEY, false)


func _mark_completed() -> void:
	GameData.tutorial_completed = true
	# Geriye donuk uyumluluk: eski metadata yolu
	GameData.set_meta(SAVE_KEY, true)


func _show_step() -> void:
	_clear_ui()

	if _current_step >= STEPS.size():
		_finish_tutorial()
		return

	var step: Dictionary = STEPS[_current_step]

	# Karanlik overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Tooltip panel
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ThemeConstants.SURFACE_COLOR, 0.98)
	style.corner_radius_top_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_top_right = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS
	style.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS
	style.border_width_top = 3
	style.border_color = ThemeConstants.PRIMARY_COLOR
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_tooltip)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_tooltip.add_child(vbox)

	# Adim gostergesi
	var step_label := Label.new()
	step_label.text = "Adim %d / %d" % [_current_step + 1, STEPS.size()]
	step_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_CAPTION)
	step_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(step_label)

	# Baslik
	var title := Label.new()
	title.text = step["title"]
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_HEADING)
	title.add_theme_color_override("font_color", ThemeConstants.PRIMARY_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	# Aciklama
	var text := Label.new()
	text.text = step["text"]
	text.add_theme_font_size_override("font_size", ThemeConstants.FONT_BODY)
	text.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(text)

	# Butonlar
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	var skip_btn := Button.new()
	skip_btn.text = "ATLA"
	skip_btn.custom_minimum_size = Vector2(100, ThemeConstants.MIN_TOUCH_TARGET)
	skip_btn.pressed.connect(_finish_tutorial)
	btn_hbox.add_child(skip_btn)

	var next_btn := Button.new()
	next_btn.text = "SONRAKI" if _current_step < STEPS.size() - 1 else "TAMAM"
	next_btn.custom_minimum_size = Vector2(140, ThemeConstants.MIN_TOUCH_TARGET)
	next_btn.pressed.connect(_next_step)
	btn_hbox.add_child(next_btn)

	# Tab'a gecis
	ScreenManager.switch_screen(step.get("tab", "home"))

	_fit_and_center_tooltip()
	step_shown.emit(_current_step)

	# Fade in
	_overlay.modulate.a = 0.0
	_tooltip.modulate.a = 0.0
	_tooltip.scale = Vector2(0.9, 0.9)
	_tooltip.pivot_offset = _tooltip.size / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(_tooltip, "modulate:a", 1.0, 0.2)
	tween.tween_property(_tooltip, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _fit_and_center_tooltip() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var margin := float(ThemeConstants.SCREEN_MARGIN)
	var target_width := clampf(view_size.x - (margin * 2.0), TOOLTIP_MIN_WIDTH, TOOLTIP_MAX_WIDTH)

	_tooltip.custom_minimum_size = Vector2(target_width, 0.0)
	var min_size := _tooltip.get_combined_minimum_size()
	_tooltip.size = Vector2(target_width, min_size.y)
	_tooltip.position.x = floorf((view_size.x - target_width) * 0.5)

	var desired_top := (view_size.y * 0.55) - (_tooltip.size.y * 0.5)
	_tooltip.position.y = clampf(desired_top, margin, view_size.y - _tooltip.size.y - margin)


func _next_step() -> void:
	_current_step += 1
	_show_step()


func _finish_tutorial() -> void:
	_clear_ui()
	_is_active = false
	_mark_completed()
	tutorial_completed.emit()
	queue_free()


func _clear_ui() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _tooltip:
		_tooltip.queue_free()
		_tooltip = null
