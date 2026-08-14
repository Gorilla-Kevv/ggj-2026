extends SubViewport

# 小地图：复用主世界 (world_2d 共享)，只渲染瓦片层。
# 关键设计：
#   - 不用 Camera2D，直接每帧设置 canvas_transform 跟随玩家，
#     彻底避开 SubViewport 相机"是否 current"导致不跟随之类的问题。
#   - 用 canvas_cull_mask 过滤：
#       layer 2 (visibility_layer=2)：瓦片层，主视图+小地图都显示
#       layer 3 (visibility_layer=4)：小地图专用标记，只在小地图显示
#     其余(默认=1)被过滤掉，不显示在小地图上。
#   - 视野中心按主相机 (world/Camera2D) 的 limit 做 clamp，
#     和玩家画面一样不画出 board 边界以外的区域。
# 舞台侧 (stage_3.tscn) 需配合：
#   - 4 个瓦片层 visibility_layer = 2
#   - 小地图标记：自身 visibility_layer = 4，且其所有祖先 (Player/player_pack/world)
#     visibility_layer 需含 layer 3 (Godot 要求 item 与其全部父级都跟 cull mask 有交集)
#   - 场景根 Stage3 visibility_layer = 3 (父级要带上 layer 2，子瓦片才可见)
#   - 本 SubViewport canvas_cull_mask = 6 (layer 2 + layer 3)
@export var zoom: Vector2 = Vector2(0.25, 0.25)

var _player: Node2D
var _camera: Camera2D
var _minimap_layer: CanvasLayer

func _ready() -> void:
	world_2d = get_tree().root.world_2d
	# 主视图不渲染 layer 3，避免小地图专用标记(如玩家标记)泄漏到主画面
	get_tree().root.canvas_cull_mask &= ~4
	# 结构: SubViewport -> SubViewportContainer -> Minimap(CanvasLayer)
	_minimap_layer = get_parent().get_parent() as CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and _minimap_layer != null:
		_minimap_layer.visible = not _minimap_layer.visible

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D
	if _player == null:
		return

	var center := _player.global_position
	if _camera != null:
		center = _clamp_to_camera_limits(center)

	var half := Vector2(size) * 0.5
	canvas_transform = Transform2D(
		Vector2(zoom.x, 0.0),
		Vector2(0.0, zoom.y),
		Vector2(half.x - center.x * zoom.x, half.y - center.y * zoom.y)
	)

# 视野中心 clamp 到主相机的 limit 内，保证小地图不显示 board 以外区域。
func _clamp_to_camera_limits(center: Vector2) -> Vector2:
	var half_world := Vector2(size) * 0.5 / zoom
	var left := _camera.limit_left
	var right := _camera.limit_right
	var top := _camera.limit_top
	var bottom := _camera.limit_bottom

	if right - left > half_world.x * 2.0:
		center.x = clampf(center.x, left + half_world.x, right - half_world.x)
	else:
		center.x = (left + right) * 0.5

	if bottom - top > half_world.y * 2.0:
		center.y = clampf(center.y, top + half_world.y, bottom - half_world.y)
	else:
		center.y = (top + bottom) * 0.5

	return center
