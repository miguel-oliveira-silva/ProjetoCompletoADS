extends VBoxContainer

@onready var safe_area_margin:   MarginContainer = %SafeAreaMargin
@onready var counter_label:      Label           = %SelectionCounterLabel
@onready var selection_progress: ProgressBar     = %SelectionProgressBar
@onready var suggested_row:      HBoxContainer   = %SuggestedPortfoliosRow
@onready var suggested_scroll:   ScrollContainer = %SuggestedScrollContainer
@onready var search_edit:        LineEdit        = %SearchLineEdit
@onready var assets_scroll:      ScrollContainer = %AssetsScrollContainer
@onready var assets_list:        VBoxContainer   = %AssetsListContainer
@onready var bottom_bar:         PanelContainer  = %BottomSelectionBar
@onready var bottom_count_label: Label           = %BottomCountLabel
@onready var bottom_progress:    ProgressBar     = %BottomProgressBar
@onready var clear_button:       Button          = %ClearSelectionButton
@onready var continue_button:    Button          = %ContinueButton

const CATEGORY_SECTION_SCENE := preload("res://scenes/components/category_section.tscn")
const SUGGESTED_CHIP_SCENE   := preload("res://scenes/components/suggested_portfolio_chip.tscn")

const BREAKPOINT_TABLET  := 600
const BREAKPOINT_DESKTOP := 900
const INERTIA_FRICTION   := 7.0

var _category_sections: Dictionary = {}
var _touch_in_assets_scroll: bool  = false
var _last_drag_velocity: float     = 0.0
var _scroll_inertia: float         = 0.0
var _loading_label: Label

