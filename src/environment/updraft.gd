# ============================================================
# Updraft — 上升气流 (大厅/关卡组件)
# Area2D 区域，玩家进入后持续获得向上的升力，不消耗能量。
# 用于大厅攀升塔 (借助气流升到上层章节) 以及峡谷关卡的热气流攀升。
#
# 使用：
#   1. 调整碰撞形状确定气流范围 (宽高建议: 宽80~160, 高250~600)
#   2. lift_force: 每秒施加的上升冲量 (越大攀升越快)
#   3. max_up_speed: 气流内竖直速度上限 (防止无限加速)
#   4. 视觉为 _draw() 上升箭头流线 + 可选粒子子节点
# ============================================================
extends Area2D

# ---------- 导出变量 (编辑器配置) ----------
@export var lift_force: float = 900.0      # 上升冲量 (px/s²)
@export var max_up_speed: float = 300.0    # 气流内竖直上升速度上限
@export var flow_color: Color = Color(0.35, 0.85, 1.0)  # 气流颜色

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

func _physics_process(_delta: float) -> void:
	# 直接钳制竖直速度为稳定的上升目标速度，而非叠加冲量。
	# 直接设定 velocity.y 可避开与玩家 _physics_process 的执行顺序问题，
	# 无论本节点在场景树中排前还是排后，玩家都能稳定上升。
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.velocity.y > -max_up_speed:
				body.velocity.y = -max_up_speed

# ---------- 占位视觉 (可替换) ----------

func _draw() -> void:
	var rect := _get_visual_rect()
	var col := Color(flow_color, 0.18)
	# 区域淡色填充
	draw_rect(rect, col, true)
	# 上升流线 (自上而下排布，箭头朝上)
	var step_y := 48.0
	var y := rect.position.y + 30.0
	while y < rect.end.y - 20.0:
		draw_line(Vector2(rect.position.x + 20.0, y), Vector2(rect.position.x + 20.0, y - 24.0), Color(flow_color, 0.5), 2.0)
		draw_line(Vector2(rect.position.x + 20.0, y - 24.0), Vector2(rect.position.x + 14.0, y - 14.0), Color(flow_color, 0.5), 2.0)
		draw_line(Vector2(rect.position.x + 20.0, y - 24.0), Vector2(rect.position.x + 26.0, y - 14.0), Color(flow_color, 0.5), 2.0)
		draw_line(Vector2(rect.end.x - 20.0, y), Vector2(rect.end.x - 20.0, y - 24.0), Color(flow_color, 0.35), 2.0)
		draw_line(Vector2(rect.end.x - 20.0, y - 24.0), Vector2(rect.end.x - 26.0, y - 14.0), Color(flow_color, 0.35), 2.0)
		draw_line(Vector2(rect.end.x - 20.0, y - 24.0), Vector2(rect.end.x - 14.0, y - 14.0), Color(flow_color, 0.35), 2.0)
		y += step_y
	# 边框
	draw_rect(rect, Color(flow_color, 0.6), false, 2.0)

# 根据碰撞形状计算可视矩形 (支持 RectangleShape2D；其他形状回退到默认)
func _get_visual_rect() -> Rect2:
	var shape_node := get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is RectangleShape2D:
		var shape := shape_node.shape as RectangleShape2D
		return Rect2(-shape.size * 0.5, shape.size)
	return Rect2(-60.0, -300.0, 120.0, 600.0)
