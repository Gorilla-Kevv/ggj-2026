# 地图边界控制器：根据 TileMapLayer 的 used_rect 设置相机限制
# 放在场景根节点下，自动查找场景中的 Camera2D
# 也可提供手动边界 (无 TileMap 的场景，如大厅)：
#   use_manual_limits = true 时用 manual_limit_* 四个值
extends Node2D

@export var tile_map_layer: TileMapLayer
@export var target_camera: Camera2D

@export var use_manual_limits: bool = false
@export var manual_limit_left: float = 0.0
@export var manual_limit_top: float = 0.0
@export var manual_limit_right: float = 0.0
@export var manual_limit_bottom: float = 0.0

func _ready() -> void:
	if target_camera == null:
		target_camera = get_tree().get_first_node_in_group("camera") as Camera2D
	if target_camera == null:
		return

	if tile_map_layer != null:
		var used := tile_map_layer.get_used_rect()
		var tile_size := tile_map_layer.tile_set.tile_size
		target_camera.limit_left   = used.position.x * tile_size.x
		target_camera.limit_top    = used.position.y * tile_size.y
		target_camera.limit_right  = used.end.x * tile_size.x
		target_camera.limit_bottom = used.end.y * tile_size.y
	elif use_manual_limits:
		target_camera.limit_left   = manual_limit_left
		target_camera.limit_top    = manual_limit_top
		target_camera.limit_right  = manual_limit_right
		target_camera.limit_bottom = manual_limit_bottom
	else:
		return

	target_camera.reset_smoothing()
