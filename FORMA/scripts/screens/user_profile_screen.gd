extends VBoxContainer

@onready var safe_area_margin:    MarginContainer = %SafeAreaMargin
@onready var main_scroll:         ScrollContainer = %MainScroll
@onready var back_button:         Button          = %BackButton
@onready var avatar_label:        Label           = %AvatarLabel
@onready var user_name_label:     Label           = %UserNameLabel
@onready var user_email_label:    Label           = %UserEmailLabel
@onready var risk_label:          Label           = %RiskLabel
@onready var portfolio_count:     Label           = %PortfolioCountLabel
@onready var portfolio_list:      VBoxContainer   = %PortfoliosList
@onready var empty_portfolios:    Label           = %EmptyPortfoliosLabel
@onready var notification_list:   VBoxContainer   = %NotificationsList
@onready var empty_notifs:        Label           = %EmptyNotificationsLabel
@onready var risk_desc_label:     Label           = %RiskDescLabel
@onready var conservador_btn:     Button          = %ConservadorButton
@onready var moderado_btn:        Button          = %ModeradoButton
@onready var agressivo_btn:       Button          = %AgressivoButton
@onready var new_portfolio_btn:   Button          = %NewPortfolioButton

const PORTFOLIO_CARD_SCENE    := preload("res://scenes/components/portfolio_card.tscn")
const NOTIFICATION_ITEM_SCENE := preload("res://scenes/components/notification_item.tscn")

const BREAKPOINT_TABLET  := 600
const BREAKPOINT_DESKTOP := 900

var _current_risk: String = "MODERADO"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.size_changed.connect(_update_responsive_layout)

	back_button.pressed.connect(_go_back)
	new_portfolio_btn.pressed.connect(_go_to_selection)
	conservador_btn.pressed.connect(func() -> void: _select_risk("CONSERVADOR"))
	moderado_btn.pressed.connect(func() -> void: _select_risk("MODERADO"))
	agressivo_btn.pressed.connect(func() -> void: _select_risk("AGRESSIVO"))

	_populate_user_header()
	await _load_portfolios()
	await _load_notifications()

	await get_tree().process_frame
	await get_tree().process_frame
	_update_responsive_layout()
	_hide_scrollbar(main_scroll.get_v_scroll_bar())
	_hide_scrollbar(main_scroll.get_h_scroll_bar())

# ── Cabeçalho do usuário (dados do AppSession) ─────────────────────────────────

func _populate_user_header() -> void:
	var name:  String = AppSession.user_name
	var email: String = AppSession.user_email
	var risk:  String = AppSession.user_risk
	_current_risk = risk

	var initial := name.left(1).to_upper() if not name.is_empty() else "?"
	avatar_label.text     = initial
	user_name_label.text  = name
	user_email_label.text = email
	risk_label.text       = _risk_display(risk)
	risk_desc_label.text  = _risk_desc(risk)

	# Estiliza o chip de perfil de risco
	_apply_risk_chip_style(risk)
	_update_risk_buttons(risk)

func _apply_risk_chip_style(risk: String) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color              = _risk_color(risk)
	s.content_margin_left   = 10.0
	s.content_margin_right  = 10.0
	s.content_margin_top    = 5.0
	s.content_margin_bottom = 5.0
	risk_label.get_parent().add_theme_stylebox_override("panel", s)

# ── Carteiras (GET /api/portfolios/user/{userId}) ──────────────────────────────

# ── Carregamento com guards obrigatórios após await ────────────────────────────

func _load_portfolios() -> void:
	var result := await WalletApiClient.get_user_portfolios(AppSession.user_id)
	if not is_inside_tree():
		return
	if not result.ok or result.data == null or not (result.data is Array):
		empty_portfolios.visible = true
		return
	var portfolios: Array = result.data
	if portfolios.is_empty():
		empty_portfolios.visible = true
		return
	portfolio_count.text     = "(%d)" % portfolios.size()
	empty_portfolios.visible = false
	for portfolio: Dictionary in portfolios:
		var card: PortfolioCard = PORTFOLIO_CARD_SCENE.instantiate()
		portfolio_list.add_child(card)
		card.setup(portfolio)
		card.view_pressed.connect(func(p: Dictionary) -> void: _view_portfolio(p))

# ── Notificações (GET /api/notifications/user/{userId}) ───────────────────────

func _load_notifications() -> void:
	var result := await WalletApiClient.get_notifications(AppSession.user_id)
	if not is_inside_tree():
		return
	if not result.ok or result.data == null or not (result.data is Array):
		empty_notifs.visible = true
		return
	var notifs: Array = result.data
	if notifs.is_empty():
		empty_notifs.visible = true
		return
	empty_notifs.visible = false
	for i in range(mini(notifs.size(), 5)):
		var item: NotificationItem = NOTIFICATION_ITEM_SCENE.instantiate()
		notification_list.add_child(item)
		item.setup(notifs[i])

