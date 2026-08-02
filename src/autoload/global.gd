# ============================================================
# Global — 全局单例 (Autoload)
# 存储贯穿整个游戏的共享状态：能量、选中目标、检查点
# 所有场景中通过 get_node("/root/Global") 访问
# ============================================================
extends Node

# ---------- 能量系统参数 ----------
# energy:       当前能量值 (0 ~ ENERGY_MAX)
# ENERGY_MAX:   能量上限 (满能量可连吹约5秒)
# ENERGY_DRAIN: 吹风时每秒消耗量
# ENERGY_REGEN: 不吹风时每秒回复量 (约7秒从空到满)
var energy: float = 100.0
const ENERGY_MAX: float = 100.0
const ENERGY_DRAIN: float = 20.0
const ENERGY_REGEN: float = 15.0

# ---------- 目标选择状态 ----------
# selected_target: 当前 R 键选中的操作目标 (主角或可交互物体)
# 由 TargetSelector 写入，WindSystem / WindLine / HUD 读取
var selected_target: Node2D = null

# ---------- 检查点/重生状态 ----------
# current_checkpoint:    最后一次激活的检查点坐标
# last_checkpoint_level: 检查点所在关卡路径 (用于死亡后跨关卡重载)
var current_checkpoint: Vector2 = Vector2.ZERO
var last_checkpoint_level: String = ""

# ---------- 信号 ----------
# energy_changed: 能量变化时触发，HUD 监听此信号更新能量条
# energy_depleted: 能量归零时触发，WindSystem 监听此信号强制停风
# energy_full: 能量回满时触发 (预留，可用于 UI 特效)
signal energy_changed(new_energy: float)
signal energy_depleted()
signal energy_full()

func _ready() -> void:
	energy = ENERGY_MAX

# 消耗能量 (每帧由 WindSystem 调用)
# delta: 上一帧耗时 (秒)
func drain_energy(delta: float) -> void:
	energy = maxf(0.0, energy - ENERGY_DRAIN * delta)
	energy_changed.emit(energy)
	if energy <= 0.0:
		energy_depleted.emit()

# 自动回复能量 (当前未在 _process 中自动调用，需由外部驱动)
# 实际由 WindSystem 控制是否在吹风，非吹风期由外部调用
func regen_energy(delta: float) -> void:
	if energy >= ENERGY_MAX:
		return
	energy = minf(ENERGY_MAX, energy + ENERGY_REGEN * delta)
	energy_changed.emit(energy)
	if energy >= ENERGY_MAX:
		energy_full.emit()

# 瞬间回满能量 (重生时调用)
func refill_energy() -> void:
	energy = ENERGY_MAX
	energy_changed.emit(energy)
	energy_full.emit()

# 检查是否有足够能量吹风
func has_energy() -> bool:
	return energy > 0.0
