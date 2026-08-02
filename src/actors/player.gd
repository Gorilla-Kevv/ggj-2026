# ============================================================
# Player — 风滚草主角
# CharacterBody2D，全程悬浮漂行，可着陆于地面
# 通过 WindSystem 信号接收风力推动
# 死亡条件：尖刺 / 敌人触碰 / 深渊
#
# 动画驱动：
#   AnimationPlayer  — 主动画 (idle / rolling 精灵帧)
#   BreatheParticles — 辅助粒子 (仅 idle 时发射呼吸粒子)
# ============================================================
extends CharacterBody2D

# ---------- 动画状态 ----------
enum AnimState { IDLE, ROLLING }
var current_anim: AnimState = AnimState.IDLE

# ---------- 物理参数 (可在编辑器中调整) ----------
# GRAVITY_SCALE:          重力缩放 (0.3 = 30% 正常重力，模拟轻盈飘浮)
# MAX_SPEED:              最大速度限制 (px/s)
# AIR_FRICTION:           空中摩擦系数 (每帧速度 *= 0.95)
# GROUND_FRICTION:        地面摩擦系数 (接地时水平速度 *= 0.7)
# COLLISION_RADIUS:       圆形碰撞体半径 (px)
# WIND_FORCE_MULTIPLIER:  风力→速度的转换系数 (调大 = 风更"猛")
const GRAVITY_SCALE: float = 0.3
const MAX_SPEED: float = 600.0
const AIR_FRICTION: float = 0.95
const GROUND_FRICTION: float = 0.7
const COLLISION_RADIUS: float = 20.0
const WIND_FORCE_MULTIPLIER: float = 0.2

# CO碰撞回弹参数 (可在编辑器中调整) ----------
# BOUNCE_FACTOR:           回弹系数 (0=不弹, 1=完全弹性，风滚草推荐 0.3~0.5)
# BOUNCE_MIN_SPEED:        触发回弹的最小速度 (px/s)，低于此值不弹
# BOUNCE_WALL_ONLY:        仅墙壁反弹 (true=地面不弹, false=所有碰撞都弹)
const BOUNCE_FACTOR: float = 0.35
const BOUNCE_MIN_SPEED: float = 50.0
const BOUNCE_WALL_ONLY: bool = true

# ---------- 子节点引用 ----------
# anim_player:       主动画控制器 (idle / rolling)
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# 发出死亡信号，供外部 (关卡管理/音效) 监听
signal player_died()
# 碰撞回弹信号 (碰撞点, 碰撞前速度, 反弹后速度)
signal player_bounced(collision_point: Vector2)

func _ready() -> void:
	# 注册到 "player" 组，供 TargetSelector / 敌人 / 检查点查找
	add_to_group("player")
	_connect_wind_system()

# 连接到场景中的 WindSystem 节点 (通过 "wind_system" 组查找)
func _connect_wind_system() -> void:
	var wind_system := get_tree().get_first_node_in_group("wind_system")
	if wind_system:
		wind_system.wind_updated.connect(_on_wind_updated)
		wind_system.micro_burst.connect(_on_micro_burst)
		wind_system.wind_started.connect(_on_wind_started)
		wind_system.wind_stopped.connect(_on_wind_stopped)

# ---------- 风力回调 ----------

# 当前风力强度缓存 (吹风时更新，风停后保留最后一次值供衰减参考)
var _last_wind_strength: float = 0.0
var _is_being_blown: bool = false

func _on_wind_started(_target: Node2D, _direction: Vector2) -> void:
	if _target == self:
		_is_being_blown = true
		_enter_rolling()

# 持续吹风回调：按住左键期间每帧触发
# target:    风作用的目标 (仅当 target == self 时才对自己生效)
# direction: 风向单位向量 (鼠标→目标)
# strength:  风力强度 [0.0, 1.0] (随按住时间递增)
func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	if target == self:
		var force := direction * 800.0 * strength * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)
		_last_wind_strength = strength

