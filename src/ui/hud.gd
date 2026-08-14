# ============================================================
# HUD — 抬头显示 (CanvasLayer)
# 显示能量条 + 当前选中目标名称 + Boss 血条/阶段提示
# 挂载于每个关卡场景，永远覆盖在画面最上层
# ============================================================
extends CanvasLayer

# ---------- 子节点引用 (场景中手动放置) ----------
# EnergyBar:    ProgressBar，显示能量 [0, ENERGY_MAX]
# TargetLabel:  Label，显示当前选中目标的 display_name
# BossUI:       Boss 战 UI (阶段标签 + 提示 + 血条)
@onready var energy_bar: ProgressBar = $EnergyBar
@onready var target_label: Label = $TargetLabel
@onready var boss_ui: Control = $BossUI
@onready var boss_phase_label: Label = $BossUI/BossPhaseLabel
@onready var boss_hint_label: Label = $BossUI/BossHintLabel
@onready var boss_health_bar: ProgressBar = $BossUI/BossHealthBar

# 各阶段的提示文案 (玩家该做什么)
const BOSS_PHASE_NAMES := {
	0: "阶段一 · 吸附",
	1: "阶段二 · 暴风",
	2: "阶段三 · 平静",
}
const BOSS_PHASE_HINTS := {
	0: "狂风骤起，活下去！",
	1: "抓住时机！撞击Boss使它冷却",
	2: "利用场地进行攻击",
}

var _boss: Node = null   # 不标注类型，避免已释放实例报错

func _ready() -> void:
	var global := get_node("/root/Global")
	# 监听能量变化，实时更新能量条
	global.energy_changed.connect(_on_energy_changed)
	energy_bar.max_value = global.ENERGY_MAX
	energy_bar.value = global.energy
	# Boss UI 默认隐藏
	boss_ui.visible = false
	# 延迟查找 Boss 并连接信号 (Boss 可能在 HUD 之后才加入场景树)
	call_deferred("_find_and_connect_boss")

# 查找 Boss 并连接血条/阶段信号
func _find_and_connect_boss() -> void:
	_boss = get_tree().get_first_node_in_group("boss")
	if _boss == null:
		return
	if _boss.has_signal("boss_health_changed") and not _boss.boss_health_changed.is_connected(_on_boss_health_changed):
		_boss.boss_health_changed.connect(_on_boss_health_changed)
	if _boss.has_signal("phase_changed") and not _boss.phase_changed.is_connected(_on_boss_phase_changed):
		_boss.phase_changed.connect(_on_boss_phase_changed)
	if _boss.has_signal("boss_defeated") and not _boss.boss_defeated.is_connected(_on_boss_defeated):
		_boss.boss_defeated.connect(_on_boss_defeated)
	# 初始化血条与阶段文案 (UI 仍隐藏，等 Boss 激活后由 phase_changed 信号触发显示)
	_on_boss_health_changed(4, 4)

# Boss 血量变化回调
func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current

# Boss 阶段变化回调 (首次收到即为 Boss 激活，此时显示 UI)
func _on_boss_phase_changed(new_phase: int) -> void:
	boss_phase_label.text = BOSS_PHASE_NAMES.get(new_phase, "阶段")
	boss_hint_label.text = BOSS_PHASE_HINTS.get(new_phase, "")
	boss_ui.visible = true

# Boss 击败回调
func _on_boss_defeated() -> void:
	boss_ui.visible = false

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

	# 优先显示 TargetSelector 发来的提示 (持续3秒)
	if global.target_label_hint != "":
		if Time.get_ticks_msec() - global.target_label_hint_time < 3000:
			target_label.text = global.target_label_hint
			return
		else:
			global.target_label_hint = ""

	var target = global.selected_target   # 不标注类型，避免已释放实例报错
	if target != null and is_instance_valid(target):
		var display_name: String = target.get_meta("display_name", target.name)
		target_label.text = display_name
	else:
		target_label.text = ""
