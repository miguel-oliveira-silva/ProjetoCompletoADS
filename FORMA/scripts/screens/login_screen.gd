# FORMA/scripts/screens/login_screen.gd
# Raiz é ScrollContainer para responsividade total.
extends ScrollContainer

# ── Nós compartilhados ─────────────────────────────────────────────────────
@onready var tab_login:    Button = %TabLogin
@onready var tab_register: Button = %TabRegister
@onready var error_label:  Label  = %ErrorLabel

# ── Painel Login ───────────────────────────────────────────────────────────
@onready var panel_login:     VBoxContainer = %PanelLogin
@onready var email_edit:      LineEdit      = %EmailEdit
@onready var password_edit:   LineEdit      = %PasswordEdit
@onready var password_toggle: Button        = %PasswordToggle
@onready var login_btn:       Button        = %LoginBtn

# ── Painel Cadastro ────────────────────────────────────────────────────────
@onready var panel_register:       VBoxContainer = %PanelRegister
@onready var name_edit:            LineEdit      = %NameEdit
@onready var reg_email_edit:       LineEdit      = %RegEmailEdit
@onready var reg_password_edit:    LineEdit      = %RegPasswordEdit
@onready var reg_password_toggle:  Button        = %RegPasswordToggle
@onready var strength_bar_1:       Panel         = %StrengthBar1
@onready var strength_bar_2:       Panel         = %StrengthBar2
@onready var strength_bar_3:       Panel         = %StrengthBar3
@onready var strength_label:       Label         = %StrengthLabel
@onready var conservador_btn:      Button        = %ConservadorButton
@onready var moderado_btn:         Button        = %ModeradoButton
@onready var agressivo_btn:        Button        = %AgressivoButton
@onready var risk_desc_label:      Label         = %RiskDescLabel
@onready var register_btn:         Button        = %RegisterBtn

# ── Referência ao card para responsividade ─────────────────────────────────
@onready var content_panel: PanelContainer = $CenterWrapper/ContentPanel

var _email_regex: RegEx
var _active_tab:  String = "login"
var _selected_risk: String = "MODERADO"

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

	password_toggle.pressed.connect(func(): _toggle_password_visibility(password_edit, password_toggle))
	reg_password_toggle.pressed.connect(func(): _toggle_password_visibility(reg_password_edit, reg_password_toggle))

	reg_password_edit.text_changed.connect(_on_reg_password_changed)
	_update_password_strength("")

	conservador_btn.pressed.connect(func(): _select_risk("CONSERVADOR"))
	moderado_btn.pressed.connect(func(): _select_risk("MODERADO"))
	agressivo_btn.pressed.connect(func(): _select_risk("AGRESSIVO"))
	_select_risk("MODERADO")

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

	var risk: String = _selected_risk

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

func _select_risk(profile: String) -> void:
	_selected_risk = profile
	
	# Atualiza a descrição
	match profile:
		"CONSERVADOR":
			risk_desc_label.text = "Preservação de capital. Preferência por renda fixa, FIIs e ativos defensivos com menor volatilidade."
		"AGRESSIVO":
			risk_desc_label.text = "Alta tolerância ao risco visando maiores retornos. Foco em ativos de alta volatilidade."
		_:
			risk_desc_label.text = "Equilíbrio entre risco e retorno. Mix de renda variável e renda fixa para diversificação eficiente."

	# Atualiza o visual dos botões
	_style_risk_button(conservador_btn, profile == "CONSERVADOR", FormaTokens.GREEN)
	_style_risk_button(moderado_btn,    profile == "MODERADO",    FormaTokens.BLUE)
	_style_risk_button(agressivo_btn,   profile == "AGRESSIVO",   FormaTokens.RED)