# ── Perfil de risco (PUT /api/users/{id}/risk-profile) ────────────────────────

func _select_risk(profile: String) -> void:
	if profile == _current_risk:
		return
	_set_risk_loading(true)
	var result := await WalletApiClient.update_risk_profile(AppSession.user_id, profile)
	if not is_inside_tree():
		return
	_set_risk_loading(false)
	if result.ok:
		_current_risk        = profile
		AppSession.user_risk = profile
		risk_label.text      = _risk_display(profile)
		risk_desc_label.text = _risk_desc(profile)
		_apply_risk_chip_style(profile)
		_update_risk_buttons(profile)

func _update_risk_buttons(active: String) -> void:
	var btns := {"CONSERVADOR": conservador_btn, "MODERADO": moderado_btn, "AGRESSIVO": agressivo_btn}
	for profile: String in btns:
		var btn: Button = btns[profile]
		if profile == active:
			var s := StyleBoxFlat.new()
			s.bg_color = _risk_color(profile)
			s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
			s.corner_radius_bottom_right = 4; s.corner_radius_bottom_left = 4
			btn.add_theme_stylebox_override("normal",  s)
			btn.add_theme_stylebox_override("hover",   s)
			btn.add_theme_stylebox_override("pressed", s)
			btn.add_theme_color_override("font_color", FormaTokens.N50)
		else:
			var s := StyleBoxFlat.new()
			s.draw_center = false
			s.border_color = FormaTokens.N200
			s.border_width_left = 1; s.border_width_top = 1
			s.border_width_right = 1; s.border_width_bottom = 1
			s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
			s.corner_radius_bottom_right = 4; s.corner_radius_bottom_left = 4
			btn.add_theme_stylebox_override("normal", s)
			var sh := StyleBoxFlat.new()
			sh.bg_color = FormaTokens.N100
			sh.corner_radius_top_left = 4; sh.corner_radius_top_right = 4
			sh.corner_radius_bottom_right = 4; sh.corner_radius_bottom_left = 4
			btn.add_theme_stylebox_override("hover",   sh)
			btn.add_theme_stylebox_override("pressed", sh)
			btn.add_theme_color_override("font_color", FormaTokens.N700)

func _set_risk_loading(loading: bool) -> void:
	conservador_btn.disabled = loading
	moderado_btn.disabled    = loading
	agressivo_btn.disabled   = loading

# ── Navegação ──────────────────────────────────────────────────────────────────

# ── Navegação segura ───────────────────────────────────────────────────────────

func _navigate_to(path: String) -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(path)

func _view_portfolio(portfolio: Dictionary) -> void:
	AppSession.latest_portfolio = portfolio
	_navigate_to("res://scenes/screens/portfolio_result_screen.tscn")

func _go_back() -> void:
	_navigate_to("res://scenes/screens/wallet_selection_screen.tscn")

func _go_to_selection() -> void:
	_navigate_to("res://scenes/screens/wallet_selection_screen.tscn")

# ── Responsividade ─────────────────────────────────────────────────────────────

func _update_responsive_layout() -> void:
	var w := get_tree().root.size.x
	if w <= 0:
		return
	var margin := 20
	if w >= BREAKPOINT_DESKTOP:
		margin = 64
	elif w >= BREAKPOINT_TABLET:
		margin = 32
	safe_area_margin.add_theme_constant_override("margin_left",  margin)
	safe_area_margin.add_theme_constant_override("margin_right", margin)

func _hide_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2.ZERO
	bar.modulate            = Color(1, 1, 1, 0)
	bar.mouse_filter        = Control.MOUSE_FILTER_IGNORE

# ── Helpers de texto ───────────────────────────────────────────────────────────

func _risk_display(risk: String) -> String:
	match risk:
		"CONSERVADOR": return "Conservador"
		"AGRESSIVO":   return "Agressivo"
		_:             return "Moderado"

func _risk_color(risk: String) -> Color:
	match risk:
		"CONSERVADOR": return FormaTokens.GREEN
		"AGRESSIVO":   return FormaTokens.RED
		_:             return FormaTokens.BLUE

func _risk_desc(risk: String) -> String:
	match risk:
		"CONSERVADOR":
			return "Preservação de capital. Preferência por renda fixa, FIIs e ativos defensivos com menor volatilidade."
		"AGRESSIVO":
			return "Alta tolerância ao risco visando maiores retornos. Foco em small caps, BDRs e ativos de alta volatilidade."
		_:
			return "Equilíbrio entre risco e retorno. Mix de renda variável e renda fixa para diversificação eficiente."
