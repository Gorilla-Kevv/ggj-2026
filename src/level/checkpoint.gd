# ============================================================
# Checkpoint — 检查点/重生点
# 玩家触碰后激活，死亡后从最后激活的检查点重生
# 激活状态写入 Global (跨场景保留)
# 视觉反馈：未激活=白色 / 已激活=绿色半透明
# ============================================================
extends Area2D

# is_active: 是否已被激活 (设为 true 可使检查点默认激活)
@export var is_active: bool = false

# checkpoint_activated: 检查点被激活时触发 (供音效/VFX 监听)
signal checkpoint_activated(checkpoint: Node2D)

func _ready() -> void:
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_update_visual()

# 碰撞回调：玩家首次触碰 → 激活
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		activate()

# 激活检查点：记录位置和关卡路径 → 回满能量 → 更新视觉
func activate() -> void:
	is_active = true
	var global := get_node("/root/Global")
	global.current_checkpoint = global_position
	global.last_checkpoint_level = get_tree().current_scene.scene_file_path
	# 抵达检查点即回满能量 (旅途补给)
	global.refill_energy()
	print("[Checkpoint] 激活 坐标=", global.current_checkpoint, " 关卡=", global.last_checkpoint_level)
	_update_visual()
	checkpoint_activated.emit(self)

# 视觉状态：已激活=亮绿 + "CHECKED!" / 未激活=白 + "CHECKPOINT"
func _update_visual() -> void:
	if is_active:
		modulate = Color(1.0, 0.843, 0.875, 0.682)
	else:
		modulate = Color(1, 1, 1, 1)
	_update_label()

func _update_label() -> void:
	var label := get_node_or_null("Label") as Label
	if label == null:
		return
	if is_active:
		label.text = "CHECKED!"
	else:
		label.text = "CHECKPOINT"
