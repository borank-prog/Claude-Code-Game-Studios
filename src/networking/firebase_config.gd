## Firebase yapilandirmasi — REST API endpoint'leri ve anahtarlar.
class_name FirebaseConfig

const API_KEY: String = "AIzaSyBq5Kt65Ou8ikGDnVn8oK4XezVKHz4LOXg"
const PROJECT_ID: String = "cartelhood-c3502"

# Auth REST API
const AUTH_SIGNUP_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY
const AUTH_SIGNIN_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + API_KEY
const AUTH_TOKEN_REFRESH_URL: String = "https://securetoken.googleapis.com/v1/token?key=" + API_KEY
const AUTH_USERDATA_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + API_KEY
const AUTH_UPDATE_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:update?key=" + API_KEY
const AUTH_LINK_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=" + API_KEY

# Firestore REST API
const FIRESTORE_BASE_URL: String = "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"

# Token yenileme suresi (dakika)
const TOKEN_REFRESH_MINUTES: int = 55
