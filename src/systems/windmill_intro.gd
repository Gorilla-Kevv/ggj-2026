# ============================================================
# WindmillIntro — 风车入场动画
# 挂载在场景根节点上
# 玩家 y 达到触发线时(仅一次)：聚焦风车 + 镜头 zoom 缩小(视野扩大) → 停留 → 回玩家 → 恢复
# ============================================================
extends Node2D

@export var trigger_y: float = -13578.0    # 触发线 (玩家 y <= 此值时触发)
@export var windmill_path: NodePath          # 拖入 Windmill 节点
@export var focus_duration: float = 2.0      # 聚焦风车停留时长
@export var zoom_out_value: float = 0.4      # 聚焦时镜头 zoom (越小视野越大)
@export var zoom_transition: float = 1.0     # zoom/平移过渡时长

var _triggered: bool = false

func _process(_delta: float) -> void:
	if _triggered:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.global_position.y <= trigger_y:
		_triggered = true
		_play_intro()

func _play_intro() -> void:
	print("[WindmillIntro] 触发！玩家越过 y=", trigger_y)

	var player := get_tree().get_first_node_in_group("player")
	var windmill := get_node_or_null(windmill_path) as Node2D

	# 查找相机
	var camera: Camera2D = null
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			camera = cam
			break
	if camera == null:
		push_error("[WindmillIntro] 找不到相机")
		return
	if windmill == null:
		push_error("[WindmillIntro] 找不到 Windmill 节点")
		return

	# 冻结玩家 + 接管镜头
	if player:
		player.set_physics_process(false)
		player.set_process(false)
	camera.manual_control = true

	# 步骤1：平滑 zoom 缩小 + 平移到风车
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", Vector2(zoom_out_value, zoom_out_value), zoom_transition)
	tween.tween_property(camera, "global_position", windmill.global_position, zoom_transition)
	await tween.finished

	# 步骤2：停留观察
	await get_tree().create_timer(focus_duration).timeout

	# 步骤3：恢复 zoom (回到场景默认) + 回玩家
	var back_target: Vector2 = player.global_position if player else windmill.global_position
	var default_zoom: Vector2 = camera._default_zoom if camera.get("_default_zoom") != null else Vector2.ONE
	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(camera, "zoom", default_zoom, zoom_transition)
	tween2.tween_property(camera, "global_position", back_target, zoom_transition)
	await tween2.finished

	# 步骤4：恢复镜头控制 + 玩家
	camera.manual_control = false
	if player:
		player.set_physics_process(true)
		player.set_process(true)
	print("[WindmillIntro] 入场动画结束")
