# ============================================================
# Player — 风滚草主角
# CharacterBody2D，全程悬浮漂行，可着陆于地面
# 通过 WindSystem 信号接收风力推动
# 死亡条件：尖刺 / 敌人触碰 / 深渊
# ============================================================
extends CharacterBody2D

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

# 发出死亡信号，供外部 (关卡管理/音效) 监听
signal player_died()

func _ready() -> void:
	# 注册到 "player" 组，供 TargetSelector / 敌人 / 检查点查找
	add_to_group("player")
	# 动态创建圆形碰撞体
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	$CollisionShape2D.shape = shape
	_connect_wind_system()

# 连接到场景中的 WindSystem 节点 (通过 "wind_system" 组查找)
func _connect_wind_system() -> void:
	var wind_system := get_tree().get_first_node_in_group("wind_system")
	if wind_system:
		wind_system.wind_updated.connect(_on_wind_updated)
		wind_system.micro_burst.connect(_on_micro_burst)

# 持续吹风回调：按住左键期间每帧触发
# target:    风作用的目标 (仅当 target == self 时才对自己生效)
# direction: 风向单位向量 (鼠标→目标)
# strength:  风力强度 [0.0, 1.0] (随按住时间递增)
func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	if target == self:
		var force := direction * 800.0 * strength * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)

# 短点微风回调：松开左键时按住时间 < 阈值触发
func _on_micro_burst(target: Node2D, direction: Vector2) -> void:
	if target == self:
		var force := direction * 200.0 * WIND_FORCE_MULTIPLIER
		apply_wind_force(force)

# 每物理帧：施加重力、摩擦、限速、碰撞检测
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

# 施加风力冲量 (由 WindSystem 和 环境风带 调用)
func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

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
