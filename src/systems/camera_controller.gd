# ============================================================
# CameraController — 跟随当前选中目标
# 挂载到场景根节点下的 Camera2D 上
# 玩家按下 R 切换目标时自动平滑跟随新目标
# 同时注册到 "camera" 组供 world_camera.gd 设置边界
#
# zoom 逻辑：
#   选中玩家/普通物体 → normal_zoom (默认 1.0)
#   选中 Windmill 力臂  → windmill_zoom (默认 0.4，视野扩大)
# ============================================================
extends Camera2D

# 跟随速度 (越大越快跟上目标，1=立即跟随)
@export var follow_speed: float = 5.0
# 选中风车力臂时的 zoom (越小视野越大)
@export var windmill_zoom: float = 0.4
# 正常 zoom
@export var normal_zoom: float = 1.0

# 镜头锁定：设为一个节点时，无视 selected_target 强制跟随它
var camera_lock_target: Node2D = null
# 手动控制：入场动画期间设为 true，本脚本不干预 position/zoom
var manual_control: bool = false

func _ready() -> void:
	add_to_group("camera")
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed
	zoom = Vector2(normal_zoom, normal_zoom)

func _process(_delta: float) -> void:
	# 入场动画接管期间，不干预
	if manual_control:
		return

	var global := get_node("/root/Global")
	# 镜头锁定优先
	if camera_lock_target != null and is_instance_valid(camera_lock_target):
		global_position = camera_lock_target.global_position
	else:
		var target = global.selected_target   # 不标注类型，避免已释放实例报错
		if target == null or not is_instance_valid(target):
			# 自清理：指向已释放对象时重置
			if target != null:
				global.selected_target = null
			return
		global_position = (target as Node2D).global_position

	_update_zoom(global.selected_target)

# 根据选中目标切换 zoom
func _update_zoom(target: Node2D) -> void:
	if _is_windmill_target(target):
		zoom = Vector2(windmill_zoom, windmill_zoom)
	else:
		zoom = Vector2(normal_zoom, normal_zoom)

# 判断选中目标是否属于风车 (力臂或风车主体)
func _is_windmill_target(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("windmill"):
		return true
	var parent := node.get_parent()
	return parent != null and parent.is_in_group("windmill")
