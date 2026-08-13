# ============================================================
# LevelBGM — 关卡音乐自动播放器
# 挂载到关卡场景根节点上，进入场景时自动播放对应 BGM
# 在 Inspector 中设置 stage_num (1/2/3)
# ============================================================
extends Node2D

@export var stage_num: int = 1

func _ready() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_stage_music"):
		audio.play_stage_music(stage_num)
