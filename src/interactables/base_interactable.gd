# ============================================================
# BaseInteractable — 可交互物体基类
# 所有可被风吹动/选中的物体继承此类
# 自动加入 "interactable" 组供 TargetSelector 扫描
# 程序C (交互/环境) 在此基础上扩展具体物体
# ============================================================
extends RigidBody2D
class_name BaseInteractable

func _ready() -> void:
	# 注册到 "interactable" 组
	# TargetSelector 通过此组自动发现所有可交互物体
	add_to_group("interactable")
	# 设置默认显示名称 (子类可覆盖)
	if not has_meta("display_name"):
		set_meta("display_name", "物体")

# 被风力推动 (由 WindSystem 调用)
# 唤醒刚体后用持续力推动
func apply_wind_force(force: Vector2) -> void:
	if sleeping:
		sleeping = false
	apply_central_force(force)

# 被 R 键选中时的高亮效果 (金色)
func on_selected() -> void:
	modulate = Color.GOLD

# 取消选中时恢复原色
func on_deselected() -> void:
	modulate = Color.WHITE
