extends Node

const _SECTOR_TO_CATEGORY := {
	"Energia":     "acoes_blue_chips",
	"Mineração":   "acoes_blue_chips",
	"Consumo":     "acoes_blue_chips",
	"Industrial":  "acoes_blue_chips",
	"Utilidades":  "acoes_blue_chips",
	"Saúde":       "acoes_blue_chips",
	"Financeiro":  "bancos_seguradoras",
	"Banco":       "bancos_seguradoras",
	"Seguros":     "bancos_seguradoras",
	"Tecnologia":  "acoes_small_caps",
	"Varejo":      "acoes_small_caps",
	"Logística":   "acoes_small_caps",
	"Transporte":  "acoes_small_caps",
	"Imobiliário": "fundos_imobiliarios",
	"FII":         "fundos_imobiliarios",
	"BDR":         "bdrs",
	"ETF":         "etfs",
	"Renda Fixa":  "renda_fixa",
}

const CATEGORIES := [
	{ "id": "acoes_blue_chips",    "nome": "Ações · Blue Chips" },
	{ "id": "acoes_small_caps",    "nome": "Ações · Small & Mid Caps" },
	{ "id": "bancos_seguradoras",  "nome": "Bancos & Seguradoras" },
	{ "id": "fundos_imobiliarios", "nome": "Fundos Imobiliários (FIIs)" },
	{ "id": "bdrs",                "nome": "BDRs · Empresas Globais" },
	{ "id": "etfs",                "nome": "ETFs" },
	{ "id": "renda_fixa",          "nome": "Renda Fixa Indexada" },
]

# Os tickers aqui são candidatos, serão filtrados contra o que a API
# realmente tem cadastrado antes de exibir os chips ao usuário.
var _suggested_portfolios := [
	{
		"id":        "carteira_dividendos",
		"nome":      "Carteira\nDividendos",
		"tag":       "Renda · Dividendos",
		"variante":  "dark",
		"descricao": "Bancos, seguradoras e FIIs com histórico sólido de proventos.",
		"tickers":   ["BBAS3", "BBSE3", "ITSA4", "HGLG11", "KNRI11", "PSSA3", "MXRF11"]
	},
	{
		"id":        "carteira_crescimento",
		"nome":      "Carteira\nCrescimento",
		"tag":       "Arrojada · Tech",
		"variante":  "blue",
		"descricao": "Empresas líderes em inovação no Brasil e nos EUA.",
		"tickers":   ["WEGE3", "RENT3", "RAIL3", "AAPL34", "MSFT34", "NVDC34", "AMZO34"]
	},
	{
		"id":        "carteira_internacional",
		"nome":      "Carteira\nInternacional",
		"tag":       "Global · Dólar",
		"variante":  "amber",
		"descricao": "BDRs de líderes globais e ETF S&P 500 para diversificação cambial.",
		"tickers":   ["IVVB11", "AAPL34", "MSFT34", "GOGL34", "AMZO34", "NVDC34", "TSLA34"]
	},
]

var _assets_cache: Array = []
var _cache_valid:  bool  = false

# API pública

func get_categories() -> Array:
	return CATEGORIES.duplicate(true)

