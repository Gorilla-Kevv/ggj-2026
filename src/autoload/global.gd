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
const ENERGY_DRAIN: float = 4.0
const ENERGY_REGEN: float = 1.0

# ---------- 目标选择状态 ----------
# selected_target: 当前 R 键选中的操作目标 (主角或可交互物体)
# 由 TargetSelector 写入，WindSystem / WindLine / HUD 读取
var selected_target: Node2D = null

# ---------- 大厅/关卡进度参数 ----------
# HUB_SCENE:      大厅场景路径 (关卡出口返回大厅时使用；等你的大厅场景定名后修改此路径)
# SAVE_PATH:      存档文件路径 (user:// 为 Godot 用户数据目录)
# CHAPTER_LEVELS: 章节→关卡ID注册表，自行填写。
#                 格式: { "章节ID": ["关卡ID", "关卡ID", ...] }
#                 章节ID/关卡ID 必须与关卡门(level_door)中配置的完全一致 (区分大小写)
# CHAPTER_NAMES:  章节显示名 (可选，用于提示文案，如 { "ch1": "实验室" })
const HUB_SCENE: String = "res://src/scenes/hub_world.tscn"
const SAVE_PATH: String = "user://wind_whisper_save.cfg"
const CHAPTER_LEVELS: Dictionary = { "ch1": ["test_level"],}
const CHAPTER_NAMES: Dictionary = {}

# ---------- 检查点/重生状态 ----------
# current_checkpoint:    最后一次激活的检查点坐标
# last_checkpoint_level: 检查点所在关卡路径 (用于死亡后跨关卡重载)
var current_checkpoint: Vector2 = Vector2.ZERO
var last_checkpoint_level: String = ""

# ---------- 关卡进度/大厅状态 ----------
# levels_clear:    已通关关卡集合 {关卡ID: true}
# current_level:   当前所在关卡ID (进关时由关卡门写入，出口自动读取)
# current_chapter: 当前所在章节ID
# hub_return:      返回大厅的落点 (进关时由关卡门记录为"门的位置"，回到大厅后玩家在此出生)
var levels_clear: Dictionary = {}
var current_level: String = ""
var current_chapter: String = ""
var hub_return: Vector2 = Vector2.ZERO

# ---------- 信号 ----------
# energy_changed: 能量变化时触发，HUD 监听此信号更新能量条
# energy_depleted: 能量归零时触发，WindSystem 监听此信号强制停风
# energy_full: 能量回满时触发 (预留，可用于 UI 特效)
# level_cleared:     某关卡通关时触发 (关卡ID, 章节ID)
# chapter_completed: 某章节全部关卡通关时触发 (章节ID)，章节锁(chapter_gate)监听此信号解锁
signal energy_changed(new_energy: float)
signal energy_depleted()
signal energy_full()
signal level_cleared(level_id: String, chapter_id: String)
signal chapter_completed(chapter_id: String)

func _ready() -> void:
	energy = ENERGY_MAX
	load_game()

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

# ---------- 关卡进度 ----------

# 查询某关卡是否已通关
func is_level_clear(level_id: String) -> bool:
	return levels_clear.get(level_id, false)

# 标记关卡通关：置位 → 发信号 → 整章通关则发章节信号 → 存档
func mark_level_clear(level_id: String, chapter_id: String) -> void:
	if is_level_clear(level_id):
		return
	levels_clear[level_id] = true
	level_cleared.emit(level_id, chapter_id)
	if is_chapter_complete(chapter_id):
		chapter_completed.emit(chapter_id)
	save_game()

# 查询章节是否全部通关
# 未在 CHAPTER_LEVELS 登记的章节视为已通关 (防止软锁)
func is_chapter_complete(chapter_id: String) -> bool:
	if not CHAPTER_LEVELS.has(chapter_id):
		return true
	for id: String in CHAPTER_LEVELS[chapter_id]:
		if not is_level_clear(id):
			return false
	return true

# 获取章节显示名 (未登记则返回章节ID)
func get_chapter_name(chapter_id: String) -> String:
	return str(CHAPTER_NAMES.get(chapter_id, chapter_id))

# ---------- 存档 ----------

# 将已通关关卡集合写入存档文件
func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "levels_clear", levels_clear)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("存档失败: %s" % error_string(err))

# 启动时读取存档 (文件不存在或损坏时保持空状态)
func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	levels_clear = config.get_value("progress", "levels_clear", {})

# 删除存档文件 (含物理文件删除)，清空内存中的通关记录。
# 返回是否成功删除 (文件原本不存在也算成功)。
func delete_save() -> bool:
	levels_clear.clear()
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		return err == OK or not FileAccess.file_exists(SAVE_PATH)
	return true

# 是否已存在存档文件
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
