extends VBoxContainer

@onready var safe_area_margin: MarginContainer = %SafeAreaMargin
@onready var back_button:      Button          = %BackButton
@onready var title_label:      Label           = %TitleLabel
@onready var main_scroll:      ScrollContainer = %MainScroll
@onready var notifications_list: VBoxContainer = %NotificationsList
@onready var empty_state_container: VBoxContainer = %EmptyStateContainer
@onready var loading_label:    Label           = %LoadingLabel

const NOTIFICATION_CARD_SCENE := preload("res://scenes/components/notification_card.tscn")

const BREAKPOINT_TABLET  := 600
const BREAKPOINT_DESKTOP := 900

var _notifications: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	get_tree().root.size_changed.connect(_update_responsive_layout)
	back_button.pressed.connect(_go_back)
	
	_load_notifications()
	
	await get_tree().process_frame
	await get_tree().process_frame
	_update_responsive_layout()
	_hide_scrollbar(main_scroll.get_v_scroll_bar())
	_hide_scrollbar(main_scroll.get_h_scroll_bar())

func _hide_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2.ZERO
	bar.modulate            = Color(1.0, 1.0, 1.0, 0.0)
	bar.mouse_filter        = Control.MOUSE_FILTER_IGNORE

# Carregamento de notificações

func _load_notifications() -> void:
	_set_loading(true)
	empty_state_container.visible = false
	notifications_list.visible = false
	
	var result := await WalletApiClient.get_notifications(AppSession.user_id)
	
	_set_loading(false)
	
	if not result.ok or result.data == null:
		_show_empty_state("Erro ao carregar notificações.\nVerifique sua conexão.")
		return
	
	_notifications = result.data if result.data is Array else []
	
	if _notifications.is_empty():
		_show_empty_state("📭 Nenhuma notificação ainda.\n\nQuando você criar e otimizar carteiras,\nas notificações aparecerão aqui!")
		return
	
	_populate_notifications()

func _populate_notifications() -> void:
	notifications_list.visible = true
	
	# Ordena por mais recente primeiro (ID decrescente)
	var sorted := _notifications.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("id", 0)) > int(b.get("id", 0))
	)
	
	for notification: Dictionary in sorted:
		var card: NotificationCard = NOTIFICATION_CARD_SCENE.instantiate()
		notifications_list.add_child(card)
		card.setup(notification)

func _show_empty_state(message: String) -> void:
	empty_state_container.visible = true
	var empty_label := empty_state_container.get_node_or_null("EmptyLabel") as Label
	if empty_label:
		empty_label.text = message

func _set_loading(is_loading: bool) -> void:
	loading_label.visible = is_loading
	if is_loading:
		loading_label.text = "Carregando notificações..."

# Navegação

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/wallet_selection_screen.tscn")

# Responsividade

func _update_responsive_layout() -> void:
	var w := get_tree().root.size.x
	if w <= 0:
		return
	
	var margin := 20
	if w >= BREAKPOINT_DESKTOP:
		margin = 64
	elif w >= BREAKPOINT_TABLET:
		margin = 32
	
	safe_area_margin.add_theme_constant_override("margin_left",  margin)
	safe_area_margin.add_theme_constant_override("margin_right", margin)
