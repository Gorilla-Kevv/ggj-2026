# ============================================================
# Scorpion — 蝎子炮台 (第3关: 炽风峡谷)
# 继承 BaseEnemy，原地炮台：
#   IDLE:   等待玩家进入侦测范围
#   ATTACK: 面向玩家，周期性发射子弹 (shoot 动画)
# 子弹命中玩家 → player.die() (即死)
# 动画: AnimatedSprite2D idle / shoot (占位贴图，可替换)
# ============================================================
extends BaseEnemy
class_name Scorpion

# ---------- 导出变量 (编辑器可调) ----------
@export var detection_range: float = 500.0     # 侦测半径 (玩家进入此距离才会射击)
@export var fire_cooldown: float = 2.0         # 两次射击间隔 (秒)
@export var bullet_scene: PackedScene          # 子弹场景 (默认已绑定 scorpion_bullet.tscn)
@export var bullet_speed: float = 320.0        # 子弹飞行速度 (px/s)

# ---------- 子节点引用 ----------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bullet_spawn: Marker2D = $BulletSpawn

# ---------- 运行时状态 ----------
var _fire_timer: float = 0.0
var _player_in_range: bool = false

func _ready() -> void:
	super._ready()
	_play_anim("idle")

# ---------- 侦测: 玩家进入范围 → 进入 ATTACK ----------
func _detect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_player_in_range = global_position.distance_to(player.global_position) <= detection_range
	if current_state == State.IDLE and _player_in_range:
		_enter_state(State.ATTACK)

# ---------- AI 执行 ----------
func _execute_ai(delta: float) -> void:
	match current_state:
		State.ATTACK:
			_attack(delta)
		_:
			velocity = Vector2.ZERO

func _attack(delta: float) -> void:
	if not _player_in_range:
		_enter_state(State.IDLE)
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_enter_state(State.IDLE)
		return
	_facing_player(player)
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_fire(player)

# 面向玩家 (水平翻转精灵)
func _facing_player(player: Node2D) -> void:
	if animated_sprite == null:
		return
	animated_sprite.flip_h = player.global_position.x < global_position.x

# 发射子弹
func _fire(player: Node2D) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	var dir: Vector2 = (player.global_position - global_position).normalized()
	var spawn_pos: Vector2 = bullet_spawn.global_position if bullet_spawn else global_position
	bullet.setup(spawn_pos, dir * bullet_speed)
	get_tree().current_scene.add_child(bullet)

# ---------- 动画 ----------
func _play_anim(anim: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)

# ---------- 状态进入 ----------
func _on_state_entered(state: BaseEnemy.State) -> void:
	match state:
		State.ATTACK:
			_fire_timer = 0.0
			_play_anim("shoot")
		State.IDLE:
			_play_anim("idle")
		State.STUNNED:
			velocity = Vector2.ZERO
		State.DEAD:
			_handle_death()
