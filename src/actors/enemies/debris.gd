# ============================================================
# Debris — 碎石 (Boss 战专用)
# Area2D，velocity 控制飞行，碰到玩家即死
# ============================================================
extends Area2D

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.die()
