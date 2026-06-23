extends CenterContainer

@onready var email_line_edit: LineEdit = $ContentPanel/VBox/EmailLineEdit
@onready var password_line_edit: LineEdit = $ContentPanel/VBox/PasswordLineEdit
@onready var login_button: Button = $ContentPanel/VBox/LoginButton
@onready var error_label: Label = $ContentPanel/VBox/ErrorLabel

var email_regex: RegEx

func _ready() -> void:
	email_regex = RegEx.new()
	email_regex.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
	login_button.pressed.connect(_on_login_button_pressed)

func _on_login_button_pressed() -> void:
	# Limpar mensagens de erro anteriores
	clear_error()

	# Obter valores dos campos de entrada
	var email: String = email_line_edit.text.strip_edges()
	var password: String = password_line_edit.text

	# Validar entrada ANTES de desativar o botão
	if not _validate_inputs(email, password):
		return

	# Desativar interação e mostrar feedback visual de carregamento
	login_button.disabled = true
	login_button.text = "Conectando..."

	# Aguardar resposta do servidor
	var result = await AuthManager.login(email, password)

	# Reativar o botão independentemente do resultado
	_reset_login_button()

	# Processar resultado do login
	if result.ok:
		# Login bem-sucedido: mudar de cena
		get_tree().change_scene_to_file("res://scenes/screens/wallet_selection_screen.tscn")
		return

	# Login falhou: tratar diferentes códigos de erro
	match result.code:
		400:
			_show_error("E-mail ou senha inválidos. Verifique e tente novamente.")
		401:
			_show_error("Credenciais incorretas. Tente novamente.")
		500, 501, 502, 503, 504:
			_show_error("Erro no servidor. Tente novamente mais tarde.")
		404:
			_show_error(result.error if result.error != "" else "Endpoint de autenticação não encontrado.")
		_:
			_show_error(result.error if result.error != "" else "Não foi possível conectar ao servidor. Verifique sua internet.")

func _validate_inputs(email: String, password: String) -> bool:
	if email == "" or password == "":
		_show_error("Preencha e-mail e senha antes de continuar.")
		return false
	if not email_regex.search(email):
		_show_error("Informe um e-mail válido.")
		return false
	return true

func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true

func clear_error() -> void:
	error_label.visible = false
	error_label.text = ""

func _reset_login_button() -> void:
	login_button.disabled = false
	login_button.text = "Entrar"
