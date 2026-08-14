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


# 死亡特效：震动 + 黑屏闪一下 (最简方式：运行时生成全屏黑幕，淡入淡出后自毁)
func death_effect() -> void:
	screen_shake(15.0, 0.6)
	_flash_black(0.35, 0.4, 0.6)


func _flash_black(fade_in: float, hold: float, fade_out: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)

	var tween := create_tween()
	tween.tween_property(rect, "color", Color.BLACK, fade_in)
	tween.tween_interval(hold)
	tween.tween_property(rect, "color", Color(0, 0, 0, 0), fade_out)
	tween.tween_callback(layer.queue_free)
