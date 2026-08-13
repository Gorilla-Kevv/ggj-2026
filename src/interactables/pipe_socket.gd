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
# 吸附锚点：放入一个 Marker2D 子节点命名 "SnapPoint"，物体原点会自动对齐到它
# 没有 SnapPoint 时回退到插槽原点
@export var completion_sound: AudioStream = null

var _completed: bool = false

signal pipe_connected()

func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _get_snap_position() -> Vector2:
	var point := get_node_or_null("SnapPoint") as Marker2D
	return point.global_position

# 递归重置所有 CanvasItem 子节点的颜色
func _reset_modulate_recursive(node: Node) -> void:
	if node is CanvasItem:
		node.modulate = Color.WHITE
	for child in node.get_children():
		_reset_modulate_recursive(child)

func _on_body_entered(body: Node2D) -> void:
	if _completed:
		return
	if not body.is_in_group("interactable"):
		return

	_completed = true

	if snap_to_self:
		# 移出可交互组 → 不再被 TargetSelector/WindSystem 选中吹动
		body.remove_from_group("interactable")
		# 递归重置选中颜色 (父节点 + 所有子 CanvasItem)
		_reset_modulate_recursive(body)
		if body is RigidBody2D:
			# 先冻结再传送，避免物理引擎把刚体拉回旧位置
			body.freeze = true
			body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
			# 用物理服务器同步传送，防止唤醒时回弹
			var t := body.global_transform
			t.origin = _get_snap_position()
			PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, t)
		# 通知 TargetSelector 重新扫描目标列表
		var selector := get_tree().get_first_node_in_group("target_selector")
		if selector:
			selector.call_deferred("_refresh_targets")
		print("[PipeSocket] 【吸附】物体已锁定到 ", body.global_position)

	pipe_connected.emit()
	print("[PipeSocket] 【发信号】pipe_connected")
