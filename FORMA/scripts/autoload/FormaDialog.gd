# FORMA/scripts/autoload/FormaDialog.gd
# Fabrica de dialogos estilizados seguindo o Design System do projeto.
# Uso:
#   FormaDialog.show_error(self, "Mensagem de erro")
#   FormaDialog.show_confirm(self, "Titulo", "Mensagem", on_confirm_callable)
extends CanvasLayer

const FONT_BOLD := preload("res://assets/fonts/SpaceGrotesk-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/SpaceGrotesk-Regular.ttf")
const FONT_MONO := preload("res://assets/fonts/SpaceMono-Regular.ttf")

func _ready() -> void:
	layer = 100 # Garante exibição acima de todos os elementos das cenas

# =============================================================================
# DIALOGO DE ERRO (Customizado, responsivo)
# =============================================================================
func show_error(parent: Node, message: String, title: String = "Erro") -> void:
	var base := _create_dialog_base(title, message)
	
	var ok_btn := Button.new()
	ok_btn.text = "Entendido"
	_apply_primary_button_style(ok_btn, FormaTokens.RED)
	base.buttons_hbox.add_child(ok_btn)
	
	ok_btn.pressed.connect(func():
		_close_dialog(base.dimmer)
	)

# =============================================================================
# DIALOGO DE CONFIRMACAO (Customizado, responsivo)
# =============================================================================
func show_confirm(
	parent:      Node,
	title:       String,
	message:     String,
	on_confirm:  Callable,
	ok_text:     String = "Confirmar",
	cancel_text: String = "Cancelar",
	danger:      bool   = false
) -> void:
	var base := _create_dialog_base(title, message)
	
	var cancel_btn := Button.new()
	cancel_btn.text = cancel_text
	_apply_outlined_button_style(cancel_btn)
	base.buttons_hbox.add_child(cancel_btn)
	
	var ok_btn := Button.new()
	ok_btn.text = ok_text
	_apply_primary_button_style(ok_btn, FormaTokens.RED if danger else FormaTokens.N900)
	base.buttons_hbox.add_child(ok_btn)
	
	cancel_btn.pressed.connect(func():
		_close_dialog(base.dimmer)
	)
	
	ok_btn.pressed.connect(func():
		on_confirm.call()
		_close_dialog(base.dimmer)
	)

# =============================================================================
# CONSTRUTORES DE ELEMENTOS VISUAIS
# =============================================================================
func _create_dialog_base(title: String, message: String) -> Dictionary:
	# 1. Dimmer overlay para escurecer o fundo
	var dimmer := ColorRect.new()
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.color = Color(0.05, 0.05, 0.08, 0.4) # N900 com opacidade
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	
	# 2. PanelContainer (Caixa do diálogo)
	var dialog_box := PanelContainer.new()
	dialog_box.anchor_left = 0.5
	dialog_box.anchor_right = 0.5
	dialog_box.anchor_top = 0.5
	dialog_box.anchor_bottom = 0.5
	dialog_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = FormaTokens.N200
	panel_style.shadow_color = Color(0.05, 0.05, 0.08, 0.12)
	panel_style.shadow_size = 12
	panel_style.corner_radius_top_left = 0
	panel_style.corner_radius_top_right = 0
	panel_style.corner_radius_bottom_right = 0
	panel_style.corner_radius_bottom_left = 0
	dialog_box.add_theme_stylebox_override("panel", panel_style)
	
	dimmer.add_child(dialog_box)
	
	# Responsividade na largura do diálogo
	var resize_dialog := func() -> void:
		var size_x = get_viewport().size.x
		if size_x <= 480:
			dialog_box.custom_minimum_size = Vector2(size_x - 32.0, 0.0)
		else:
			dialog_box.custom_minimum_size = Vector2(400.0, 0.0)
	
	resize_dialog.call()
	get_viewport().size_changed.connect(resize_dialog)
	dimmer.set_meta("resize_callable", resize_dialog)
	
	# 3. MarginContainer
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	dialog_box.add_child(margin_container)
	
	# 4. VBoxContainer
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin_container.add_child(vbox)
	
	# 5. Title Label
	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_override("font", FONT_BOLD)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", FormaTokens.N900)
	vbox.add_child(title_label)
	
	# 6. Message Label
	var message_label := Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_override("font", FONT_REGULAR)
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.add_theme_color_override("font_color", FormaTokens.N700)
	vbox.add_child(message_label)
	
	# 7. Buttons HBox
	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 12)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(buttons_hbox)
	
	return {
		"dimmer": dimmer,
		"dialog_box": dialog_box,
		"vbox": vbox,
		"buttons_hbox": buttons_hbox
	}

func _close_dialog(dimmer: ColorRect) -> void:
	if not is_instance_valid(dimmer):
		return
	if dimmer.has_meta("resize_callable"):
		var resize_callable = dimmer.get_meta("resize_callable")
		if get_viewport().size_changed.is_connected(resize_callable):
			get_viewport().size_changed.disconnect(resize_callable)
	dimmer.queue_free()

# =============================================================================
# MÉTODOS LEGADOS DE COMPATIBILIDADE
# =============================================================================
func _style_primary() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FormaTokens.N900
	return s

func _style_danger() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FormaTokens.RED
	return s

func _style_ok_button(btn: Button, normal: StyleBoxFlat) -> void:
	_apply_primary_button_style(btn, normal.bg_color)

func _style_cancel_button(btn: Button) -> void:
	_apply_outlined_button_style(btn)

func _apply_primary_button_style(btn: Button, bg_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.corner_radius_top_left = 0
	normal.corner_radius_top_right = 0
	normal.corner_radius_bottom_right = 0
	normal.corner_radius_bottom_left = 0
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = FormaTokens.BLUE
	hover.corner_radius_top_left = 0
	hover.corner_radius_top_right = 0
	hover.corner_radius_bottom_right = 0
	hover.corner_radius_bottom_left = 0
	hover.content_margin_left = 20
	hover.content_margin_right = 20
	
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = FormaTokens.BLUE
	focus.corner_radius_top_left = 0
	focus.corner_radius_top_right = 0
	focus.corner_radius_bottom_right = 0
	focus.corner_radius_bottom_left = 0
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", FormaTokens.N50)
	btn.add_theme_color_override("font_hover_color", FormaTokens.N50)
	btn.add_theme_color_override("font_pressed_color", FormaTokens.N50)
	btn.add_theme_font_override("font", FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(100, 44)

func _apply_outlined_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.draw_center = false
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = FormaTokens.N200
	normal.corner_radius_top_left = 0
	normal.corner_radius_top_right = 0
	normal.corner_radius_bottom_right = 0
	normal.corner_radius_bottom_left = 0
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = FormaTokens.N100
	hover.corner_radius_top_left = 0
	hover.corner_radius_top_right = 0
	hover.corner_radius_bottom_right = 0
	hover.corner_radius_bottom_left = 0
	hover.content_margin_left = 20
	hover.content_margin_right = 20
	
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = FormaTokens.BLUE
	focus.corner_radius_top_left = 0
	focus.corner_radius_top_right = 0
	focus.corner_radius_bottom_right = 0
	focus.corner_radius_bottom_left = 0
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", FormaTokens.N700)
	btn.add_theme_color_override("font_hover_color", FormaTokens.N900)
	btn.add_theme_color_override("font_pressed_color", FormaTokens.N900)
	btn.add_theme_font_override("font", FONT_BOLD)
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(100, 44)
