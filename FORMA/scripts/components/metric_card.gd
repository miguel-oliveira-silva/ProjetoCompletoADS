extends PanelContainer
class_name MetricCard

@onready var accent_bar:   Panel = %AccentBar
@onready var metric_label: Label = %MetricLabel
@onready var value_label:  Label = %ValueLabel
@onready var sub_label:    Label = %SubLabel

func setup(p_label: String, p_value: String, p_sub: String, color: Color) -> void:
	metric_label.text = p_label.to_upper()
	value_label.text  = p_value
	sub_label.text    = p_sub

	var accent_style := StyleBoxFlat.new()
	accent_style.bg_color = color
	accent_bar.add_theme_stylebox_override("panel", accent_style)
	value_label.add_theme_color_override("font_color", color)
