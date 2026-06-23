extends Node

var token: String = ""
const TOKEN_FILE_PATH: String = "user://auth.dat"
const BASE_URL: String = "http://20.195.170.160:8081"
const AUTH_PATHS: Array[String] = ["/api/users/authenticate", "/api/users/login"]
const HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept: application/json"]

func _ready() -> void:
	load_token()

func login(email: String, password: String) -> Dictionary:
	if email == "" or password == "":
		return {
			"ok": false,
			"code": 0,
			"error": "E-mail e senha são obrigatórios."
		}

	var payload: String = JSON.stringify({"email": email, "password": password})

	for path in AUTH_PATHS:
		var url: String = BASE_URL + path
		var result: Dictionary = await _request(url, HTTPClient.METHOD_POST, payload)

		if result.code == 200 or result.code == 201:
			if result.data is Dictionary:
				var token_value: String = str(result.data.get("token", ""))
				if token_value != "":
					save_token(token_value)
					return {
						"ok": true,
						"code": result.code,
						"token": token_value,
						"data": result.data
					}
				return {
					"ok": false,
					"code": result.code,
					"error": "Resposta do servidor não contém token.",
					"data": result.data
				}
			return {
				"ok": false,
				"code": result.code,
				"error": "Resposta do servidor inesperada.",
				"data": result.data
			}

		if result.code == 404:
			continue

		return result

	return {
		"ok": false,
		"code": 404,
		"error": "Endpoint de autenticação não encontrado. Verifique a URL.",
	}

func clear_token() -> void:
	token = ""
	if FileAccess.file_exists(TOKEN_FILE_PATH):
		FileAccess.remove(TOKEN_FILE_PATH)

func save_token(new_token: String) -> void:
	token = new_token
	var file := FileAccess.open(TOKEN_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[AuthManager] Não foi possível abrir %s para gravação." % TOKEN_FILE_PATH)
		return
	file.store_string(token)
	file.close()

func load_token() -> String:
	if not FileAccess.file_exists(TOKEN_FILE_PATH):
		return ""
	var file := FileAccess.open(TOKEN_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[AuthManager] Não foi possível abrir %s para leitura." % TOKEN_FILE_PATH)
		return ""
	token = file.get_as_text().strip_edges()
	file.close()
	return token

func _request(url: String, method: int = HTTPClient.METHOD_GET, body: String = "") -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var err: int = http.request(url, HEADERS, method, body)
	if err != OK:
		http.queue_free()
		return {
			"ok": false,
			"code": -1,
			"error": "Falha ao iniciar requisição HTTP.",
			"data": null
		}

	var result: Array = await http.request_completed
	http.queue_free()

	var status: int = result[1]
	var raw_body: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = null
	if raw_body.length() > 0:
		data = JSON.parse_string(raw_body)

	var ok: bool = status >= 200 and status < 300

    var mensagem_erro: String = ""
	if not ok:
		mensagem_erro = raw_body.strip_edges()

	return {
		"ok": ok,
		"code": status,
		"data": data,
		"error": mensagem_erro
	}
