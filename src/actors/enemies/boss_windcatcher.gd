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
@export var suction_duration: float = 10.0
@export var blast_duration: float = 5.0
@export var calm_duration: float = 15.0
@export var debris_interval: float = 0.64
@export var debris_speed: float = 400.0
@export var debris_paths: Array[String] = []
@export var rock_scene: PackedScene
@export var rock_hits_needed: int = 4        # 累计砸满4次死亡
@export var rock_hits_to_leave: int = 2      # 本次CALM砸满2次提前退出
@export var rock_spawn_interval: float = 3.0
@export var rock_spawn_positions: Array[Vector2] = []

@onready var suction_area: Area2D = $SuctionArea
@onready var phase_timer: Timer = $PhaseTimer
@onready var debris_timer: Timer = $DebrisTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var debris_spawner: Node2D = $DebrisSpawner
@onready var rock_timer: Timer = $RockTimer

var blast_wind_effect: Node = null

var current_phase: Phase = Phase.SUCTION
var rock_hit_count: int = 0        # 本次 CALM 的受击次数
var rock_hit_total: int = 0        # 累计受击次数（跨多个 CALM）
var start_active: bool = false

signal phase_changed(new_phase: Phase)
signal boss_defeated()

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	if not is_instance_valid(debris_timer):
		push_error("BossWindcatcher: DebrisTimer 节点不存在！")
		return
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	debris_timer.timeout.connect(_on_debris_timer_timeout)
	rock_timer.timeout.connect(_on_rock_timer_timeout)
	# 查找暴风特效节点
	blast_wind_effect = get_node_or_null("/root/stage-5/BlastWindEffect")
	# 初始不激活，等待开场动画结束后调用 activate()
	set_physics_process(false)
	print("BossWindcatcher: _ready 完成，等待 activate()")

# 由开场动画脚本调用，正式启动 Boss
func activate() -> void:
	if start_active: return
	start_active = true
	set_physics_process(true)
	_enter_phase(Phase.SUCTION, false)   # 首次进入不震动

func _enter_phase(phase: Phase, shake: bool = true) -> void:
	if current_state == State.DEAD:
		return
	current_phase = phase
	phase_changed.emit(phase)
	_play_phase_anim(phase)
	# 切换状态时触发明显震动
	if shake:
		_shake(15.0, 0.4)
	match phase:
		Phase.SUCTION:
			contact_area.monitoring = true        # 即死开
			debris_timer.start(debris_interval)
			phase_timer.start(suction_duration)
			rock_timer.stop()
			_clear_rocks()                       # 清理 CALM 剩余石头
			_set_wind_effect(true, 1)            # 右吹、开
			_switch_camera_to_player_deferred()
			print("BossWindcatcher: 进入 SUCTION，debris_timer 启动，间隔=", debris_interval)
		Phase.BLAST:
			contact_area.monitoring = true          # 保持碰撞检测，但不致死
			debris_timer.stop()
			phase_timer.stop()
			rock_timer.stop()
			_set_wind_effect(true, -1)           # 左吹、开
		Phase.CALM:
			contact_area.monitoring = true
			debris_timer.stop()
			rock_timer.start(rock_spawn_interval)
			phase_timer.start(calm_duration)
			rock_hit_count = 0                  # 重置本次计数，累计保留
			_set_wind_effect(false, 0)           # 关
			print("BossWindcatcher: 进入 CALM，本次砸满 ", rock_hits_to_leave, " 次退出，累计 ", rock_hit_total, "/", rock_hits_needed, " 死")

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
	debris.rotation = randf_range(0, TAU)   # 随机旋转方向
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
	if body == null or not is_instance_valid(body):
		return
	if current_state in [State.DEAD, State.STUNNED]: return
	# 玩家碰到 Boss → 向左弹开
	if body.is_in_group("player"):
		_knockback_player(body)
	match current_phase:
		Phase.SUCTION:
			super._on_contact_area_body_entered(body)   # 即死
		Phase.BLAST:
			if body.is_in_group("player"):
				_enter_phase(Phase.CALM)
		Phase.CALM:
			pass   # 平静态不触发任何效果

# 把玩家向左弹开
func _knockback_player(player: Node2D) -> void:
	if player == null:
		return
	var knockback := Vector2(-1200.0, -500.0)   # 向左上强力弹
	if player.has_method("apply_knockback"):
		player.apply_knockback(knockback)
	elif player.has_method("apply_wind_force"):
		player.apply_wind_force(knockback)

func _apply_suction(delta: float) -> void:
	for body in suction_area.get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		var dir := (global_position - body.global_position).normalized()
		if body is RigidBody2D:
			body.apply_central_force(dir * suction_force)
		elif body.is_in_group("player"):
			body.apply_wind_force(dir * suction_force * delta)

func _apply_blast(delta: float) -> void:
	_blast_timer += delta
	var cycle: float = blast_pulse_on + blast_pulse_off
	var t: float = fmod(_blast_timer, cycle)
	var pulse_on := t <= blast_pulse_on

	# 通知特效脉冲状态
	if blast_wind_effect and blast_wind_effect.has_method("set_pulse"):
		blast_wind_effect.set_pulse(pulse_on)

	if not pulse_on:
		return    # 关风间隙
	for body in suction_area.get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if body is RigidBody2D:
			body.apply_central_force(Vector2.LEFT * blast_force)
		elif body.is_in_group("player"):
			var dir := (body.global_position - global_position).normalized()
			body.apply_wind_force(dir * blast_force * delta)

# 覆盖死亡：延迟销毁，让死亡动画播完
func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	# 停止所有计时器，防止死亡后继续阶段切换
	phase_timer.stop()
	debris_timer.stop()
	rock_timer.stop()
	_set_wind_effect(false, 0)
	_handle_death()   # 内部 await 死亡动画后自行销毁

