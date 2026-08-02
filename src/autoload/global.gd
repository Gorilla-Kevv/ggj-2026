extends Node

var energy: float = 100.0
const ENERGY_MAX: float = 100.0
const ENERGY_DRAIN: float = 20.0
const ENERGY_REGEN: float = 15.0

var selected_target: Node2D = null

var current_checkpoint: Vector2 = Vector2.ZERO
var last_checkpoint_level: String = ""

signal energy_changed(new_energy: float)
signal energy_depleted()
signal energy_full()

func _ready() -> void:
	energy = ENERGY_MAX

func drain_energy(delta: float) -> void:
	energy = maxf(0.0, energy - ENERGY_DRAIN * delta)
	energy_changed.emit(energy)
	if energy <= 0.0:
		energy_depleted.emit()

func regen_energy(delta: float) -> void:
	if energy >= ENERGY_MAX:
		return
	energy = minf(ENERGY_MAX, energy + ENERGY_REGEN * delta)
	energy_changed.emit(energy)
	if energy >= ENERGY_MAX:
		energy_full.emit()

func refill_energy() -> void:
	energy = ENERGY_MAX
	energy_changed.emit(energy)
	energy_full.emit()

func has_energy() -> bool:
	return energy > 0.0