# ============================================================
# BaseEnemy — 敌人基类
# 子类自行决定侦测方式 (RayCast2D / Area2D)
# 状态机: IDLE → PATROL → CHASE → ATTACK → STUNNED / DEAD
# 即死碰撞: ContactArea.body_entered → player.die()
# 眩晕:     外部调用 stun(duration)，由交互物触发
# ============================================================
extends CharacterBody2D
class_name BaseEnemy

# ---------- 状态枚举 ----------
enum State { IDLE, PATROL, CHASE, ATTACK, STUNNED, DEAD }

# ---------- 导出变量 (子类/编辑器可调) ----------
@export var move_speed: float = 80.0
@export var chase_speed: float = 120.0
@export var stun_duration: float = 2.0

# ---------- 运行时状态 ----------
var current_state: State = State.IDLE

# ---------- 子节点引用 ----------
@onready var stun_timer: Timer = $StunTimer
@onready var contact_area: Area2D = $ContactArea

# ---------- 信号 ----------
# state_changed: 状态变化时触发 (old_state, new_state)
# enemy_died:    死亡时触发 (供关卡/音效监听)
signal state_changed(old_state: State, new_state: State)
signal enemy_died()

func _ready() -> void:
	# 连接即死碰撞
	contact_area.body_entered.connect(_on_contact_area_body_entered)
	# 启动眩晕计时器
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	# 初始状态
	_enter_state(State.IDLE)

# ---------- 即死碰撞 ----------
func _on_contact_area_body_entered(body: Node2D) -> void:
	if current_state == State.DEAD or current_state == State.STUNNED:
		return
	if body.is_in_group("player"):
		body.die()

# ---------- 眩晕 ----------
# 外部调用：程序C的交互物碰撞到敌人时触发
func stun(duration: float = -1.0) -> void:
	if current_state == State.DEAD:
		return
	var d := duration if duration > 0.0 else stun_duration
	stun_timer.start(d)
	_enter_state(State.STUNNED)

func _on_stun_timer_timeout() -> void:
	if current_state == State.STUNNED:
		# 眩晕结束，回到 IDLE (子类可覆盖为回到巡逻)
		_enter_state(State.IDLE)

# ---------- 死亡 ----------
func die() -> void:
	if current_state == State.DEAD:
		return
	_enter_state(State.DEAD)
	enemy_died.emit()
	queue_free()

# ---------- 状态机 ----------
func _enter_state(new_state: State) -> void:
	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	_on_state_entered(new_state)

# 子类覆盖以处理状态进入逻辑
func _on_state_entered(state: State) -> void:
	match state:
		State.IDLE:
			pass
		State.PATROL:
			pass
		State.CHASE:
			pass
		State.ATTACK:
			pass
		State.STUNNED:
			pass
		State.DEAD:
			_handle_death()

func _handle_death() -> void:
	# 禁用碰撞 + 视觉
	contact_area.set_deferred("monitoring", false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	set_process(false)

# ---------- 每帧物理 (子类覆盖) ----------
func _physics_process(delta: float) -> void:
	if current_state in [State.DEAD, State.STUNNED]:
		return
	_update_ai(delta)
	move_and_slide()

# AI part
func _update_ai(_delta: float) -> void:
	pass
