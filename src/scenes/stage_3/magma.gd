# ============================================================
# Magma — 岩浆瓦片层 (第3关)
# 挂在岩浆 TileMapLayer 上：
#   玩家圆形碰撞体任一点碰到任意岩浆瓦片 → 立即死亡 (player.die())
# 通过采样玩家碰撞体外圈若干点 + 中心点，映射到瓦片坐标判断
# ============================================================
extends TileMapLayer
class_name Magma

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# 死亡动画期间物理已停止，避免重复触发 die()
	if not player.is_physics_processing():
		return
	if _player_touches_magma(player):
		player.die()

func _player_touches_magma(player: Node2D) -> bool:
	var center := player.global_position
	var shape := player.get_node_or_null("CollisionShape2D")
	var radius := 50.0
	var offset := Vector2.ZERO
	if shape != null and shape.shape is CircleShape2D:
		var circle := shape.shape as CircleShape2D
		radius = circle.radius
		offset = shape.position

	# 采样点: 圆心 + 圆形外圈 8 个方向
	var points: Array[Vector2] = [Vector2.ZERO]
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	for p in points:
		var coords := local_to_map(to_local(center + offset + p))
		if get_cell_source_id(coords) != -1:
			return true
	return false
