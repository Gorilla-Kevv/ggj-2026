# ============================================================
# Player — 风滚草主角
# CharacterBody2D，全程悬浮漂行，可着陆于地面
# 通过 WindSystem 信号接收风力推动
# 死亡条件：尖刺 / 敌人触碰 / 深渊
#
# 动画驱动：AnimatedSprite2D (idle / rolling / die / underattack)
# ============================================================
extends CharacterBody2D

# ---------- 动画状态 ----------
enum AnimState { IDLE, ROLLING }
var current_anim: AnimState = AnimState.IDLE
# 死亡一次性守卫：子弹/接触点可能同时触发多次 die()，防止重复启动重生协程
var _is_dead: bool = false

# ---------- 物理参数 (可在编辑器中调整) ----------
# 空中运动遵循上抛/平抛物理：水平速度惯性保持，仅垂直受重力+轻微空气阻力
# 落地后弹跳并滚动，受摩擦力和重力逐渐减速直至停止
#
# GRAVITY_SCALE:          重力缩放 (1.0=标准重力，抛物线弧)
# MAX_SPEED:              最大速度限制 (px/s)
# AIR_DRAG_VERTICAL:      空中竖直空气阻力 (每帧 *= 0.992，产生终端速度感)
# GROUND_FRICTION:        地面滚动摩擦 (每帧水平速度 *= 0.92)
# GROUND_BOUNCE:          落地竖直反弹系数 (0.35=弹起35%高度)
# WALL_BOUNCE:            墙壁反弹系数
# MIN_BOUNCE_VELOCITY:    低于此竖直速度停止弹跳 (px/s)
# COLLISION_RADIUS:       圆形碰撞体半径 (px)
# WIND_FORCE_MULTIPLIER:  风力→速度的转换系数
const GRAVITY_SCALE: float = 0.1
const MAX_SPEED: float = 1000.0
const AIR_DRAG_VERTICAL: float = 0.992
const GROUND_FRICTION: float = 0.2
const GROUND_BOUNCE: float = 0.7
const WALL_BOUNCE: float = 1.2
const MIN_BOUNCE_VELOCITY: float = 5.0
const COLLISION_RADIUS: float = 20.0
const WIND_FORCE_MULTIPLIER: float = 0.5
# KEY_MOVE_FORCE:          A/D 键左右移动力度 (px/s)
const KEY_MOVE_FORCE: float = 200.0
# MAX_MANUAL_SPEED:        手动吹风/操控可达到的沿风向速度上限 (px/s)。
#                          防止玩家单靠左键无限加速绕过机关；环境风/回弹等物理冲量可超过此值。
const MAX_MANUAL_SPEED: float = 350.0
# MANUAL_WIND_ACCEL:       手动吹风推动速率 (px/s²)，等效原 move_toward 的 accel*MAX_SPEED
#                          与 strength 解耦 (初按即满速响应)，只作用于沿风向分量 (热风偏航不受影响)
const MANUAL_WIND_ACCEL: float = 8000.0

# 第3关热风火花场景：飞行时前方擦出橙红火星，合理化"热区=飞得慢但凝汽回得快"的设定
const FIRE_SPARKS_SCENE: PackedScene = preload("res://src/effects/stage3_fire_sparks.tscn")
const STAGE_3_PATH: String = "res://src/scenes/stage_3/stage_3.tscn"

# ---------- 子节点引用 ----------
# animated_sprite:         AnimatedSprite2D 动画 (idle / rolling / die / underattack)
# trail_particles:         风迹线粒子 (拖尾跟随运动方向)
# trail_material:           粒子材质缓存 (避免每帧 cast)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trail_particles: GPUParticles2D = $windline_particles_player
@onready var trail_material: ParticleProcessMaterial = null
var _spark_particles: GPUParticles2D = null
var _in_stage_3: bool = false

# 发出死亡信号，供外部 (关卡管理/音效) 监听
signal player_died()
# 碰撞回弹信号 (碰撞点, 碰撞前速度, 反弹后速度)
signal player_bounced(collision_point: Vector2)

func _ready() -> void:
	# 注册到 "player" 组，供 TargetSelector / 敌人 / 检查点查找
	add_to_group("player")
	# 缓存粒子材质引用
	if trail_particles and trail_particles.process_material is ParticleProcessMaterial:
		trail_material = trail_particles.process_material as ParticleProcessMaterial
	# 重生后定位到检查点
	_restore_checkpoint()
	_connect_wind_system()
	# 第3关: 悬挂热风火花发射器 (仅该关生效)
	_in_stage_3 = _is_stage_3()
	if _in_stage_3:
		_spark_particles = FIRE_SPARKS_SCENE.instantiate()
		add_child(_spark_particles)

