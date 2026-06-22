extends VBoxContainer
class_name AssetAllocationRow

@onready var ticker_label:   Label       = %TickerLabel
@onready var allocation_bar: ProgressBar = %AllocationBar
@onready var weight_label:   Label       = %WeightLabel
@onready var return_label:   Label       = %ReturnLabel
@onready var risk_label:     Label       = %RiskLabel

func setup(asset_data: Dictionary) -> void:
	var ticker:     String = str(asset_data.get("ticker", ""))
	var weight:     float  = _nf(asset_data, "weight")
	var exp_return: float  = _nf(asset_data, "expectedReturn")
	var risk:       float  = _nf(asset_data, "risk")

	ticker_label.text    = ticker
	allocation_bar.value = weight
	weight_label.text    = "%.1f%%" % (weight * 100.0)
	return_label.text    = " +%.1f%%" % (exp_return * 100.0)
	risk_label.text      = " ±%.1f%%" % (risk * 100.0)

func _nf(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key)
	return 0.0 if v == null else float(v)
