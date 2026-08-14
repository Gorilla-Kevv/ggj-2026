# ============================================================
# BossIntro — Boss 开场动画
# 挂载在 stage_5 场景根节点上
# 玩家 x 达到 1000 时触发：镜头切到 Boss → 平移到 door → 触发 door 动画 → 停留 → 切回玩家 → Boss 激活
# ============================================================
extends Node2D

@export var trigger_x: float = 1000.0
@export var boss_look_pos: Vector2 = Vector2(2301, 666)
@export var door_node_path: NodePath      # 在 Inspector 中拖入 door 节点
@export var door_anim_name: String = "new_animation"
@export var boss_anim_player_path: NodePath   # Boss 的 AnimationPlayer 路径
@export var boss_showup_anim: String = "show up"
@export var boss_loop_anim: String = "new_animation"
@export var look_duration: float = 2.0

var _triggered: bool = false
var _door_anim_player: AnimationPlayer = null
var _shaking_door: bool = false
var _shake_timer: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	# door 动画播放期间持续震动
	if _shaking_door and _door_anim_player and _door_anim_player.is_playing():
		_shake_timer -= delta
		if _shake_timer <= 0.0:
			_shake(10.0, 0.08)
			_shake_timer = 0.08
	if _triggered: return
	var player := get_tree().get_first_node_in_group("player")
	if player == null: return
	if player.global_position.x >= trigger_x:
		_triggered = true
		# Boss 动画触发瞬间启动音乐
		var audio := get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_boss_fight_music"):
			audio.play_boss_fight_music()
		_play_intro()

func _play_intro() -> void:
	print("[BossIntro] 触发！玩家越过 x=", trigger_x)

	# 禁用玩家输入
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.set_process(false)

	# 获取摄像机
	var camera: Camera2D = null
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			camera = cam
			break

	# 获取全局对象和 Boss
	var global := get_node("/root/Global")
	var boss: BossWindcatcher = null
	for b in get_tree().get_nodes_in_group("boss"):
		if b is BossWindcatcher:
			boss = b
			break

	if camera == null:
		push_error("[BossIntro] 找不到摄像机！")
		_restore_player(player)
		if boss: boss.activate()
		return

	if boss == null:
		push_error("[BossIntro] 找不到 Boss！")
		_restore_player(player)
		return

	# 暂存原目标，镜头脱离 select_target
	var original_target = global.selected_target
	global.selected_target = null

	# 步骤1：平滑平移到 Boss 位置
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.0
	camera.global_position = boss_look_pos
	await get_tree().create_timer(1.5).timeout

	# 步骤1b：循环播放 Boss 常态动画
	var boss_anim: AnimationPlayer = null
	if boss_anim_player_path:
		boss_anim = get_node_or_null(boss_anim_player_path) as AnimationPlayer
	if boss_anim == null and boss:
		for child in boss.get_children():
			if child is AnimationPlayer:
				boss_anim = child
				break
	if boss_anim and boss_anim.has_animation(boss_loop_anim):
		boss_anim.play(boss_loop_anim)
		print("[BossIntro] 循环播放 Boss ", boss_loop_anim)

	# 查找 door 节点
	var door_node: Node2D = null
	if door_node_path:
		door_node = get_node_or_null(door_node_path) as Node2D
	if door_node == null:
		# 回退：按名字查找
		for child in get_children():
			if child.name.to_lower().contains("door") and child is Node2D:
				door_node = child
				break
	var door_target: Vector2 = door_node.global_position if door_node else Vector2(100, 1500)

	# 步骤2：平滑平移到 door 位置
	camera.position_smoothing_speed = 2.0
	camera.global_position = door_target
	await get_tree().create_timer(1.5).timeout

	# 步骤2b：触发 door 动画
	if door_node:
		var anim_player: AnimationPlayer = null
		for child in door_node.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
		if anim_player and anim_player.has_animation(door_anim_name):
			anim_player.play(door_anim_name)
			_door_anim_player = anim_player
			_shaking_door = true
			print("[BossIntro] 播放 door 动画: ", door_anim_name)

	# 步骤3：停留观察
	await get_tree().create_timer(look_duration).timeout

	# 步骤4：切回玩家
	camera.position_smoothing_speed = 5.0
	if original_target != null and is_instance_valid(original_target):
		global.selected_target = original_target
	elif player != null and is_instance_valid(player):
		global.selected_target = player
	else:
		global.selected_target = null

	# 等摄像机回位
	await get_tree().create_timer(1.0).timeout

	# 步骤5：恢复玩家 + 激活 Boss
	_restore_player(player)
	if boss: boss.activate()
	print("[BossIntro] 开场动画结束，Boss 激活")

func _restore_player(player: Node2D) -> void:
	if player == null: return
	player.set_physics_process(true)
	player.set_process(true)

# 触发屏幕震动
func _shake(strength: float, duration: float) -> void:
	for node in get_tree().get_nodes_in_group("screen_shaker"):
		if node.has_method("screen_shake"):
			node.screen_shake(strength, duration)
			return
