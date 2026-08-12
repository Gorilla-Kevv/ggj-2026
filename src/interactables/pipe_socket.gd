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
# 吸附偏移：管道视觉中心相对插槽原点的偏移，用于微调拼合位置
@export var snap_offset: Vector2 = Vector2.ZERO
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
	if _completed:
		return
	if not body.is_in_group("interactable"):
		return

	_completed = true

	if snap_to_self:
		body.global_position = global_position + snap_offset
		# 移出可交互组 → 不再被 TargetSelector/WindSystem 选中吹动
		body.remove_from_group("interactable")
		if body is RigidBody2D:
			body.freeze = true
			body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
			body.sleeping = true
		print("[PipeSocket] 【吸附】物体已锁定到 ", body.global_position)

	pipe_connected.emit()
	print("[PipeSocket] 【发信号】pipe_connected")
