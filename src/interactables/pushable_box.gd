# ============================================================
# PushableBox — 可吹动箱子
# 继承 BaseInteractable，质量 5.0
# 关卡中最基础的解谜物体：吹开挡路、吹到指定位置触发机关
# ============================================================
extends BaseInteractable

func _ready() -> void:
	super._ready()
	# 显示名称 (HUD 中显示)
	set_meta("display_name", "箱子")
	# 质量 (kg)，影响风吹动的响应速度
	# 值越大越难吹动，配合 WindSystem 的力度设计关卡难度
	mass = 5.0
