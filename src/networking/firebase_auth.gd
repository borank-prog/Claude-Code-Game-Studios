## Firebase Authentication — Guest login, token yonetimi, hesap baglama.
## REST API kullanir, plugin bagImliligi yok.
extends Node

signal auth_completed(success: bool, user_id: String)
signal auth_failed(error: String)
signal token_refreshed()

var user_id: String = ""
var id_token: String = ""
var refresh_token: String = ""
var is_authenticated: bool = false

var _http_request: HTTPRequest
var _refresh_timer: Timer
var _pending_action: String = ""  # "signup", "signin", "refresh", "link"

const SAVE_PATH: String = "user://auth.dat"


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = FirebaseConfig.TOKEN_REFRESH_MINUTES * 60.0
	_refresh_timer.timeout.connect(_refresh_auth_token)
	_refresh_timer.autostart = false
	add_child(_refresh_timer)

	# Onceki oturumu yukle
	_load_saved_auth()


## Anonim (guest) giris — sifir surtuNme
func sign_in_anonymous() -> void:
	if is_authenticated:
		auth_completed.emit(true, user_id)
		return

	_pending_action = "signup"
	var body := JSON.stringify({"returnSecureToken": true})
	var headers := ["Content-Type: application/json"]
	var err := _http_request.request(
		FirebaseConfig.AUTH_SIGNUP_URL, headers, HTTPClient.METHOD_POST, body
	)
	if err != OK:
		auth_failed.emit("HTTP request failed: %d" % err)


## Token yenile (arka planda, sessiz)
func _refresh_auth_token() -> void:
	if refresh_token.is_empty():
		return

	_pending_action = "refresh"
	var body := "grant_type=refresh_token&refresh_token=%s" % refresh_token
	var headers := ["Content-Type: application/x-www-form-urlencoded"]
	_http_request.request(
		FirebaseConfig.AUTH_TOKEN_REFRESH_URL, headers, HTTPClient.METHOD_POST, body
	)


## Email/password ile hesap baglama (guest -> kalici)
func link_email_password(email: String, password: String) -> void:
	if not is_authenticated:
		auth_failed.emit("Not authenticated")
		return

	_pending_action = "link"
	var body := JSON.stringify({
		"idToken": id_token,
		"email": email,
		"password": password,
		"returnSecureToken": true,
	})
	var headers := ["Content-Type: application/json"]
	_http_request.request(
		FirebaseConfig.AUTH_UPDATE_URL, headers, HTTPClient.METHOD_POST, body
	)


## Auth header (diger sistemler icin)
func get_auth_header() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token,
	])


## HTTP yanit isleme
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		auth_failed.emit("Connection failed: %d" % result)
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		auth_failed.emit("JSON parse error")
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}

	# Hata kontrolu
	if data.has("error"):
		var error_msg: String = data["error"].get("message", "Unknown error")
		auth_failed.emit(error_msg)
		return

	match _pending_action:
		"signup", "signin":
			_handle_auth_response(data)
		"refresh":
			_handle_refresh_response(data)
		"link":
			_handle_link_response(data)

	_pending_action = ""


func _handle_auth_response(data: Dictionary) -> void:
	user_id = data.get("localId", "")
	id_token = data.get("idToken", "")
	refresh_token = data.get("refreshToken", "")
	is_authenticated = not user_id.is_empty()

	if is_authenticated:
		_save_auth()
		_refresh_timer.start()
		print("Firebase Auth: Logged in as %s" % user_id)
		auth_completed.emit(true, user_id)
	else:
		auth_failed.emit("Auth response missing user data")


func _handle_refresh_response(data: Dictionary) -> void:
	id_token = data.get("id_token", id_token)
	refresh_token = data.get("refresh_token", refresh_token)
	user_id = data.get("user_id", user_id)
	_save_auth()
	token_refreshed.emit()
	print("Firebase Auth: Token refreshed")


func _handle_link_response(data: Dictionary) -> void:
	id_token = data.get("idToken", id_token)
	refresh_token = data.get("refreshToken", refresh_token)
	_save_auth()
	print("Firebase Auth: Account linked")


## Yerel kayit (cihaz degistirmede kaybolmasin)
func _save_auth() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var save_data := {
			"user_id": user_id,
			"refresh_token": refresh_token,
		}
		file.store_string(JSON.stringify(save_data))


func _load_saved_auth() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	user_id = data.get("user_id", "")
	refresh_token = data.get("refresh_token", "")

	if not refresh_token.is_empty():
		# Kayitli token var — yenile ve giris yap
		_refresh_auth_token()


## Cikis
func sign_out() -> void:
	user_id = ""
	id_token = ""
	refresh_token = ""
	is_authenticated = false
	_refresh_timer.stop()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
