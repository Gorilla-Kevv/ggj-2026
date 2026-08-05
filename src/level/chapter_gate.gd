# ============================================================
# ChapterGate — 章节锁 (大厅组件)
# 放在章节区域入口，阻挡玩家进入未解锁的章节。
# 监听 Global.chapter_completed 信号：指定前置章节全部通关后自动解锁。
#
# 使用：
#   1. 配置 chapter_id (本门守卫的章节) 与 requires_chapter (需先通关的章节)
#   2. requires_chapter 留空 = 永远开放 (仅作装饰门)
#   3. 未解锁：碰撞开启 (阻挡飞行) + 红色锁定视觉 + 靠近提示"需先通关xx章"
#   4. 解锁后：碰撞关闭 (可通行) + 绿色开放视觉
#   5. 章节解锁判定依赖 Global.CHAPTER_LEVELS 注册表已填写
#
# 注意：若 requires_chapter 未在 CHAPTER_LEVELS 中登记，视为已通关 (防软锁)。
# ============================================================
extends Node2D

# ---------- 导出变量 (编辑器配置) ----------
@export var chapter_id: String = ""                  # 本门守卫的章节ID
@export var requires_chapter: String = ""            # 需先通关的章节ID (空=永远开放)
@export var locked_color: Color = Color(0.75, 0.25, 0.25)  # 锁定颜色
@export var open_color: Color = Color(0.3, 0.9, 0.5)       # 开放颜色

# ---------- 子节点引用 ----------
@onready var barrier_shape: CollisionShape2D = $Barrier/CollisionShape2D
@onready var lock_area: Area2D = $LockArea
@onready var name_label: Label = $NameLabel

var _unlocked: bool = false

func _ready() -> void:
	lock_area.body_entered.connect(_on_lock_area_body_entered)
	lock_area.body_exited.connect(_on_lock_area_body_exited)
	var global := get_node("/root/Global")
	global.chapter_completed.connect(_on_chapter_completed)
	_refresh_state()

# 刷新锁定状态：依据前置章节是否全部通关
func _refresh_state() -> void:
	var global := get_node("/root/Global")
	_unlocked = requires_chapter.is_empty() or global.is_chapter_complete(requires_chapter)
	barrier_shape.disabled = _unlocked
	queue_redraw()
	if _unlocked:
		name_label.hide()

# 前置章节通关 → 解锁本门
func _on_chapter_completed(completed_chapter_id: String) -> void:
	if completed_chapter_id == requires_chapter:
		_refresh_state()

# ---------- 提示标签 ----------

func _on_lock_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_update_label()

func _on_lock_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		name_label.hide()

# 玩家停留在提示范围内时每帧刷新 (解锁瞬间标签立即隐藏)
func _process(_delta: float) -> void:
	if not name_label.visible:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and lock_area.overlaps_body(player):
		_update_label()

# 锁定中：显示"需先通关xx章"
func _update_label() -> void:
	if _unlocked:
		name_label.hide()
		return
	var global := get_node("/root/Global")
	var text := "🔒 需先通关"
	if not requires_chapter.is_empty():
		text += "「" + global.get_chapter_name(requires_chapter) + "」"
	name_label.text = text
	name_label.show()

# ---------- 占位视觉 (可替换) ----------

func _draw() -> void:
	var col := open_color if _unlocked else locked_color
	var rect := Rect2(-25.0, -100.0, 50.0, 200.0)
	# 光晕
	for i in range(3):
		var glow_rect := Rect2(
			rect.position - Vector2.ONE * (i + 1) * 5.0,
			rect.size + Vector2.ONE * (i + 1) * 10.0
		)
		draw_rect(glow_rect, Color(col, 0.2 - i * 0.05), false, 3.0 - i)
	# 主体
	draw_rect(rect, Color(col, 0.18), true)
	draw_rect(rect, col, false, 4.0)
	if _unlocked:
		# 开放：中间开口
		var open_rect := Rect2(-8.0, -60.0, 16.0, 120.0)
		draw_rect(open_rect, Color(0.0, 0.0, 0.0, 0.4), true)
	else:
		# 锁定：横杠 + 锁眼
		draw_line(Vector2(-20, -30), Vector2(20, -30), col, 5.0)
		draw_line(Vector2(-20, 30), Vector2(20, 30), col, 5.0)
		draw_circle(Vector2(0, 0), 10.0, Color(col, 0.3))
		draw_circle(Vector2(0, 0), 4.0, col)
