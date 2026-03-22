## Neon dark tema — runtime'da olusturulur, root'a uygulanir.
## Tum UI elementleri otomatik olarak bu temayi miras alir.
class_name NeonTheme

const BG := Color("0D0D0D")
const SURFACE := Color("1A1A2E")
const SURFACE_LIGHT := Color("252540")
const PRIMARY := Color("E2B714")
const DANGER := Color("FF3333")
const SUCCESS := Color("33FF57")
const NEON_BLUE := Color("00D4FF")
const NEON_ORANGE := Color("FF6B35")
const TEXT_PRIMARY := Color("EEEEEE")
const TEXT_SECONDARY := Color("777777")
const TEXT_DIM := Color("444444")
const TAB_BG := Color("111122")
const CARD_BG := Color("16162A")
const BORDER := Color("2A2A4A")


static func create_theme() -> Theme:
	var theme := Theme.new()

	# === FONTS ===
	theme.set_default_font_size(16)

	# === LABEL ===
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", 16)

	# === BUTTON ===
	var btn_normal := _flat_box(SURFACE_LIGHT, 8)
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = BORDER
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := _flat_box(Color(SURFACE_LIGHT, 1.0).lightened(0.1), 8)
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = PRIMARY
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := _flat_box(PRIMARY.darkened(0.3), 8)
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_color = PRIMARY
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := _flat_box(Color(0.12, 0.12, 0.18), 8)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	var btn_focus := _flat_box(SURFACE_LIGHT, 8)
	btn_focus.border_width_bottom = 2
	btn_focus.border_color = NEON_BLUE
	theme.set_stylebox("focus", "Button", btn_focus)

	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", PRIMARY)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_font_size("font_size", "Button", 15)

	# === PANEL CONTAINER ===
	var panel_style := _flat_box(SURFACE, 10)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# === PROGRESS BAR ===
	var pb_bg := _flat_box(Color(0.1, 0.1, 0.15), 6)
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	theme.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := _flat_box(PRIMARY, 6)
	pb_fill.content_margin_top = 0
	pb_fill.content_margin_bottom = 0
	theme.set_stylebox("fill", "ProgressBar", pb_fill)

	theme.set_color("font_color", "ProgressBar", TEXT_PRIMARY)
	theme.set_font_size("font_size", "ProgressBar", 12)

	# === LINE EDIT ===
	var le_normal := _flat_box(Color(0.08, 0.08, 0.14), 8)
	le_normal.border_width_bottom = 2
	le_normal.border_color = BORDER
	theme.set_stylebox("normal", "LineEdit", le_normal)

	var le_focus := _flat_box(Color(0.08, 0.08, 0.14), 8)
	le_focus.border_width_bottom = 2
	le_focus.border_color = PRIMARY
	theme.set_stylebox("focus", "LineEdit", le_focus)

	theme.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	theme.set_color("caret_color", "LineEdit", PRIMARY)

	# === SCROLL CONTAINER ===
	var scroll_style := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", scroll_style)

	# === HSEPARATOR ===
	var sep_style := _flat_box(BORDER, 0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", sep_style)
	theme.set_constant("separation", "HSeparator", 12)

	# === RICH TEXT LABEL ===
	theme.set_color("default_color", "RichTextLabel", TEXT_PRIMARY)
	theme.set_font_size("normal_font_size", "RichTextLabel", 16)

	# === TAB STYLING CONSTANTS ===
	theme.set_constant("separation", "VBoxContainer", 4)
	theme.set_constant("separation", "HBoxContainer", 6)

	return theme


static func _flat_box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
