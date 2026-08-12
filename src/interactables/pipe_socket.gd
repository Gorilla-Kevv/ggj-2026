#管道关卡
#├── PipePiece (RigidBody2D)           ← 挂 pushable_box.gd，能吹动
#│   ├── CollisionShape2D
#│   └── Sprite2D (管道贴图)
#│
#├── PipeSocket (Area2D)               ← 挂 pipe_socket.gd，目标位置
#│   ├── CollisionShape2D (比管道大一圈)
#│   └── Sprite2D (半透明虚线框，提示"放在这里")
#│
#└── PassageBlocker (StaticBody2D)     ← 拼合后打开的障碍

# 管道插槽 — 检测可交互物体到达目标位置后锁定
# 放在目标位置的 Area2D 上
extends Area2D

@export var snap_to_self: bool = true
@export var completion_sound: AudioStream = null

var _completed: bool = false

signal pipe_connected()

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("[PipeSocket] 物体进入: ", body.name, " 在interactable组=", body.is_in_group("interactable"))
	if _completed:
		print("[PipeSocket] 已拼合，忽略")
		return
	if not body.is_in_group("interactable"):
		print("[PipeSocket] 不在interactable组，忽略")
		return

	_completed = true
	print("[PipeSocket] 锁定物体 ", body.name)

	if snap_to_self:
		body.global_position = global_position
		body.freeze = true
		if body is RigidBody2D:
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0

	pipe_connected.emit()
