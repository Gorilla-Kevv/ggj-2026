# ============================================================
# WindSystem — 风力系统 (核心玩法)
# 挂载于每个关卡场景的 Node2D 节点
# 处理鼠标输入 → 计算风向/强度 → 消耗能量 → 发出信号
# 需加入 "wind_system" 组供 Player 查找连接
# ============================================================
extends Node2D

# ---------- 风力参数 ----------
# MAX_WIND_FORCE:          最大风力 (牛顿，用于物理计算)
# RAMP_TIME:               长按达到满力的时间 (秒)
# MICRO_BURST_FORCE:       短点微风力度
# MICRO_BURST_THRESHOLD:   判定为"短点"的按住时间阈值 (秒)
const MAX_WIND_FORCE: float = 800.0
const RAMP_TIME: float = 6.0
const MICRO_BURST_FORCE: float = 200.0
const MICRO_BURST_THRESHOLD: float = 0.5

# ---------- 运行时状态 ----------
# is_blowing:         当前是否正在吹风
# blow_hold_time:     本次吹风已按住时长 (用于计算力度)
# mouse_was_pressed:  上一帧鼠标状态 (用于检测按下/释放边缘)
var is_blowing: bool = false
var blow_hold_time: float = 0.0
var mouse_was_pressed: bool = false

# ---------- 信号 ----------
# wind_started:  开始吹风 (按下瞬间)
# wind_updated:  持续吹风中 (每帧，携带当前强度和方向)
# wind_stopped:  停止吹风 (松开或能量耗尽)
# micro_burst:   短点微风 (按住时间 < MICRO_BURST_THRESHOLD)
signal wind_started(target: Node2D, direction: Vector2)
signal wind_updated(target: Node2D, direction: Vector2, strength: float)
signal wind_stopped()
signal micro_burst(target: Node2D, direction: Vector2)

func _ready() -> void:
	# 注册到组，供 Player 和其他节点查找
	add_to_group("wind_system")

# 主循环：检测鼠标状态变化 → 发射对应信号
func _process(delta: float) -> void:
	var global := get_node("/root/Global")

	# --- 不吹风时自动回复能量 ---
	if not is_blowing:
		global.regen_energy(delta)

	var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed := mouse_pressed and not mouse_was_pressed
	var just_released := not mouse_pressed and mouse_was_pressed
	mouse_was_pressed = mouse_pressed

	# --- 按下瞬间：开始吹风 ---
	if just_pressed:
		if global.selected_target == null:
			return
		if not global.has_energy():
			return
		is_blowing = true
		blow_hold_time = 0.0
		var direction := _get_wind_direction()
		wind_started.emit(global.selected_target, direction)

	# --- 按住中：持续吹风，累计力度，消耗能量 ---
	if is_blowing and mouse_pressed:
		blow_hold_time += delta
		if global.selected_target == null:
			_stop_wind()
			return
		global.drain_energy(delta)
		var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
		var direction := _get_wind_direction()
		wind_updated.emit(global.selected_target, direction, strength)
		# 交互物直接推 (Player 通过信号自行处理)
		if global.selected_target is BaseInteractable:
			global.selected_target.apply_wind_force(direction * MAX_WIND_FORCE * strength)
		if not global.has_energy():
			_stop_wind()

	# --- 松开瞬间：判断是否短点微风 → 停风 ---
	if just_released and is_blowing:
		if blow_hold_time < MICRO_BURST_THRESHOLD:
			micro_burst.emit(global.selected_target, _get_wind_direction())
			if global.selected_target is BaseInteractable:
				global.selected_target.apply_wind_force(_get_wind_direction() * MICRO_BURST_FORCE)
		_stop_wind()

# 内部：停止吹风，重置状态
func _stop_wind() -> void:
	is_blowing = false
	blow_hold_time = 0.0
	wind_stopped.emit()

# 计算风向单位向量：从鼠标位置指向选中目标
# 鼠标是风源，风从鼠标吹向目标
func _get_wind_direction() -> Vector2:
	var global := get_node("/root/Global")
	var mouse_pos := get_global_mouse_position()
	if global.selected_target == null:
		return Vector2.ZERO
	var target_pos: Vector2 = global.selected_target.global_position
	var diff := target_pos - mouse_pos
	if diff.length() < 1.0:
		return Vector2.ZERO
	return diff.normalized()

# 获取当前风力向量 (供外部直接查询，如环境机制)
func get_current_force() -> Vector2:
	var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
	return _get_wind_direction() * MAX_WIND_FORCE * strength
