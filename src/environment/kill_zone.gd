# ============================================================
# KillZone — 深渊/无底边界 (即死区域)
# 放置在关卡底部或不可到达的区域边缘
# 任何进入此区域的 "player" 组节点立即死亡
# ============================================================
extends Area2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[KillZone] 玩家进入即死区")
		body.die()
	elif body.is_in_group("interactable"):
		print("[KillZone] 物体碰撞有效")
		
