# ============================================================
# Researcher — 巡逻研究员 (第2关: 通风管道)
# 继承 BaseEnemy，使用 RayCast2D 前方射线检测玩家
#
# 行为:
#   PATROL:  沿巡逻路径往返移动
#   CHASE:   发现玩家 → 加速追击
#   STUNNED: 被管道挡板砸晕 → 暂停行动
#
# 导出变量可在编辑器中配置巡逻路径 (Marker2D 数组)
# ============================================================
extends BaseEnemy
class_name Researcher

# ---------- 导出变量 ----------
@export var patrol_points: Array[Marker2D] = []
@export var detection_range: float = 300.0
@export var chase_duration: float = 4.0          # 追击持续最长时间 (丢失目标后)
@export var patrol_pause: float = 1.0            # 巡逻到端点后的停顿

# ---------- 子节点引用 ----------
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ---------- 运行时状态 ----------
var _patrol_index: int = 0
var _patrol_direction: int = 1        # 1=正向, -1=反向
var _patrol_pause_timer: float = 0.0
var _chase_timer: float = 0.0
var _player_last_seen_dir: int = 1    # 最后看到玩家的方向 (用于丢失后继续搜索)

# ---------- 辅助节点引用 ----------
func _ready() -> void:
	super._ready()
	# 从精灵朝向初始化巡逻方向 (镜像: scale.x < 0 → 朝左)
	if sprite != null and sprite.scale.x < 0:
		_patrol_direction = -1
	_enter_state(State.PATROL)

# ---------- 侦测玩家: RayCast2D + 朝向 + 距离 ----------
func _detect_player() -> void:
	if current_state in [State.DEAD, State.STUNNED]:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# 确定当前朝向 (从巡逻方向或精灵翻转)
	var facing_dir: int = _patrol_direction

	if current_state == State.CHASE:
		# 追击中：RayCast2D 追踪玩家
		ray_cast.target_position = to_player.normalized() * minf(dist, detection_range)
		if dist > detection_range * 1.5 or not _is_player_visible(player):
			_chase_timer += get_physics_process_delta_time()
			if _chase_timer > chase_duration:
				_enter_state(State.PATROL)
		else:
			_chase_timer = 0.0
			_player_last_seen_dir = 1 if to_player.x > 0 else -1
	else:
		# 巡逻中：射线仅水平前方（不检测斜上方）
		ray_cast.target_position = Vector2(facing_dir * detection_range, 0)
		ray_cast.force_raycast_update()
		var hit := ray_cast.get_collider()
		var player_in_front: bool = (to_player.x * facing_dir) > 0
		if player_in_front and hit != null and hit.is_in_group("player"):
			print("[Researcher] 发现玩家！进入追击")
			_enter_state(State.CHASE)

# ---------- DEBUG ----------
func _debug_trace(player: Node2D, dist: float, facing_dir: int, player_in_front: bool) -> void:
	print("--- Researcher ---")
	print("  距离: %.1f (阈值: %.1f)" % [dist, detection_range])
	print("  面朝: %s  在前方: %s" % ["→" if facing_dir > 0 else "←", player_in_front])
	print("  射线命中: %s" % _is_player_visible(player))
	print("  触发: %s" % (dist <= detection_range and player_in_front and _is_player_visible(player)))

# 射线检测：RayCast2D 是否碰到玩家
func _is_player_visible(player: Node2D) -> bool:
	ray_cast.force_raycast_update()
	var collider := ray_cast.get_collider()
	return collider != null and collider.is_in_group("player")

# ---------- AI 执行 ----------
func _execute_ai(delta: float) -> void:
	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.STUNNED:
			velocity = Vector2.ZERO

# ---------- 巡逻 ----------
func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	# 停顿计时
	if _patrol_pause_timer > 0:
		_patrol_pause_timer -= delta
		velocity = Vector2.ZERO
		return

	var target_pos: Vector2 = patrol_points[_patrol_index].global_position
	var dist: float = absf(target_pos.x - global_position.x)

	if dist < 4.0:
		# 到达端点 → 立即翻转 + 停顿
		_patrol_pause_timer = patrol_pause
		_patrol_index += _patrol_direction
		if _patrol_index >= patrol_points.size():
			_patrol_direction = -1
			_patrol_index = patrol_points.size() - 2
			_flip_sprite(_patrol_direction)
		elif _patrol_index < 0:
			_patrol_direction = 1
			_patrol_index = 1
			_flip_sprite(_patrol_direction)
	else:
		velocity.x = (target_pos.x - global_position.x) / absf(target_pos.x - global_position.x) * move_speed
		velocity.y = 0.0
		_flip_sprite(velocity.x)

# ---------- 追击 ----------
func _chase(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_enter_state(State.PATROL)
		return

	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 5.0:
		var dir_x: float = 1.0 if dx > 0 else -1.0
		velocity.x = dir_x * chase_speed
		_flip_sprite(dir_x)
	else:
		velocity.x = 0.0
	velocity.y = 0.0

	# 钳制：不超出巡逻点 X 范围
	velocity.x *= _clamp_to_patrol_bounds()

# 如果超出巡逻边界 → 减速为0，防止踏空
func _clamp_to_patrol_bounds() -> float:
	if patrol_points.is_empty():
		return 1.0
	var left: float = patrol_points[0].global_position.x
	var right: float = patrol_points[-1].global_position.x
	if left > right:
		var t := left; left = right; right = t
	if global_position.x <= left and velocity.x < 0:
		return 0.0
	if global_position.x >= right and velocity.x > 0:
		return 0.0
	return 1.0

# ---------- 翻转精灵 ----------
func _flip_sprite(dir_x: float) -> void:
	if dir_x != 0 and sprite != null:
		sprite.scale.x = absf(sprite.scale.x) * (-1.0 if dir_x < 0 else 1.0)
		_patrol_direction = -1 if dir_x < 0 else 1

# ---------- 状态进入 ----------
func _on_state_entered(state: BaseEnemy.State) -> void:
	match state:
		State.CHASE:
			_chase_timer = 0.0
		State.PATROL:
			# 追丢后掉头向最后看到的玩家方向
			if _player_last_seen_dir != 0:
				_flip_sprite(_player_last_seen_dir)
				_patrol_direction = _player_last_seen_dir
		State.STUNNED:
			velocity = Vector2.ZERO
		State.DEAD:
			_handle_death()
