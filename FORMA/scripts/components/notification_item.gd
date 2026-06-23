extends VBoxContainer
class_name NotificationItem

@onready var type_bar:     Panel = %TypeBar
@onready var title_label:  Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var date_label:   Label = %DateLabel

func setup(notif: Dictionary) -> void:
	var notif_type: String = str(notif.get("type", ""))
	var raw_title:  String = str(notif.get("title", ""))
	var raw_msg:    String = str(notif.get("message", ""))
	var created:    String = str(notif.get("createdAt", ""))

	# Limpa caracteres não suportados pela fonte (emoji do backend)
	title_label.text   = raw_title.replace("✅", "").replace("🎉", "").strip_edges()
	message_label.text = raw_msg.left(80) + ("..." if raw_msg.length() > 80 else "")
	date_label.text    = _format_dt(created)

	# Barra lateral colorida por tipo de notificação
	var bar_style := StyleBoxFlat.new()
	match notif_type:
		"CARTEIRA_OTIMIZADA": bar_style.bg_color = FormaTokens.GREEN
		"BOAS_VINDAS":        bar_style.bg_color = FormaTokens.BLUE
		_:                    bar_style.bg_color = FormaTokens.N400
	type_bar.add_theme_stylebox_override("panel", bar_style)

func _format_dt(dt: String) -> String:
	if dt.length() < 10:
		return "–"
	var parts := dt.split("T")
	var d := parts[0].split("-")
	if d.size() < 3:
		return parts[0]
	return "%s/%s/%s" % [d[2], d[1], d[0]]
