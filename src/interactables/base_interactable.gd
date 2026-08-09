# ============================================================
# BaseInteractable — 可交互物体基类
# 所有可被风吹动/选中的物体继承此类
# 自动加入 "interactable" 组供 TargetSelector 扫描
#
# 编辑器用法：
#   1. 场景中新建 RigidBody2D，挂载 pushable_box.gd
#   2. 在属性面板设置 Display Name / Mass 即可创建不同物体
#   3. 无需为每种物体单独写脚本
# ============================================================
extends RigidBody2D
class_name BaseInteractable

# 在编辑器中显示的名称 (HUD TargetLabel)
@export var display_name: String = "物体"
# 质量 (kg)，越大越难吹动
@export var interact_mass: float = 5.0

func _ready() -> void:
	add_to_group("interactable")
	set_meta("display_name", display_name)
	mass = interact_mass
	# 防止刚体自旋干扰操作
	lock_rotation = true

func apply_wind_force(force: Vector2) -> void:
	if sleeping:
		sleeping = false
	apply_central_force(force)

func on_selected() -> void:
	modulate = Color.AQUA

func on_deselected() -> void:
	modulate = Color.WHITE
