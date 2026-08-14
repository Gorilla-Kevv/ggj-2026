# ============================================================
# WindTrailSystem — 可交互物体风迹粒子跟踪系统 (系统 2)
# Autoload 单例：自动扫描 "interactable" 组，
# 为每个 RigidBody2D 或旋转的风车臂 (Node2D) 挂载速度驱动、
# 体积自适应的风迹拖尾粒子。背景风场 (系统 1) 暂缓。
# ============================================================
extends Node

const TRAIL_SCENE: PackedScene = preload("res://src/scenes/wind_trail_object.tscn")

# ---------- 可调参数 ----------
# trail_speed_threshold:   物体速度高于该值才发射拖尾 (px/s)
# reference_volume:        体积归一化基准 (px²)，等于基准物体的碰撞面积
# base_amount:             基准物体 (体积=reference_volume) 的粒子数量
# base_box_extents:        基准发射盒尺寸
# base_scale:              基准粒子缩放
# base_trail_lifetime:     基准拖尾时长
# scan_interval:           动态物体重扫间隔 (秒)，捕获运行中新增的可交互物体
@export var trail_speed_threshold: float = 30.0
@export var reference_volume: float = 10000.0
@export var base_amount: int = 18
@export var base_box_extents: Vector3 = Vector3(70, 70, 1)
@export var base_scale: float = 0.5
@export var base_trail_lifetime: float = 0.62
@export var scan_interval: float = 0.5

# ---------- 运行时状态 ----------
# _trails:            body -> 拖尾 GPUParticles2D
# _materials:         body -> 拖尾 ParticleProcessMaterial (独立实例)
# _rotation_parents:  旋转臂 (Node2D) -> 其旋转平台父节点 (含 angular_velocity)
var _trails: Dictionary = {}
var _materials: Dictionary = {}
var _rotation_parents: Dictionary = {}
var _scan_timer: float = 0.0
var _last_scene: Node = null

func _ready() -> void:
	_last_scene = get_tree().current_scene
	_scan_and_mount()

func _process(delta: float) -> void:
	# 场景切换 → 清理重建
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_clear_all()
		_scan_and_mount()

	# 周期性重扫，捕获运行中动态生成的可交互物体 (如 boss 战的投掷巨石)
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_scan_and_mount()

	_update_trails()

# 扫描 interactable 组，为每个 RigidBody2D 或旋转臂 (Node2D) 挂载拖尾 (幂等)
func _scan_and_mount() -> void:
	for body in get_tree().get_nodes_in_group("interactable"):
		if _trails.has(body):
			continue
		if body is RigidBody2D:
			_mount_trail(body as Node2D)
		elif body is Node2D:
			var parent := _find_rotation_parent(body as Node2D)
			if parent != null:
				_mount_trail(body as Node2D)
				_rotation_parents[body] = parent

# 判断 Node2D 是否是旋转的风车臂 (父节点在 "windmill" 组)
func _find_rotation_parent(body: Node2D) -> Node2D:
	var p := body.get_parent()
	if p is Node2D and p.is_in_group("windmill"):
		return p as Node2D
	return null

# 为单个物体挂载拖尾，并按体积等比缩放
func _mount_trail(body: Node2D) -> void:
	var emitter: GPUParticles2D = TRAIL_SCENE.instantiate()
	body.add_child(emitter)
	emitter.position = Vector2.ZERO
	emitter.emitting = false

	var mat := emitter.process_material as ParticleProcessMaterial
	if mat == null:
		emitter.queue_free()
		return
	var k := _linear_scale(body)

	# 体积自适应：发射盒、粒子缩放、数量、拖尾长度等比缩放
	mat.emission_box_extents = base_box_extents * k
	mat.scale_min = base_scale * k
	mat.scale_max = base_scale * 1.5 * k
	emitter.amount = clampi(int(base_amount * k * k), 4, 64)
	emitter.trail_lifetime = clampf(base_trail_lifetime * k, 0.3, 1.5)

	_trails[body] = emitter
	_materials[body] = mat

# 线性尺寸缩放因子 = sqrt(面积 / 基准体积)
func _linear_scale(body: Node2D) -> float:
	return sqrt(_compute_area(body) / reference_volume)

# 估算物体体积 (碰撞形状面积，含形状节点自身 scale)
func _compute_area(body: Node2D) -> float:
	for child in body.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape == null:
				continue
			var s := cs.scale.abs()
			if cs.shape is CircleShape2D:
				var r: float = (cs.shape as CircleShape2D).radius * maxf(s.x, s.y)
				return PI * r * r
			elif cs.shape is RectangleShape2D:
				var sz: Vector2 = (cs.shape as RectangleShape2D).size
				return abs(sz.x * sz.y * s.x * s.y)
			elif cs.shape is CapsuleShape2D:
				var cap := cs.shape as CapsuleShape2D
				var r: float = cap.radius * maxf(s.x, s.y)
				return PI * r * r + 2.0 * r * cap.height * s.y
	return reference_volume

# 计算物体的当前速度：RigidBody2D 用线速度，旋转臂用切向速度
func _get_velocity(body: Node2D) -> Vector2:
	if body is RigidBody2D:
		return (body as RigidBody2D).linear_velocity
	if _rotation_parents.has(body):
		var parent = _rotation_parents[body]
		var omega: float = parent.angular_velocity
		var r: Vector2 = body.global_position - parent.global_position
		return omega * Vector2(-r.y, r.x)
	return Vector2.ZERO

# 每帧按速度驱动拖尾；同时清理已释放的物体
func _update_trails() -> void:
	for body in _trails.keys():
		if not is_instance_valid(body):
			_trails.erase(body)
			_materials.erase(body)
			_rotation_parents.erase(body)
			continue
		var vel: Vector2 = _get_velocity(body as Node2D)
		var speed: float = vel.length()
		if speed < trail_speed_threshold:
			(_trails[body] as GPUParticles2D).emitting = false
			continue
		var emitter: GPUParticles2D = _trails[body]
		var mat: ParticleProcessMaterial = _materials[body]
		emitter.emitting = true
		var dir: Vector2 = -vel.normalized()
		mat.direction = Vector3(dir.x, dir.y, 0.0)
		mat.initial_velocity_min = speed * 0.35
		mat.initial_velocity_max = speed * 0.7

# 释放全部拖尾 (场景切换用)
func _clear_all() -> void:
	for emitter in _trails.values():
		if is_instance_valid(emitter):
			(emitter as GPUParticles2D).queue_free()
	_trails.clear()
	_materials.clear()
	_rotation_parents.clear()
