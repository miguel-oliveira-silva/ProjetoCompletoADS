extends VBoxContainer

@onready var safe_area_margin:   MarginContainer = %ScrollContent
@onready var counter_label:      Label           = %SelectionCounterLabel
@onready var selection_progress: ProgressBar     = %SelectionProgressBar
@onready var suggested_row:      HBoxContainer   = %SuggestedPortfoliosRow
@onready var suggested_scroll:   ScrollContainer = %SuggestedScrollContainer
@onready var search_edit:        LineEdit        = %SearchLineEdit
@onready var assets_scroll:      ScrollContainer = %MainScrollContainer
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

var _fill_blue:  StyleBoxFlat
var _fill_amber: StyleBoxFlat
var _fill_green: StyleBoxFlat

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fill_blue  = _make_fill(FormaTokens.BLUE)
	_fill_amber = _make_fill(FormaTokens.AMBER)
	_fill_green = _make_fill(FormaTokens.GREEN)

	if not is_inside_tree():
		return

	get_tree().root.size_changed.connect(_update_responsive_layout)
	search_edit.text_changed.connect(_on_search_changed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	SelectionManager.selection_limit_reached.connect(_on_limit_reached)
	clear_button.pressed.connect(SelectionManager.clear)
	continue_button.pressed.connect(_on_continue_pressed)

	# TopAppBar
	%ProfileButton.pressed.connect(_go_to_profile)
	%MoreButton.pressed.connect(_go_to_notifications)
	%ProfileNameLabel.text = AppSession.user_name

	await _load_categories()
	if not is_inside_tree():
		return

	_load_suggested_portfolios()
	_on_selection_changed([], 0)

	await get_tree().process_frame
	await get_tree().process_frame
	_update_responsive_layout()
	_hide_all_scrollbars()

# Navegação

func _navigate_to(path: String) -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(path)

func _go_to_profile() -> void:
	_navigate_to("res://scenes/screens/user_profile_screen.tscn")

func _go_to_notifications() -> void:
	_navigate_to("res://scenes/screens/notifications_screen.tscn")

# Carregamento 

func _load_categories() -> void:
	_set_loading(true)
	var all_assets: Array = await WalletRepository.get_available_assets()

	# Guard obrigatório após await: a cena pode ter mudado enquanto aguardava
	if not is_inside_tree():
		return

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
	var available: Dictionary = {}
	for asset: Dictionary in WalletRepository.get_cached_assets():
		available[str(asset.get("ticker", ""))] = true

	for portfolio: Dictionary in WalletRepository.get_suggested_portfolios():
		var raw: Array   = portfolio.get("tickers", [])
		var valid: Array = raw.filter(func(t: String) -> bool: return available.has(t))
		if valid.size() < 2:
			continue
		var chip: SuggestedPortfolioChip = SUGGESTED_CHIP_SCENE.instantiate()
		suggested_row.add_child(chip)
		var filtered := portfolio.duplicate()
		filtered["tickers"] = valid
		chip.setup(filtered)
		var tickers_copy := valid.duplicate()
		chip.applied.connect(func() -> void: SelectionManager.apply_preset(tickers_copy))

# Botão "Continuar"

func _on_continue_pressed() -> void:
	var tickers := SelectionManager.get_selected()
	if tickers.is_empty():
		return

	_set_continue_loading(true)

	var create_result := await WalletApiClient.create_portfolio(
		AppSession.user_id,
		"Carteira %s" % Time.get_datetime_string_from_system().left(10),
		tickers, "MAX_SHARPE"
	)
	if not is_inside_tree():
		return
	if not create_result.ok or create_result.data == null:
		_set_continue_loading(false)
		_show_error("Não foi possível criar a carteira.")
		return

	var portfolio_id: int = int(create_result.data.get("id", 0))
	if portfolio_id == 0:
		_set_continue_loading(false)
		_show_error("ID de carteira inválido retornado pela API.")
		return

	var opt_result := await WalletApiClient.optimize_portfolio(portfolio_id)
	if not is_inside_tree():
		return
	_set_continue_loading(false)

	if not opt_result.ok or opt_result.data == null:
		_show_error("Ativos sem histórico suficiente para otimização.")
		return

	AppSession.latest_portfolio = opt_result.data
	_navigate_to("res://scenes/screens/portfolio_result_screen.tscn")

# Seleção 

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
		fill_style = _fill_green; count_color = FormaTokens.GREEN
	elif count >= 8:
		fill_style = _fill_amber; count_color = FormaTokens.AMBER
	elif count > 0:
		fill_style = _fill_blue;  count_color = FormaTokens.BLUE
	else:
		fill_style = _fill_blue;  count_color = FormaTokens.N500

	selection_progress.add_theme_stylebox_override("fill", fill_style)
	bottom_progress.add_theme_stylebox_override("fill",    fill_style)
	counter_label.add_theme_color_override("font_color",      count_color)
	bottom_count_label.add_theme_color_override("font_color", count_color)

	bottom_bar.visible       = count > 0
	clear_button.visible     = count > 0
	continue_button.disabled = count == 0

func _on_limit_reached() -> void:
	push_warning("Limite de 10 ativos atingido.")

# UI helpers 

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

var _loading_label: Label

func _set_continue_loading(loading: bool) -> void:
	continue_button.disabled = loading
	continue_button.text     = "Otimizando..." if loading else "Continuar"

func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title       = "Erro"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

# Responsividade

func _update_responsive_layout() -> void:
	var w := get_tree().root.size.x
	if w <= 0:
		return
	var columns := 1
	var margin  := 20
	if w >= BREAKPOINT_DESKTOP:
		columns = 3; margin = 64
	elif w >= BREAKPOINT_TABLET:
		columns = 2; margin = 32
	for section: CategorySection in _category_sections.values():
		section.set_columns(columns)
	safe_area_margin.add_theme_constant_override("margin_left",  margin)
	safe_area_margin.add_theme_constant_override("margin_right", margin)
	assets_list.queue_sort()

# Scrollbars

func _hide_all_scrollbars() -> void:
	_hide_scrollbar_pair(assets_scroll)
	_hide_scrollbar_pair(suggested_scroll)

func _hide_scrollbar_pair(container: ScrollContainer) -> void:
	_hide_scrollbar(container.get_h_scroll_bar())
	_hide_scrollbar(container.get_v_scroll_bar())

func _hide_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2.ZERO
	bar.modulate            = Color(1, 1, 1, 0)
	bar.mouse_filter        = Control.MOUSE_FILTER_IGNORE

# Inércia de rolagem

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_in_assets_scroll = assets_scroll.get_global_rect().has_point(event.position)
			if _touch_in_assets_scroll:
				_scroll_inertia = 0.0; _last_drag_velocity = 0.0
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

func _make_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s
