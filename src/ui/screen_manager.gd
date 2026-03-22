## Ekran yonetimi — tab gecisleri, popup kuyrugu, bildirim sistemi.
## 3-tap kurali: herhangi bir ozellige max 3 dokunusta ulasim.
extends Node

var current_screen: String = "home"
var popup_queue: Array[Dictionary] = []
var is_popup_showing: bool = false

const MAX_POPUP_QUEUE: int = 5
const SCREEN_TRANSITION_DURATION: float = 0.2

signal screen_switched(screen_name: String)
signal popup_shown(popup_data: Dictionary)
signal popup_closed()


## Ekran degistir
func switch_screen(screen_name: String) -> void:
	if screen_name == current_screen:
		return
	current_screen = screen_name
	screen_switched.emit(screen_name)
	EventBus.screen_changed.emit(screen_name)


## Popup goster (kuyruklu)
func show_popup(data: Dictionary) -> void:
	if is_popup_showing:
		if popup_queue.size() < MAX_POPUP_QUEUE:
			popup_queue.append(data)
		return

	is_popup_showing = true
	popup_shown.emit(data)
	EventBus.popup_requested.emit(data)


## Popup kapat, kuyruktan sonrakini goster
func close_popup() -> void:
	is_popup_showing = false
	popup_closed.emit()

	if not popup_queue.is_empty():
		var next := popup_queue.pop_front() as Dictionary
		# Bir sonraki frame'de goster (animasyon bitsin)
		call_deferred("show_popup", next)


## Bildirim kuyrukla
func queue_notification(text: String, type: String = "info") -> void:
	EventBus.notification_queued.emit(text, type)