# 从 Global 恢复检查点位置 (死亡重生/场景重载后调用)
func _restore_checkpoint() -> void:
	var global := get_node("/root/Global")
	# 任何重生都回满能量 (无检查点数据时也要回满)
	global.refill_energy()
	if global.current_checkpoint != Vector2.ZERO:
		global_position = global.current_checkpoint
		print("[Player] 重生到检查点 坐标=", global.current_checkpoint)
		_enter_idle()
	elif global.hub_return != Vector2.ZERO and get_tree().current_scene.scene_file_path == global.HUB_SCENE:
		global_position = global.hub_return
		global.hub_return = Vector2.ZERO
		_enter_idle()
	else:
		print("[Player] 无检查点数据，留在默认出生位 坐标=", global_position)

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
		# 飞行音效
		var audio := get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("sfx_fly"):
			audio.sfx_fly()

# 持续吹风回调：只推动"沿风向"分量，保留垂直分量，确保与热风/环境风叠加生效
# target:    风作用的目标 (仅当 target == self 时才对自己生效)
# direction: 风向单位向量 (鼠标→目标)
# strength:  风力强度 [0.0, 1.0] (随按住时间递增)
func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	if target != self:
		return
	_last_wind_strength = strength

	# 沿风向分量朝 target_along 以 MANUAL_WIND_ACCEL 速率逼近 (等效原 move_toward，
	# 速率足够大才能在每帧 *0.2 的地面摩擦下推得动)；垂直分量完全不动，
	# 因此手动吹风不会吸收热风的偏航，热风照常把玩家吹偏航/加速。
	# 速率与 strength 解耦：初按即是满速响应 (起手灵敏)，strength 只决定目标速度。
	var along: float = velocity.dot(direction)
	var target_along := MAX_MANUAL_SPEED * strength
	var rate := MANUAL_WIND_ACCEL * (0.5 if is_on_floor() else 1.0) * get_physics_process_delta_time()
	var step := clampf(target_along - along, -rate, rate)
	velocity += direction * step

func _on_wind_stopped() -> void:
	# 风停后不再标记为吹风状态，动画速度交由 _process 根据 velocity 衰减
	_is_being_blown = false
	# 落地则回到 idle
	if is_on_floor():
		_enter_idle()

# 短点微风回调：给一个瞬时速度冲量
func _on_micro_burst(target: Node2D, direction: Vector2) -> void:
	if target == self:
		velocity += direction * 200.0
		velocity = velocity.limit_length(MAX_SPEED)
		_is_being_blown = false

# ---------- 动画状态切换 ----------

# 进入 idle 状态
func _enter_idle() -> void:
	if current_anim == AnimState.IDLE:
		return
	current_anim = AnimState.IDLE
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")

# 进入 rolling 状态
func _enter_rolling() -> void:
	if current_anim == AnimState.ROLLING:
		return
	current_anim = AnimState.ROLLING
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("rolling"):
		animated_sprite.play("rolling")

# 播放一次 die 动画，播完后重生 (最多等 1.5 秒保底)
func _play_die_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("die"):
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("die")
		# 等待动画自然播完，超时 1.5 秒强制重生
		var timeout := get_tree().create_timer(1.5)
		await _wait_for_animation_or_timeout(timeout)
	_respawn()

# 等待动画结束或超时
func _wait_for_animation_or_timeout(timeout: SceneTreeTimer) -> void:
	while is_instance_valid(animated_sprite) and animated_sprite.is_playing() and timeout.time_left > 0:
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame

# 播放受击动画 (供敌人/机关调用)
func play_underattack() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("underattack"):
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("underattack")

# ---------- 每帧视觉更新 ----------

# 根据当前速度实时调整 rolling 动画播放速度
# 吹风时：跟随风力强度 → 风停后：跟随 velocity 自然衰减
# 同时驱动风迹线粒子跟随运动方向
func _process(_delta: float) -> void:
	_update_trail()
	_update_sparks()

	if current_anim != AnimState.ROLLING or animated_sprite == null:
		return

	var speed_factor: float
	if _is_being_blown:
		# 吹风中：风力强度直接映射
		speed_factor = maxf(_last_wind_strength, 0.3)
	else:
		# 风停衰减：速度占比映射，随 friction 和重力自然降低
		speed_factor = clampf(velocity.length() / MAX_SPEED, 0.15, 1.0)

	animated_sprite.speed_scale = speed_factor

# 风迹线粒子：速度超过阈值时发射，方向与运动方向相反 (拖尾效果)
func _update_trail() -> void:
	if trail_particles == null:
		return

	var speed := velocity.length()
	if speed < 10.0:
		trail_particles.emitting = false
		return

	trail_particles.emitting = true
	trail_particles.amount = clampi(int(speed / 15.0), 4, 32)

	if trail_material:
		var dir_2d := -velocity.normalized()
		trail_material.direction = Vector3(dir_2d.x, dir_2d.y, 0.0)
		trail_material.initial_velocity_min = speed * 0.35
		trail_material.initial_velocity_max = speed * 0.7

