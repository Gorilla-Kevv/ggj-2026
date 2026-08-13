# ============================================================
# WindmillPlatform — 十字风车旋转平台 (主体)
# 挂载于风车根节点 (AnimatableBody2D)
# 玩家可选中四臂吹风 → 施加扭矩 → 风车绕中轴旋转
# 玩家站上风车后跟随旋转
# ============================================================
extends AnimatableBody2D

@export var torque_factor: float = 30.0    # 力→扭矩系数
@export var friction: float = 0.95          # 角速度衰减 (每帧)
@export var max_angular_speed: float = 2.0  # 最大角速度 (rad/s)

var angular_velocity: float = 0.0

# 站在风车上的玩家 (用于跟随旋转)
var _carried_players: Array[CharacterBody2D] = []

func _ready() -> void:
	add_to_group("windmill")
	sync_to_physics = true

func _physics_process(delta: float) -> void:
	# 角速度衰减
	angular_velocity *= friction

	# 应用旋转
	var delta_angle := angular_velocity * delta
	rotation += delta_angle

	# 带动站上来的玩家一起绕中轴旋转
	_carry_players(delta_angle)

# 臂受力 → 扭矩
# arm: 哪条臂；force: 风力向量 (牛顿)
func apply_arm_force(arm: Node2D, force: Vector2) -> void:
	# 力臂 = 臂相对中轴的方向 (单位向量)
	var lever: Vector2 = arm.position.normalized()
	# 扭矩 = 力臂 × 力 (2D 叉积)
	var torque: float = lever.x * force.y - lever.y * force.x
	angular_velocity += torque * torque_factor * 0.001
	angular_velocity = clampf(angular_velocity, -max_angular_speed, max_angular_speed)

# 玩家站在风车上 → 记录，每帧绕中轴旋转
func _on_body_entered(body: Node2D) -> void:
	print("[Windmill] 检测到物体进入: ", body.name, " 是玩家=", body.is_in_group("player"))
	if body.is_in_group("player") and body is CharacterBody2D:
		if body not in _carried_players:
			_carried_players.append(body)
			print("[Windmill] 玩家绑定风车，当前跟随人数=", _carried_players.size())

func _on_body_exited(body: Node2D) -> void:
	if body in _carried_players:
		_carried_players.erase(body)
		print("[Windmill] 玩家离开风车，剩余=", _carried_players.size())

func _carry_players(delta_angle: float) -> void:
	for player in _carried_players:
		var offset: Vector2 = player.global_position - global_position
		var rotated_offset: Vector2 = offset.rotated(delta_angle)
		player.global_position = global_position + rotated_offset