var _fill_blue:  StyleBoxFlat
var _fill_amber: StyleBoxFlat
var _fill_green: StyleBoxFlat

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fill_blue  = _make_fill(FormaTokens.BLUE)
	_fill_amber = _make_fill(FormaTokens.AMBER)
	_fill_green = _make_fill(FormaTokens.GREEN)

	get_tree().root.size_changed.connect(_update_responsive_layout)

	search_edit.text_changed.connect(_on_search_changed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	SelectionManager.selection_limit_reached.connect(_on_limit_reached)
	clear_button.pressed.connect(SelectionManager.clear)
	continue_button.pressed.connect(_on_continue_pressed)

	await _load_categories()
	_load_suggested_portfolios()

	_on_selection_changed([], 0)

	await get_tree().process_frame
	await get_tree().process_frame
	_update_responsive_layout()
	_hide_all_scrollbars()

# Carregamento (async)

func _load_categories() -> void:
	_set_loading(true)

	var all_assets: Array = await WalletRepository.get_available_assets()
	var categories: Array = WalletRepository.get_categories()

	for category: Dictionary in categories:
		var in_cat: Array = all_assets.filter(
			func(a: Dictionary) -> bool:
				return a.get("categoria", "") == category.get("id", "")
		)
		if in_cat.is_empty():
			continue
		var section: CategorySection = CATEGORY_SECTION_SCENE.instantiate()
		assets_list.add_child(section)
		section.setup(category.get("nome", ""), in_cat)
		_category_sections[category.get("id", "")] = section

	_set_loading(false)

func _load_suggested_portfolios() -> void:
	# Monta um Set de tickers disponíveis (API ou mock, o que estiver no cache)
	var available: Dictionary = {}
	for asset: Dictionary in WalletRepository.get_cached_assets():
		available[str(asset.get("ticker", ""))] = true

	for portfolio: Dictionary in WalletRepository.get_suggested_portfolios():
		var raw_tickers: Array  = portfolio.get("tickers", [])

		# Mantém apenas tickers que existem de fato na fonte de dados atual
		var valid_tickers: Array = raw_tickers.filter(
			func(t: String) -> bool: return available.has(t)
		)

		# Markowitz exige mínimo 2 ativos — chip inútil se não há quórum
		if valid_tickers.size() < 2:
			push_warning(
				"[WalletRepository] Preset '%s' ignorado: apenas %d ticker(s) disponível(is) na API." \
				% [portfolio.get("id", "?"), valid_tickers.size()]
			)
			continue

		var chip: SuggestedPortfolioChip = SUGGESTED_CHIP_SCENE.instantiate()
		suggested_row.add_child(chip)

		# Passa ao chip a versão filtrada (sem tickers inexistentes na API)
		var filtered := portfolio.duplicate()
		filtered["tickers"] = valid_tickers
		chip.setup(filtered)

		# Captura local evita problema de closure-em-loop
		var tickers_copy := valid_tickers.duplicate()
		chip.applied.connect(
			func() -> void: SelectionManager.apply_preset(tickers_copy)
		)

# Botão "Continuar"

func _on_continue_pressed() -> void:
	var tickers := SelectionManager.get_selected()
	if tickers.is_empty():
		return

	_set_continue_loading(true)

	var create_result := await WalletApiClient.create_portfolio(
		AppSession.user_id,
		"Carteira %s" % Time.get_datetime_string_from_system().left(10),
		tickers,
		"MAX_SHARPE"
	)
	if not create_result.ok or create_result.data == null:
		_set_continue_loading(false)
		_show_error("Não foi possível criar a carteira. Verifique a conexão.")
		return

	var portfolio_id: int = int(create_result.data.get("id", 0))
	if portfolio_id == 0:
		_set_continue_loading(false)
		_show_error("ID de carteira inválido retornado pela API.")
		return

	var opt_result := await WalletApiClient.optimize_portfolio(portfolio_id)
	_set_continue_loading(false)

	if not opt_result.ok or opt_result.data == null:
		_show_error("Ativos sem histórico de preços suficiente.\n(mín. 2 preços por ativo no asset-service)")
		return

	# Armazena resultado e navega para a tela de resultado
	AppSession.latest_portfolio = opt_result.data
	get_tree().change_scene_to_file("res://scenes/screens/portfolio_result_screen.tscn")

func _show_optimization_result(portfolio: Dictionary) -> void:
	var portfolio_name:  String = str(portfolio.get("name", "Carteira"))
	var expected_return: float  = _api_pct(portfolio, "expectedReturn")
	var portfolio_risk:  float  = _api_pct(portfolio, "portfolioRisk")
	var sharpe_ratio:    float  = _api_float(portfolio, "sharpeRatio")
	var assets:          Array  = portfolio.get("assets", [])

	var lines: Array[String] = []
	lines.append("📊 %s" % portfolio_name)
	lines.append("")
	lines.append("Retorno esperado : %.1f%% a.a." % expected_return)
	lines.append("Risco anual      : %.1f%%" % portfolio_risk)
	lines.append("Índice de Sharpe : %.3f" % sharpe_ratio)

	if not assets.is_empty():
		lines.append("")
		lines.append("Alocação ótima (Markowitz):")
		for asset: Dictionary in assets:
			var ticker: String = str(asset.get("ticker", "—"))
			var weight: float  = _api_float(asset, "weight") * 100.0
			lines.append("  %-8s → %5.1f%%" % [ticker, weight])

	var dialog := AcceptDialog.new()
	dialog.title       = "✅ Carteira Otimizada"
	dialog.dialog_text = "\n".join(lines)
	dialog.min_size    = Vector2(360, 0)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title       = "Erro"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _set_continue_loading(loading: bool) -> void:
	continue_button.disabled = loading
	continue_button.text     = "Otimizando..." if loading else "Continuar"

# Loading indicator

func _set_loading(is_loading: bool) -> void:
	if is_loading:
		if _loading_label == null:
			_loading_label = Label.new()
			_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_loading_label.add_theme_color_override("font_color", FormaTokens.N400)
			assets_list.add_child(_loading_label)
		_loading_label.text    = "Carregando ativos..."
		_loading_label.visible = true
	elif _loading_label != null:
		_loading_label.visible = false

# Scrollbars

func _hide_all_scrollbars() -> void:
	_hide_scrollbar_pair(assets_scroll)
	_hide_scrollbar_pair(suggested_scroll)

func _hide_scrollbar_pair(container: ScrollContainer) -> void:
	_hide_scrollbar(container.get_h_scroll_bar())
	_hide_scrollbar(container.get_v_scroll_bar())

func _hide_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2.ZERO
	bar.modulate            = Color(1.0, 1.0, 1.0, 0.0)
	bar.mouse_filter        = Control.MOUSE_FILTER_IGNORE

# Inércia de rolagem

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_in_assets_scroll = assets_scroll.get_global_rect().has_point(event.position)
			if _touch_in_assets_scroll:
				_scroll_inertia     = 0.0
				_last_drag_velocity = 0.0
		else:
			if _touch_in_assets_scroll:
				_scroll_inertia = _last_drag_velocity
			_touch_in_assets_scroll = false
	elif event is InputEventScreenDrag and _touch_in_assets_scroll:
		_last_drag_velocity = -event.velocity.y

func _process(delta: float) -> void:
	if _touch_in_assets_scroll or abs(_scroll_inertia) <= 1.0:
		if not _touch_in_assets_scroll:
			_scroll_inertia = 0.0
		return
	assets_scroll.scroll_vertical += int(_scroll_inertia * delta)
	_scroll_inertia = lerpf(_scroll_inertia, 0.0, INERTIA_FRICTION * delta)

# Busca e seleção

func _on_search_changed(text: String) -> void:
	for section: CategorySection in _category_sections.values():
		section.filter_by_text(text)

func _on_selection_changed(_selected: Array, count: int) -> void:
	counter_label.text       = "%d  /  10" % count
	selection_progress.value = count
	bottom_count_label.text  = str(count)
	bottom_progress.value    = count

	var fill_style: StyleBoxFlat
	var count_color: Color
	if count == SelectionManager.MAX_SELECTION:
		fill_style  = _fill_green;  count_color = FormaTokens.GREEN
	elif count >= 8:
		fill_style  = _fill_amber;  count_color = FormaTokens.AMBER
	elif count > 0:
		fill_style  = _fill_blue;   count_color = FormaTokens.BLUE
	else:
		fill_style  = _fill_blue;   count_color = FormaTokens.N500

	selection_progress.add_theme_stylebox_override("fill", fill_style)
	bottom_progress.add_theme_stylebox_override("fill",    fill_style)
	counter_label.add_theme_color_override("font_color",      count_color)
	bottom_count_label.add_theme_color_override("font_color", count_color)

	bottom_bar.visible       = count > 0
	clear_button.visible     = count > 0
	continue_button.disabled = count == 0

func _on_limit_reached() -> void:
	push_warning("Limite de 10 ativos atingido.")

func _update_responsive_layout() -> void:
	var w := get_tree().root.size.x
	if w <= 0:
		return

	var columns := 1
	var margin  := 20

	if w >= BREAKPOINT_DESKTOP:
		columns = 3
		margin  = 64
	elif w >= BREAKPOINT_TABLET:
		columns = 2
		margin  = 32

	for section: CategorySection in _category_sections.values():
		section.set_columns(columns)

	safe_area_margin.add_theme_constant_override("margin_left",  margin)
	safe_area_margin.add_theme_constant_override("margin_right", margin)
	assets_list.queue_sort()

func _make_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s

# Helpers de leitura segura de dados da API

func _api_float(dict: Dictionary, key: String, default: float = 0.0) -> float:
	var val: Variant = dict.get(key)
	if val == null:
		return default
	return float(val)

func _api_pct(dict: Dictionary, key: String) -> float:
	return _api_float(dict, key) * 100.0