# 第3关热风火花：飞行 (速度超过阈值) 时紧盯运动方向，在"前方"边缘抛出向后溅射的火星。
# 顶点距球心 COLLISION_RADIUS+6px，随速度越快火花越多越密。
func _update_sparks() -> void:
	if _spark_particles == null:
		return
	var speed := velocity.length()
	if speed < 120.0:
		_spark_particles.emitting = false
		return
	_spark_particles.emitting = true
	_spark_particles.rotation = velocity.angle()
	_spark_particles.position = Vector2(COLLISION_RADIUS + 6.0, 0.0)
	_spark_particles.amount = clampi(int(speed / 40.0), 4, 12)

# 关卡判断: 是否第3关 (逐帧按当前场景判定，换关自动失效)
func _is_stage_3() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == STAGE_3_PATH

# 关卡移动速度倍率: 第3关操控速度减半，其他关不变
func _get_movement_multiplier() -> float:
	return 0.5 if _is_stage_3() else 1.0

# ---------- 物理 ----------

var _was_on_floor: bool = false

# 每物理帧：上抛/平抛运动 + 落地弹跳滚动
func _physics_process(delta: float) -> void:
	# A/D 键左右移动 (手动速度受 MAX_MANUAL_SPEED 限制；风向/物理冲量不受此限)
	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0.0:
		var can_accel: bool = (input_dir > 0.0 and velocity.x < MAX_MANUAL_SPEED) or (input_dir < 0.0 and velocity.x > -MAX_MANUAL_SPEED)
		if can_accel:
			velocity.x += input_dir * KEY_MOVE_FORCE * _get_movement_multiplier() * delta

	var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE

	if not is_on_floor():
		# === 空中：抛物线运动 ===
		# 竖直：重力加速 + 轻微空气阻力 (终端速度感)
		velocity.y += gravity * delta
		velocity.y *= AIR_DRAG_VERTICAL
		# 水平：惯性保持 (无摩擦，保留风的冲量)
	else:
		# === 地面：滚动 + 弹跳 ===
		if not _was_on_floor:
			# 刚落地：竖直反弹
			velocity.y = -abs(velocity.y) * GROUND_BOUNCE
		elif abs(velocity.y) > MIN_BOUNCE_VELOCITY:
			# 持续弹跳中：每帧反弹 (模拟多次小弹跳)
			velocity.y = -abs(velocity.y) * GROUND_BOUNCE
		else:
			# 弹跳结束：贴地
			velocity.y = 0.0

		# 水平：滚动摩擦减速
		velocity.x *= GROUND_FRICTION

	velocity = velocity.limit_length(MAX_SPEED)
	move_and_slide()
	_handle_wall_bounce()

	_was_on_floor = is_on_floor()

	# 落地静止 → idle
	if is_on_floor() and abs(velocity.x) < 10.0 and abs(velocity.y) < MIN_BOUNCE_VELOCITY:
		var wind_system := get_tree().get_first_node_in_group("wind_system")
		if wind_system == null or not wind_system.is_blowing:
			if current_anim == AnimState.ROLLING:
				_enter_idle()

# 墙壁反弹：仅侧向碰撞 (normal.x 显著)，不影响地面弹跳
func _handle_wall_bounce() -> void:
	var collision_count := get_slide_collision_count()
	if collision_count == 0:
		return

	for i in range(collision_count):
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()

		# 仅处理墙壁碰撞 (法线接近水平)
		if abs(normal.x) < 0.7:
			continue

		var speed := velocity.length()
		if speed < 30.0:
			continue

		velocity = velocity.bounce(normal) * WALL_BOUNCE
		player_bounced.emit(collision.get_position())
		break

# 施加风力冲量 (由 WindSystem 和 环境风带 调用)
func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

# 强击退：绕过速度上限，用于 Boss 弹开等强力击退
func apply_knockback(force: Vector2) -> void:
	velocity += force

# ---------- 死亡与重生 ----------

# 死亡入口：由 kill_zone / spike / 敌人 调用 (防重入：子弹+接触点可能同时触发)
func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	print("[Player] 死亡触发")
	# 停止音乐 + 死亡音效
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("stop_music"):
		audio.stop_music()
	if audio and audio.has_method("sfx_player_dead"):
		audio.sfx_player_dead()
	# 强制镜头锁定玩家
	var global := get_node("/root/Global")
	global.selected_target = self
	player_died.emit()
	set_physics_process(false)
	_play_die_animation()

# 重生逻辑：切换/重载关卡，新场景的 _ready 中读取检查点位置
func _respawn() -> void:
	var global := get_node("/root/Global")
	print("[Player] _respawn 关卡=", global.last_checkpoint_level)
	if global.last_checkpoint_level != "" and global.last_checkpoint_level != get_tree().current_scene.scene_file_path:
		print("[Player] 切换场景到 ", global.last_checkpoint_level)
		get_tree().change_scene_to_file(global.last_checkpoint_level)
	else:
		print("[Player] 重载当前场景")
		get_tree().reload_current_scene()
