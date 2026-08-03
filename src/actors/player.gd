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
const GRAVITY_SCALE: float = 0.6
const MAX_SPEED: float = 600.0
const AIR_DRAG_VERTICAL: float = 0.992
const GROUND_FRICTION: float = 0.92
const GROUND_BOUNCE: float = 0.35
const WALL_BOUNCE: float = 0.4
const MIN_BOUNCE_VELOCITY: float = 30.0
const COLLISION_RADIUS: float = 20.0
const WIND_FORCE_MULTIPLIER: float = 0.5

# ---------- 子节点引用 ----------
# anim_player:       主动画控制器 (idle / rolling)
# sprite:            主角精灵 (碰撞回弹变形目标)
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D

# 发出死亡信号，供外部 (关卡管理/音效) 监听
signal player_died()
# 碰撞回弹信号 (碰撞点, 碰撞前速度, 反弹后速度)
signal player_bounced(collision_point: Vector2)

func _ready() -> void:
	# 注册到 "player" 组，供 TargetSelector / 敌人 / 检查点查找
	add_to_group("player")
	# 设置碰撞层：layer 1 供 Area2D (kill_zone/spike/checkpoint) 检测
	collision_layer = 1
	collision_mask = 1
	# 重生后定位到检查点
	_restore_checkpoint()
	_connect_wind_system()

# 从 Global 恢复检查点位置 (死亡重生/场景重载后调用)
func _restore_checkpoint() -> void:
	var global := get_node("/root/Global")
	if global.current_checkpoint != Vector2.ZERO:
		global_position = global.current_checkpoint
		global.refill_energy()
		_enter_idle()

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

var _was_on_floor: bool = false

# 每物理帧：上抛/平抛运动 + 落地弹跳滚动
func _physics_process(delta: float) -> void:
	var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE

	if not is_on_floor():
		# === 空中：抛物线运动 ===u
		# 竖直：重力加速 + 轻微空气阻力 (终端速度感)
		velocity.y += gravity * delta
		velocity.y *= AIR_DRAG_VERTICAL
		# 水平：惯性保持 (无摩擦，保留风的冲量)
	else:
		# === 地面：滚动 + 弹跳 ===
		if not _was_on_floor:
			# 刚落地：竖直反弹
			velocity.y = -abs(velocity.y) * GROUND_BOUNCE
			_play_bounce_squash(Vector2.UP)
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
		_play_bounce_squash(normal)
		player_bounced.emit(collision.get_position())
		break

# 碰撞回弹视觉：沿碰撞法线方向压扁精灵，再弹回原形
func _play_bounce_squash(normal: Vector2) -> void:
	if sprite == null:
		return
	# 将法线转换到精灵局部坐标
	var local_normal := normal.rotated(-global_rotation)
	var squash_scale := Vector2(
		1.0 - abs(local_normal.x) * 0.3,
		1.0 - abs(local_normal.y) * 0.3
	)
	var stretch_scale := Vector2(
		1.0 + abs(local_normal.y) * 0.2,
		1.0 + abs(local_normal.x) * 0.2
	)
	var target_scale := squash_scale * stretch_scale

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "scale", target_scale, 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)

# 施加风力冲量 (由 WindSystem 和 环境风带 调用)
func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

# ---------- 死亡与重生 ----------

# 死亡入口：由 kill_zone / spike / 敌人 调用
func die() -> void:
	player_died.emit()
	call_deferred("_respawn")

# 重生逻辑：切换/重载关卡，新场景的 _ready 中读取检查点位置
func _respawn() -> void:
	var global := get_node("/root/Global")
	if global.last_checkpoint_level != "" and global.last_checkpoint_level != get_tree().current_scene.scene_file_path:
		get_tree().change_scene_to_file(global.last_checkpoint_level)
	else:
		get_tree().reload_current_scene()
