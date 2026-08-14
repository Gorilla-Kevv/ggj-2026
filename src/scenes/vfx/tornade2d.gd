# ============================================================
# Tornade2D — 龙卷风 (第3关: 炽风峡谷)
# 挂载于 tornade2d 场景根节点。
# 玩家进入 TornadoArea 区域会被"卷飞"：持续受到较小的向上托举力 +
# 左右往复的卷动(甩动)力，使玩家在区域内被来回甩动旋转上升；
# 玩家按 A/D 左右移动会加强卷动，一旦移出区域即不再施加任何力。
#
# 检测区: 子节点 Area2D "TornadoArea" (monitoring 检测玩家)
# ============================================================
extends Node2D
class_name Tornade2D

# ---------- 导出变量 (编辑器可调) ----------
@export var area_path: NodePath = NodePath("TornadoArea")  # 检测区域 Area2D
@export var lift_force: float = 500.0      # 向上托举加速度 (px/s²)，较小的上浮力
@export var swirl_force: float = 1200.0    # 左右卷动(甩动)加速度 (px/s²)
@export var swirl_speed: float = 6.0       # 卷动往复频率 (rad/s)
@export var input_gain: float = 1.5        # 玩家按 A/D 左右移动时对卷动的增强倍率
@export var use_knockback: bool = true     # true=强卷飞(绕过速度上限)；false=走限速

# ---------- 运行时状态 ----------
var _area: Area2D
var _swirl_time: float = 0.0

func _ready() -> void:
	_area = get_node_or_null(area_path) as Area2D

func _physics_process(delta: float) -> void:
	if _area == null:
		return
	# 每帧检查玩家是否仍在区域内；移出 (左右) 后自然不再施力
	var player := _find_player_inside()
	if player == null:
		return

	_swirl_time += delta
	# 左右往复甩动 (旋转感) + 玩家左右输入增强卷动 → 明显被卷着甩动上升
	var input_dir := Input.get_axis("move_left", "move_right")
	var sway := cos(_swirl_time * swirl_speed)
	var force := Vector2(
		sway * swirl_force + input_dir * swirl_force * input_gain,
		-lift_force
	) * delta

	if use_knockback and player.has_method("apply_knockback"):
		player.apply_knockback(force)
	elif player.has_method("apply_wind_force"):
		player.apply_wind_force(force)

# 从检测区域内找出玩家 (player 组)
func _find_player_inside() -> Node2D:
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body
	return null
