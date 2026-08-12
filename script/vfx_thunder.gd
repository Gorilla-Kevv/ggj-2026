extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_start_cycle()

func _set_all_collisions(disabled: bool) -> void:
	for child in find_children("*", "CollisionShape2D"):
		child.disabled = disabled

func _start_cycle() -> void:
	while true:
		# 1. 危险期 — 所有碰撞开启
		_set_all_collisions(false)
		animation_player.play("start")
		await animation_player.animation_finished

		# 2. 过渡 — 等待
		await get_tree().create_timer(2.0).timeout

		# 3. 安全期 — 所有碰撞关闭
		_set_all_collisions(true)
		animation_player.play("end_animation")
		await animation_player.animation_finished

		# 4. 等待后循环
		await get_tree().create_timer(2.0).timeout
