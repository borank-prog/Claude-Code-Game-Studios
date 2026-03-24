## TutorialOverlay layout yardimci fonksiyon testleri.
extends GutTest

const TutorialOverlay := preload("res://src/ui/components/tutorial_overlay.gd")


func test_calculate_tooltip_width_clamps_to_min() -> void:
	var width := TutorialOverlay.calculate_tooltip_width(180.0, 12.0)
	assert_eq(width, 260.0, "cok dar ekranda minimum genislik korunmali")


func test_calculate_tooltip_width_clamps_to_max() -> void:
	var width := TutorialOverlay.calculate_tooltip_width(900.0, 12.0)
	assert_eq(width, 420.0, "genis ekranda maksimum genislik asinmamali")


func test_calculate_tooltip_width_uses_available_space() -> void:
	var width := TutorialOverlay.calculate_tooltip_width(360.0, 12.0)
	assert_eq(width, 336.0, "normal durumda kenar bosluklari dusulmeli")


func test_calculate_button_columns_stacks_on_narrow_width() -> void:
	assert_eq(TutorialOverlay.calculate_button_columns(300.0), 1, "dar alanda butonlar alt alta olmali")


func test_calculate_button_columns_uses_two_columns_on_wide_width() -> void:
	assert_eq(TutorialOverlay.calculate_button_columns(360.0), 2, "yeterli alanda butonlar yanyana olmali")
