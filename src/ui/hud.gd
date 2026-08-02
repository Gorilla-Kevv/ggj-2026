extends CanvasLayer

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var target_label: Label = $TargetLabel

func _ready() -> void:
	var global := get_node("/root/Global")
	global.energy_changed.connect(_on_energy_changed)
	energy_bar.max_value = global.ENERGY_MAX
	energy_bar.value = global.energy

func _on_energy_changed(new_energy: float) -> void:
	energy_bar.value = new_energy
	if new_energy <= 0.0:
		energy_bar.modulate = Color(1.0, 0.3, 0.3, 1.0)
	else:
		energy_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _process(_delta: float) -> void:
	var global := get_node("/root/Global")
	var target := global.selected_target
	if target and is_instance_valid(target):
		var display_name: String = target.get_meta("display_name", target.name)
		target_label.text = display_name
	else:
		target_label.text = ""
