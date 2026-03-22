## CartelHood UI tema sabitleri — neon sokak estetigi.
class_name ThemeConstants

# === RENKLER ===
const BG_COLOR := Color("0D0D0D")
const SURFACE_COLOR := Color("1A1A2E")
const PRIMARY_COLOR := Color("E2B714")       # Altin — ana aksiyonlar
const DANGER_COLOR := Color("FF3333")         # Kirmizi — savas, uyari
const SUCCESS_COLOR := Color("33FF57")        # Yesil — kazanim
const TEXT_PRIMARY := Color("FFFFFF")
const TEXT_SECONDARY := Color("888888")
const NEON_ACCENT := Color("FF6B35")          # Neon turuncu vurgu
const NEON_BLUE := Color("00D4FF")            # Neon mavi — respect, info
const RARITY_COMMON := Color("AAAAAA")
const RARITY_UNCOMMON := Color("33FF57")
const RARITY_RARE := Color("3399FF")
const RARITY_EPIC := Color("AA33FF")
const RARITY_LEGENDARY := Color("FFD700")

# === BOYUTLAR ===
const TAB_BAR_HEIGHT: int = 56
const MIN_TOUCH_TARGET: int = 44
const SCREEN_MARGIN: int = 12
const CARD_PADDING: int = 16
const CORNER_RADIUS: int = 12

# === ANIMASYON ===
const TRANSITION_DURATION: float = 0.2
const POPUP_FADE_IN: float = 0.15
const POPUP_FADE_OUT: float = 0.1
const FEEDBACK_FLOAT_DURATION: float = 1.0

# === FONT BOYUTLARI ===
const FONT_HEADING: int = 28
const FONT_SUBHEADING: int = 22
const FONT_BODY: int = 18
const FONT_CAPTION: int = 14
const FONT_NUMBERS: int = 20


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"COMMON": return RARITY_COMMON
		"UNCOMMON": return RARITY_UNCOMMON
		"RARE": return RARITY_RARE
		"EPIC": return RARITY_EPIC
		"LEGENDARY": return RARITY_LEGENDARY
		_: return RARITY_COMMON


static func format_number(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	elif n >= 1_000:
		return "%.1fK" % (n / 1_000.0)
	return str(n)
