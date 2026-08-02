# ============================================================
# Player — 风滚草主角
# CharacterBody2D，全程悬浮漂行，可着陆于地面
# 通过 WindSystem 信号接收风力推动
# 死亡条件：尖刺 / 敌人触碰 / 深渊
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
const GRAVITY_SCALE: float = 0.1
const MAX_SPEED: float = 600.0
const AIR_FRICTION: float = 0.95
const GROUND_FRICTION: float = 0.7
const COLLISION_RADIUS: float = 20.0
const WIND_FORCE_MULTIPLIER: float = 0.2

# ---------- 动画参数 ----------
# ROLLING_SPIN_SPEED:  空中旋转速度 (弧度/秒，风滚草翻滚)
# IDLE_BREATHE_SCALE:  地面呼吸缩放幅度
# IDLE_BREATHE_SPEED:  地面呼吸频率 (周期/秒)
const ROLLING_SPIN_SPEED: float = 8.0
const IDLE_BREATHE_SCALE: float = 0.05
const IDLE_BREATHE_SPEED: float = 2.0

# ---------- 子节点引用 ----------
# sprite:         主角精灵 (占位用 Sprite2D，后续替换为 AnimatedSprite2D)
# breathe_particles: 地面呼吸粒子 (CPUParticles2D)
var sprite: Node2D = null
var breathe_particles: CPUParticles2D = null

# 发出死亡信号，供外部 (关卡管理/音效) 监听
signal player_died()

func _ready() -> void:
	# 注册到 "player" 组，供 TargetSelector / 敌人 / 检查点查找
	add_to_group("player")
	# 动态创建圆形碰撞体
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	$CollisionShape2D.shape = shape
	# 获取子节点引用
	_setup_nodes()
	_connect_wind_system()

# 获取并初始化所有子节点引用
func _setup_nodes() -> void:
	sprite = $Sprite2D
	breathe_particles = $BreatheParticles
	if breathe_particles:
		breathe_particles.emitting = false

# 连接到场景中的 WindSystem 节点 (通过 "wind_system" 组查找)
func _connect_wind_system() -> void:
	var wind_system := get_tree().get_first_node_in_group("wind_system")
	if wind_system:
		wind_system.wind_updated.connect(_on_wind_updated)
		wind_system.micro_burst.connect(_on_micro_burst)
		wind_system.wind_started.connect(_on_wind_started)
		wind_system.wind_stopped.connect(_on_wind_stopped)

# ---------- 风力回调 ----------

func _on_wind_started(_target: Node2D, _direction: Vector2) -> void:
	if _target == self:
		_enter_rolling()

# 持续吹风回调：按住左键期间每帧触发
func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	if target == self:
		var force := direction * 800.0 * strength * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)
		# 风力强度影响旋转速度
		_update_rolling_speed(strength)

func _on_wind_stopped() -> void:
	# 风停后如果落地则回到 idle
	if is_on_floor():
		_enter_idle()

# 短点微风回调
func _on_micro_burst(target: Node2D, direction: Vector2) -> void:
	if target == self:
		var force := direction * 200.0 * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)

# ---------- 动画状态切换 ----------

# 进入 idle 状态：地面呼吸
func _enter_idle() -> void:
	if current_anim == AnimState.IDLE:
		return
	current_anim = AnimState.IDLE
	if breathe_particles:
		breathe_particles.emitting = true

# 进入 rolling 状态：空中翻滚
func _enter_rolling() -> void:
	if current_anim == AnimState.ROLLING:
		return
	current_anim = AnimState.ROLLING
	if breathe_particles:
		breathe_particles.emitting = false

# 根据风力强度调整翻滚速度
func _update_rolling_speed(strength: float) -> void:
	if sprite == null:
		return
	var spin := ROLLING_SPIN_SPEED * maxf(strength, 0.2)
	sprite.rotation += spin * get_process_delta_time()

# ---------- 每帧视觉更新 ----------

func _process(_delta: float) -> void:
	match current_anim:
		AnimState.IDLE:
			_update_idle_visual(_delta)
		AnimState.ROLLING:
			_update_rolling_visual(_delta)

# idle 呼吸动画：缩放微微脉动，模拟呼吸感
func _update_idle_visual(delta: float) -> void:
	if sprite == null:
		return
	var breathe := sin(Time.get_ticks_msec() * 0.001 * PI * IDLE_BREATHE_SPEED)
	sprite.scale = Vector2.ONE * (1.0 + breathe * IDLE_BREATHE_SCALE)

# rolling 动画：持续旋转 (基础旋转 + 风强驱动在 _update_rolling_speed 中)
func _update_rolling_visual(delta: float) -> void:
	if sprite == null:
		return
	# 空中基础慢转，风力驱动的高速旋转在 wind_updated 回调中处理
	sprite.rotation += ROLLING_SPIN_SPEED * 0.3 * delta

# ---------- 物理 ----------

# 每物理帧：施加重力、摩擦、限速、碰撞检测
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE * delta
		velocity *= AIR_FRICTION
	else:
		velocity.x *= GROUND_FRICTION
	velocity = velocity.limit_length(MAX_SPEED)
	move_and_slide()

	# 落地且未被吹 → 回到 idle
	if is_on_floor() and current_anim == AnimState.ROLLING:
		var wind_system := get_tree().get_first_node_in_group("wind_system")
		if wind_system == null or not wind_system.is_blowing:
			_enter_idle()

# 施加风力冲量 (由 WindSystem 和 环境风带 调用)
func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

# ---------- 死亡与重生 ----------

func die() -> void:
	player_died.emit()
	call_deferred("_respawn")

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
