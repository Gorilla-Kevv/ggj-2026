# ============================================================
# Spike — 尖刺/致命地形
# 放置在关卡中的尖刺、毒池、激光栅栏等
# 任何进入此区域的 "player" 组节点立即死亡
# 对应策划案中的"触碰尖刺、毒池"死亡条件
# 使用注意：在编辑器中为 CollisionShape2D 调整形状适配实际尖刺布局
# ============================================================
extends Area2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()
