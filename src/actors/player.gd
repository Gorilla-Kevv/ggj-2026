extends CharacterBody2D

const GRAVITY_SCALE: float = 0.3
const MAX_SPEED: float = 600.0
const AIR_FRICTION: float = 0.95
const GROUND_FRICTION: float = 0.7
const COLLISION_RADIUS: float = 20.0
const WIND_FORCE_MULTIPLIER: float = 0.02

signal player_died()

func _ready() -> void:
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	$CollisionShape2D.shape = shape
	_connect_wind_system()

func _connect_wind_system() -> void:
	var wind_system := get_tree().get_first_node_in_group("wind_system")
	if wind_system:
		wind_system.wind_updated.connect(_on_wind_updated)
		wind_system.micro_burst.connect(_on_micro_burst)

func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	if target == self:
		var force := direction * 800.0 * strength * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)

func _on_micro_burst(target: Node2D, direction: Vector2) -> void:
	if target == self:
		var force := direction * 200.0 * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE * delta
		velocity *= AIR_FRICTION
	else:
		velocity.x *= GROUND_FRICTION
	velocity = velocity.limit_length(MAX_SPEED)
	move_and_slide()

func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

func die() -> void:
	player_died.emit()
	call_deferred("_respawn")

func _respawn() -> void:
	var global := get_node("/root/Global")
	if global.last_checkpoint_level != "":
		get_tree().change_scene_to_file(global.last_checkpoint_level)
	else:
		get_tree().reload_current_scene()
	await get_tree().process_frame
	global_position = global.current_checkpoint
	global.refill_energy()
