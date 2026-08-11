extends Node2D

@export var amplitude: float = 10.0
@export var frequency: float = 2.0

var _base_y: float

func _ready() -> void:
	_base_y = position.y

func _process(_delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.001 * frequency) * amplitude
