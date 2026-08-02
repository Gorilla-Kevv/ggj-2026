extends Node2D

const MAX_WIND_FORCE: float = 800.0
const RAMP_TIME: float = 3.0
const MICRO_BURST_FORCE: float = 200.0
const MICRO_BURST_THRESHOLD: float = 0.15

var is_blowing: bool = false
var blow_hold_time: float = 0.0
var mouse_was_pressed: bool = false

signal wind_started(target: Node2D, direction: Vector2)
signal wind_updated(target: Node2D, direction: Vector2, strength: float)
signal wind_stopped()
signal micro_burst(target: Node2D, direction: Vector2)

func _ready() -> void:
	add_to_group("wind_system")

func _process(delta: float) -> void:
	var global := get_node("/root/Global")
	var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed := mouse_pressed and not mouse_was_pressed
	var just_released := not mouse_pressed and mouse_was_pressed
	mouse_was_pressed = mouse_pressed

	if just_pressed:
		if global.selected_target == null:
			return
		if not global.has_energy():
			return
		is_blowing = true
		blow_hold_time = 0.0
		var direction := _get_wind_direction()
		wind_started.emit(global.selected_target, direction)

	if is_blowing and mouse_pressed:
		blow_hold_time += delta
		if global.selected_target == null:
			_stop_wind()
			return
		global.drain_energy(delta)
		var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
		var direction := _get_wind_direction()
		wind_updated.emit(global.selected_target, direction, strength)
		if not global.has_energy():
			_stop_wind()

	if just_released and is_blowing:
		if blow_hold_time < MICRO_BURST_THRESHOLD:
			micro_burst.emit(global.selected_target, _get_wind_direction())
		_stop_wind()

func _stop_wind() -> void:
	is_blowing = false
	blow_hold_time = 0.0
	wind_stopped.emit()

func _get_wind_direction() -> Vector2:
	var global := get_node("/root/Global")
	var mouse_pos := get_viewport().get_mouse_position()
	if global.selected_target == null:
		return Vector2.ZERO
	var target_pos := global.selected_target.global_position
	var diff := target_pos - mouse_pos
	if diff.length() < 1.0:
		return Vector2.ZERO
	return diff.normalized()

func get_current_force() -> Vector2:
	var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
	return _get_wind_direction() * MAX_WIND_FORCE * strength