func _style_risk_button(btn: Button, active: bool, color: Color) -> void:
	if active:
		var s := StyleBoxFlat.new()
		s.bg_color = color
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
		s.corner_radius_bottom_left = 4
		s.content_margin_left = 12
		s.content_margin_right = 12
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_color_override("font_color",         FormaTokens.N50)
		btn.add_theme_color_override("font_hover_color",   FormaTokens.N50)
		btn.add_theme_color_override("font_pressed_color", FormaTokens.N50)
	else:
		var s := StyleBoxFlat.new()
		s.draw_center = false
		s.border_color = FormaTokens.N200
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
		s.border_width_bottom = 1
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
		s.corner_radius_bottom_left = 4
		s.content_margin_left = 12
		s.content_margin_right = 12
		btn.add_theme_stylebox_override("normal", s)
		
		var sh := StyleBoxFlat.new()
		sh.bg_color = FormaTokens.N100
		sh.corner_radius_top_left = 4
		sh.corner_radius_top_right = 4
		sh.corner_radius_bottom_right = 4
		sh.corner_radius_bottom_left = 4
		sh.content_margin_left = 12
		sh.content_margin_right = 12
		btn.add_theme_stylebox_override("hover",   sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_color_override("font_color",         FormaTokens.N700)
		btn.add_theme_color_override("font_hover_color",   FormaTokens.N900)
		btn.add_theme_color_override("font_pressed_color", FormaTokens.N900)

# ===========================================================================
# LÓGICA DE SENHA (Mostrar/Ocultar e Força da Senha)
# ===========================================================================
func _toggle_password_visibility(edit: LineEdit, btn: Button) -> void:
	edit.secret = not edit.secret
	btn.text = "Ocultar" if not edit.secret else "Mostrar"

func _on_reg_password_changed(new_text: String) -> void:
	_update_password_strength(new_text)

func _update_password_strength(pw: String) -> void:
	if pw.is_empty():
		strength_bar_1.self_modulate = FormaTokens.N200
		strength_bar_2.self_modulate = FormaTokens.N200
		strength_bar_3.self_modulate = FormaTokens.N200
		strength_label.text = ""
		return
		
	if pw.length() < 6:
		strength_bar_1.self_modulate = FormaTokens.RED
		strength_bar_2.self_modulate = FormaTokens.N200
		strength_bar_3.self_modulate = FormaTokens.N200
		strength_label.text = "Senha muito curta (mínimo 6 caracteres)"
		strength_label.add_theme_color_override("font_color", FormaTokens.RED)
		return
		
	# Cálculo de pontos (máx 4)
	var score: int = 1 # Já possui comprimento >= 6
	
	var has_upper := false
	var has_lower := false
	var has_digit := false
	var has_special := false
	var specials := "!@#$%^&*()_+-=[]{}|;':\",./<>?\\"
	
	for i in range(pw.length()):
		var c := pw.unicode_at(i)
		if c >= 65 and c <= 90:
			has_upper = true
		elif c >= 97 and c <= 122:
			has_lower = true
		elif c >= 48 and c <= 57:
			has_digit = true
		elif specials.contains(pw[i]):
			has_special = true
			
	if has_upper and has_lower:
		score += 1
	if has_digit:
		score += 1
	if has_special:
		score += 1
		
	match score:
		1, 2:
			strength_bar_1.self_modulate = FormaTokens.RED
			strength_bar_2.self_modulate = FormaTokens.N200
			strength_bar_3.self_modulate = FormaTokens.N200
			strength_label.text = "Senha fraca (misture letras maiúsculas/números/símbolos)"
			strength_label.add_theme_color_override("font_color", FormaTokens.RED)
		3:
			strength_bar_1.self_modulate = FormaTokens.AMBER
			strength_bar_2.self_modulate = FormaTokens.AMBER
			strength_bar_3.self_modulate = FormaTokens.N200
			strength_label.text = "Senha média (adicione símbolos para torná-la forte)"
			strength_label.add_theme_color_override("font_color", FormaTokens.AMBER)
		4:
			strength_bar_1.self_modulate = FormaTokens.GREEN
			strength_bar_2.self_modulate = FormaTokens.GREEN
			strength_bar_3.self_modulate = FormaTokens.GREEN
			strength_label.text = "Senha forte! Excelente padrão."
			strength_label.add_theme_color_override("font_color", FormaTokens.GREEN)
