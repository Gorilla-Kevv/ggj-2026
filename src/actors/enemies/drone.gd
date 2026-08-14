# ============================================================
# Drone — 追踪无人机 (第3关: 炽风峡谷)
# 间隔向下扫描：黄色光束区域 + RayCast2D 检测, 照到玩家即死
# 纯代码绘制扫描光束（无需美术素材）
# ============================================================
extends BaseEnemy
class_name Drone

enum ScanPhase { COOLDOWN, WARNING, ACTIVE }

@export var patrol_points: Array[Marker2D] = []
@export var scan_range: float = 1000.0
@export var scan_active_time: float = 1.0
@export var scan_cooldown_time: float = 2.0
@export var scan_warning_time: float = 0.5
@export var scan_beam_width: float = 180.0

@onready var ray_cast: RayCast2D = $RayCast2D
@onready var scan_timer: Timer = $ScanTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _patrol_index: int = 0
var _patrol_direction: int = 1
var _scan_phase: ScanPhase = ScanPhase.COOLDOWN
var _elapsed: float = 0.0
var _beam: float = 0.0

func _ready() -> void:
	super._ready()
	ray_cast.target_position = Vector2(0, scan_range)
	ray_cast.enabled = false
	scan_timer.wait_time = scan_cooldown_time
	scan_timer.start()
	scan_timer.timeout.connect(_advance_scan)
	_enter_state(State.PATROL)

func _advance_scan() -> void:
	match _scan_phase:
		ScanPhase.COOLDOWN:
			_scan_phase = ScanPhase.WARNING
			scan_timer.wait_time = scan_warning_time
		ScanPhase.WARNING:
			_scan_phase = ScanPhase.ACTIVE
			ray_cast.enabled = true
			scan_timer.wait_time = scan_active_time
		ScanPhase.ACTIVE:
			_scan_phase = ScanPhase.COOLDOWN
			ray_cast.enabled = false
			scan_timer.wait_time = scan_cooldown_time
	_elapsed = 0.0
	scan_timer.start()

func _detect_player() -> void:
	if _scan_phase != ScanPhase.ACTIVE or current_state != State.PATROL:
		return
	ray_cast.force_raycast_update()
	var hit := ray_cast.get_collider()
	if hit != null and hit.is_in_group("player"):
		hit.die()

func _execute_ai(delta: float) -> void:
	if current_state == State.PATROL:
		_patrol(delta)
	else:
		velocity = Vector2.ZERO

func _patrol(_delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	var target_pos: Vector2 = patrol_points[_patrol_index].global_position
	var dist: float = absf(target_pos.x - global_position.x)
	if dist < 4.0:
		_patrol_index += _patrol_direction
		if _patrol_index >= patrol_points.size():
			_patrol_direction = -1; _patrol_index = patrol_points.size() - 2
		elif _patrol_index < 0:
			_patrol_direction = 1; _patrol_index = 1
	else:
		velocity.x = (target_pos.x - global_position.x) / absf(target_pos.x - global_position.x) * move_speed
	velocity.y = 0.0

# ---------- 绘制扫描光束 ----------
func _process(_delta: float) -> void:
	if _scan_phase == ScanPhase.COOLDOWN:
		return
	_elapsed += _delta
	queue_redraw()

func _draw() -> void:
	if _scan_phase == ScanPhase.COOLDOWN:
		return

	var hw: float = scan_beam_width * 0.5
	var pct: float
	var alpha: float
	var col: Color

	match _scan_phase:
		ScanPhase.WARNING:
			pct = _elapsed / scan_warning_time
			alpha = 0.15 + sin(_elapsed * 20.0) * 0.1
			col = Color.YELLOW
			col.a = alpha
		ScanPhase.ACTIVE:
			pct = _elapsed / scan_active_time
			alpha = 0.35 + sin(_elapsed * 8.0) * 0.1
			col = Color(1.0, 0.9, 0.1, alpha)
	var body_top: float = -100.0   # 从无人机腹部开始发射
	var top_left := Vector2(-hw, body_top)
	var top_right := Vector2(hw, body_top)
	var bot_left := Vector2(-hw * 1.5, scan_range)
	var bot_right := Vector2(hw * 1.5, scan_range)
	draw_colored_polygon(PackedVector2Array([top_left, top_right, bot_right, bot_left]), col)
	draw_line(top_left, bot_left, Color.WHITE, 1.0)
	draw_line(top_right, bot_right, Color.WHITE, 1.0)

func _on_state_entered(state: BaseEnemy.State) -> void:
	match state:
		State.STUNNED:
			velocity = Vector2.ZERO
			die()
		State.DEAD:
			_handle_death()
