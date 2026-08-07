# ============================================================
# HUD — 抬头显示 (CanvasLayer)
# 显示能量条 + 当前选中目标名称
# 挂载于每个关卡场景，永远覆盖在画面最上层
# ============================================================
extends CanvasLayer

# ---------- 子节点引用 (场景中手动放置) ----------
# EnergyBar:    ProgressBar，显示能量 [0, ENERGY_MAX]
# TargetLabel:  Label，显示当前选中目标的 display_name
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var target_label: Label = $TargetLabel

func _ready() -> void:
	var global := get_node("/root/Global")
	# 监听能量变化，实时更新能量条
	global.energy_changed.connect(_on_energy_changed)
	energy_bar.max_value = global.ENERGY_MAX
	energy_bar.value = global.energy

# 能量变化回调：更新进度条 + 低能量红色警告
func _on_energy_changed(new_energy: float) -> void:
	energy_bar.value = new_energy
	if new_energy <= 30.0:
		# 能量<30 → 能量条变红
		energy_bar.modulate = Color(1.0, 0.3, 0.3, 1.0)
	else:
		energy_bar.modulate = Color(1,1,1,1)

# 每帧更新目标名称显示
func _process(_delta: float) -> void:
	var global := get_node("/root/Global")
	var target: Node2D = global.selected_target
	if target and is_instance_valid(target):
		# 读取目标节点的 display_name 元数据
		# 例如：箱子设置 "箱子"，风化岩柱设置 "风化岩柱"
		var display_name: String = target.get_meta("display_name", target.name)
		target_label.text = display_name
	else:
		target_label.text = ""
