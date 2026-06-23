# FORMA/scripts/autoload/AuthManager.gd
extends Node

const TOKEN_FILE_PATH: String = "user://auth.dat"
const BASE_URL: String = "http://20.195.170.160:8081"
const HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept: application/json"]

var token: String = ""
var current_user: Dictionary = {}

func _ready() -> void:
	token = _load_token()

# ---------------------------------------------------------------------------
# LOGIN — tenta buscar o usuário pelo e-mail listando todos os usuários.
# O backend não possui endpoint de autenticação com senha; o fluxo real é:
#   1. Listar usuários e encontrar o e-mail
#   2. Verificar a senha localmente (texto puro, igual ao backend em dev)
#   3. Armazenar o ID na sessão
# ---------------------------------------------------------------------------
func login(email: String, password: String) -> Dictionary:
	if email == "" or password == "":
		return _err(0, "E-mail e senha são obrigatórios.")

	var result := await _request(BASE_URL + "/api/users", HTTPClient.METHOD_GET)

	if not result.ok:
		return _err(result.code, "Não foi possível conectar ao servidor.")

	var users: Array = []
	if result.data is Array:
		users = result.data
	else:
		return _err(result.code, "Resposta inesperada do servidor.")

	for user in users:
		if user is Dictionary and user.get("email", "") == email:
			# Verificação de senha (texto puro — igual ao backend em modo dev)
			# Se o backend armazenar hash, este passo precisará de endpoint próprio.
			var stored_pass: String = str(user.get("password", ""))
			if stored_pass != "" and stored_pass != password:
				return _err(401, "Senha incorreta.")

			_populate_session(user)
			_save_token("session_%d" % AppSession.user_id)
			return {
				"ok": true,
				"code": 200,
				"data": user
			}

	return _err(404, "E-mail não encontrado. Verifique ou crie uma conta.")

# ---------------------------------------------------------------------------
# REGISTER — cria conta e preenche sessão
# ---------------------------------------------------------------------------
func register(name: String, email: String, password: String,
		risk_profile: String = "MODERADO") -> Dictionary:
	if name == "" or email == "" or password == "":
		return _err(0, "Preencha todos os campos obrigatórios.")

	var payload := JSON.stringify({
		"name": name,
		"email": email,
		"password": password,
		"riskProfile": risk_profile
	})

	var result := await _request(BASE_URL + "/api/users/register",
			HTTPClient.METHOD_POST, payload)

	if result.ok and result.data is Dictionary:
		_populate_session(result.data)
		_save_token("session_%d" % AppSession.user_id)
		return {"ok": true, "code": result.code, "data": result.data}

	if result.code == 409:
		return _err(409, "Este e-mail já está cadastrado. Faça login.")

	var msg: String = ""
	if result.data is Dictionary:
		msg = str(result.data.get("message", result.data.get("error", "")))
	if msg == "":
		msg = "Erro ao criar conta. Tente novamente."
	return _err(result.code, msg)

# ---------------------------------------------------------------------------
# SESSÃO
# ---------------------------------------------------------------------------
func _populate_session(user: Dictionary) -> void:
	AppSession.user_id    = int(user.get("id",          0))
	AppSession.user_name  = str(user.get("name",        "Usuário"))
	AppSession.user_email = str(user.get("email",       ""))
	AppSession.user_risk  = str(user.get("riskProfile", "MODERADO"))

func clear_token() -> void:
	token = ""
	current_user = {}
	if FileAccess.file_exists(TOKEN_FILE_PATH):
		DirAccess.remove_absolute(TOKEN_FILE_PATH)

func _save_token(new_token: String) -> void:
	token = new_token
	var file := FileAccess.open(TOKEN_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[AuthManager] Não foi possível gravar token.")
		return
	file.store_string(token)
	file.close()

func _load_token() -> String:
	if not FileAccess.file_exists(TOKEN_FILE_PATH):
		return ""
	var file := FileAccess.open(TOKEN_FILE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var t := file.get_as_text().strip_edges()
	file.close()
	return t

# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
func _request(url: String, method: int = HTTPClient.METHOD_GET,
		body: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url, HEADERS, method, body)
	if err != OK:
		http.queue_free()
		return _err(-1, "Falha ao iniciar requisição HTTP.")

	var res: Array = await http.request_completed
	http.queue_free()

	var code: int = res[1]
	var raw: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(raw) if raw.length() > 2 else null
	var ok: bool = code >= 200 and code < 300

	return {"ok": ok, "code": code, "data": data, "error": raw if not ok else ""}

func _err(code: int, msg: String) -> Dictionary:
	return {"ok": false, "code": code, "error": msg, "data": null}
