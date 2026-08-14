# ============================================================
# WeatherFogController — 天气雾流动控制器
# 挂到雾节点 (带 ShaderMaterial 的 Sprite2D/ColorRect) 上
# 跟踪玩家飞行方向和速度，动态更新 shader 的 speed 参数
# 玩家飞行时，雾朝玩家运动反方向流动，速度越快雾流动越快
# ============================================================
extends Node2D

# 雾的 ShaderMaterial (拖入 weather_fog_heavy 材质)
@export var fog_material: ShaderMaterial
# 玩家速度 → shader speed 的缩放系数
# 玩家速度约 0~1000 px/s，shader speed 默认 0.02，此系数做映射
@export var speed_scale: float = 0.00005

func _process(_delta: float) -> void:
	if fog_material == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var vel: Vector2 = player.velocity
	# 负号 = 相对运动：玩家向右飞，雾向左飘 (模拟穿过雾)
	fog_material.set_shader_parameter("speed", -vel * speed_scale)
