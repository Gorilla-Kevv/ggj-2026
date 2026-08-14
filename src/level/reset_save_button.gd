# ============================================================
# ResetSaveButton — 清除存档按钮 (大厅组件)
# 玩家踩到按钮区域时按 X 键 (动作名 "delete") → 删除所有存档。
# 相比一触即删 / 长按式，需要"主动按键"更防误触。
#
# 使用：
#   1. 拖入大厅场景，放在固定区域
#   2. 在项目设置 Input Map 添加动作 "delete" 绑定 X 键
#   3. 玩家进入按钮区域，按 X → 删除存档 → 按钮变红显示"已清除"
#   4. 视觉为 _draw() 占位按钮，可自行替换
#
# 清理逻辑由 Global.delete_save() 完成：
#   删除存档文件 + 清空 levels_clear → 关卡门/章节锁需自行刷新视觉。
#   本按钮会发出 save_reset 信号，关卡门(chapter_gate)等可监听并重绘。
# ============================================================
extends Area2D

# ---------- 导出变量 (编辑器配置) ----------
@export var button_color: Color = Color(0.9, 0.5, 0.3)  # 按钮颜色
@export var reset_color: Color = Color(1.0, 0.25, 0.2)   # 清除后颜色
@export var action_name: String = "delete"        # 触发动作 (Input Map 中绑定 X 键)

# save_reset: 存档已删除时触发，供关卡门/章节锁等刷新显示
signal save_reset()

# ---------- 子节点引用 ----------
@onready var name_label: Label = $NameLabel

var _player_inside: bool = false
var _is_reset: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	name_label.hide()
	if get_node("/root/Global").has_save():
		_update_label("踩上去按 X 清除")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if not _is_reset:
			_update_label("踩上去按 X 清除")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		name_label.hide()

# 玩家在区域内且按下 X → 清档
func _unhandled_input(event: InputEvent) -> void:
	if _is_reset or not _player_inside:
		return
	if event.is_action_pressed(action_name):
		_reset_save()

# 执行清档
func _reset_save() -> void:
	get_node("/root/Global").delete_save()
	_is_reset = true
	_update_label("✓ 存档已清除")
	queue_redraw()
	save_reset.emit()

# ---------- 标签 ----------

func _update_label(text: String) -> void:
	name_label.text = text
	name_label.show()

# ---------- 占位视觉 (可替换) ----------

func _draw() -> void:
	var col := reset_color if _is_reset else button_color
	# 按钮主体 (圆角方形)
	var rect := Rect2(-50.0, -50.0, 100.0, 100.0)
	for i in range(3):
		var glow_rect := Rect2(
			rect.position - Vector2.ONE * (i + 1) * 5.0,
			rect.size + Vector2.ONE * (i + 1) * 10.0
		)
		draw_rect(glow_rect, Color(col, 0.2 - i * 0.05), false, 3.0 - i)
	draw_rect(rect, Color(col, 0.15), true)
	draw_rect(rect, col, false, 4.0)
	# 图标 (清除后叉号，平时字母 X 示意按键)
	if _is_reset:
		draw_circle(Vector2.ZERO, 12.0, col)
		draw_line(Vector2(-6, -6), Vector2(6, 6), Color(1, 1, 1, 0.9), 3.0)
		draw_line(Vector2(6, -6), Vector2(-6, 6), Color(1, 1, 1, 0.9), 3.0)
	else:
		draw_line(Vector2(-8, -8), Vector2(8, 8), col, 3.0)
		draw_line(Vector2(8, -8), Vector2(-8, 8), col, 3.0)
