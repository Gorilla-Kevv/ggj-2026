extends Node2D

var targets: Array[Node2D] = []
var current_index: int = 0

signal target_changed(new_target: Node2D)

func _ready() -> void:
	call_deferred("_refresh_targets")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_target"):
		_cycle_target()

func _refresh_targets() -> void:
	targets.clear()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		targets.append(player)
	for node in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(node):
			targets.append(node)
	if targets.size() > 0:
		select_target(0)

func _cycle_target() -> void:
	if targets.size() == 0:
		return
	current_index = (current_index + 1) % targets.size()
	select_target(current_index)

func select_target(index: int) -> void:
	if current_index < targets.size():
		var old_target := targets[current_index]
		if old_target is BaseInteractable:
			old_target.on_deselected()

	current_index = clampi(index, 0, targets.size() - 1)

	var global := get_node("/root/Global")
	global.selected_target = targets[current_index]

	if global.selected_target is BaseInteractable:
		global.selected_target.on_selected()

	target_changed.emit(global.selected_target)

func get_current_target() -> Node2D:
	if targets.size() == 0:
		return null
	return targets[current_index]

func register_target(node: Node2D) -> void:
	if node not in targets:
		targets.append(node)
		_refresh_targets()
