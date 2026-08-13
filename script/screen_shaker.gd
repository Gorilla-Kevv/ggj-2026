extends Node

func _ready() -> void:
	add_to_group("screen_shaker")

func screen_shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		print("get camera failed")
		return

	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)

	tween.tween_method(
		func(s: float):
			camera.offset = Vector2.from_angle(randf_range(0, TAU)) * s,
		strength,
		0.0,
		duration
	)
