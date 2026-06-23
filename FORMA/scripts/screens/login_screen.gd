# FORMA/scripts/screens/login_screen.gd
# Raiz é ScrollContainer para responsividade total.
extends ScrollContainer

# ── Nós compartilhados ─────────────────────────────────────────────────────
@onready var tab_login:    Button = %TabLogin
@onready var tab_register: Button = %TabRegister
@onready var error_label:  Label  = %ErrorLabel

# ── Painel Login ───────────────────────────────────────────────────────────
@onready var panel_login:    VBoxContainer = %PanelLogin
@onready var email_edit:     LineEdit      = %EmailEdit
@onready var password_edit:  LineEdit      = %PasswordEdit
@onready var login_btn:      Button        = %LoginBtn

# ── Painel Cadastro ────────────────────────────────────────────────────────
@onready var panel_register:    VBoxContainer = %PanelRegister
@onready var name_edit:         LineEdit      = %NameEdit
@onready var reg_email_edit:    LineEdit      = %RegEmailEdit
@onready var reg_password_edit: LineEdit      = %RegPasswordEdit
@onready var risk_option:       OptionButton  = %RiskOption
@onready var register_btn:      Button        = %RegisterBtn

# ── Referência ao card para responsividade ─────────────────────────────────
@onready var content_panel: PanelContainer = $CenterWrapper/ContentPanel

var _email_regex: RegEx
var _active_tab:  String = "login"

# ===========================================================================
func _ready() -> void:
	_email_regex = RegEx.new()
	_email_regex.compile("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")

	tab_login.pressed.connect(func(): _switch_tab("login"))
	tab_register.pressed.connect(func(): _switch_tab("register"))
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)

	# Envio com Enter
	password_edit.text_submitted.connect(func(_t): _on_login_pressed())
	reg_password_edit.text_submitted.connect(func(_t): _on_register_pressed())

	_switch_tab("login")
	_apply_responsive()
	get_tree().root.size_changed.connect(_apply_responsive)

# ===========================================================================
# RESPONSIVIDADE
# ===========================================================================
func _apply_responsive() -> void:
	var vp_w: int = get_tree().root.size.x
	if vp_w <= 480:
		# Mobile: ocupa quase toda a largura
		content_panel.custom_minimum_size = Vector2(float(vp_w) - 32.0, 0.0)
	else:
		# Desktop / tablet: card fixo de 400 px
		content_panel.custom_minimum_size = Vector2(400.0, 0.0)

# ===========================================================================
# ABAS
# ===========================================================================
func _switch_tab(tab: String) -> void:
	_active_tab = tab
	_clear_error()

	panel_login.visible    = (tab == "login")
	panel_register.visible = (tab == "register")

	# Estilos visuais das abas (underline ativo / inativo + peso da fonte)
	_set_tab_active(tab_login,    tab == "login")
	_set_tab_active(tab_register, tab == "register")

	# Atualiza o título do cabeçalho
	var title: Label = $CenterWrapper/ContentPanel/Margin/VBox/Header/TitleLabel
	if tab == "login":
		title.text = "Bem-vindo de volta"
	else:
		title.text = "Crie sua conta"

func _set_tab_active(btn: Button, active: bool) -> void:
	var color_active   := Color(0.051, 0.051, 0.082, 1.0)
	var color_inactive := Color(0.384, 0.380, 0.447, 1.0)
	btn.add_theme_color_override("font_color", color_active if active else color_inactive)
	btn.add_theme_color_override("font_hover_color",   color_active)
	btn.add_theme_color_override("font_pressed_color", color_active)

# ===========================================================================
# LOGIN
# ===========================================================================
func _on_login_pressed() -> void:
	_clear_error()
	var email    := email_edit.text.strip_edges()
	var password := password_edit.text

	if not _validate_email_password(email, password):
		return

	_set_loading(login_btn, true, "Entrando...")
	var result: Dictionary = await AuthManager.login(email, password)
	if not is_inside_tree():
		return
	_set_loading(login_btn, false, "Entrar")

	if result.ok:
		get_tree().change_scene_to_file("res://scenes/screens/wallet_selection_screen.tscn")
		return

	_show_error(_map_error(result))

# ===========================================================================
# CADASTRO
# ===========================================================================
func _on_register_pressed() -> void:
	_clear_error()
	var name_val  := name_edit.text.strip_edges()
	var email     := reg_email_edit.text.strip_edges()
	var password  := reg_password_edit.text

	var risk_map: Array[String] = ["CONSERVADOR", "MODERADO", "AGRESSIVO"]
	var risk: String = risk_map[risk_option.selected]

	if name_val.length() < 2:
		_show_error("Nome deve ter pelo menos 2 caracteres.")
		return
	if not _validate_email_password(email, password):
		return
	if password.length() < 6:
		_show_error("Senha deve ter pelo menos 6 caracteres.")
		return

	_set_loading(register_btn, true, "Criando conta...")
	var result: Dictionary = await AuthManager.register(name_val, email, password, risk)
	if not is_inside_tree():
		return
	_set_loading(register_btn, false, "Criar Conta")

	if result.ok:
		get_tree().change_scene_to_file("res://scenes/screens/wallet_selection_screen.tscn")
		return

	if result.code == 409:
		_show_error("E-mail já cadastrado. Use a aba Entrar.")
		_switch_tab("login")
		return

	_show_error(_map_error(result))

# ===========================================================================
# HELPERS
# ===========================================================================
func _validate_email_password(email: String, password: String) -> bool:
	if email == "" or password == "":
		_show_error("Preencha todos os campos.")
		return false
	if not _email_regex.search(email):
		_show_error("Informe um e-mail válido.")
		return false
	return true

func _map_error(result: Dictionary) -> String:
	var msg: String = str(result.get("error", ""))
	var code: int = int(result.get("code", -1))
	match code:
		0, -1: return "Nao foi possivel conectar ao servidor. Verifique sua internet."
		401:   return "Credenciais invalidas. Verifique e-mail e senha."
		403:   return "Acesso negado."
		404:   return "E-mail nao encontrado. Crie uma conta."
		409:   return "E-mail ja cadastrado."
		400:   return "Dados invalidos. Verifique os campos."
		500, 501, 502, 503, 504: return "Erro no servidor. Tente novamente mais tarde."
		_:     return msg if msg != "" else "Erro desconhecido. Tente novamente."

func _show_error(msg: String) -> void:
	error_label.text    = msg
	error_label.visible = true

func _clear_error() -> void:
	error_label.text    = ""
	error_label.visible = false

func _set_loading(btn: Button, loading: bool, label: String) -> void:
	btn.disabled = loading
	btn.text     = label
