extends VBoxContainer

@onready var safe_area_margin:       MarginContainer = %SafeAreaMargin
@onready var main_scroll:            ScrollContainer = %MainScroll
@onready var back_button:            Button          = %BackButton
@onready var goal_label:             Label           = %GoalLabel
@onready var status_label:           Label           = %StatusLabel
@onready var portfolio_name_label:   Label           = %PortfolioNameLabel
@onready var timestamp_label:        Label           = %TimestampLabel
@onready var metrics_grid:           GridContainer   = %MetricsGrid
@onready var allocation_count_label: Label           = %AllocationCountLabel
@onready var allocation_list:        VBoxContainer   = %AllocationList
@onready var goal_desc_label:        Label           = %GoalDescLabel
@onready var new_portfolio_button:   Button          = %NewPortfolioButton
@onready var done_button:            Button          = %DoneButton

const METRIC_CARD_SCENE := preload("res://scenes/components/metric_card.tscn")
const ASSET_ROW_SCENE   := preload("res://scenes/components/asset_allocation_row.tscn")

const BREAKPOINT_TABLET  := 600
const BREAKPOINT_DESKTOP := 900

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size

	get_tree().root.size_changed.connect(_on_viewport_resized)

	back_button.pressed.connect(_go_to_selection)
	new_portfolio_button.pressed.connect(_go_to_selection)
	done_button.pressed.connect(_go_to_selection)

	# Garante que o scroll não expande horizontalmente
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_populate(AppSession.latest_portfolio)

	await get_tree().process_frame
	await get_tree().process_frame
	_update_responsive_layout()
	_hide_scrollbar(main_scroll.get_v_scroll_bar())
	_hide_scrollbar(main_scroll.get_h_scroll_bar())

func _on_viewport_resized() -> void:
	size = get_viewport_rect().size
	_update_responsive_layout()


func _hide_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2.ZERO
	bar.modulate            = Color(1.0, 1.0, 1.0, 0.0)
	bar.mouse_filter        = Control.MOUSE_FILTER_IGNORE

# Preenchimento com dados da API

func _populate(portfolio: Dictionary) -> void:
	if portfolio.is_empty():
		push_warning("[PortfolioResultScreen] AppSession.latest_portfolio está vazio.")
		return

	# Cabeçalho
	var goal   := str(portfolio.get("optimizationGoal", ""))
	var status := str(portfolio.get("status", ""))

	goal_label.text           = _goal_display(goal)
	status_label.text         = _status_display(status)
	portfolio_name_label.text = str(portfolio.get("name", "Carteira"))
	timestamp_label.text      = _format_dt(str(portfolio.get("optimizedAt", "")))

	# Métricas
	_add_metric(
		"Retorno",
		"%.1f%%" % _pct(portfolio, "expectedReturn"),
		"esperado a.a.",
		FormaTokens.GREEN
	)
	_add_metric(
		"Risco",
		"%.1f%%" % _pct(portfolio, "portfolioRisk"),
		"volatilidade a.a.",
		FormaTokens.AMBER
	)
	_add_metric(
		"Sharpe",
		"%.3f"   % _nf(portfolio, "sharpeRatio"),
		"retorno / risco",
		FormaTokens.BLUE
	)

	# Alocação por ativo
	var assets: Array = portfolio.get("assets", [])
	allocation_count_label.text = "%d ativos" % assets.size()
	for asset: Dictionary in assets:
		var row: AssetAllocationRow = ASSET_ROW_SCENE.instantiate()
		allocation_list.add_child(row)
		row.setup(asset)

	# Nota de rodapé adaptada ao objetivo
	goal_desc_label.text = _goal_description(goal)

func _add_metric(p_label: String, p_value: String, p_sub: String, color: Color) -> void:
	var card: MetricCard = METRIC_CARD_SCENE.instantiate()
	metrics_grid.add_child(card)
	card.setup(p_label, p_value, p_sub, color)

# Navegação

func _navigate_to(path: String) -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(path)

func _go_to_selection() -> void:
	SelectionManager.clear()
	_navigate_to("res://scenes/screens/wallet_selection_screen.tscn")

# Responsividade

func _update_responsive_layout() -> void:
	var w := get_viewport_rect().size.x
	if w <= 0:
		w = get_tree().root.size.x
	if w <= 0:
		return

	var margin := 20
	if w >= BREAKPOINT_DESKTOP:
		margin = 64
		metrics_grid.columns = 3
	elif w >= BREAKPOINT_TABLET:
		margin = 32
		metrics_grid.columns = 3
	else:
		margin = 20
		metrics_grid.columns = 3

	safe_area_margin.add_theme_constant_override("margin_left",  margin)
	safe_area_margin.add_theme_constant_override("margin_right", margin)

# Helpers nula-seguro (mesmo padrão usado em asset_allocation_row.gd)

func _nf(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key)
	return 0.0 if v == null else float(v)

func _pct(d: Dictionary, key: String) -> float:
	return _nf(d, key) * 100.0

# Formatação de textos

func _goal_display(goal: String) -> String:
	match goal:
		"MAX_SHARPE":  return "Máx. Sharpe"
		"MIN_RISK":    return "Mín. Risco"
		"MAX_RETURN":  return "Máx. Retorno"
		_:             return goal

func _status_display(status: String) -> String:
	match status:
		"OTIMIZADO": return "Otimizado"
		"PENDENTE":  return "Pendente"
		_:           return status.to_lower().capitalize()

func _goal_description(goal: String) -> String:
	match goal:
		"MAX_SHARPE":
			return "Carteira de Máximo Índice de Sharpe: melhor equilíbrio entre retorno esperado e risco assumido por unidade de volatilidade."
		"MIN_RISK":
			return "Carteira de Mínima Variância: menor risco possível dados os ativos selecionados, independente do retorno."
		"MAX_RETURN":
			return "Carteira de Máximo Retorno: maior retorno esperado, com o risco associado à concentração em ativos de alto μ."
		_:
			return "Carteira otimizada pelo Algoritmo de Markowitz."

func _format_dt(dt: String) -> String:
	if dt.length() < 16:
		return ""
	var parts := dt.split("T")
	if parts.size() < 2:
		return ""
	var d := parts[0].split("-")
	if d.size() < 3:
		return ""
	return "Otimizado em %s/%s/%s às %s" % [d[2], d[1], d[0], parts[1].left(5)]
