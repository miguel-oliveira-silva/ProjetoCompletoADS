# FORMA/scripts/autoload/app_session.gd
extends Node

var user_id:          int    = 0
var user_name:        String = ""
var user_email:       String = ""
var user_risk:        String = "MODERADO"
var latest_portfolio: Dictionary = {}

func _ready() -> void:
	pass  # Sessão é preenchida pelo AuthManager após login/register

func is_logged_in() -> bool:
	return user_id > 0

func clear() -> void:
	user_id          = 0
	user_name        = ""
	user_email       = ""
	user_risk        = "MODERADO"
	latest_portfolio = {}
