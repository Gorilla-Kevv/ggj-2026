# ============================================================
# WindLine — 风向连线可视化
# 挂载于每个关卡场景的 Node2D 节点
# 按住鼠标时：在鼠标与选中目标之间绘制半透明虚线 + 流动粒子
# 松开鼠标时：完全隐藏
# 线宽随风力强度变化，给玩家直观的操作反馈
#
# 连接点规则：
#   1. 优先取目标的 "WindAnchor" 子节点位置 (Marker2D)
#   2. 没有 WindAnchor → 使用目标的 global_position (原点)
#   设计师可在任何可交互物体下放置 Marker2D 改名为 "WindAnchor" 来自定义连接点
# ============================================================
extends Node2D

# ---------- 外观参数 (可在编辑器中调整) ----------
# line_color:     虚线颜色 (默认半透明白)
# line_width:     基础线宽 (px)
# particle_count: 流动粒子数量
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var line_width: float = 2.0
@export var particle_count: int = 8

# current_strength: 当前风力强度 [0.0, 1.0]，用于动态调整线宽
var current_strength: float = 0.0
var particles: Array[Sprite2D] = []

func _ready() -> void:
	# 预创建流动粒子 (小光点，沿风向线均匀分布)
	for i in range(particle_count):
		var p := Sprite2D.new()
		p.scale = Vector2(0.3, 0.3)
		p.modulate = Color(0.6, 0.8, 1.0, 0.6)
		p.visible = false
		add_child(p)
		particles.append(p)

func _process(_delta: float) -> void:
	# 仅鼠标按住时显示风向线
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hide_all()
		return

	var global := get_node("/root/Global")
	# 无目标或目标已销毁 → 隐藏所有元素
	if global.selected_target == null or not is_instance_valid(global.selected_target):
		_hide_all()
		return
	var target: Node2D = global.selected_target

	# 解析连接点：优先 WindAnchor → 回退 global_position
	var anchor_pos := _get_target_anchor_pos(target)
	var mouse_pos := get_viewport().get_mouse_position()
	_update_particles(mouse_pos, anchor_pos)
	queue_redraw()

# 获取目标上的连线连接点
# 优先查找子节点中名为 "WindAnchor" 的 Marker2D
# 没有则返回目标原点
func _get_target_anchor_pos(target: Node2D) -> Vector2:
	var anchor := target.get_node_or_null("WindAnchor") as Marker2D
	if anchor:
		return anchor.global_position
	return target.global_position

# 供 WindSystem 调用：更新当前风力强度
func set_strength(s: float) -> void:
	current_strength = s

# 更新流动粒子位置：沿鼠标→连接点方向均匀分布
func _update_particles(mouse_pos: Vector2, target_pos: Vector2) -> void:
	var diff := target_pos - mouse_pos
	var dist := diff.length()
	if dist < 1.0:
		_hide_all()
		return

	var norm := diff.normalized()
	for i in range(particle_count):
		var t := float(i) / float(maxf(particle_count - 1, 1))
		var pos := mouse_pos + norm * dist * t
		particles[i].position = pos
		particles[i].visible = true

func _hide_all() -> void:
	for p in particles:
		p.visible = false

# 绘制半透明虚线 (Godot 内置 draw_dashed_line)
# 线宽 = 基础线宽 * (1 + 力度 * 3)，吹得越猛线越粗
func _draw() -> void:
	var global := get_node("/root/Global")
	if global.selected_target == null or not is_instance_valid(global.selected_target):
		return
	var target: Node2D = global.selected_target
	var anchor_pos := _get_target_anchor_pos(target)
	var mouse_pos := get_viewport().get_mouse_position()
	var width := line_width * (1.0 + current_strength * 3.0)
	draw_dashed_line(mouse_pos, anchor_pos, line_color, width, 8.0, true)
