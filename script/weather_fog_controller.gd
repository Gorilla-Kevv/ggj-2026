# ============================================================
# WeatherFogController — 天气雾流动控制器
# 挂到雾节点 (ColorRect / Sprite2D 等 CanvasItem) 上
# 跟踪玩家飞行方向和速度，动态更新 shader 的 speed 参数
# 玩家飞行时，雾朝玩家运动反方向流动，速度越快雾流动越快
# ============================================================
extends CanvasItem

# 雾的 ShaderMaterial (留空则自动使用本节点的 material)
@export var fog_material: ShaderMaterial
# 玩家速度 → shader speed 的缩放系数 (步进 0.00001，可精确调小)
@export_range(0.0, 0.01, 0.00001) var speed_scale: float = 0.0001
# shader speed 上限，防止飞行太快时雾流动过于剧烈
@export var max_speed: float = 0.05

func _process(_delta: float) -> void:
	# 优先用手动指定的材质，否则用本节点挂载的 material
	var mat := fog_material
	if mat == null:
		mat = material as ShaderMaterial
	if mat == null:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var vel: Vector2 = player.velocity
	# 正号：玩家向右飞 → speed.x > 0 → 雾向左飘 (相对运动)
	var shader_speed := vel * speed_scale
	shader_speed = shader_speed.limit_length(max_speed)
	mat.set_shader_parameter("speed", shader_speed)