func _on_wind_stopped() -> void:
	# 风停后不再标记为吹风状态，动画速度交由 _process 根据 velocity 衰减
	_is_being_blown = false
	# 落地则回到 idle
	if is_on_floor():
		_enter_idle()

# 短点微风回调：松开左键时按住时间 < 阈值触发
func _on_micro_burst(target: Node2D, direction: Vector2) -> void:
	if target == self:
		var force := direction * 200.0 * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)
		_is_being_blown = false

# ---------- 动画状态切换 ----------

# 进入 idle 状态：播放 AnimationPlayer 的 "idle"
func _enter_idle() -> void:
	if current_anim == AnimState.IDLE:
		return
	current_anim = AnimState.IDLE
	if anim_player and anim_player.has_animation("idle"):
		anim_player.speed_scale = 1.0
		anim_player.play("idle")

# 进入 rolling 状态：播放 AnimationPlayer 的 "rolling"
func _enter_rolling() -> void:
	if current_anim == AnimState.ROLLING:
		return
	current_anim = AnimState.ROLLING
	if anim_player and anim_player.has_animation("rolling"):
		anim_player.play("rolling")

# ---------- 每帧视觉更新 ----------

# 根据当前速度实时调整 rolling 动画播放速度
# 吹风时：跟随风力强度 → 风停后：跟随 velocity 自然衰减 (受 AIR_FRICTION+重力影响)
func _process(_delta: float) -> void:
	if current_anim != AnimState.ROLLING or anim_player == null:
		return

	var speed_factor: float
	if _is_being_blown:
		# 吹风中：风力强度直接映射
		speed_factor = maxf(_last_wind_strength, 0.3)
	else:
		# 风停衰减：速度占比映射，随 friction 和重力自然降低
		speed_factor = clampf(velocity.length() / MAX_SPEED, 0.15, 1.0)

	anim_player.speed_scale = speed_factor

# ---------- 物理 ----------

# 每物理帧：施加重力、摩擦、限速、碰撞检测 + 墙壁回弹
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		# 空中：轻重力 + 空气阻力缓慢减速
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE * delta
		velocity *= AIR_FRICTION
	else:
		# 地面：仅水平方向受地面摩擦 (可着陆不死亡)
		velocity.x *= GROUND_FRICTION
	velocity = velocity.limit_length(MAX_SPEED)
	move_and_slide()
	_handle_bounce()

	# 落地且未被吹 → 回到 idle
	if is_on_floor() and current_anim == AnimState.ROLLING:
		var wind_system := get_tree().get_first_node_in_group("wind_system")
		if wind_system == null or not wind_system.is_blowing:
			_enter_idle()

# 碰撞回弹：检测 move_and_slide 后的碰撞，速度足够时沿法线反弹
func _handle_bounce() -> void:
	var collision_count := get_slide_collision_count()
	if collision_count == 0:
		return

	for i in range(collision_count):
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()

		# 仅墙壁反弹模式下跳过地面/天花板碰撞
		if BOUNCE_WALL_ONLY and abs(normal.x) < 0.5:
			continue

		var speed := velocity.length()
		if speed < BOUNCE_MIN_SPEED:
			continue

		# 沿法线反射速度 + 弹性系数
		var reflected := velocity.bounce(normal) * BOUNCE_FACTOR
		velocity = reflected
		player_bounced.emit(collision.get_position())
		break

# 施加风力冲量 (由 WindSystem 和 环境风带 调用)
func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

# ---------- 死亡与重生 ----------

# 死亡入口：由 kill_zone / spike / 敌人 调用
func die() -> void:
	player_died.emit()
	call_deferred("_respawn")

# 重生逻辑：重载检查点所在关卡，传送到检查点位置，能量回满
func _respawn() -> void:
	var global := get_node("/root/Global")
	if global.last_checkpoint_level != "":
		get_tree().change_scene_to_file(global.last_checkpoint_level)
	else:
		get_tree().reload_current_scene()
	await get_tree().process_frame
	global_position = global.current_checkpoint
	global.refill_energy()
	_enter_idle()
