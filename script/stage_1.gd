extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# 背景环境音（在关卡/大厅 _ready 里调用）
	get_node("/root/AudioManager").play_default_ambient(0.0)
