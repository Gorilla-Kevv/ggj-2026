# ============================================================
# RockPillar — 岩柱机关 (第3关: 炽风峡谷)
# 与可操纵石头 (interactable 组) 交互的机关柱。
#   模式 Rise:  初始无实体碰撞 (碰后实体 disabled)。石头进入检测区 →
#               播放动画 → 停在最后一帧 → 启用碰后实体碰撞 (柱子立起来) → 删除指定火舌
#   模式 Crush: 初始有实体碰撞。石头进入检测区 → 播放动画 → 播放完删除自身
# 检测区: 子节点 Area2D "RockDetector" (检测可操纵石头)
# 动画: 子节点 AnimatedSprite2D，播放 animation_name 后冻结在最后一帧
# ============================================================
extends StaticBody2D
class_name RockPillar

# ---------- 导出变量 (编辑器可调) ----------
@export_enum("Rise", "Crush") var pillar_mode: int = 0
@export var detection_area: NodePath = NodePath("RockDetector")
@export var animation_path: NodePath = NodePath("AnimatedSprite2D")
@export var animation_name: String = "default"
@export var collision_to_enable: NodePath  # Rise: 动画结束后启用的实体碰撞 (碰后实体)
@export var fire_tongue_path: NodePath     # Rise: 触发后要删除的火舌节点

# ---------- 运行时状态 ----------
var _triggered: bool = false

func _ready() -> void:
	var detector := get_node_or_null(detection_area) as Area2D
	if detector:
		detector.body_entered.connect(_on_rock_entered)
	if pillar_mode == 0:
		# Rise: 初始关闭实体碰撞 (柱子未立起来，可穿过)
		var solid := get_node_or_null(collision_to_enable) as CollisionShape2D
		if solid:
			solid.disabled = true
			solid.visible = false

# 检测区回调: 只认可操纵石头 (interactable 组)
func _on_rock_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("interactable"):
		return
	_triggered = true
	var detector := get_node_or_null(detection_area) as Area2D
	if detector:
		detector.set_deferred("monitoring", false)
	# 石头撞上柱子机关 → 破碎销毁 (播放一次 broken 动画)
	if body.has_method("break_rock"):
		body.break_rock()

	var anim := get_node_or_null(animation_path) as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(animation_name):
		anim.animation = animation_name
		anim.frame = 0
		anim.speed_scale = 1.0
		anim.play()
	await _wait_anim_finish(anim)

	if pillar_mode == 0:
		# Rise: 冻结在最后一帧 → 立起实体碰撞 → 删除火舌
		var solid := get_node_or_null(collision_to_enable) as CollisionShape2D
		if solid:
			solid.disabled = false
			solid.visible = true
		_remove_fire_tongue()
	else:
		# Crush: 播放完直接删除自身
		queue_free()

# 等待动画播放完整一遍后，冻结在最后一帧 (loop 动画也强制停末帧，不会绕回第一帧)
func _wait_anim_finish(anim: AnimatedSprite2D) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(anim.animation):
		return
	var frame_count := anim.sprite_frames.get_frame_count(anim.animation)
	# 临时改为不循环，播完即停 (is_playing 变 false)，避免观察末帧时被绕回第 0 帧
	anim.sprite_frames.set_animation_loop(anim.animation, false)
	while is_instance_valid(anim) and anim.is_playing():
		await get_tree().process_frame
	if is_instance_valid(anim):
		anim.stop()
		anim.frame = frame_count - 1   # 确保停在最后一帧

# 删除指定的火舌节点 (如永不熄灭的 fire_tongue10)
func _remove_fire_tongue() -> void:
	if fire_tongue_path.is_empty():
		return
	var ft := get_node_or_null(fire_tongue_path)
	if ft:
		ft.queue_free()