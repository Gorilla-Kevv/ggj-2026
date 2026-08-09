extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_2d: CollisionShape2D = $KillZone/CollisionShape2D

func _ready() -> void:
	_start_cycle()

func _start_cycle() -> void:
	while true:
		# 1. 播放 start — 安全期，碰撞关闭
		collision_shape_2d.disabled = true
		animation_player.play("start")
		await animation_player.animation_finished

		# 2. 播放 reset 2 秒
		animation_player.play("reset")
		await get_tree().create_timer(2.0).timeout

		# 3. 播放 end_animation — 危险期，碰撞开启
		collision_shape_2d.disabled = false
		animation_player.play("end_animation")
		await animation_player.animation_finished

		# 4. 等待 2 秒后循环
		await get_tree().create_timer(2.0).timeout
