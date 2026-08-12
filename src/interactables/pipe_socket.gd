# 管道插槽 — 检测可交互物体到达目标位置后锁定
# 放在目标位置的 Area2D 上
extends Area2D

@export var snap_to_self: bool = true
@export var completion_sound: AudioStream = null

var _completed: bool = false

signal pipe_connected()

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _completed:
		return
	if not body.is_in_group("interactable"):
		return

	_completed = true

	if snap_to_self:
		body.global_position = global_position
		body.freeze = true
		if body is RigidBody2D:
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0

	pipe_connected.emit()
