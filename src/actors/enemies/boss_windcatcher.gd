# ============================================================
# BossWindcatcher — 捕风者 Boss (第5关: 飓风之眼)
extends BaseEnemy
class_name BossWindcatcher

enum Phase { SUCTION, BLAST, CALM }

@export var suction_force: float = 300.0
@export var blast_force: float = 2000.0
@export var blast_pulse_on: float = 1
@export var blast_pulse_off: float = 2

var _blast_timer: float = 0.0
@export var suction_duration: float = 6.0
@export var blast_duration: float = 5.0
@export var calm_duration: float = 7.0
@export var debris_interval: float = 1.5
@export var debris_speed: float = 800.0
@export var max_hp: float = 100.0
@export var debris_paths: Array[String] = []
@export var rock_scene: PackedScene
@export var rock_hits_needed: int = 2
@export var rock_spawn_interval: float = 3.0
@export var rock_spawn_positions: Array[Vector2] = []

@onready var suction_area: Area2D = $SuctionArea
@onready var phase_timer: Timer = $PhaseTimer
@onready var debris_timer: Timer = $DebrisTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var debris_spawner: Node2D = $DebrisSpawner
@onready var rock_timer: Timer = $RockTimer

var current_phase: Phase = Phase.SUCTION
var hp: float = max_hp
var rock_hit_count: int = 0
var start_active: bool = false

signal phase_changed(new_phase: Phase)
signal boss_defeated()

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	hp = max_hp
	if not is_instance_valid(debris_timer):
		push_error("BossWindcatcher: DebrisTimer 节点不存在！")
		return
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	debris_timer.timeout.connect(_on_debris_timer_timeout)
	rock_timer.timeout.connect(_on_rock_timer_timeout)
	# 初始不激活，等待开场动画结束后调用 activate()
	set_physics_process(false)
	print("BossWindcatcher: _ready 完成，等待 activate()")

# 由开场动画脚本调用，正式启动 Boss
func activate() -> void:
	if start_active: return
	start_active = true
	set_physics_process(true)
	_enter_phase(Phase.SUCTION)

func _enter_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(phase)
	match phase:
		Phase.SUCTION:
			contact_area.monitoring = true        # 即死开
			debris_timer.start(debris_interval)
			phase_timer.start(suction_duration)
			rock_timer.stop()
			print("BossWindcatcher: 进入 SUCTION，debris_timer 启动，间隔=", debris_interval)
		Phase.BLAST:
			contact_area.monitoring = true          # 保持碰撞检测，但不致死
			debris_timer.stop()
			phase_timer.stop()
			rock_timer.stop()
		Phase.CALM:
			contact_area.monitoring = true
			debris_timer.stop()
			rock_timer.start(rock_spawn_interval)
			phase_timer.start(calm_duration)       # 保底：超时自动回到 SUCTION
			rock_hit_count = 0
			print("BossWindcatcher: 进入 CALM，需要砸 ", rock_hits_needed, " 次，保底 ", calm_duration, " 秒")

func _on_phase_timer_timeout() -> void:
	match current_phase:
		Phase.SUCTION: _enter_phase(Phase.BLAST)
		Phase.CALM:    _enter_phase(Phase.SUCTION)

func _on_debris_timer_timeout() -> void:
	print("BossWindcatcher: _on_debris_timer_timeout 触发, paths=", debris_paths)
	if debris_paths.is_empty():
		push_warning("BossWindcatcher: debris_paths 为空！请在 Inspector 中填入碎石场景路径。")
		return
	var scene_path: String = debris_paths.pick_random()
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("BossWindcatcher: load(%s) 返回 null，检查路径是否正确。" % scene_path)
		return
	var debris: Area2D = scene.instantiate() as Area2D
	if debris == null:
		push_error("BossWindcatcher: instantiate() 返回 null，场景可能已损坏。")
		return
	var fly_dir: Vector2 = Vector2.RIGHT if current_phase == Phase.SUCTION else Vector2.LEFT
	var spawn_x: float = -800.0 if fly_dir.x > 0 else 20000.0
	debris.global_position = Vector2(spawn_x, randf_range(-1000, 2000))
	debris.velocity = fly_dir * debris_speed
	get_parent().add_child(debris)
	get_tree().create_timer(24.0).timeout.connect(debris.queue_free)
	print("BossWindcatcher: 生成碎石 @ ", debris.global_position)

func _physics_process(delta: float) -> void:
	if current_state in [State.DEAD, State.STUNNED]: return
	match current_phase:
		Phase.SUCTION: _apply_suction(delta)
		Phase.BLAST:   _apply_blast(delta)

# 碰撞处理按阶段分发
func _on_contact_area_body_entered(body: Node2D) -> void:
	if current_state in [State.DEAD, State.STUNNED]: return
	match current_phase:
		Phase.SUCTION:
			super._on_contact_area_body_entered(body)   # 即死
		Phase.BLAST:
			if body.is_in_group("player"):
				_enter_phase(Phase.CALM)
		Phase.CALM:
			pass   # 平静态不触发任何效果

func _apply_suction(delta: float) -> void:
	for body in suction_area.get_overlapping_bodies():
		var dir := (global_position - body.global_position).normalized()
		if body is RigidBody2D:
			body.apply_central_force(dir * suction_force)
		elif body.is_in_group("player"):
			body.apply_wind_force(dir * suction_force * delta)

func _apply_blast(delta: float) -> void:
	_blast_timer += delta
	var cycle: float = blast_pulse_on + blast_pulse_off
	var t: float = fmod(_blast_timer, cycle)
	if t > blast_pulse_on:
		return    # 关风间隙
	for body in suction_area.get_overlapping_bodies():
		if body is RigidBody2D:
			body.apply_central_force(Vector2.LEFT * blast_force)
		elif body.is_in_group("player"):
			var dir := (body.global_position - global_position).normalized()
			body.apply_wind_force(dir * blast_force * delta)

func take_damage(amount: float) -> void:
	if current_phase == Phase.SUCTION: return
	hp -= amount
	if hp <= 0: die()

# 被石头砸中 (CALM 阶段专用)
func hit_by_rock(damage: float) -> void:
	if current_phase != Phase.CALM: return
	rock_hit_count += 1
	hp -= damage
	print("BossWindcatcher: 被石头砸中! 次数=", rock_hit_count, "/", rock_hits_needed, " hp=", hp)
	if hp <= 0:
		die()
		return
	if rock_hit_count >= rock_hits_needed:
		print("BossWindcatcher: 砸够次数，返回 SUCTION")
		_enter_phase(Phase.SUCTION)

# 第三阶段刷可投掷石头
func _on_rock_timer_timeout() -> void:
	if current_phase != Phase.CALM: return
	if rock_scene == null:
		push_warning("BossWindcatcher: rock_scene 未设置！")
		return
	var rock: RigidBody2D = rock_scene.instantiate() as RigidBody2D
	if rock == null:
		push_error("BossWindcatcher: rock 实例化失败！")
		return
	# 在指定区间随机生成石头，让它自然落下
	rock.global_position = Vector2(randf_range(0, 2000), -1000)
	get_parent().add_child(rock)
	get_tree().call_group("target_selector", "_refresh_targets")
	print("BossWindcatcher: 刷新可投掷石头 @ ", rock.global_position)

func _handle_death() -> void:
	boss_defeated.emit()
	super._handle_death()

func _detect_player() -> void: pass
func _execute_ai(_delta: float) -> void: pass
