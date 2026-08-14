# ============================================================
# Settings — 游戏设置单例 (Autoload)
# 存储玩家物理、风力、音乐音效三类可调参数
# 通过 /root/Settings 访问；设置场景读写，存档到 user://settings.cfg
# 默认值 = 当前各脚本的 const 值，保证未调整时游戏行为不变
# ============================================================
extends Node

const SAVE_PATH := "user://settings.cfg"

# ---------- 玩家物理 ----------
var gravity_scale: float = 0.1          # 重力缩放
var max_speed: float = 1000.0           # 最大速度 (px/s)
var ground_friction: float = 0.8        # 地面摩擦
var ground_bounce: float = 0.5          # 地面弹跳
var wall_bounce: float = 0.95           # 墙壁反弹
var key_move_force: float = 200.0       # A/D 移动力

# ---------- 风力 ----------
var max_wind_force: float = 400.0       # 最大风力
var wind_ramp_time: float = 3.5         # 蓄力到满力时间 (秒)
var energy_drain: float = 4.0           # 吹风能量消耗
var energy_regen: float = 1.0           # 能量回复

# ---------- 音乐音效 ----------
var master_volume_db: float = 0.0       # 总音量 (分贝)
var music_volume_db: float = -10.0      # 音乐音量 (分贝)
var sfx_volume_db: float = -6.0         # 音效音量 (分贝)

# 默认值表 (恢复默认用)
const DEFAULT_VALUES: Dictionary = {
	"gravity_scale": 0.1,
	"max_speed": 1000.0,
	"ground_friction": 0.8,
	"ground_bounce": 0.5,
	"wall_bounce": 0.95,
	"key_move_force": 200.0,
	"max_wind_force": 400.0,
	"wind_ramp_time": 3.5,
	"energy_drain": 4.0,
	"energy_regen": 1.0,
	"master_volume_db": 0.0,
	"music_volume_db": -10.0,
	"sfx_volume_db": -6.0,
}

# 设置变化信号 (参数名, 新值)
signal setting_changed(key: String, value: float)

func _ready() -> void:
	load_settings()

# ---------- 读写 ----------

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in _all_keys():
		if config.has_section_key("settings", key):
			set(key, config.get_value("settings", key))

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in _all_keys():
		config.set_value("settings", key, get(key))
	config.save(SAVE_PATH)

func _all_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in DEFAULT_VALUES.keys():
		keys.append(key)
	return keys

# 设置某参数并广播信号
func set_param(key: String, value: float) -> void:
	if not (key in _all_keys()):
		return
	set(key, value)
	setting_changed.emit(key, value)

# 恢复所有参数为默认值并广播信号
func reset_all() -> void:
	for key in _all_keys():
		set(key, DEFAULT_VALUES[key])
		setting_changed.emit(key, DEFAULT_VALUES[key])
