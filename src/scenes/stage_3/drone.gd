# ============================================================
# Drone — 无人机 (第3关: 炽风峡谷)
# 继承 BaseEnemy，状态机:
#   PATROL:   围绕出生点左右的固定巡航 (patrol_range 单侧半宽)
#   CHASE:    侦测范围内发现玩家 → 正常追 + 周期性冲刺技能
#   STUNNED:  冲刺撞墙/撞到玩家后的停滞 (crash_stall_time)，结束后:
#             范围内仍有玩家 → 继续索敌冲撞；否则 → 回到巡航
# 即死碰撞: ContactArea.body_entered → player.die()
# 动画: AnimatedSprite2D fly / stun (占位贴图，可替换)
# 命名: ChargerDrone (与队友 xiaoyukuki 的扫描无人机 Drone 区分)
# ============================================================
extends BaseEnemy
class_name ChargerDrone

# ---------- 导出变量 (编辑器可调) ----------
@export var patrol_range: float = 140.0     # 巡航范围单侧半径 (px)
@export var detection_range: float = 620.0  # 索敌侦测半径 (大圆, px)
@export var patrol_speed: float = 70.0      # 巡航速度 (px/s)
@export var normal_chase_speed: float = 150.0  # 正常追速度 (明显低于玩家, 持续拉开距离) (px/s)
@export var chase_accel: float = 400.0      # 正常追加速度 (px/s^2)
@export var dash_speed: float = 400.0       # 冲刺最高速度 (略高于玩家最高速, 需配合走位躲) (px/s)
@export var dash_accel: float = 1200.0      # 冲刺加速度 (px/s^2)
@export var dash_interval: float = 2.2      # 两次冲刺的间隔 (秒)
@export var dash_duration: float = 0.55     # 单次冲刺持续时长 (秒)
@export var crash_stall_time: float = 0.9   # 撞后停滞时长 (秒)

# ---------- 子节点引用 ----------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ---------- 运行时状态 ----------
var _patrol_center: Vector2 = Vector2.ZERO
var _patrol_dir: float = -1.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_time_left: float = 0.0

func _ready() -> void:
	super._ready()
	_patrol_center = global_position
	_enter_state(State.PATROL)

# ---------- 侦测: 巡逻中发现玩家进入范围 → 冲撞 ----------
func _detect_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var in_range := global_position.distance_to(player.global_position) <= detection_range
	if in_range and current_state == State.PATROL:
		_enter_state(State.CHASE)

# ---------- AI 执行 ----------
func _execute_ai(_delta: float) -> void:
	match current_state:
		State.PATROL:
			_patrol()
		State.CHASE:
			_chase(_delta)
		_:
			velocity = Vector2.ZERO

# 左右固定巡航，超出巡逻半径则掉头
func _patrol() -> void:
	if _patrol_dir == 0.0:
		_patrol_dir = -1.0
	velocity.x = _patrol_dir * patrol_speed
	var dist := global_position.x - _patrol_center.x
	if absf(dist) >= patrol_range:
		_patrol_dir = -signf(dist)
		velocity.x = _patrol_dir * patrol_speed
	_flip_sprite(_patrol_dir < 0.0)

# 追击: 丢失目标/超出范围 → 回巡航；否则正常追 + 周期性冲刺技能
func _chase(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > detection_range:
		_enter_state(State.PATROL)
		return
	var dir: Vector2 = (player.global_position - global_position).normalized()

	if _is_dashing:
		# 冲刺中: 高速加速朝玩家 (撞墙则停滞)
		_dash_time_left -= delta
		velocity = velocity.move_toward(dir * dash_speed, dash_accel * delta)
		_flip_sprite(velocity.x < 0.0)
		if is_on_wall() or _dash_time_left <= 0.0:
			_end_dash()
			if is_on_wall():
				_crash()
		return

	# 正常追: 速度略低于玩家
	velocity = velocity.move_toward(dir * normal_chase_speed, chase_accel * delta)
	_flip_sprite(velocity.x < 0.0)
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_start_dash()

# 冲刺技能开始: 重置计时 (撞到玩家由 ContactArea 处理)
func _start_dash() -> void:
	_is_dashing = true
	_dash_time_left = dash_duration

# 冲刺结束: 进入下一轮间隔
func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = dash_interval

# 撞击停滞 (冲刺撞墙或撞到玩家)
func _crash() -> void:
	if current_state == State.STUNNED:
		return
	stun_timer.start(crash_stall_time)
	_enter_state(State.STUNNED)

# 停滞结束: 范围内仍有玩家 → 继续索敌冲撞；否则 → 回巡航
func _on_stun_timer_timeout() -> void:
	if current_state != State.STUNNED:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) <= detection_range:
		_enter_state(State.CHASE)
	else:
		_enter_state(State.PATROL)

# ---------- 即死碰撞 (撞到玩家 → 秒杀 + 停滞) ----------
func _on_contact_area_body_entered(body: Node2D) -> void:
	if current_state in [State.DEAD, State.STUNNED]:
		return
	if body.is_in_group("player"):
		_crash()
		body.die()

# ---------- 动画 ----------
func _flip_sprite(facing_left: bool) -> void:
	if animated_sprite:
		animated_sprite.flip_h = facing_left

func _play_anim(anim: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)

# ---------- 状态进入 ----------
func _on_state_entered(state: State) -> void:
	match state:
		State.PATROL:
			_is_dashing = false
			_play_anim("fly")
		State.CHASE:
			_is_dashing = false
			_dash_timer = dash_interval * 0.5   # 进场后半程出冲刺，尽快形成威胁
			_play_anim("fly")
		State.STUNNED:
			velocity = Vector2.ZERO
			_play_anim("stun")
		State.DEAD:
			_handle_death()
