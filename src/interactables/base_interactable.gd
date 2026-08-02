extends RigidBody2D
class_name BaseInteractable

func _ready() -> void:
	add_to_group("interactable")
	if not has_meta("display_name"):
		set_meta("display_name", "物体")

func apply_wind_force(force: Vector2) -> void:
	apply_central_force(force)

func on_selected() -> void:
	modulate = Color.GOLD

func on_deselected() -> void:
	modulate = Color.WHITE
