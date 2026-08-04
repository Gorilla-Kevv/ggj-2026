# ============================================================
# Drone — 追踪无人机 (第3关: 炽风峡谷)
# 继承 BaseEnemy，沿固定路径水平巡航
# 向下 RayCast2D 检测：玩家在正下方 → 即死 (被抓到)
# 被岩柱砸中 → 直接死亡
# ============================================================
extends BaseEnemy
class_name Drone

# ---------- 导出变量 ----------
@export var patrol_points: Array[Marker2D] = []
@export var detection_range: float = 300.0     # 向下射线长度

# ---------- 子节点引用 ----------
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# ---------- 运行时状态 ----------
var _patrol_index: int = 0
var _patrol_direction: int = 1

func _ready() -> void:
	super._ready()
	ray_cast.target_position = Vector2(0, detection_range)
	_enter_state(State.PATROL)

# ---------- 侦测: 正下方有玩家 → 即死 ----------
func _detect_player() -> void:
	if current_state != State.PATROL:
		return
	ray_cast.force_raycast_update()
	var collider := ray_cast.get_collider()
	if collider != null and collider.is_in_group("player"):
		collider.die()

# ---------- AI 执行 ----------
func _execute_ai(delta: float) -> void:
	match current_state:
		State.PATROL:
			_patrol(delta)
		State.STUNNED:
			velocity = Vector2.ZERO

# ---------- 巡逻: 水平折返 (不停顿) ----------
func _patrol(_delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	var target_pos: Vector2 = patrol_points[_patrol_index].global_position
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()

	if dist < 4.0:
		_patrol_index += _patrol_direction
		if _patrol_index >= patrol_points.size():
			_patrol_direction = -1
			_patrol_index = patrol_points.size() - 2
		elif _patrol_index < 0:
			_patrol_direction = 1
			_patrol_index = 1
	else:
		velocity.x = to_target.normalized().x * move_speed   # 仅水平移动

# ---------- 状态进入 ----------
func _on_state_entered(state: BaseEnemy.State) -> void:
	match state:
		State.STUNNED:
			velocity = Vector2.ZERO
			die()                               # 岩柱砸中 → 直接死
		State.DEAD:
			_handle_death()
			_handle_death()
