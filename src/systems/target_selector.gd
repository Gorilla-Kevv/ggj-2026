# ============================================================
# TargetSelector — R键目标切换器
# 挂载于每个关卡场景的 Node2D 节点
# 管理可操作目标列表，R键循环切换，更新 Global.selected_target
# 自动扫描 "player" 组 和 "interactable" 组
# 按下 R 键时如果除了玩家外没有可交互物体，通知 HUD 显示提示
# ============================================================
extends Node2D

# ---------- 状态 ----------
# targets:            当前场景中所有可操作目标 (主角 + 可交互物体)
# current_index:      当前选中目标的索引
# has_interactables:  是否存在除玩家外的可交互物体
var targets: Array[Node2D] = []
var current_index: int = 0
var has_interactables: bool = false

# target_changed: 目标切换时触发 (new_target 为新选中目标)
signal target_changed(new_target: Node2D)

func _ready() -> void:
	call_deferred("_refresh_targets")

# 输入处理：R键 → 循环切换
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_target"):
		if not has_interactables:
			# 除玩家外没有可交互物体 → 通知 HUD
			var global := get_node("/root/Global")
			global.target_label_hint = "无可选物体"
		else:
			_cycle_target()

# 重新扫描场景中的目标列表
func _refresh_targets() -> void:
	targets.clear()
	has_interactables = false

	# 1. 主角始终在列表第一位
	var player := get_tree().get_first_node_in_group("player")
	if player:
		targets.append(player)

	# 2. 所有可交互物体依次排列
	for node in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(node):
			targets.append(node)
			has_interactables = true

	if targets.size() > 0:
		select_target(0)

# 切换到下一个目标 (R键触发)
func _cycle_target() -> void:
	if targets.size() <= 1:
		return
	current_index = (current_index + 1) % targets.size()
	select_target(current_index)

# 选中指定索引的目标
func select_target(index: int) -> void:
	if current_index < targets.size():
		var old_target := targets[current_index]
		if old_target is BaseInteractable:
			old_target.on_deselected()

	current_index = clampi(index, 0, targets.size() - 1)

	var global := get_node("/root/Global")
	global.selected_target = targets[current_index]

	if global.selected_target is BaseInteractable:
		global.selected_target.on_selected()

	target_changed.emit(global.selected_target)

# 获取当前选中目标 (供外部查询)
func get_current_target() -> Node2D:
	if targets.size() == 0:
		return null
	return targets[current_index]

# 动态注册新目标 (供场景中动态生成的交互物调用)
func register_target(node: Node2D) -> void:
	if node not in targets:
		targets.append(node)
		has_interactables = true
		_refresh_targets()
