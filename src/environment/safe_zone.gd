# ============================================================
# SafeZone — 通用安全区
# 挂到任意 Area2D 上：玩家进入时关闭指定组的所有节点，退出时恢复
# 用途：风车安全区、安全屋、电梯等，避免玩家在特定区域内触发危险
# ============================================================
extends Area2D

# 要批量开关的节点组名 (进入时关闭这些节点的 monitoring，退出恢复)
@export var target_group: String = "deadzone"

func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_group_monitoring(false)
		print("[SafeZone] 玩家进入，关闭组 ", target_group)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_group_monitoring(true)
		print("[SafeZone] 玩家退出，恢复组 ", target_group)

# 批量开关指定组内所有 Area2D 的 monitoring
func _set_group_monitoring(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group(target_group):
		if node is Area2D:
			node.monitoring = enabled
