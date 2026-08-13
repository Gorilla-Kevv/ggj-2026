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
# switch_range:       R键可切换的可交互物体最大距离 (px)，超出距离的物体无法选中/操控
@export var switch_range: float = 900.0
var targets: Array[Node2D] = []
var current_index: int = 0
var has_interactables: bool = false

# target_changed: 目标切换时触发 (new_target 为新选中目标)
signal target_changed(new_target: Node2D)

func _ready() -> void:
	add_to_group("target_selector")
	call_deferred("_refresh_targets")

# 输入处理：R键 → 循环切换
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_target"):
		print("[TargetSelector] R键按下 has_interactables=", has_interactables)
		if not has_interactables:
			# 除玩家外没有可交互物体 → 通知 HUD (持续3秒)
			_show_hint("无可选物体")
		elif _get_in_range_interactables().is_empty():
			# 有可交互物体但都在玩家范围外 → 只能切回玩家，提示
			_show_hint("范围内无可选物体")
		else:
			_cycle_target()

# 通知 HUD 显示提示 (持续3秒)
func _show_hint(text: String) -> void:
	var global := get_node("/root/Global")
	global.target_label_hint = text
	global.target_label_hint_time = Time.get_ticks_msec()

# 获取玩家周围 switch_range 内的可交互物体 (供 R 键切换)
func _get_in_range_interactables() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return result
	for node in targets:
		if not is_instance_valid(node) or not node.is_in_group("interactable"):
			continue
		if player.global_position.distance_to(node.global_position) <= switch_range:
			result.append(node)
	return result

# 重新扫描场景中的目标列表
func _refresh_targets() -> void:
	# 记住当前选中的目标，避免刷新后跳回玩家
	var previous_target: Node2D = null
	if current_index < targets.size():
		previous_target = targets[current_index]

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

	# 3. 尝试恢复到之前选中的目标
	if previous_target and is_instance_valid(previous_target):
		var idx := targets.find(previous_target)
		if idx >= 0:
			select_target(idx)
			return

	if targets.size() > 0:
		select_target(0)

# 切换到下一个目标 (R键触发)：只在玩家范围内物体之间循环，玩家始终可切回
func _cycle_target() -> void:
	if targets.size() <= 1:
		print("[TargetSelector] _cycle_target 跳过 targets.size=", targets.size())
		return
	var in_range := _get_in_range_interactables()
	# 从当前索引往后找第一个有效目标 (玩家 index 0 永远可选，范围内物体可选)
	var start := current_index
	var next_index := (start + 1) % targets.size()
	while next_index != start:
		if is_instance_valid(targets[next_index]):
			var t: Node2D = targets[next_index]
			if not t.is_in_group("interactable") or in_range.has(t):
				select_target(next_index)
				return
		next_index = (next_index + 1) % targets.size()
	# 没有范围内新目标 → 切回玩家 (不选中已飞走的物体)
	select_target(0)

func select_target(index: int) -> void:
	var old_index := current_index
	print("[TargetSelector] select_target 旧index=", old_index, " 新index=", index, " 目标列表=", targets)
	# 取消旧目标高亮
	if old_index < targets.size() and is_instance_valid(targets[old_index]) and targets[old_index].is_in_group("interactable"):
		_set_modulate_recursive(targets[old_index], Color.WHITE)
		print("[TargetSelector] 取消高亮: ", targets[old_index].name)

	current_index = clampi(index, 0, targets.size() - 1)

	var global := get_node("/root/Global")
	var new_target = targets[current_index]
	if new_target == null or not is_instance_valid(new_target):
		global.selected_target = null
		return
	global.selected_target = new_target

	# 新目标高亮
	if is_instance_valid(new_target) and new_target.is_in_group("interactable"):
		_set_modulate_recursive(new_target, Color("6bffa3ff"))
		print("[TargetSelector] 设置高亮: ", new_target.name, " modulate=", new_target.modulate)
	else:
		print("[TargetSelector] 目标不在interactable组: ", new_target.name if is_instance_valid(new_target) else "(已释放)")

	target_changed.emit(global.selected_target)

# 递归设色：自身 + 所有子节点的 modulate
func _set_modulate_recursive(node: Node, color: Color) -> void:
	if node is CanvasItem:
		node.modulate = color
	for child in node.get_children():
		_set_modulate_recursive(child, color)

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
