# ============================================================
# CameraController — 跟随当前选中目标
# 挂载到场景根节点下的 Camera2D 上
# 玩家按下 R 切换目标时自动平滑跟随新目标
# ============================================================
extends Camera2D

# 跟随速度 (越大越快跟上目标，1=立即跟随)
@export var follow_speed: float = 5.0

func _ready() -> void:
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed

func _process(_delta: float) -> void:
	var global := get_node("/root/Global")
	var target := global.selected_target
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position
