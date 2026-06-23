extends PanelContainer
class_name PortfolioCard

signal view_pressed(portfolio: Dictionary)

@onready var portfolio_name_label: Label          = %PortfolioNameLabel
@onready var date_label:           Label          = %DateLabel
@onready var status_label:         Label          = %StatusLabel
@onready var metrics_row:          HBoxContainer  = %MetricsRow
@onready var return_label:         Label          = %ReturnLabel
@onready var risk_label:           Label          = %RiskLabel
@onready var sharpe_label:         Label          = %SharpeLabel
@onready var view_button:          Button         = %ViewButton

var _portfolio: Dictionary = {}

func setup(portfolio: Dictionary) -> void:
	_portfolio = portfolio

	var status:  String = str(portfolio.get("status", "PENDENTE"))
	var p_name:  String = str(portfolio.get("name", "Carteira"))
	var created: String = _format_dt(str(portfolio.get("createdAt", "")))

	portfolio_name_label.text = p_name
	date_label.text           = created

	# ── Chip de status ─────────────────────────────────────────────────────────
	var is_optimized := status == "OTIMIZADO"
	var chip_color   := FormaTokens.GREEN if is_optimized else FormaTokens.AMBER

	status_label.text = "OTIMIZADO" if is_optimized else "PENDENTE"

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color              = chip_color
	chip_style.content_margin_left   = 8.0
	chip_style.content_margin_right  = 8.0
	chip_style.content_margin_top    = 5.0
	chip_style.content_margin_bottom = 5.0
	status_label.get_parent().add_theme_stylebox_override("panel", chip_style)

	# ── Métricas (só se OTIMIZADO) ─────────────────────────────────────────────
	metrics_row.visible = is_optimized
	if is_optimized:
		return_label.text = "%.1f%%" % (_nf(portfolio, "expectedReturn") * 100.0)
		risk_label.text   = "%.1f%%" % (_nf(portfolio, "portfolioRisk")  * 100.0)
		sharpe_label.text = "%.3f"   % _nf(portfolio, "sharpeRatio")

	# ── Texto do botão adapta ao status ───────────────────────────────────────
	view_button.text = "Ver resultado" if is_optimized else "Otimizar carteira"
	view_button.pressed.connect(func() -> void: view_pressed.emit(_portfolio))

func _nf(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key)
	return 0.0 if v == null else float(v)

func _format_dt(dt: String) -> String:
	if dt.length() < 10:
		return "–"
	var parts := dt.split("T")
	var d := parts[0].split("-")
	if d.size() < 3:
		return parts[0]
	return "%s/%s/%s" % [d[2], d[1], d[0]]
