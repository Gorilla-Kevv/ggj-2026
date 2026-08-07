# ============================================================
# TargetSelector — R键目标切换器
# 挂载于每个关卡场景的 Node2D 节点
# 管理可操作目标列表，R键循环切换，更新 Global.selected_target
# 自动扫描 "player" 组 和 "interactable" 组
# ============================================================
extends Node2D

# ---------- 状态 ----------
# targets:        当前场景中所有可操作目标 (主角 + 可交互物体)
# current_index:  当前选中目标的索引
# no_target_label: 无可选物体时的提示 Label
var targets: Array[Node2D] = []
var current_index: int = 0
var no_target_label: Label = null

# target_changed: 目标切换时触发 (new_target 为新选中目标)
signal target_changed(new_target: Node2D)

func _ready() -> void:
	# 创建屏幕提示 (CanvasLayer 确保在屏幕上显示)
	var canvas := CanvasLayer.new()
	canvas.name = "NoTargetCanvas"
	add_child(canvas)

	no_target_label = Label.new()
	no_target_label.name = "NoTargetLabel"
	no_target_label.text = "无可选物体"
	no_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_target_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 0.8))
	no_target_label.add_theme_font_size_override("font_size", 24)
	no_target_label.anchor_right = 1.0
	no_target_label.anchor_bottom = 1.0
	no_target_label.visible = false
	canvas.add_child(no_target_label)

	# 延迟刷新，确保场景中所有节点完成 _ready() 后再收集目标
	call_deferred("_refresh_targets")

# 输入处理：R键 → 循环切换
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_target"):
		_cycle_target()

# 重新扫描场景中的目标列表
# 调用时机：场景加载 / 新交互物动态注册后
func _refresh_targets() -> void:
	targets.clear()
	# 1. 主角始终在列表第一位
	var player := get_tree().get_first_node_in_group("player")
	if player:
		targets.append(player)
	# 2. 所有可交互物体依次排列
	var interactable_count := 0
	for node in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(node):
			targets.append(node)
			interactable_count += 1
	if targets.size() > 0:
		select_target(0)
	# 除玩家外无可选物体 → 显示提示
	no_target_label.visible = (interactable_count == 0)

# 切换到下一个目标 (R键触发)
func _cycle_target() -> void:
	if targets.size() == 0:
		return
	current_index = (current_index + 1) % targets.size()
	select_target(current_index)

# 选中指定索引的目标
# 会自动取消旧目标的选中高亮，并为新目标添加高亮
func select_target(index: int) -> void:
	# 取消旧目标高亮
	if current_index < targets.size():
		var old_target := targets[current_index]
		if old_target is BaseInteractable:
			old_target.on_deselected()

	current_index = clampi(index, 0, targets.size() - 1)

	# 更新全局状态
	var global := get_node("/root/Global")
	global.selected_target = targets[current_index]

	# 为新目标添加高亮
	if global.selected_target is BaseInteractable:
		global.selected_target.on_selected()

	target_changed.emit(global.selected_target)

# 获取当前选中目标 (供外部查询)
func get_current_target() -> Node2D:
	if targets.size() == 0:
		return null
	return targets[current_index]

# 动态注册新目标 (供场景中动态生成的交互物调用)
# 例如：Boss 战中生成的碎石、关卡中触发的机关
func register_target(node: Node2D) -> void:
	if node not in targets:
		targets.append(node)
		no_target_label.visible = false
		_refresh_targets()
