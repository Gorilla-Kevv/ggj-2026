extends SubViewport

# 小地图 (可复用)：复用主世界 (world_2d 共享)，只渲染瓦片结构 + 专用标记。
# 关键设计：
#   - 不用 Camera2D，直接每帧设置 canvas_transform 跟随玩家，
#     彻底避开 SubViewport 相机"是否 current"导致不跟随之类的问题。
#   - 用 canvas_cull_mask 过滤：
#       layer 2 (visibility_layer=2)：瓦片结构，主视图+小地图都显示
#       layer 3 (visibility_layer=4)：小地图专用标记，只在小地图显示
#     其余(默认=1)被过滤掉，不显示在小地图上。
#   - _apply_minimap_layers() 在 _ready 自动把场景里所有 TileMapLayer 及其
#     祖先打上 layer 2，并给玩家标记链打上 layer 3 —— 这样任何 stage 只要挂上
#     minimap.tscn 即可复用，无需手动改瓦片/祖先的 visibility_layer。
#     (Godot 要求 CanvasItem 与其全部父级都跟 cull mask 有交集才会被渲染)
#   - 视野中心按主相机 limit 做 clamp (overrun_margin 可略超出 board)。

const TILE_LAYER := 2    # bit 1：瓦片结构层
const MARKER_LAYER := 4  # bit 2：小地图专用标记层

@export var zoom: Vector2 = Vector2(0.25, 0.25)
# 允许小地图视野超出 board 边界多少 (世界单位)。调大即可让标记/边缘多露出一点。
@export var overrun_margin: Vector2 = Vector2(300.0, 300.0)

var _player: Node2D
var _camera: Camera2D
var _minimap_layer: CanvasLayer

func _ready() -> void:
	world_2d = get_tree().root.world_2d
	# 主视图不渲染 layer 3 由 player.gd 统一处理 (任何场景/关卡都生效)
	_apply_minimap_layers()
	_minimap_layer = _find_ancestor_canvas_layer()

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

# 视野中心 clamp 到主相机的 limit 附近；overrun_margin 让 clamp 范围向外扩，
# 使小地图可以比大地图限制稍微超出一点 (默认 300 世界单位)。
func _clamp_to_camera_limits(center: Vector2) -> Vector2:
	var half_world := Vector2(size) * 0.5 / zoom
	var left := _camera.limit_left - overrun_margin.x
	var right := _camera.limit_right + overrun_margin.x
	var top := _camera.limit_top - overrun_margin.y
	var bottom := _camera.limit_bottom + overrun_margin.y

	if right - left > half_world.x * 2.0:
		center.x = clampf(center.x, left + half_world.x, right - half_world.x)
	else:
		center.x = (left + right) * 0.5

	if bottom - top > half_world.y * 2.0:
		center.y = clampf(center.y, top + half_world.y, bottom - half_world.y)
	else:
		center.y = (top + bottom) * 0.5

	return center

# 自动给瓦片与标记链打上对应 layer，让任何 stage 复用小地图时无需手动设置。
func _apply_minimap_layers() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "TileMapLayer", true, false):
		var ci := node as CanvasItem
		if ci != null:
			_set_chain_layer(ci, TILE_LAYER)
	var player := get_tree().get_first_node_in_group("player") as CanvasItem
	if player != null:
		_set_chain_layer(player, MARKER_LAYER)

# 给 ci 及其所有 CanvasItem 祖先 OR 上 layer，满足 Godot 的父级渲染规则。
func _set_chain_layer(ci: CanvasItem, layer: int) -> void:
	ci.visibility_layer |= layer
	var p := ci.get_parent()
	while p is CanvasItem:
		(p as CanvasItem).visibility_layer |= layer
		p = p.get_parent()

# 向上找到最近的 CanvasLayer (Minimap 节点)，用于 M 键开关整个小地图。
func _find_ancestor_canvas_layer() -> CanvasLayer:
	var p := get_parent()
	while p != null and not (p is CanvasLayer):
		p = p.get_parent()
	return p as CanvasLayer
