# 地图边界控制器：根据 TileMapLayer 的 used_rect 设置相机限制
# 放在场景根节点下，自动查找场景中的 Camera2D
extends Node2D

@export var tile_map_layer: TileMapLayer
@export var target_camera: Camera2D

func _ready() -> void:
	if tile_map_layer == null:
		return

	if target_camera == null:
		target_camera = get_tree().get_first_node_in_group("camera") as Camera2D
	if target_camera == null:
		return

	var used := tile_map_layer.get_used_rect()
	var tile_size := tile_map_layer.tile_set.tile_size

	target_camera.limit_top    = used.position.y * tile_size.y
	target_camera.limit_right  = used.end.x * tile_size.x
	target_camera.limit_bottom = used.end.y * tile_size.y
	target_camera.limit_left   = used.position.x * tile_size.x
	target_camera.reset_smoothing()
