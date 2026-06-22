extends Node

const BASE_USER  := "http://20.195.170.160:8081"
const BASE_ASSET := "http://20.195.170.160:8082"
const BASE_PORTF := "http://20.195.170.160:8083"
const BASE_NOTIF := "http://20.195.170.160:8084"

const _HEADERS := ["Content-Type: application/json", "Accept: application/json"]

func _req(url: String, method: int = HTTPClient.METHOD_GET, body: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var err := http.request(url, _HEADERS, method, body)
	if err != OK:
		http.queue_free()
		push_error("[API] Falha ao iniciar requisição para %s — erro %d" % [url, err])
		return {"ok": false, "code": -1, "data": null}

	var result: Array = await http.request_completed
	http.queue_free()

	var code: int   = result[1]
	var raw: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(raw) if raw.length() > 2 else null
	var ok: bool    = code >= 200 and code < 300

	if not ok:
		push_warning("[API] %s → HTTP %d: %s" % [url, code, raw.left(200)])

	return {"ok": ok, "code": code, "data": data}

# User Service 

func register_user(user_name: String, email: String, password: String,
		risk_profile: String = "MODERADO") -> Dictionary:
	var body := JSON.stringify({
		"name": user_name, "email": email,
		"password": password, "riskProfile": risk_profile
	})
	return await _req(BASE_USER + "/api/users/register", HTTPClient.METHOD_POST, body)

func get_user(user_id: int) -> Dictionary:
	return await _req(BASE_USER + "/api/users/%d" % user_id)

func update_risk_profile(user_id: int, profile: String) -> Dictionary:
	return await _req(
		BASE_USER + "/api/users/%d/risk-profile" % user_id,
		HTTPClient.METHOD_PUT,
		JSON.stringify(profile)
	)

# Asset Service

func get_all_assets() -> Dictionary:
	return await _req(BASE_ASSET + "/api/assets")

func get_asset(ticker: String) -> Dictionary:
	return await _req(BASE_ASSET + "/api/assets/%s" % ticker)

func get_asset_stats(ticker: String) -> Dictionary:
	return await _req(BASE_ASSET + "/api/assets/%s/stats" % ticker)

# Portfolio Service

func create_portfolio(user_id: int, portfolio_name: String, tickers: Array,
		goal: String = "MAX_SHARPE") -> Dictionary:
	var body := JSON.stringify({
		"userId":           user_id,
		"name":             portfolio_name,
		"tickers":          tickers,
		"optimizationGoal": goal
	})
	return await _req(BASE_PORTF + "/api/portfolios", HTTPClient.METHOD_POST, body)

func optimize_portfolio(portfolio_id: int) -> Dictionary:
	return await _req(
		BASE_PORTF + "/api/portfolios/%d/optimize" % portfolio_id,
		HTTPClient.METHOD_POST
	)

func get_portfolio(portfolio_id: int) -> Dictionary:
	return await _req(BASE_PORTF + "/api/portfolios/%d" % portfolio_id)

func get_user_portfolios(user_id: int) -> Dictionary:
	return await _req(BASE_PORTF + "/api/portfolios/user/%d" % user_id)

# Notification Service

func get_notifications(user_id: int) -> Dictionary:
	return await _req(BASE_NOTIF + "/api/notifications/user/%d" % user_id)
	
	# Métodos de seed (usados por AppSession na inicialização)

func create_asset(ticker: String, asset_name: String, sector: String) -> Dictionary:
	var body := JSON.stringify({"ticker": ticker, "name": asset_name, "sector": sector})
	return await _req(BASE_ASSET + "/api/assets", HTTPClient.METHOD_POST, body)

func add_price_history(ticker: String, price: float, price_date: String) -> Dictionary:
	var body := JSON.stringify({"price": price, "priceDate": price_date})
	return await _req(
		BASE_ASSET + "/api/assets/%s/prices" % ticker,
		HTTPClient.METHOD_POST, body
	)
