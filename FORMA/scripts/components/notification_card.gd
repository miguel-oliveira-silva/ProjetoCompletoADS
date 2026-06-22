extends PanelContainer
class_name NotificationCard

@onready var icon_label:    Label = %IconLabel
@onready var title_label:   Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var date_label:    Label = %DateLabel
@onready var type_badge:    Label = %TypeBadge

func setup(notification: Dictionary) -> void:
	var notification_type: String = str(notification.get("type", ""))
	var title: String = str(notification.get("title", "Notificação"))
	var message: String = str(notification.get("message", ""))
	var created_at: String = str(notification.get("createdAt", ""))
	
	# Ícone e cor por tipo
	match notification_type:
		"BOAS_VINDAS":
			icon_label.text = "🎉"
			type_badge.text = "Boas-vindas"
			type_badge.add_theme_color_override("font_color", FormaTokens.BLUE)
		"CARTEIRA_OTIMIZADA":
			icon_label.text = "✅"
			type_badge.text = "Carteira"
			type_badge.add_theme_color_override("font_color", FormaTokens.GREEN)
		_:
			icon_label.text = "📬"
			type_badge.text = "Notificação"
			type_badge.add_theme_color_override("font_color", FormaTokens.N500)
	
	title_label.text = title
	message_label.text = message
	date_label.text = _format_date(created_at)

func _format_date(iso_date: String) -> String:
	if iso_date.length() < 16:
		return ""
	
	var parts := iso_date.split("T")
	if parts.size() < 2:
		return ""
	
	var date_parts := parts[0].split("-")
	if date_parts.size() < 3:
		return ""
	
	var time := parts[1].left(5)
	
	return "%s/%s/%s às %s" % [date_parts[2], date_parts[1], date_parts[0], time]
