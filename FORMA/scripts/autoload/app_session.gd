extends Node

var user_id:   int    = 0
var user_name: String = ""
var latest_portfolio: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	await _ensure_test_user()

func _ensure_test_user() -> void:
	var result := await WalletApiClient.get_user(1)
	if result.ok and result.data != null:
		user_id   = int(result.data.get("id", 1))
		user_name = str(result.data.get("name", "Usuário"))
		print("[Session] Usuário carregado: %s (id=%d)" % [user_name, user_id])
	else:
		var reg := await WalletApiClient.register_user(
			"João Silva", "joao@markovitz.app", "senha123", "MODERADO"
		)
		if reg.ok and reg.data != null:
			user_id   = int(reg.data.get("id", 1))
			user_name = str(reg.data.get("name", "João Silva"))
			print("[Session] Usuário criado: %s (id=%d)" % [user_name, user_id])
		else:
			push_warning("[Session] Não foi possível criar usuário — usando id=1 como fallback")
			user_id = 1
