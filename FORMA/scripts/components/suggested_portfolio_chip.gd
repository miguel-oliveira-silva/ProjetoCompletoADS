extends PanelContainer
class_name SuggestedPortfolioChip

signal applied

@onready var tag_label:  Label  = %CategoryTagLabel
@onready var name_label: Label  = %PortfolioNameLabel
@onready var desc_label: Label  = %PortfolioDescriptionLabel
@onready var apply_btn:  Button = %ApplyButton

func setup(portfolio: Dictionary) -> void:
	name_label.text = portfolio.get("nome", "")
	desc_label.text = portfolio.get("descricao", "")
	tag_label.text  = str(portfolio.get("tag", "")).to_upper()
	apply_btn.pressed.connect(func() -> void: applied.emit())
	_apply_variant(portfolio.get("variante", "dark"))

func _apply_variant(variant: String) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.border_width_top = 3
	panel_style.border_color     = FormaTokens.YELLOW

	var btn_style := StyleBoxFlat.new()
	btn_style.draw_center         = false
	btn_style.border_width_left   = 1
	btn_style.border_width_top    = 1
	btn_style.border_width_right  = 1
	btn_style.border_width_bottom = 1
	btn_style.content_margin_left  = 10.0
	btn_style.content_margin_right = 10.0

	match variant:
		"blue":
			panel_style.bg_color = FormaTokens.BLUE
			tag_label.add_theme_color_override(
				"font_color", Color(0.78, 0.85, 1.0, 0.85)
			)
			desc_label.add_theme_color_override(
				"font_color", Color(0.78, 0.85, 1.0, 0.60)
			)
			btn_style.border_color = Color(1.0, 1.0, 1.0, 0.20)

		"amber":
			panel_style.bg_color = FormaTokens.AMBER
			tag_label.add_theme_color_override(
				"font_color", Color(1.0, 0.902, 0.627, 0.85)
			)
			desc_label.add_theme_color_override(
				"font_color", Color(1.0, 0.902, 0.627, 0.65)
			)
			btn_style.border_color = Color(1.0, 1.0, 1.0, 0.20)

		_:  
			panel_style.bg_color = FormaTokens.N900
			tag_label.add_theme_color_override("font_color", FormaTokens.YELLOW)
			desc_label.add_theme_color_override("font_color", FormaTokens.N500)
			btn_style.border_color = Color(0.184, 0.180, 0.220, 1.0)  # n700

	add_theme_stylebox_override("panel", panel_style)
	apply_btn.add_theme_stylebox_override("normal",  btn_style)
	apply_btn.add_theme_stylebox_override("hover",   btn_style)
	apply_btn.add_theme_stylebox_override("pressed", btn_style)
	apply_btn.add_theme_stylebox_override("focus",   btn_style)
