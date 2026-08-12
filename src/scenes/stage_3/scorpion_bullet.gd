# ============================================================
# ScorpionBullet — 蝎子弹
# Area2D 直线飞行：
#   命中玩家 → player.die() (即死)
#   命中墙壁 / 超出存活时间 → 消失
# 外观: Sprite2D (占位贴图，可替换)
# ============================================================
extends Area2D
class_name ScorpionBullet

@export var speed: float = 320.0   # 飞行速度 (px/s)
@export var lifetime: float = 5.0  # 最长存活时间 (秒)

var _velocity: Vector2 = Vector2.ZERO

# 蝎子调用: 设置出生点与飞行方向
func setup(start_pos: Vector2, vel: Vector2) -> void:
	global_position = start_pos
	_velocity = vel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var t := get_tree().create_timer(lifetime)
	await t.timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()
	queue_free()