func get_suggested_portfolios() -> Array:
	var risk := AppSession.user_risk
	var portfolios := []
	
	match risk:
		"CONSERVADOR":
			portfolios = [
				{
					"id":        "carteira_dividendos",
					"nome":      "Carteira\nDividendos",
					"tag":       "Conservadora · Renda",
					"variante":  "dark",
					"descricao": "FIIs, seguradoras e renda fixa para geração de renda com segurança.",
					"tickers":   ["CDB-LIQ-DIARIA", "TESOURO-SELIC-2029", "BBSE3", "PSSA3", "HGLG11", "KNRI11", "MXRF11"]
				},
				{
					"id":        "carteira_crescimento",
					"nome":      "Carteira\nPreservação",
					"tag":       "Segurança · Liquidez",
					"variante":  "blue",
					"descricao": "Foco em títulos públicos indexados e alta liquidez diária.",
					"tickers":   ["TESOURO-SELIC-2029", "CDB-LIQ-DIARIA", "TESOURO-IPCA-2035", "HGLG11", "KNRI11", "ITSA4"]
				},
				{
					"id":        "carteira_internacional",
					"nome":      "Carteira\nGlobal Defensiva",
					"tag":       "Global · Estabilidade",
					"variante":  "amber",
					"descricao": "Diversificação global em dólar por meio de BDRs líderes e renda fixa.",
					"tickers":   ["IVVB11", "AAPL34", "MSFT34", "GOGL34", "TESOURO-SELIC-2029"]
				}
			]
		"AGRESSIVO":
			portfolios = [
				{
					"id":        "carteira_dividendos",
					"nome":      "Carteira\nDividendos",
					"tag":       "Agressiva · Renda",
					"variante":  "dark",
					"descricao": "Bancos e ações pagadoras com maior volatilidade, buscando retornos robustos.",
					"tickers":   ["BBAS3", "BPAC11", "SANB11", "ITSA4", "WEGE3", "PSSA3"]
				},
				{
					"id":        "carteira_crescimento",
					"nome":      "Carteira\nCrescimento",
					"tag":       "Arrojada · Small Caps",
					"variante":  "blue",
					"descricao": "Empresas com alto potencial de valorização, small caps e tecnologia.",
					"tickers":   ["WEGE3", "RENT3", "RAIL3", "MGLU3", "SOMA3", "NVDC34", "TSLA34"]
				},
				{
					"id":        "carteira_internacional",
					"nome":      "Carteira\nGlobal Tech",
					"tag":       "Global · Alta Volatilidade",
					"variante":  "amber",
					"descricao": "Alta exposição a BDRs de inteligência artificial, tecnologia e ETFs de crescimento.",
					"tickers":   ["IVVB11", "SMAL11", "AAPL34", "MSFT34", "NVDC34", "AMZO34", "TSLA34"]
				}
			]
		_: # MODERADO
			portfolios = [
				{
					"id":        "carteira_dividendos",
					"nome":      "Carteira\nDividendos",
					"tag":       "Renda · Dividendos",
					"variante":  "dark",
					"descricao": "Bancos, seguradoras e FIIs com histórico sólido de proventos.",
					"tickers":   ["BBAS3", "BBSE3", "ITSA4", "HGLG11", "KNRI11", "PSSA3", "MXRF11"]
				},
				{
					"id":        "carteira_crescimento",
					"nome":      "Carteira\nCrescimento",
					"tag":       "Equilibrada · Tech",
					"variante":  "blue",
					"descricao": "Empresas líderes em inovação no Brasil e nos EUA.",
					"tickers":   ["WEGE3", "RENT3", "RAIL3", "AAPL34", "MSFT34", "NVDC34", "AMZO34"]
				},
				{
					"id":        "carteira_internacional",
					"nome":      "Carteira\nInternacional",
					"tag":       "Global · Dólar",
					"variante":  "amber",
					"descricao": "BDRs de líderes globais e ETF S&P 500 para diversificação cambial.",
					"tickers":   ["IVVB11", "AAPL34", "MSFT34", "GOGL34", "AMZO34", "NVDC34", "TSLA34"]
				}
			]

	return portfolios.duplicate(true)

# Expõe o cache para que a tela filtre os presets contra o que a API tem.
# Sempre chamado APÓS get_available_assets() — cache estará populado.
func get_cached_assets() -> Array:
	return _assets_cache.duplicate(true)

func invalidate_cache() -> void:
	_cache_valid = false
	_assets_cache.clear()

func get_available_assets() -> Array:
	if _cache_valid and not _assets_cache.is_empty():
		return _assets_cache.duplicate(true)

	var result: Dictionary = await WalletApiClient.get_all_assets()

	if not result.ok or result.data == null or not (result.data is Array):
		push_warning("[WalletRepository] API indisponível — usando dados mock")
		# Popula o cache com mock para que o filtro de preset funcione
		# mesmo sem conexão.
		_assets_cache = _mock_assets()
		_cache_valid  = true
		return _assets_cache.duplicate(true)

	var api_list: Array = result.data
	if api_list.is_empty():
		push_warning("[WalletRepository] API retornou lista vazia — usando dados mock")
		_assets_cache = _mock_assets()
		_cache_valid  = true
		return _assets_cache.duplicate(true)

	_assets_cache.clear()
	for item: Dictionary in api_list:
		var sector:   String = str(item.get("sector", ""))
		var category: String = _SECTOR_TO_CATEGORY.get(sector, "acoes_small_caps")
		_assets_cache.append({
			"ticker":       str(item.get("ticker", "")).to_upper(),
			"nome":         str(item.get("name", "")),
			"categoria":    category,
			"preco":        float(item.get("lastPrice", -1.0)),
			"variacao_pct": float(item.get("variationPct", 0.0)),
		})

	_cache_valid = true
	print("[WalletRepository] %d ativos carregados da API" % _assets_cache.size())
	return _assets_cache.duplicate(true)

# Fallback offline
# Usado APENAS quando a API está indisponível.
# NÃO misturado com dados reais, ou é API ou é mock, nunca os dois.