# 被石头砸中 (CALM 阶段专用)
func hit_by_rock(damage: float) -> void:
	if current_phase != Phase.CALM: return
	if current_state == State.DEAD: return
	rock_hit_count += 1
	rock_hit_total += 1
	# 播放受击动画 + 强震动
	_play_hit_anim()
	_shake(20.0, 0.5)
	print("BossWindcatcher: 被石头砸中! 本次=", rock_hit_count, "/", rock_hits_to_leave, " 累计=", rock_hit_total, "/", rock_hits_needed)
	# 累计满4次 → 死亡
	if rock_hit_total >= rock_hits_needed:
		print("BossWindcatcher: 累计被砸满 ", rock_hits_needed, " 次，Boss 死亡")
		die()
		return
	# 本次CALM满2次 → 提前退出，进入下一阶段
	if rock_hit_count >= rock_hits_to_leave:
		print("BossWindcatcher: 本次 CALM 砸满 ", rock_hits_to_leave, " 次，退出 CALM")
		_enter_phase(Phase.SUCTION)

# 播放受击动画
func _play_hit_anim() -> void:
	if sprite == null: return
	var anim := "hit_at_2"
	if sprite.sprite_frames.has_animation(anim):
		# 强制不循环，确保 animation_finished 会触发
		sprite.sprite_frames.set_animation_loop(anim, false)
		sprite.play(anim)
		# 受击动画播完后回到对应阶段待机 (先断开避免重复连接)
		if sprite.animation_finished.is_connected(_on_hit_anim_finished):
			sprite.animation_finished.disconnect(_on_hit_anim_finished)
		sprite.animation_finished.connect(_on_hit_anim_finished, CONNECT_ONE_SHOT)

func _on_hit_anim_finished() -> void:
	if current_state == State.DEAD: return
	_play_phase_anim(current_phase)

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
	# 断开受击动画回调，防止死亡后触发待机切换
	if sprite and sprite.animation_finished.is_connected(_on_hit_anim_finished):
		sprite.animation_finished.disconnect(_on_hit_anim_finished)
	# 锁定玩家（停止物理和输入）
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.set_process(false)
	# 清空剩余石头
	_clear_rocks()
	_shake(25.0, 0.6)                    # 强震动
	# 播放 Boss 死亡 BGM + 死亡音效
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_boss_dead_music"):
		audio.play_boss_dead_music()
	if audio and audio.has_method("sfx_boss_dead"):
		audio.sfx_boss_dead()
	_switch_camera_to_boss()             # 镜头切到 Boss
	# 播放 Boss 挂载的 AnimationPlayer 的 dead 动画
	var boss_anim := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if boss_anim == null:
		boss_anim = get_node_or_null("../AnimationPlayer") as AnimationPlayer
	if boss_anim and boss_anim.has_animation("dead"):
		boss_anim.play("dead")
	# 同时播放 AnimatedSprite2D 的 dead 帧动画
	if sprite and sprite.sprite_frames.has_animation("dead"):
		sprite.sprite_frames.set_animation_loop("dead", false)
		sprite.play("dead")
	boss_defeated.emit()
	# 停留 3 秒（等死亡动画播完），再切回玩家
	await get_tree().create_timer(3.0).timeout
	_switch_camera_to_player()           # 3秒后切回玩家
	# 恢复玩家
	if player and is_instance_valid(player):
		player.set_physics_process(true)
		player.set_process(true)
	# 不销毁，只关碰撞和物理
	if contact_area:
		contact_area.monitoring = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	set_physics_process(false)
	set_process(false)

# 镜头切到 Boss
func _switch_camera_to_boss() -> void:
	# 用镜头锁定强制跟随 Boss，避免被 TargetSelector 覆盖
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			cam.camera_lock_target = self

# 清除 CALM 阶段剩余的可投掷石头
func _clear_rocks() -> void:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is ThrowableRock:
			node.queue_free()

# 切回玩家镜头
func _switch_camera_to_player() -> void:
	# 解除镜头锁定，恢复跟随 selected_target
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			cam.camera_lock_target = null
	var player := get_tree().get_first_node_in_group("player")
	if player == null: return
	var global := get_node("/root/Global")
	global.selected_target = player

# 延迟一帧切回玩家（等石头销毁完成）
func _switch_camera_to_player_deferred() -> void:
	call_deferred("_switch_camera_to_player")

# 触发屏幕震动
func _shake(strength: float, duration: float) -> void:
	for node in get_tree().get_nodes_in_group("screen_shaker"):
		if node.has_method("screen_shake"):
			node.screen_shake(strength, duration)
			return

# 风线特效: dir=1 右吹, dir=-1 左吹, on=false 关闭
func _set_wind_effect(on: bool, dir: int) -> void:
	if blast_wind_effect == null:
		return
	if blast_wind_effect.has_method("set_active"):
		blast_wind_effect.set_active(on)
	if blast_wind_effect.has_method("set_direction"):
		match dir:
			1:
				blast_wind_effect.set_direction(0)
			-1:
				blast_wind_effect.set_direction(1)
			_:
				pass

# 按阶段播放 Boss 动画
func _play_phase_anim(phase: Phase) -> void:
	if sprite == null:
		return
	var anim: String = ""
	match phase:
		Phase.SUCTION: anim = "idle_at_1"
		Phase.BLAST:   anim = "idle_at_2"
		Phase.CALM:    anim = "idle_at_3"
	if anim != "" and sprite.sprite_frames.has_animation(anim):
		# 待机动画循环播放
		sprite.sprite_frames.set_animation_loop(anim, true)
		sprite.play(anim)

func _detect_player() -> void: pass
func _execute_ai(_delta: float) -> void: pass
