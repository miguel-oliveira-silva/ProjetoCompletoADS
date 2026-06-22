extends Node
# Autoload: "SelectionManager"

signal selection_changed(selected_tickers: Array, count: int)
signal selection_limit_reached()

const MAX_SELECTION := 10

var _selected: Array[String] = []

func is_selected(ticker: String) -> bool:
	return _selected.has(ticker)

func get_count() -> int:
	return _selected.size()

func can_select_more() -> bool:
	return _selected.size() < MAX_SELECTION

func toggle(ticker: String) -> void:
	if _selected.has(ticker):
		_selected.erase(ticker)
	elif can_select_more():
		_selected.append(ticker)
	else:
		selection_limit_reached.emit()
		return
	selection_changed.emit(_selected, _selected.size())

func clear() -> void:
	_selected.clear()
	selection_changed.emit(_selected, 0)

func apply_preset(tickers: Array) -> void:
	clear()
	for t in tickers:
		if _selected.size() >= MAX_SELECTION:
			break
		_selected.append(t)
	selection_changed.emit(_selected, _selected.size())

func get_selected() -> Array[String]:
	return _selected.duplicate()
