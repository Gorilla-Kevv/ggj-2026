# ============================================================
# CameraController — 跟随当前选中目标
# 挂载到场景根节点下的 Camera2D 上
# 玩家按下 R 切换目标时自动平滑跟随新目标
# 同时注册到 "camera" 组供 world_camera.gd 设置边界
# ============================================================
extends Camera2D

# 跟随速度 (越大越快跟上目标，1=立即跟随)
@export var follow_speed: float = 5.0

func _ready() -> void:
	add_to_group("camera")
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed

func _process(_delta: float) -> void:
	var global := get_node("/root/Global")
	var target = global.selected_target   # 不标注类型，避免已释放实例报错
	if target == null or not is_instance_valid(target):
		# 自清理：指向已释放对象时重置
		if target != null:
			global.selected_target = null
		return
	global_position = (target as Node2D).global_position
