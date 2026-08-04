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
@onready var sprite: Sprite2D = $Sprite2D
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
	_enter_state(State.PATROL)

# ---------- 侦测玩家: RayCast2D + 距离 ----------
func _detect_player() -> void:
	if current_state in [State.DEAD, State.STUNNED]:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# 计算到玩家的距离和方向
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# 更新 RayCast2D 朝向玩家
	ray_cast.target_position = to_player.normalized() * minf(dist, detection_range)

	if current_state == State.CHASE:
		# 追击中：检查是否丢失目标
		if dist > detection_range * 1.5 or not _is_player_visible(player):
			_chase_timer += get_physics_process_delta_time()
			if _chase_timer > chase_duration:
				# 丢失太久 → 回到巡逻
				_enter_state(State.PATROL)
		else:
			_chase_timer = 0.0
			_player_last_seen_dir = 1 if to_player.x > 0 else -1
	else:
		# 巡逻中：检测玩家是否进入视野
		if dist <= detection_range and _is_player_visible(player):
			_enter_state(State.CHASE)

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
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist < 4.0:
		# 到达端点
		_patrol_pause_timer = patrol_pause
		_patrol_index += _patrol_direction
		if _patrol_index >= patrol_points.size():
			_patrol_direction = -1
			_patrol_index = patrol_points.size() - 2
		elif _patrol_index < 0:
			_patrol_direction = 1
			_patrol_index = 1
	else:
		velocity = to_target.normalized() * move_speed
		_flip_sprite(velocity.x)

# ---------- 追击 ----------
func _chase(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_enter_state(State.PATROL)
		return

	var to_player: Vector2 = player.global_position - global_position
	velocity = to_player.normalized() * chase_speed
	_flip_sprite(velocity.x)

# ---------- 翻转精灵 ----------
func _flip_sprite(dir_x: float) -> void:
	if dir_x != 0 and sprite != null:
		sprite.flip_h = dir_x < 0

# ---------- 状态进入 ----------
func _on_state_entered(state: BaseEnemy.State) -> void:
	match state:
		State.CHASE:
			_chase_timer = 0.0
		State.STUNNED:
			velocity = Vector2.ZERO
		State.DEAD:
			_handle_death()