func _mock_assets() -> Array:
	return [
		{"ticker":"PETR4","nome":"Petrobras PN","categoria":"acoes_blue_chips","preco":38.42,"variacao_pct":1.27},
		{"ticker":"PETR3","nome":"Petrobras ON","categoria":"acoes_blue_chips","preco":40.15,"variacao_pct":1.10},
		{"ticker":"VALE3","nome":"Vale ON","categoria":"acoes_blue_chips","preco":61.80,"variacao_pct":-0.45},
		{"ticker":"ITUB4","nome":"Itaú Unibanco PN","categoria":"acoes_blue_chips","preco":33.27,"variacao_pct":0.62},
		{"ticker":"BBDC4","nome":"Bradesco PN","categoria":"acoes_blue_chips","preco":14.55,"variacao_pct":-0.88},
		{"ticker":"ABEV3","nome":"Ambev ON","categoria":"acoes_blue_chips","preco":12.34,"variacao_pct":0.33},
		{"ticker":"BBAS3","nome":"Banco do Brasil ON","categoria":"acoes_blue_chips","preco":27.10,"variacao_pct":1.95},
		{"ticker":"WEGE3","nome":"WEG ON","categoria":"acoes_blue_chips","preco":39.88,"variacao_pct":2.41},
		{"ticker":"ITSA4","nome":"Itaúsa PN","categoria":"acoes_blue_chips","preco":9.87,"variacao_pct":0.51},
		{"ticker":"B3SA3","nome":"B3 ON","categoria":"acoes_blue_chips","preco":11.45,"variacao_pct":-1.12},
		{"ticker":"RENT3","nome":"Localiza ON","categoria":"acoes_blue_chips","preco":45.20,"variacao_pct":0.89},
		{"ticker":"RAIL3","nome":"Rumo ON","categoria":"acoes_small_caps","preco":19.60,"variacao_pct":0.77},
		{"ticker":"MGLU3","nome":"Magazine Luiza ON","categoria":"acoes_small_caps","preco":8.12,"variacao_pct":3.10},
		{"ticker":"SOMA3","nome":"Grupo Soma ON","categoria":"acoes_small_caps","preco":7.95,"variacao_pct":1.02},
		{"ticker":"MOVI3","nome":"Movida ON","categoria":"acoes_small_caps","preco":10.30,"variacao_pct":0.58},
		{"ticker":"SANB11","nome":"Santander Brasil Unit","categoria":"bancos_seguradoras","preco":28.40,"variacao_pct":0.41},
		{"ticker":"BPAC11","nome":"BTG Pactual Unit","categoria":"bancos_seguradoras","preco":32.15,"variacao_pct":1.18},
		{"ticker":"PSSA3","nome":"Porto Seguro ON","categoria":"bancos_seguradoras","preco":24.70,"variacao_pct":-0.30},
		{"ticker":"BBSE3","nome":"BB Seguridade ON","categoria":"bancos_seguradoras","preco":31.05,"variacao_pct":0.66},
		{"ticker":"CXSE3","nome":"Caixa Seguridade ON","categoria":"bancos_seguradoras","preco":13.85,"variacao_pct":0.22},
		{"ticker":"HGLG11","nome":"CSHG Logística FII","categoria":"fundos_imobiliarios","preco":162.30,"variacao_pct":0.18},
		{"ticker":"KNRI11","nome":"Kinea Renda Imobiliária FII","categoria":"fundos_imobiliarios","preco":148.90,"variacao_pct":-0.12},
		{"ticker":"MXRF11","nome":"Maxi Renda FII","categoria":"fundos_imobiliarios","preco":10.45,"variacao_pct":0.05},
		{"ticker":"XPLG11","nome":"XP Log FII","categoria":"fundos_imobiliarios","preco":105.60,"variacao_pct":0.40},
		{"ticker":"VISC11","nome":"Vinci Shopping Centers FII","categoria":"fundos_imobiliarios","preco":118.20,"variacao_pct":-0.25},
		{"ticker":"AAPL34","nome":"Apple Inc","categoria":"bdrs","preco":68.90,"variacao_pct":1.05},
		{"ticker":"MSFT34","nome":"Microsoft Corp","categoria":"bdrs","preco":92.45,"variacao_pct":0.84},
		{"ticker":"GOGL34","nome":"Alphabet Inc","categoria":"bdrs","preco":54.30,"variacao_pct":-0.41},
		{"ticker":"AMZO34","nome":"Amazon.com Inc","categoria":"bdrs","preco":48.75,"variacao_pct":0.97},
		{"ticker":"TSLA34","nome":"Tesla Inc","categoria":"bdrs","preco":71.20,"variacao_pct":-2.18},
		{"ticker":"NVDC34","nome":"Nvidia Corp","categoria":"bdrs","preco":135.60,"variacao_pct":3.05},
		{"ticker":"BOVA11","nome":"iShares Ibovespa","categoria":"etfs","preco":124.80,"variacao_pct":0.55},
		{"ticker":"IVVB11","nome":"iShares S&P 500","categoria":"etfs","preco":280.10,"variacao_pct":0.72},
		{"ticker":"SMAL11","nome":"iShares Small Cap","categoria":"etfs","preco":98.40,"variacao_pct":-0.15},
		{"ticker":"TESOURO-SELIC-2029","nome":"Tesouro Selic 2029","categoria":"renda_fixa","preco":1.00,"variacao_pct":0.04},
		{"ticker":"TESOURO-IPCA-2035","nome":"Tesouro IPCA+ 2035","categoria":"renda_fixa","preco":1.00,"variacao_pct":0.06},
		{"ticker":"CDB-LIQ-DIARIA","nome":"CDB Liquidez Diária 102% CDI","categoria":"renda_fixa","preco":1.00,"variacao_pct":0.03},
	]
