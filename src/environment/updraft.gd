# ============================================================
# Updraft — 上升气流 (大厅/关卡组件)
# Area2D 区域，玩家进入后持续获得沿节点朝上方向的升力，不消耗能量。
# 吹风方向跟随节点旋转 (朝节点的 -Y 方向吹)。
# 用于大厅攀升塔 (借助气流升到上层章节) 以及峡谷关卡的热气流攀升。
#
# 使用：
#   1. 调整碰撞形状确定气流范围 (宽高建议: 宽80~160, 高250~600)
#   2. lift_force: 气流加速度 (越大攀升越快)
#   3. max_up_speed: 气流内沿风向速度上限 (防止无限加速)
#   4. 视觉效果由子节点粒子系统负责，粒子方向自动跟随节点旋转
# ============================================================
extends Area2D

# ---------- 导出变量 (编辑器配置) ----------
@export var lift_force: float = 450.0      # 风力加速度 (px/s²)，越大越难抵抗
@export var max_up_speed: float = 320.0    # 气流内沿风向速度上限 (反向抗风不受限)
@export var particle_gravity: float = 160.0  # 粒子沿风向的额外加速

# ---------- 子节点引用 ----------
@onready var wind_particles: GPUParticles2D = get_node_or_null("windline_particles bg")

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	_prepare_particles()
	# 预模拟 (preprocess) 前先同步方向，避免起始粒子朝旧方向乱飘
	_sync_particle_direction(-transform.y)

# 粒子在世界空间发射 (local_coords=false)，方向/重力由代码每帧同步为当前风向。
# 复制一份材质，避免多个 Updraft 实例共享材质互相覆盖。
func _prepare_particles() -> void:
	if wind_particles == null:
		return
	wind_particles.local_coords = false
	var mat := wind_particles.process_material
	if mat != null:
		wind_particles.process_material = mat.duplicate()

func _sync_particle_direction(blow_dir: Vector2) -> void:
	if wind_particles == null or wind_particles.process_material == null:
		return
	var mat := wind_particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	mat.direction = Vector3(blow_dir.x, blow_dir.y, 0.0)
	mat.gravity = Vector3(blow_dir.x, blow_dir.y, 0.0) * particle_gravity

func _physics_process(delta: float) -> void:
	# 吹风方向 = 节点本地朝上 (-Y 轴)，跟随节点旋转
	var blow_dir: Vector2 = -transform.y
	_sync_particle_direction(blow_dir)
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			var player := body as CharacterBody2D
			if player == null:
				continue
			# 风力按加速度逐帧推进，玩家可用输入抵消/逃离，而非瞬间拉满
			player.velocity += blow_dir * lift_force * delta
			# 沿风向速度上限 (玩家反向抗风不受此限制)
			var speed_along: float = player.velocity.dot(blow_dir)
			if speed_along > max_up_speed:
				player.velocity -= blow_dir * (speed_along - max_up_speed)
