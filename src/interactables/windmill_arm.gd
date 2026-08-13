# ============================================================
# WindmillArm — 风车臂 (可交互物体)
# 四臂之一，加入 "interactable" 组可被 R 选中、有风向线
# 玩家吹此臂时，不移动自身，而是把力传给风车主体转成扭矩
# ============================================================
extends Node2D
class_name WindmillArm

# 力臂显示名 (R 键选中时 HUD 显示，如 "上臂"/"右臂")
@export var arm_name: String = "风车臂"

func _ready() -> void:
	add_to_group("interactable")
	set_meta("display_name", arm_name)

# WindSystem 对 interactable 组物体调用此方法
# 但臂不是 RigidBody2D，WindSystem 默认会跳过 —— 需要它在 wind_system 里兼容
func apply_wind_force(force: Vector2) -> void:
	var platform := get_parent()
	if platform and platform.has_method("apply_arm_force"):
		platform.apply_arm_force(self, force)

func on_selected() -> void:
	modulate = Color.AQUA

func on_deselected() -> void:
	modulate = Color.WHITE
