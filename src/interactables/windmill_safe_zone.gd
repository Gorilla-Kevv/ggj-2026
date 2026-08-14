# ============================================================
# WindmillSafeZone — 风车安全区
# 挂到 Windmill 下的 Area2D 子节点上
# 玩家进入风车区域 → 关闭场上所有死区；退出 → 恢复所有死区
# 死区通过 "deadzone" 组识别 (kill_zone.gd 等已加入该组)
# ============================================================
extends Area2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_all_deadzones(false)
		print("[WindmillSafeZone] 玩家进入，关闭所有死区")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_all_deadzones(true)
		print("[WindmillSafeZone] 玩家退出，恢复所有死区")

# 批量开关场上所有死区
func _set_all_deadzones(enabled: bool) -> void:
	for zone in get_tree().get_nodes_in_group("deadzone"):
		if zone is Area2D:
			zone.monitoring = enabled
