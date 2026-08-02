extends Area2D

@export var is_active: bool = false

signal checkpoint_activated(checkpoint: Node2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		activate()

func activate() -> void:
	is_active = true
	var global := get_node("/root/Global")
	global.current_checkpoint = global_position
	global.last_checkpoint_level = get_tree().current_scene.scene_file_path
	_update_visual()
	checkpoint_activated.emit(self)

func _update_visual() -> void:
	if is_active:
		modulate = Color(0.2, 1.0, 0.4, 0.8)
	else:
		modulate = Color(0.3, 0.3, 0.3, 0.5)
