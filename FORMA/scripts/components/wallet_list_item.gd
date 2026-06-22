extends Button
class_name WalletListItem

@onready var check_indicator: TextureRect = %CheckIndicator
@onready var ticker_label: Label          = %TickerLabel
@onready var name_label: Label            = %NameLabel
@onready var price_label: Label           = %PriceLabel
@onready var variation_label: Label       = %VariationLabel

# @onready garante carregamento em runtime — evita erro de preload
# se os SVGs ainda não existirem no momento em que o script é salvo
@onready var _icon_unchecked: Texture2D = load("res://assets/icons/checkbox_unchecked.svg")
@onready var _icon_checked: Texture2D   = load("res://assets/icons/checkbox_checked.svg")
@onready var _icon_disabled: Texture2D  = load("res://assets/icons/checkbox_disabled.svg")

var _ticker: String     = ""
var _data: Dictionary   = {}

func _ready() -> void:
	toggle_mode = true
	focus_mode  = Control.FOCUS_ALL
	pressed.connect(_on_pressed)
	SelectionManager.selection_changed.connect(_on_selection_changed)

func setup(asset_data: Dictionary) -> void:
	_data   = asset_data
	_ticker = str(asset_data.get("ticker", ""))

	ticker_label.text = _ticker
	name_label.text   = str(asset_data.get("nome", ""))

	var preco: float = asset_data.get("preco", -1.0)
	price_label.text = "R$ %.2f" % preco if preco >= 0.0 else "–"

	var variacao: float = asset_data.get("variacao_pct", 0.0)
	if preco < 0.0:
		variation_label.text = "–"
		variation_label.add_theme_color_override("font_color", FormaTokens.N400)
	else:
		var sinal := "+" if variacao >= 0.0 else ""
		variation_label.text = "%s%.2f%%" % [sinal, variacao]
		variation_label.add_theme_color_override(
			"font_color",
			FormaTokens.GREEN if variacao >= 0.0 else FormaTokens.RED
		)

	_refresh_visual_state()

func matches_query(query: String) -> bool:
	if query.is_empty():
		return true
	var q := query.to_lower()
	return _ticker.to_lower().contains(q) \
		or str(_data.get("nome", "")).to_lower().contains(q)

func _on_pressed() -> void:
	if not SelectionManager.is_selected(_ticker) and not SelectionManager.can_select_more():
		button_pressed = false   # reverte visualmente
		return
	SelectionManager.toggle(_ticker)

func _on_selection_changed(_s: Array, _c: int) -> void:
	_refresh_visual_state()

func _refresh_visual_state() -> void:
	var selected  := SelectionManager.is_selected(_ticker)
	var at_limit  := SelectionManager.get_count() >= SelectionManager.MAX_SELECTION

	button_pressed = selected
	disabled       = at_limit and not selected

	# Guard: ícones podem ser null se os SVGs ainda não foram importados
	if _icon_unchecked == null:
		return

	if disabled:
		check_indicator.texture = _icon_disabled
	elif selected:
		check_indicator.texture = _icon_checked
	else:
		check_indicator.texture = _icon_unchecked

	modulate = Color(1.0, 1.0, 1.0, 0.45 if disabled else 1.0)

func get_ticker() -> String:
	return _ticker
